#!/usr/bin/env python3
"""Validate the SDLC artefacts of this repository.

Checks, per docs/ai/20-review-and-delivery-policy.md "Validation" and
docs/ai/10-artifact-contract.md "Consistency":
  1. every notation file parses (tools/sdlc/dsl.py);
  2. identifier uniqueness;
  3. referential integrity along docs/traceability/manifest.yaml;
  4. consistency findings the contract asks to report (stories without journey context, rules
     without examples, components without context ownership, interfaces without behavioural
     justification, delivery items without evidence, unknown ledger ids);
  5. projections (feature files) are up to date with their source example maps;
  6. optionally (--external) the third-party validators: LikeC4, PlantUML, OpenAPI, AsyncAPI.

Usage:
  python3 tools/sdlc/validate.py [--external] [--json out.json]
External tools are located with env vars LIKEC4 (command), PLANTUML_JAR, OPENAPI_VALIDATOR
(command), REDOCLY (command), ASYNCAPI_VALIDATOR (command taking a file), and LIKEC4_JSON (path
to a `likec4 export json` output, used for component checks). Missing tools are reported as
"not run", never as passed.

Requires PyYAML.
"""
from __future__ import annotations

import glob
import json
import os
import re
import shlex
import subprocess
import sys

import yaml

sys.path.insert(0, os.path.dirname(__file__))
import dsl  # noqa: E402
import examplemap_to_feature  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


class Report:
    def __init__(self):
        self.items = []  # (level, check, message)

    def add(self, level, check, msg):
        self.items.append((level, check, msg))

    def err(self, check, msg):
        self.add("ERROR", check, msg)

    def warn(self, check, msg):
        self.add("WARNING", check, msg)

    def info(self, check, msg):
        self.add("INFO", check, msg)


def rel(p):
    return os.path.relpath(p, ROOT)


def main() -> int:
    args = sys.argv[1:]
    external = "--external" in args
    json_out = args[args.index("--json") + 1] if "--json" in args else None
    R = Report()
    stats = {}

    # ------------------------------------------------------------------ 1. parse
    parsed = {}
    patterns = ["docs/**/*.eventstorm", "docs/**/*.storymap", "docs/**/*.examplemap",
                "docs/**/*.ddd", "docs/**/*.ddm"]
    for pat in patterns:
        for f in sorted(glob.glob(os.path.join(ROOT, pat), recursive=True)):
            res = dsl.parse_file(f)
            parsed[rel(f)] = res
            for e in res.errors:
                R.err("dsl", f"{rel(f)}: {e}")
            for w in res.warnings:
                R.warn("dsl", f"{rel(f)}: {w}")
    stats["notation_files"] = len(parsed)
    by_kind = lambda k: {p: r for p, r in parsed.items() if r.kind == k and not r.errors}

    storms, smaps, emaps = by_kind("eventstorm"), by_kind("storymap"), by_kind("examplemap")
    ddds, ddms = by_kind("ddd"), by_kind("ddm")

    man_path = os.path.join(ROOT, "docs/traceability/manifest.yaml")
    man = yaml.safe_load(open(man_path))

    # ------------------------------------------------------------------ ledger ids
    ledger_text = open(os.path.join(ROOT, "docs/traceability/questions-and-assumptions.md")).read()
    design_text = open(os.path.join(ROOT, "docs/system/README.md")).read()
    analysis_text = open(os.path.join(ROOT, "docs/journeys/problem-analysis.md")).read()
    defined = set(re.findall(r"^\| `((?:Q|A|H)-\d+)`", ledger_text, re.M))
    defined |= set(re.findall(r"^### (D-\d+)", design_text, re.M))
    defined |= set(re.findall(r"^\| `(D-\d+)`", design_text, re.M))
    defined |= set(re.findall(r"^\| `(RSK-\d+)`", design_text, re.M))
    defined |= set(re.findall(r"^\| `(C-\d+)`", analysis_text, re.M))
    stats["ledger_ids"] = len(defined)

    # ------------------------------------------------------------------ service blueprint (SCR-*, RM-*)
    bp_path = os.path.join(ROOT, man["artefacts"]["service_blueprint"])
    bp_text = open(bp_path).read()
    screens, read_models = {}, {}
    for line in bp_text.splitlines():
        m = re.match(r"^\| `((?:SCR|RM)-[A-Z0-9-]+)` \|(.*)$", line)
        if not m:
            continue
        rid, rest = m.group(1), m.group(2)
        target = screens if rid.startswith("SCR-") else read_models
        if rid in target:
            R.err("ids", f"{rid} defined twice in the service blueprint")
        managed = re.findall(r"`(CMP-[A-Z0-9-]+)`", rest)
        target[rid] = dict(managed=managed[0] if managed else None, refs=set())
    stats.update(screens=len(screens), read_models=len(read_models))

    def ux_ref(rid, where):
        pool = screens if rid.startswith("SCR-") else read_models
        if rid not in pool:
            R.err("refs", f"{where}: {rid} is not defined in the service blueprint")
        else:
            pool[rid]["refs"].add(where.split(":")[0])

    # ------------------------------------------------------------------ 2. uniqueness + inventories
    # pivotal events
    evt_defs = {}
    big = parsed.get(man["artefacts"]["big_picture"])
    for card in (big.model["cards"] if big and not big.errors else []):
        for t in card["tags"]:
            if t.upper().startswith("EVT-"):
                if "pivotal" not in [x.lower() for x in card["tags"]]:
                    R.warn("ids", f"{t} is not marked +pivotal on the Big Picture")
                if t in evt_defs:
                    R.err("ids", f"pivotal event id {t} defined twice")
                evt_defs[t] = card["text"]
    pivotal_count = sum(1 for c in big.model["cards"] if "pivotal" in [x.lower() for x in c["tags"]]) if big else 0
    stats["pivotal_events"] = pivotal_count
    if big and pivotal_count > 8:
        R.warn("doctrine", f"{pivotal_count} pivotal events on the Big Picture — mark them sparingly")
    for p, r in storms.items():
        for c in r.model["cards"]:
            for t in c["tags"]:
                if re.match(r"^(SCR|RM)-", t):
                    ux_ref(t, f"{p}:{c['line']}")
                    want = "ui" if t.startswith("SCR-") else "readmodel"
                    if c["kind"] != want:
                        R.err("refs", f"{p}:{c['line']}: {t} sits on a '{c['kind']}' card, expected '{want}'")
            for t in c["tags"]:
                if t.upper().startswith("EVT-") and t not in evt_defs:
                    R.err("refs", f"{p}: {t} is not a pivotal event of the Big Picture")

    # hotspots
    hot = 0
    for p, r in storms.items():
        for c in r.model["cards"]:
            if c["kind"] != "hotspot":
                continue
            hot += 1
            refs = [t for t in c["tags"] if re.match(r"^(Q|D)-\d+$", t)]
            if not refs:
                R.warn("ledger", f"{p}:{c['line']}: hotspot has no ledger id (+Q-xx): {c['text'][:60]}")
            for t in refs:
                if t not in defined:
                    R.err("ledger", f"{p}:{c['line']}: {t} not in the ledger")
            if not any(t.lower().startswith("ask ") for t in c["tags"]):
                R.warn("doctrine", f"{p}:{c['line']}: hotspot names nobody who could settle it (+\"ask …\")")
        if not any(c["kind"] == "hotspot" for c in r.model["cards"]):
            R.warn("doctrine", f"{p}: a wall with no hotspot has not been honest yet")
    stats["hotspots"] = hot

    # story map
    smap_path = man["artefacts"]["story_map"]
    smap = smaps.get(smap_path)
    stories, story_act = {}, {}
    activities = {}
    if smap:
        dmap = {v["storymap_delivery"]: k for k, v in man["delivery_packs"].items()}
        for a in smap.model["activities"]:
            actv = [t for t in a["tags"] if t.upper().startswith("ACTV-")]
            evts = [t for t in a["tags"] if t.upper().startswith("EVT-")]
            aid = actv[0] if actv else a["title"]
            activities[aid] = dict(evt=evts[0] if evts else None, title=a["title"], stories=[])
            if not evts:
                R.warn("consistency", f"activity '{a['title']}' carries no pivotal event — stories under it lack journey context")
            for e in evts:
                if e not in evt_defs:
                    R.err("refs", f"activity '{a['title']}': {e} is not a Big Picture pivotal event")
            for s in a["steps"]:
                if not s["stories"]:
                    R.info("doctrine", f"step '{s['title']}' has no stories")
                for st in s["stories"]:
                    sids = [t for t in st["tags"] if t.upper().startswith("STORY-")]
                    if len(sids) != 1:
                        R.err("ids", f"story '{st['title']}' must carry exactly one STORY- tag")
                        continue
                    sid = sids[0]
                    if sid in stories:
                        R.err("ids", f"story id {sid} used twice")
                    if st["ticket"] or st["status"]:
                        R.warn("governance", f"{sid}: carries a #ticket or ~status — owned by the ticketing system")
                    st["delivery_pack"] = dmap.get(st["release"])
                    stories[sid] = st
                    story_act[sid] = aid
                    activities[aid]["stories"].append(sid)
                    for k in ("as", "want", "so"):
                        if k not in st["clauses"]:
                            R.warn("doctrine", f"{sid}: missing '{k}' clause")
        # slices — bands are cumulative in declaration order (the MVP ships what the skeleton shipped)
        band_order = [d["title"] for d in smap.model["deliveries"]]
        for dname, pack in dmap.items():
            upto = set(band_order[:band_order.index(dname) + 1]) if dname in band_order else {dname}
            empty = [a["title"] for a in activities.values()
                     if not any(stories[s]["release"] in upto for s in a["stories"])]
            if empty:
                R.warn("doctrine", f"delivery '{dname}' ({pack}) leaves activities empty: {', '.join(empty)}")
        skel = {story_act[s] for s, st in stories.items() if "skeleton" in [t.lower() for t in st["tags"]]}
        missing = [a["title"] for k, a in activities.items() if k not in skel]
        if missing:
            R.warn("doctrine", f"+skeleton does not reach: {', '.join(missing)}")
    stats["stories"] = len(stories)
    stats["scheduled_stories"] = sum(1 for s in stories.values() if s["release"])

    # example maps
    rules, emap_story = {}, {}
    ex_count = q_count = 0
    for p, r in emaps.items():
        st = r.model["story"]
        sid = next((t for t in (st["tags"] if st else []) if t.upper().startswith("STORY-")), None)
        emap_story[p] = sid
        if sid is None:
            R.err("refs", f"{p}: story card carries no STORY- tag")
        elif sid not in stories:
            R.err("refs", f"{p}: {sid} is not on the story map")
        elif st["title"] != stories[sid]["title"]:
            R.warn("vocabulary", f"{p}: story title differs from the story map ('{st['title']}' vs '{stories[sid]['title']}')")
        q_count += len(st["questions"]) if st else 0
        for ru in r.model["rules"]:
            rid = next((t for t in ru["tags"] if t.upper().startswith("R-")), None)
            if rid is None:
                R.warn("ids", f"{p}:{ru['line']}: rule without an R- id")
                continue
            if rid in rules:
                R.err("ids", f"rule id {rid} used twice")
            rules[rid] = dict(file=p, story=sid, examples=ru["examples"])
            ex_count += len(ru["examples"])
            q_count += len(ru["questions"])
            if ru["examples"] and all("edge-case" not in [t.lower() for t in e["tags"]] for e in ru["examples"]) and len(ru["examples"]) > 1:
                R.info("doctrine", f"{rid}: every example is a happy path — probe the edges")
            if len(ru["examples"]) > 4:
                R.info("doctrine", f"{rid}: {len(ru['examples'])} examples — possibly two rules in one")
        n_rules = len(r.model["rules"])
        if n_rules >= 6:
            R.warn("readiness", f"{p}: {n_rules} rules — the story is probably too big; split along the rules")
        nq = (len(st["questions"]) if st else 0) + sum(len(x["questions"]) for x in r.model["rules"])
        if nq >= 4:
            R.info("readiness", f"{p}: {nq} red cards — not ready to estimate")
        # example release vs story slice
        if sid in stories:
            order = {"Walking skeleton": 0, "MVP": 1}
            srel = stories[sid]["release"]
            for ru in r.model["rules"]:
                for e in ru["examples"]:
                    if e["release"] and srel and order.get(e["release"], 9) < order.get(srel, 9):
                        R.warn("consistency", f"{p}: example '{e['title']}' is scheduled before its story's slice")
    stats.update(example_maps=len(emaps), rules=len(rules), examples=ex_count, red_cards=q_count)

    # context map + domain models
    ctx_map = next(iter(ddds.values()), None)
    ctx_names = set(ctx_map.model["contexts"]) if ctx_map else set()
    invariants = {}
    for p, r in ddms.items():
        cname = r.model["context"]
        if cname not in ctx_names:
            R.err("refs", f"{p}: context '{cname}' is not on the context map")
        else:
            declared = set(ctx_map.model["contexts"][cname]["aggregates"])
            modelled = {a["name"] for a in r.model["aggregates"]}
            if declared != modelled:
                R.err("refs", f"{p}: aggregates {sorted(modelled)} differ from context map {sorted(declared)}")
        for a in r.model["aggregates"]:
            for inv in a["invariants"]:
                m = re.match(r"^\[(INV-[A-Z]+-\d+)\]", inv)
                if not m:
                    R.warn("ids", f"{p}: invariant without [INV-...] id: {inv[:50]}")
                    continue
                if m.group(1) in invariants:
                    R.err("ids", f"invariant id {m.group(1)} used twice")
                invariants[m.group(1)] = cname
    for cid, c in man["contexts"].items():
        if c["name"] not in ctx_names:
            R.err("refs", f"manifest {cid}: '{c['name']}' not on the context map")
        if c.get("model") and c["model"] not in ddms:
            R.err("refs", f"manifest {cid}: model {c['model']} missing or unparsable")
    stats.update(contexts=len(ctx_names), invariants=len(invariants))
    ctx_by_name = {c["name"]: cid for cid, c in man["contexts"].items()}

    # components (LikeC4 JSON export)
    components = {}
    lj = os.environ.get("LIKEC4_JSON")
    if lj and os.path.exists(lj):
        data = json.load(open(lj))
        elements = data.get("elements", {})
        for fqn, el in elements.items():
            md = el.get("metadata") or {}
            for rm in (md.get("readmodels") or "").split():
                ux_ref(rm, f"c4 {fqn}")
            if md.get("scr"):
                scr = md["scr"]
                ux_ref(scr, f"c4 {fqn}")
                parent = elements.get(fqn.rsplit(".", 1)[0], {}) if "." in fqn else {}
                pcmp = (parent.get("metadata") or {}).get("cmp")
                if scr in screens and screens[scr]["managed"] and screens[scr]["managed"] != pcmp:
                    R.err("refs", f"{scr}: blueprint says managed by {screens[scr]['managed']}, C4 nests it in {pcmp}")
            cmp = md.get("cmp")
            if not cmp:
                continue
            if cmp in components:
                R.err("ids", f"component id {cmp} on two elements")
            components[cmp] = dict(fqn=fqn, ctx=md.get("ctx"), stories=(md.get("stories") or "").split(),
                                   decisions=(md.get("decisions") or "").split())
        for cmp, c in components.items():
            if not c["ctx"] and cmp not in ("CMP-ASPSP-GW", "CMP-TRUST-SERVICES", "CMP-OBSERVABILITY", "CMP-XS2A-STORE", "CMP-EVENT-OUTBOX"):
                R.warn("consistency", f"component {cmp} has no owning bounded context")
            elif c["ctx"] and c["ctx"] not in man["contexts"]:
                R.err("refs", f"component {cmp}: ctx {c['ctx']} unknown")
            for s in c["stories"]:
                if s not in stories:
                    R.err("refs", f"component {cmp}: story {s} not on the story map")
            for d in c["decisions"]:
                if d not in defined:
                    R.err("ledger", f"component {cmp}: {d} not in the ledger")
        stats["components"] = len(components)
    else:
        R.info("external", "LIKEC4_JSON not provided — component checks not run")

    # interfaces
    ops = {}
    for api_id, api in man["interfaces"].items():
      if api["kind"] != "openapi":
        continue
      oapi = yaml.safe_load(open(os.path.join(ROOT, api["file"])))
      for sname, sch in (oapi.get("components", {}).get("schemas", {}) or {}).items():
        if isinstance(sch, dict) and sch.get("x-read-model"):
            ux_ref(sch["x-read-model"], f"{api_id} schema {sname}")
      for path, item in oapi.get("paths", {}).items():
        for method, op in item.items():
            if method not in ("get", "post", "put", "delete", "patch"):
                continue
            oid = op.get("operationId")
            for scr in op.get("x-screens", []):
                ux_ref(scr, f"{api_id} {oid}")
            for rm in re.findall(r"RM-[A-Z0-9-]+", str(op.get("x-read-model", ""))):
                ux_ref(rm, f"{api_id} {oid}")
            if oid in ops:
                R.err("ids", f"operationId {oid} used twice")
            ops[oid] = op
            tr = op.get("x-trace") or {}
            if not tr.get("stories"):
                R.warn("consistency", f"operation {oid} has no x-trace stories — interface without behavioural justification")
            for s in tr.get("stories", []):
                if s not in stories:
                    R.err("refs", f"operation {oid}: story {s} not on the story map")
            for rr in tr.get("rules", []):
                if rr not in rules:
                    R.err("refs", f"operation {oid}: rule {rr} not in any example map")
            if op.get("x-delivery") not in man["delivery_packs"]:
                R.err("refs", f"operation {oid}: x-delivery {op.get('x-delivery')} unknown")
            if op.get("x-conditional-on") and op["x-conditional-on"] not in defined:
                R.err("ledger", f"operation {oid}: {op['x-conditional-on']} not in the ledger")
    stats["operations"] = len(ops)

    # ------------------------------------------------------------------ 3. manifest chains
    journey_text = open(os.path.join(ROOT, "docs/journeys/journey-map.md")).read()
    stages = set(re.findall(r"`(JRN-[A-Z-]+\.S\d+)`", journey_text))
    pack_text = {k: open(os.path.join(ROOT, v["file"])).read() for k, v in man["delivery_packs"].items()}
    chained = set()
    for ch in man["chains"]:
        sid = ch["story"]
        chained.add(sid)
        where = f"chain {sid}"
        if sid not in stories:
            R.err("refs", f"{where}: story not on the story map"); continue
        st = stories[sid]
        for o in ch["objective"]:
            if o not in man["objectives"]:
                R.err("refs", f"{where}: objective {o} unknown")
        for j in ch["journey"]:
            if j not in stages:
                R.err("refs", f"{where}: journey stage {j} not in journey-map.md")
        evt = ch["pivotal_event"]
        if evt not in evt_defs:
            R.err("refs", f"{where}: {evt} not a pivotal event")
        elif activities.get(story_act[sid], {}).get("evt") != evt:
            R.err("refs", f"{where}: story sits under activity closed by {activities[story_act[sid]]['evt']}, not {evt}")
        exm = ch.get("example_map")
        if exm:
            em = man["example_maps"].get(exm)
            if not em:
                R.err("refs", f"{where}: {exm} not declared")
            elif em["file"] not in emaps:
                R.err("refs", f"{where}: {em['file']} missing or unparsable")
        else:
            R.warn("consistency", f"{where}: no example map — rules of this story have no concrete examples yet")
        for rr in ch["rules"]:
            if rr not in rules:
                R.err("refs", f"{where}: rule {rr} not found")
            elif exm and rules[rr]["file"] != man["example_maps"][exm]["file"]:
                R.err("refs", f"{where}: rule {rr} is not on {exm}")
        for c in ch["bounded_context"]:
            if c not in man["contexts"]:
                R.err("refs", f"{where}: context {c} unknown")
        for i in ch["invariants"]:
            if i not in invariants:
                R.err("refs", f"{where}: invariant {i} not found in any .ddm")
        for cmp in ch["components"]:
            if components and cmp not in components:
                R.err("refs", f"{where}: component {cmp} not in the C4 model")
            elif components and sid not in components[cmp]["stories"]:
                R.warn("traceability", f"{where}: component {cmp} does not list {sid} in metadata.stories")
        for oid in ch["operations"]:
            if oid not in ops:
                R.err("refs", f"{where}: operation {oid} not in the OpenAPI profile")
            elif sid not in (ops[oid].get("x-trace") or {}).get("stories", []):
                R.warn("traceability", f"{where}: operation {oid} does not trace back to {sid}")
        for scr in ch.get("screens", []):
            ux_ref(scr, f"manifest {sid}")
        for rm in ch.get("read_models", []):
            ux_ref(rm, f"manifest {sid}")
        for api in ch.get("interfaces", []):
            if api not in man["interfaces"]:
                R.err("refs", f"{where}: interface {api} unknown")
        pack = ch["delivery_pack"]
        if pack != st["delivery_pack"]:
            R.err("refs", f"{where}: manifest says {pack}, story map says {st['release']!r}")
        for t in ch["tests"]:
            if not os.path.exists(os.path.join(ROOT, t)):
                R.err("refs", f"{where}: test file {t} missing")
        if not ch["evidence"]:
            R.warn("consistency", f"{where}: delivery item without expected evidence")
        for e in ch["evidence"]:
            if e not in man["evidence"]:
                R.err("refs", f"{where}: evidence {e} undefined")
            elif e not in pack_text[man["evidence"][e]["pack"]]:
                R.err("refs", f"{where}: evidence {e} not described in its pack file")
        if not ch["components"]:
            R.warn("consistency", f"{where}: no component")
    scheduled = {s for s, st in stories.items() if st["release"]}
    for s in scheduled - chained:
        R.err("traceability", f"{s} is scheduled on the story map but has no chain in the manifest")
    for s in chained - scheduled:
        R.err("traceability", f"{s} has a chain but is unscheduled on the story map")
    unsched = set(man.get("unscheduled", {}))
    for s in set(stories) - scheduled - unsched:
        R.err("traceability", f"{s} is unscheduled on the map but missing from manifest 'unscheduled'")
    for s in unsched - (set(stories) - scheduled):
        R.err("traceability", f"manifest 'unscheduled' lists {s}, which is scheduled or unknown")
    for p in emaps:
        if not any(v["file"] == p for v in man["example_maps"].values()):
            R.warn("traceability", f"{p} is not declared in the manifest")
    for oid, op in ops.items():
        tr_st = (op.get("x-trace") or {}).get("stories", [])
        if tr_st and not any(s in chained for s in tr_st):
            R.warn("traceability", f"operation {oid} traces only to unscheduled stories")

    for rid, d in sorted({**screens, **read_models}.items()):
        places = {x.split()[0] for x in d["refs"]}
        if not d["refs"]:
            R.warn("ux", f"{rid} is defined but used nowhere (no storm card, C4 element, contract or chain)")
        elif rid.startswith("SCR-") and not any(x.startswith("c4") for x in d["refs"]):
            R.err("ux", f"{rid} has no element in the C4 model — which component manages it?")
        elif rid.startswith("SCR-") and not any(x.endswith(".eventstorm") for x in places) and screens[rid]["managed"] != "CMP-TPP":
            R.info("ux", f"{rid} appears on no event storm")

    # ------------------------------------------------------------------ 4. ledger references everywhere
    scan = glob.glob(os.path.join(ROOT, "docs/**/*.*"), recursive=True) + glob.glob(os.path.join(ROOT, "tests/**/*.feature"), recursive=True)
    unknown = {}
    for f in scan:
        if f.endswith((".pdf", ".png")) or "/docs/ai/" in f or "/docs/context/" in f:
            continue
        txt = open(f, errors="ignore").read()
        for ref in set(re.findall(r"\b((?:Q|A|D|H|C|RSK)-\d{2})\b", txt)):
            if ref not in defined:
                unknown.setdefault(ref, []).append(rel(f))
    for ref, files in sorted(unknown.items()):
        R.err("ledger", f"{ref} referenced but not defined ({', '.join(sorted(set(files))[:3])})")

    # ------------------------------------------------------------------ 5. projections
    for name in sorted(os.listdir(os.path.join(ROOT, "docs/stories"))):
        if name.endswith(".examplemap"):
            text = examplemap_to_feature.render(os.path.join(ROOT, "docs/stories", name))
            target = os.path.join(ROOT, "tests/acceptance/features", name.replace(".examplemap", ".feature"))
            if not os.path.exists(target) or open(target).read() != text:
                R.err("projection", f"{rel(target)} is missing or stale — regenerate from {name}")

    # ------------------------------------------------------------------ 6. external validators
    ext = {}
    if external:
        def run(label, cmd):
            try:
                p = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, timeout=300)
                ok = p.returncode == 0
                ext[label] = "passed" if ok else "FAILED"
                if not ok:
                    R.err("external", f"{label}: {(p.stdout + p.stderr).strip()[-400:]}")
            except Exception as e:  # noqa: BLE001
                ext[label] = "not run"
                R.warn("external", f"{label}: {e}")
        if os.environ.get("LIKEC4"):
            run("likec4 validate", f"{os.environ['LIKEC4']} validate docs/system/c4")
        else:
            ext["likec4 validate"] = "not run"
        jar = os.environ.get("PLANTUML_JAR")
        if jar:
            for f in sorted(glob.glob(os.path.join(ROOT, "docs/system/uml/**/*.puml"), recursive=True)):
                run(f"plantuml {rel(f)}", f"java -Djava.awt.headless=true -jar {shlex.quote(jar)} -checkonly {shlex.quote(f)}")
        else:
            ext["plantuml"] = "not run"
        checks = []
        for api in man["interfaces"].values():
            if api["kind"] == "openapi":
                checks += [("openapi-spec-validator", "OPENAPI_VALIDATOR", api["file"]),
                           ("redocly lint", "REDOCLY", api["file"])]
            elif api["kind"] == "asyncapi":
                checks.append(("asyncapi parser", "ASYNCAPI_VALIDATOR", api["file"]))
        for label, env, target in checks:
            if os.environ.get(env):
                run(f"{label} {target}", f"{os.environ[env]} {shlex.quote(target)}")
            else:
                ext[label] = "not run"

    # ------------------------------------------------------------------ output
    levels = {"ERROR": 0, "WARNING": 0, "INFO": 0}
    for lvl, check, msg in R.items:
        levels[lvl] += 1
    print(f"SDLC artefact validation — {levels['ERROR']} error(s), {levels['WARNING']} warning(s), {levels['INFO']} info")
    print("stats:", json.dumps(stats))
    if ext:
        print("external:", json.dumps(ext))
    for lvl in ("ERROR", "WARNING", "INFO"):
        for l, check, msg in R.items:
            if l == lvl:
                print(f"{lvl:7} [{check}] {msg}")
    if json_out:
        json.dump(dict(stats=stats, external=ext, items=R.items), open(json_out, "w"), indent=2)
    return 1 if levels["ERROR"] else 0


if __name__ == "__main__":
    sys.exit(main())
