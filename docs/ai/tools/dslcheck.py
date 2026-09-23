"""Parsers for the .eventstorm, .storymap, .examplemap, .ddd and .ddm notations.

Written from the EBNF in docs/ai/notations/*.md (repository revision 56c8482) and the online
DSL pages (https://doc-es.obya.ch/dsl, https://ba-cm.obya.ch/dsl, fetched 2026-09-19).
Where the online .ddm grammar is stricter than the exported one (aggregate and enum bodies
are required), the stricter form is enforced.

These parsers are an independent re-implementation, NOT the reference parsers of doc-es,
doc-sm, doc-em or ba-cm. The notation docs say "where a file and these rules disagree, the
parser is right": a clean result here is evidence, not proof. Run the files through the
boards before merging (see docs/traceability/validation-report.md).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

MAX_SOURCE = 2 * 1024 * 1024


class ParseError(Exception):
    def __init__(self, msg: str, line: int):
        super().__init__(f"line {line}: {msg}")
        self.line = line


@dataclass
class Tok:
    kind: str  # 'str' | 'word' | 'sym' | 'eof'
    val: str
    line: int


@dataclass
class Result:
    path: str
    kind: str
    errors: list = field(default_factory=list)
    warnings: list = field(default_factory=list)
    model: dict = field(default_factory=dict)


WORD = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_\-]*")


def lex_board(src: str) -> list[Tok]:
    """Lexer shared by .eventstorm, .storymap and .examplemap (Escape + Splice strings)."""
    toks, i, line, n = [], 0, 1, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c in " \t\r":
            i += 1; continue
        if src.startswith("//", i):
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == '"':
            start_line, i, buf = line, i + 1, []
            while True:
                if i >= n:
                    raise ParseError("unterminated string", start_line)
                ch = src[i]
                if ch == '"':
                    i += 1; break
                if ch == "\n":
                    raise ParseError("bare newline inside a string (unterminated string)", line)
                if ch == "\\":
                    nxt = src[i + 1] if i + 1 < n else ""
                    if nxt in ('"', "\\"):
                        buf.append(nxt); i += 2; continue
                    if nxt == "n":
                        buf.append("\n"); i += 2; continue
                    if nxt == "t":
                        buf.append("\t"); i += 2; continue
                    if nxt == "\n" or (nxt == "\r" and src[i + 2:i + 3] == "\n"):
                        i += 2 if nxt == "\n" else 3
                        line += 1
                        while i < n and src[i] in " \t":
                            i += 1
                        buf.append("\n")  # a splice is a line break in the value
                        continue
                    raise ParseError(f"invalid escape \\{nxt}", line)
                buf.append(ch); i += 1
            toks.append(Tok("str", "".join(buf), start_line)); continue
        if c in "{}@#~+":
            toks.append(Tok("sym", c, line)); i += 1; continue
        m = WORD.match(src, i)
        if m:
            toks.append(Tok("word", m.group(0), line)); i = m.end(); continue
        raise ParseError(f"unexpected character {c!r}", line)
    toks.append(Tok("eof", "", line))
    return toks


def lex_ddd(src: str) -> list[Tok]:
    """Lexer for .ddd / .ddm: strings are any chars except '"', may wrap (joined with a space)."""
    toks, i, line, n = [], 0, 1, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c in " \t\r":
            i += 1; continue
        if src.startswith("//", i):
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == '"':
            j = src.find('"', i + 1)
            if j < 0:
                raise ParseError("unterminated string", line)
            raw = src[i + 1:j]
            val = " ".join(part.strip() for part in raw.split("\n")) if "\n" in raw else raw
            toks.append(Tok("str", val, line)); line += raw.count("\n"); i = j + 1; continue
        if src.startswith("<->", i):
            toks.append(Tok("sym", "<->", line)); i += 3; continue
        if src.startswith("->", i):
            toks.append(Tok("sym", "->", line)); i += 2; continue
        if c in "{}:/":
            toks.append(Tok("sym", c, line)); i += 1; continue
        m = WORD.match(src, i)
        if m:
            toks.append(Tok("word", m.group(0), line)); i = m.end(); continue
        raise ParseError(f"unexpected character {c!r}", line)
    toks.append(Tok("eof", "", line))
    return toks


class P:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    @property
    def cur(self) -> Tok:
        return self.t[self.i]

    def at(self, kind, val=None) -> bool:
        c = self.cur
        return c.kind == kind and (val is None or c.val == val)

    def eat(self, kind, val=None, what=None) -> Tok:
        if not self.at(kind, val):
            exp = what or (val if val else kind)
            raise ParseError(f"expected {exp}, found {self.cur.val or self.cur.kind!r}", self.cur.line)
        tok = self.cur; self.i += 1; return tok

    def opt(self, kind, val=None):
        if self.at(kind, val):
            return self.eat(kind, val)
        return None


def _tag(p: P, tags: list, errors: list):
    p.eat("sym", "+")
    tok = p.cur
    if tok.kind not in ("word", "str"):
        raise ParseError("expected tag after '+'", tok.line)
    p.i += 1
    low = [t.lower() for t in tags]
    if tok.val.lower() in low:
        errors.append(f"line {tok.line}: tag +{tok.val} repeated on one card (case-insensitive)")
    tags.append(tok.val)


def _notes(p: P, allowed=("note",)):
    notes = []
    if p.opt("sym", "{"):
        while not p.at("sym", "}"):
            kw = p.eat("word", what="note").val
            if kw not in allowed:
                raise ParseError(f"'{kw}' not allowed here", p.t[p.i - 1].line)
            notes.append(p.eat("str").val)
        p.eat("sym", "}")
    return notes


# ---------------------------------------------------------------- .eventstorm
ES_KINDS = {"event", "actor", "system", "hotspot", "opportunity", "context",
            "command", "policy", "readmodel", "aggregate", "ui"}


def parse_eventstorm(src: str, path="") -> Result:
    r = Result(path, "eventstorm")
    p = P(lex_board(src))
    cards, lanes, product_count = [], [], 0
    title = None

    def card(lane):
        kind = p.eat("word").val
        tline = p.t[p.i - 1].line
        text = p.eat("str").val
        col, tags = None, []
        while p.at("sym", "@") or p.at("sym", "+"):
            if p.opt("sym", "@"):
                w = p.eat("word", what="integer column")
                if not w.val.isdigit():
                    raise ParseError("column must be an integer", w.line)
                if int(w.val) < 1:
                    raise ParseError("columns are one-based; @0 and below are refused", w.line)
                if col is not None:
                    r.errors.append(f"line {w.line}: second column on one card")
                col = int(w.val)
            else:
                _tag(p, tags, r.errors)
        notes = _notes(p)
        cards.append(dict(kind=kind, text=text, col=col, tags=tags, lane=lane, line=tline, notes=notes))

    if not p.at("eof"):
        p.eat("word", "eventstorm")
        title = p.eat("str").val
        if p.opt("sym", "{"):
            while not p.at("sym", "}"):
                w = p.cur
                if w.kind != "word":
                    raise ParseError("expected an entry", w.line)
                if w.val == "product":
                    p.i += 1; p.eat("str"); product_count += 1
                elif w.val == "lane":
                    p.i += 1; lname = p.eat("str").val; lanes.append(lname)
                    if p.opt("sym", "{"):
                        while not p.at("sym", "}"):
                            if p.at("word", "note"):
                                p.i += 1; p.eat("str")
                            elif p.cur.kind == "word" and p.cur.val in ES_KINDS:
                                card(lname)
                            else:
                                raise ParseError(f"unexpected '{p.cur.val}' in lane", p.cur.line)
                        p.eat("sym", "}")
                elif w.val == "note":
                    p.i += 1; p.eat("str")
                elif w.val == "level":
                    p.i += 1; r.warnings.append(f"line {w.line}: legacy 'level' line — never write one")
                    if p.at("word"):
                        p.i += 1
                elif w.val in ES_KINDS:
                    card("")
                else:
                    raise ParseError(f"unknown keyword '{w.val}'", w.line)
            p.eat("sym", "}")
    p.eat("eof", what="end of file (one eventstorm block per file)")
    if product_count > 1:
        r.errors.append("product declared more than once")
    r.model = dict(title=title, lanes=lanes, cards=cards)
    return r


# ---------------------------------------------------------------- .storymap / .examplemap shared
STATUS = {"open", "analysing", "ready", "in-progress", "done", "closed"}


def _annotations(p: P, allowed: set, r: Result, where: str):
    ann = dict(release=None, ticket=None, status=None, tags=[])
    while p.cur.kind == "sym" and p.cur.val in "@#~+":
        s = p.cur
        name = {"@": "release", "#": "ticket", "~": "status", "+": "tag"}[s.val]
        if name not in allowed:
            raise ParseError(f"'{s.val}' not allowed on {where}", s.line)
        if name == "tag":
            _tag(p, ann["tags"], r.errors); continue
        p.i += 1
        v = p.cur
        if v.kind not in ("word", "str"):
            raise ParseError(f"expected value after '{s.val}'", v.line)
        p.i += 1
        if name == "status" and v.val not in STATUS:
            raise ParseError(f"unknown status ~{v.val}", v.line)
        if ann[name] is not None:
            r.errors.append(f"line {s.line}: second {name} on one {where}")
        ann[name] = v.val
    return ann


def _delivery(p: P, r: Result, allow_points: bool, legacy: bool):
    line = p.cur.line
    p.i += 1
    title = p.eat("str").val
    kind = "release"
    if not legacy:
        kind = p.eat("word", what="sprint | release").val
        if kind not in ("sprint", "release"):
            raise ParseError("delivery kind must be sprint or release", line)
    else:
        r.warnings.append(f"line {line}: legacy 'release \"…\"' spelling — write 'delivery \"…\" release'")
    while p.at("sym", "#") or (allow_points and p.at("word", "points")):
        if p.opt("sym", "#"):
            if p.cur.kind not in ("word", "str"):
                raise ParseError("expected ticket", p.cur.line)
            p.i += 1
        else:
            p.i += 1
            w = p.eat("word")
            if not w.val.isdigit():
                raise ParseError("points must be an integer", w.line)
            if kind != "sprint":
                r.errors.append(f"line {w.line}: points on a release are refused")
    _notes(p)
    return dict(title=title, kind=kind, line=line)


def parse_storymap(src: str, path="") -> Result:
    r = Result(path, "storymap")
    p = P(lex_board(src))
    p.eat("word", "storymap")
    title = p.eat("str").val
    deliveries, activities, counts = [], [], {"product": 0, "space": 0}
    if p.opt("sym", "{"):
        while not p.at("sym", "}"):
            w = p.eat("word", what="entry")
            if w.val in ("product", "space"):
                p.eat("str"); counts[w.val] += 1
            elif w.val == "delivery":
                p.i -= 1; deliveries.append(_delivery(p, r, False, False))
            elif w.val == "release":
                p.i -= 1; deliveries.append(_delivery(p, r, False, True))
            elif w.val == "note":
                p.eat("str")
            elif w.val == "activity":
                a = dict(title=p.eat("str").val, line=w.line, personas=[], steps=[])
                a.update(_annotations(p, {"ticket", "status", "tag"}, r, "activity"))
                if p.opt("sym", "{"):
                    while not p.at("sym", "}"):
                        k = p.eat("word", what="persona | step | note")
                        if k.val == "persona":
                            a["personas"].append(p.eat("str").val)
                        elif k.val == "note":
                            p.eat("str")
                        elif k.val == "step":
                            s = dict(title=p.eat("str").val, line=k.line, stories=[])
                            s.update(_annotations(p, {"ticket", "status", "tag"}, r, "step"))
                            if p.opt("sym", "{"):
                                while not p.at("sym", "}"):
                                    k2 = p.eat("word", what="story | note")
                                    if k2.val == "note":
                                        p.eat("str")
                                    elif k2.val == "story":
                                        st = dict(title=p.eat("str").val, line=k2.line, clauses={})
                                        st.update(_annotations(p, {"release", "ticket", "status", "tag"}, r, "story"))
                                        if p.opt("sym", "{"):
                                            while not p.at("sym", "}"):
                                                k3 = p.eat("word", what="as | want | so | note")
                                                if k3.val not in ("as", "want", "so", "note"):
                                                    raise ParseError(f"'{k3.val}' not allowed in a story", k3.line)
                                                v = p.eat("str").val
                                                if k3.val != "note":
                                                    st["clauses"][k3.val] = v
                                            p.eat("sym", "}")
                                        s["stories"].append(st)
                                    else:
                                        raise ParseError(f"'{k2.val}' not allowed in a step", k2.line)
                                p.eat("sym", "}")
                            a["steps"].append(s)
                        else:
                            raise ParseError(f"'{k.val}' not allowed in an activity", k.line)
                    p.eat("sym", "}")
                activities.append(a)
            else:
                raise ParseError(f"unknown keyword '{w.val}'", w.line)
        p.eat("sym", "}")
    p.eat("eof", what="end of file")
    for k, v in counts.items():
        if v > 1:
            r.errors.append(f"{k} declared more than once")
    titles = [d["title"] for d in deliveries]
    for t in set(titles):
        if titles.count(t) > 1:
            r.errors.append(f"two deliveries share the title {t!r}")
    for a in activities:
        for s in a["steps"]:
            for st in s["stories"]:
                if st["release"] is not None and st["release"] not in titles:
                    r.errors.append(f"line {st['line']}: @{st['release']!r} names no declared delivery")
                who = st["clauses"].get("as")
                if who is not None and who not in a["personas"]:
                    r.errors.append(f"line {st['line']}: story as {who!r} is not a persona of activity {a['title']!r}")
    r.model = dict(title=title, deliveries=deliveries, activities=activities)
    return r


def parse_examplemap(src: str, path="") -> Result:
    r = Result(path, "examplemap")
    p = P(lex_board(src))
    p.eat("word", "examplemap")
    title = p.eat("str").val
    deliveries, stories, rules, counts = [], [], [], {"product": 0, "space": 0}

    def question(k):
        q = dict(text=p.eat("str").val, line=k.line)
        q.update(_annotations(p, {"tag"}, r, "question"))
        _notes(p)
        return q

    if p.opt("sym", "{"):
        while not p.at("sym", "}"):
            w = p.eat("word", what="entry")
            if w.val in ("product", "space"):
                p.eat("str"); counts[w.val] += 1
            elif w.val == "delivery":
                p.i -= 1; deliveries.append(_delivery(p, r, True, False))
            elif w.val == "note":
                p.eat("str")
            elif w.val == "story":
                st = dict(title=p.eat("str").val, line=w.line, clauses={}, questions=[])
                st.update(_annotations(p, {"release", "ticket", "status", "tag"}, r, "story"))
                if p.opt("sym", "{"):
                    while not p.at("sym", "}"):
                        k = p.eat("word")
                        if k.val == "question":
                            st["questions"].append(question(k))
                        elif k.val in ("as", "want", "so", "note"):
                            v = p.eat("str").val
                            if k.val != "note":
                                st["clauses"][k.val] = v
                        else:
                            raise ParseError(f"'{k.val}' not allowed in the story", k.line)
                    p.eat("sym", "}")
                stories.append(st)
            elif w.val == "rule":
                ru = dict(text=p.eat("str").val, line=w.line, examples=[], questions=[])
                ru.update(_annotations(p, {"tag"}, r, "rule"))
                if p.opt("sym", "{"):
                    while not p.at("sym", "}"):
                        k = p.eat("word")
                        if k.val == "question":
                            ru["questions"].append(question(k))
                        elif k.val == "note":
                            p.eat("str")
                        elif k.val == "example":
                            ex = dict(title=p.eat("str").val, line=k.line, steps=[])
                            ex.update(_annotations(p, {"release", "tag"}, r, "example"))
                            if p.opt("sym", "{"):
                                while not p.at("sym", "}"):
                                    k2 = p.eat("word")
                                    if k2.val in ("given", "when", "then"):
                                        ex["steps"].append((k2.val, " ".join(p.eat("str").val.split())))
                                    elif k2.val == "note":
                                        p.eat("str")
                                    else:
                                        raise ParseError(f"'{k2.val}' not allowed in an example", k2.line)
                                p.eat("sym", "}")
                            ru["examples"].append(ex)
                        else:
                            raise ParseError(f"'{k.val}' not allowed in a rule", k.line)
                    p.eat("sym", "}")
                rules.append(ru)
            else:
                raise ParseError(f"unknown keyword '{w.val}'", w.line)
        p.eat("sym", "}")
    p.eat("eof", what="end of file")
    if len(stories) > 1:
        r.errors.append("more than one story on the map")
    for k, v in counts.items():
        if v > 1:
            r.errors.append(f"{k} declared more than once")
    titles = [d["title"] for d in deliveries]
    for t in set(titles):
        if titles.count(t) > 1:
            r.errors.append(f"two deliveries share the title {t!r}")
    refs = [(s["release"], s["line"]) for s in stories]
    refs += [(e["release"], e["line"]) for ru in rules for e in ru["examples"]]
    for rel, line in refs:
        if rel is not None and rel not in titles:
            r.errors.append(f"line {line}: @{rel!r} names no declared delivery")
    for ru in rules:
        if not ru["examples"]:
            r.warnings.append(f"line {ru['line']}: rule with no examples — '{ru['text'][:60]}'")
    r.model = dict(title=title, deliveries=deliveries, story=stories[0] if stories else None, rules=rules)
    return r


# ---------------------------------------------------------------- .ddd
MUTUAL = {"partnership", "shared-kernel", "separate-ways"}
DIRECTED = {"customer-supplier", "conformist", "anticorruption-layer",
            "open-host-service", "published-language"}
PATTERNS = MUTUAL | DIRECTED | {"big-ball-of-mud"}


def parse_ddd(src: str, path="") -> Result:
    r = Result(path, "ddd")
    p = P(lex_ddd(src))
    names, contexts, rels, domains = {}, {}, [], []

    def reg(name, kind, line):
        if name in names:
            r.errors.append(f"line {line}: name {name!r} used twice (names are identities)")
        names[name] = kind

    def ctx(parent_dom, parent_sub):
        line = p.cur.line
        p.i += 1
        name = p.eat("str").val
        reg(name, "context", line)
        c = dict(name=name, domain=parent_dom, subdomain=parent_sub, language=[], aggregates=[],
                 owner=None, status=None, intent=None, serves=[], line=line)
        if p.opt("sym", "{"):
            while not p.at("sym", "}"):
                k = p.eat("word")
                if k.val in ("intent", "owner", "serves"):
                    v = p.eat("str").val
                    if k.val == "serves":
                        c["serves"].append(v)
                    else:
                        c[k.val] = v
                elif k.val in ("language", "aggregate"):
                    lst = c["language" if k.val == "language" else "aggregates"]
                    lst.append(p.eat("str").val)
                    while p.at("str"):
                        lst.append(p.eat("str").val)
                elif k.val == "status":
                    v = p.eat("word").val
                    if v not in ("modelled", "drafted", "unmodelled"):
                        raise ParseError(f"unknown status {v}", k.line)
                    c["status"] = v
                else:
                    raise ParseError(f"'{k.val}' not allowed in a context", k.line)
            p.eat("sym", "}")
        contexts[name] = c

    p.eat("word", "map")
    title = p.eat("str").val
    p.eat("sym", "{", what="'{' (the map's own braces are required)")
    while not p.at("sym", "}"):
        if p.at("word", "domain"):
            line = p.cur.line; p.i += 1
            dname = p.eat("str").val; reg(dname, "domain", line)
            d = dict(name=dname, subdomains=[])
            domains.append(d)
            if p.opt("sym", "{"):
                while not p.at("sym", "}"):
                    if p.at("word", "context"):
                        ctx(dname, None)
                    elif p.at("word", "subdomain"):
                        sl = p.cur.line; p.i += 1
                        cls = p.eat("word").val
                        if cls not in ("core", "supporting", "generic"):
                            raise ParseError(f"unknown classification {cls}", sl)
                        sname = p.eat("str").val; reg(sname, "subdomain", sl)
                        d["subdomains"].append(dict(name=sname, cls=cls))
                        if p.opt("sym", "{"):
                            while not p.at("sym", "}"):
                                if p.at("word", "context"):
                                    ctx(dname, sname)
                                else:
                                    k = p.eat("word")
                                    if k.val not in ("intent", "owner"):
                                        raise ParseError(f"'{k.val}' not allowed in a subdomain", k.line)
                                    p.eat("str")
                            p.eat("sym", "}")
                    else:
                        k = p.eat("word")
                        if k.val not in ("intent", "owner"):
                            raise ParseError(f"'{k.val}' not allowed in a domain", k.line)
                        p.eat("str")
                p.eat("sym", "}")
        elif p.at("str"):
            line = p.cur.line
            a = p.eat("str").val
            arrow = p.eat("sym", what="-> or <->").val
            if arrow not in ("->", "<->"):
                raise ParseError("expected -> or <->", line)
            b = p.eat("str").val
            p.eat("sym", ":")
            pats = [p.eat("word").val]
            if p.opt("sym", "/"):
                pats.append(p.eat("word").val)
            rel = dict(up=a, down=b, arrow=arrow, patterns=pats, line=line, exchange=[], because=[])
            if p.opt("sym", "{"):
                while not p.at("sym", "}"):
                    k = p.eat("word")
                    if k.val not in ("exchange", "because"):
                        raise ParseError(f"'{k.val}' not allowed in a relationship", k.line)
                    rel[k.val].append(p.eat("str").val)
                p.eat("sym", "}")
            for pat in pats:
                if pat not in PATTERNS:
                    r.errors.append(f"line {line}: unknown pattern {pat}")
                elif pat in MUTUAL and arrow == "->":
                    r.errors.append(f"line {line}: {pat} is mutual and may not be written with ->")
                elif pat in DIRECTED and arrow == "<->":
                    r.errors.append(f"line {line}: {pat} requires a direction (->)")
            rels.append(rel)
        else:
            raise ParseError(f"unexpected {p.cur.val!r}", p.cur.line)
    p.eat("sym", "}")
    p.eat("eof", what="end of file")
    for rel in rels:
        for end in (rel["up"], rel["down"]):
            if end not in contexts:
                r.errors.append(f"line {rel['line']}: relationship end {end!r} is not a context")
        if not rel["because"]:
            r.warnings.append(f"line {rel['line']}: relationship {rel['up']} {rel['arrow']} {rel['down']} has no 'because'")
    for c in contexts.values():
        if not c["language"]:
            r.warnings.append(f"line {c['line']}: context {c['name']!r} has no language — it has no edge")
        if not c["owner"]:
            r.warnings.append(f"line {c['line']}: context {c['name']!r} has no owner")
    subs = [s for d in domains for s in d["subdomains"]]
    if sum(1 for s in subs if s["cls"] == "core") > 3:
        r.warnings.append("more than three core subdomains")
    r.model = dict(title=title, domains=domains, contexts=contexts, relationships=rels)
    return r


# ---------------------------------------------------------------- .ddm
def parse_ddm(src: str, path="") -> Result:
    r = Result(path, "ddm")
    p = P(lex_ddd(src))
    head = p.eat("word").val
    if head not in ("context", "model"):
        raise ParseError("file must start with 'context'", 1)
    if head == "model":
        r.warnings.append("'model' header — write 'context'")
    cname = p.eat("str").val
    p.eat("sym", "{", what="'{' (the model's braces are required)")
    elements = {}  # name -> dict(kind, aggregate, links, line)
    aggregates = []

    def register(name, kind, agg, line):
        if name in elements:
            prev = elements[name]
            # aggregate named after its root is the idiom, not a collision
            idiom = {prev["kind"], kind} == {"aggregate", "entity"} and (prev.get("aggregate") == name or agg == name)
            if not idiom:
                r.errors.append(f"line {line}: name {name!r} not unique in the model")
                return
            if kind == "aggregate":
                return
        elements[name] = dict(kind=kind, aggregate=agg, line=line, links=[])

    def body_links(el_name, allow_id, agg):
        el = elements.get(el_name)
        if p.opt("sym", "{"):
            while not p.at("sym", "}"):
                k = p.eat("word")
                if k.val == "id":
                    if not allow_id:
                        raise ParseError("a value object may not carry an id", k.line)
                    p.eat("str")
                elif k.val == "attribute":
                    p.eat("str"); p.eat("sym", ":"); p.eat("str")
                elif k.val in ("contains", "embeds", "references"):
                    target = p.eat("str").val
                    mult = "one"
                    if p.at("word") and p.cur.val in ("one", "optional", "many", "at-least-one"):
                        mult = p.eat("word").val
                    if el is not None:
                        el["links"].append((k.val, target, mult, k.line, agg))
                else:
                    raise ParseError(f"'{k.val}' not allowed here", k.line)
            p.eat("sym", "}")

    def value(agg):
        line = p.cur.line; p.i += 1
        name = p.eat("str").val
        register(name, "value", agg, line)
        body_links(name, False, agg)

    def enum(agg):
        line = p.cur.line; p.i += 1
        name = p.eat("str").val
        register(name, "enum", agg, line)
        p.eat("sym", "{", what="'{' (an enum body is required)")
        p.eat("str", what="at least one enum value")
        while p.at("str"):
            p.i += 1
        p.eat("sym", "}")

    while not p.at("sym", "}"):
        if p.at("word", "aggregate"):
            line = p.cur.line; p.i += 1
            aname = p.eat("str").val
            register(aname, "aggregate", aname, line)
            agg = dict(name=aname, invariants=[], roots=[], line=line, intent=None)
            p.eat("sym", "{", what="'{' (an aggregate body is required)")
            while not p.at("sym", "}"):
                if p.at("word", "intent"):
                    p.i += 1; agg["intent"] = p.eat("str").val
                elif p.at("word", "invariant"):
                    p.i += 1; agg["invariants"].append(p.eat("str").val)
                elif p.at("word", "root") or p.at("word", "entity"):
                    is_root = bool(p.opt("word", "root"))
                    el = p.eat("word", "entity")
                    ename = p.eat("str").val
                    register(ename, "entity", aname, el.line)
                    if is_root:
                        agg["roots"].append(ename)
                    body_links(ename, True, aname)
                elif p.at("word", "value"):
                    value(aname)
                elif p.at("word", "enum"):
                    enum(aname)
                else:
                    raise ParseError(f"'{p.cur.val}' not allowed in an aggregate", p.cur.line)
            p.eat("sym", "}")
            aggregates.append(agg)
        elif p.at("word", "value"):
            value(None)
        elif p.at("word", "enum"):
            enum(None)
        else:
            raise ParseError(f"unexpected {p.cur.val!r}", p.cur.line)
    p.eat("sym", "}")
    p.eat("eof", what="end of file")

    embedded = set()
    for agg in aggregates:
        if len(agg["roots"]) != 1:
            r.errors.append(f"line {agg['line']}: aggregate {agg['name']!r} must have exactly one root (has {len(agg['roots'])})")
        if not agg["invariants"]:
            r.warnings.append(f"line {agg['line']}: aggregate {agg['name']!r} has no invariant")
    agg_names = {a["name"] for a in aggregates}
    for name, el in elements.items():
        for (link, target, mult, line, agg) in el["links"]:
            t = elements.get(target)
            if link == "references":
                if target not in agg_names:
                    r.errors.append(f"line {line}: references {target!r} — must name an aggregate in this model")
                continue
            if t is None:
                r.errors.append(f"line {line}: {link} {target!r} — unknown name")
                continue
            if link == "contains":
                if t["kind"] != "entity" or t["aggregate"] != agg:
                    r.errors.append(f"line {line}: contains {target!r} — must be an entity in the same aggregate")
            elif link == "embeds":
                if t["kind"] not in ("value", "enum") or t["aggregate"] not in (agg, None):
                    r.errors.append(f"line {line}: embeds {target!r} — must be a value/enum in the same aggregate or shared")
                embedded.add(target)
    for name, el in elements.items():
        if el["kind"] in ("value",) and el["aggregate"] is None and name not in embedded:
            r.warnings.append(f"line {el['line']}: shared value {name!r} is embedded by nothing")
    r.model = dict(context=cname, aggregates=aggregates, elements=elements)
    return r


PARSERS = {
    ".eventstorm": parse_eventstorm,
    ".storymap": parse_storymap,
    ".examplemap": parse_examplemap,
    ".ddd": parse_ddd,
    ".ddm": parse_ddm,
}


def parse_file(path: str) -> Result:
    import os
    ext = os.path.splitext(path)[1]
    with open(path, "rb") as fh:
        raw = fh.read()
    if len(raw) > MAX_SOURCE:
        res = Result(path, ext[1:]); res.errors.append("source over 2 MB refused"); return res
    try:
        return PARSERS[ext](raw.decode("utf-8"), path)
    except ParseError as e:
        res = Result(path, ext[1:]); res.errors.append(str(e)); return res
