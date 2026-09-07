#!/usr/bin/env python3
"""Generate a Gherkin .feature file from every .examplemap.

The mapping is the one docs/design/examplemap/README.md states: story to
Feature, rule to Rule, example to Scenario; questions are not exported.
Reuses the tokeniser of emcheck.py so both tools read the same grammar.
"""
import sys, os, re, glob, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from emcheck import tokenize

STEP_KW = ('given', 'when', 'then')


# ---------------------------------------------------------------- parse to AST

class Parser:
    def __init__(s, toks, path):
        s.t, s.i, s.path = toks, 0, path

    def peek(s, k=0): return s.t[s.i + k]
    def next(s): tok = s.t[s.i]; s.i += 1; return tok
    def is_kw(s, *v): t = s.peek(); return t[0] == 'kw' and t[1] in v

    def expect(s, kind, val=None):
        tok = s.next()
        if tok[0] != kind or (val is not None and tok[1] != val):
            raise SyntaxError(f'{s.path}:{tok[2]}: expected {val or kind}, got {tok[1]!r}')
        return tok

    def string(s): return s.expect('str')[1]

    def name_or_str(s):
        tok = s.next()
        if tok[0] in ('ident', 'str', 'int', 'kw'): return str(tok[1])
        raise SyntaxError(f'{s.path}:{tok[2]}: expected name, got {tok[1]!r}')

    def annotations(s):
        """Collect trailing #ticket, ~status, @delivery and +tag markers."""
        a = {'tags': [], 'ships': None, 'status': None, 'ticket': None}
        while True:
            t = s.peek()
            if t[0] == '+': s.next(); a['tags'].append(s.name_or_str())
            elif t[0] == '@': s.next(); a['ships'] = s.name_or_str()
            elif t[0] == '~': s.next(); a['status'] = s.name_or_str()
            elif t[0] == '#': s.next(); a['ticket'] = s.name_or_str()
            else: return a

    def file(s):
        s.expect('kw', 'examplemap')
        m = {'title': s.string(), 'product': None, 'story': None, 'rules': []}
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                k = s.peek()[1]
                if k == 'product': s.next(); m['product'] = s.string()
                elif k == 'space': s.next(); s.string()
                elif k == 'delivery': s.delivery()
                elif k == 'story': m['story'] = s.story()
                elif k == 'rule': m['rules'].append(s.rule())
                elif k == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}: {k} not allowed at map level')
            s.expect('}')
        s.expect('eof')
        return m

    def delivery(s):
        s.next(); s.string(); s.next()
        while s.peek()[0] == '#' or s.is_kw('points'):
            if s.peek()[0] == '#': s.next(); s.name_or_str()
            else: s.next(); s.expect('int')
        if s.peek()[0] == '{':
            s.next()
            while s.is_kw('note'): s.next(); s.string()
            s.expect('}')

    def story(s):
        s.next()
        st = {'title': s.string(), 'as': None, 'want': None, 'so': None, 'questions': 0}
        st.update(s.annotations())
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                k = s.peek()[1]
                if k in ('as', 'want', 'so'): s.next(); st[k] = s.string()
                elif k == 'question': s.question(); st['questions'] += 1
                elif k == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}: {k} not allowed in story')
            s.expect('}')
        return st

    def rule(s):
        s.next()
        r = {'title': s.string(), 'examples': [], 'questions': 0}
        r.update(s.annotations())
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                k = s.peek()[1]
                if k == 'example': r['examples'].append(s.example())
                elif k == 'question': s.question(); r['questions'] += 1
                elif k == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}: {k} not allowed in rule')
            s.expect('}')
        return r

    def example(s):
        s.next()
        e = {'title': s.string(), 'steps': []}
        e.update(s.annotations())
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                t = s.peek()
                if t[0] == 'kw' and t[1] in STEP_KW:
                    s.next(); e['steps'].append((t[1], s.string()))
                elif t[0] == 'kw' and t[1] == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}: {t[1]!r} not allowed in example')
            s.expect('}')
        return e

    def question(s):
        s.next(); s.string(); s.annotations()
        if s.peek()[0] == '{':
            s.next()
            while s.is_kw('note'): s.next(); s.string()
            s.expect('}')


# ---------------------------------------------------------------- emit Gherkin

def slug(text):
    """A tag body Gherkin accepts: lowercase, no spaces, no @.

    Dots survive only between digits, so "spec 6.3.1" keeps its section number
    while "RTS art. 7" does not keep the abbreviation's full stop.
    """
    s = text.lower()
    s = re.sub(r'\.(?!\d)', ' ', s)          # drop a dot unless a digit follows
    s = re.sub(r'(?<!\d)\.', ' ', s)          # ... and unless a digit precedes
    s = re.sub(r'[^a-z0-9_.]+', '-', s)
    return re.sub(r'-+', '-', s).strip('-')


def tags_line(indent, *groups):
    out = []
    for g in groups:
        for t in g:
            if t: out.append('@' + slug(t))
    seen, uniq = set(), []
    for t in out:
        if t not in seen: seen.add(t); uniq.append(t)
    return f'{indent}{" ".join(uniq)}\n' if uniq else ''


def render(m, src_rel):
    st = m['story']
    L = []
    L.append(f'# Generated from {src_rel} by tools/emgherkin.py -- do not edit.\n')
    L.append('# Source of truth is the example map; regenerate after changing it.\n')
    open_q = st['questions'] + sum(r['questions'] for r in m['rules'])
    if open_q:
        L.append(f'# {open_q} open question(s) in the map are not exported; '
                 f'the scenarios below assume an answer.\n')
    L.append('\n')

    L.append(tags_line('', st['tags'], [st['ships']] if st['ships'] else [],
                       [st['status']] if st['status'] else []))
    L.append(f'Feature: {st["title"]}\n')
    if st['as'] or st['want'] or st['so']:
        if st['as']:   L.append(f'  As {st["as"]}\n')
        if st['want']: L.append(f'  I want {st["want"]}\n')
        if st['so']:   L.append(f'  So that {st["so"]}\n')

    for r in m['rules']:
        L.append('\n')
        L.append(tags_line('  ', r['tags']))
        L.append(f'  Rule: {r["title"]}\n')
        for ex in r['examples']:
            L.append('\n')
            L.append(tags_line('    ', ex['tags'], [ex['ships']] if ex['ships'] else []))
            L.append(f'    Scenario: {ex["title"]}\n')
            prev = None
            for kw, text in ex['steps']:
                word = 'And' if kw == prev else kw.capitalize()
                L.append(f'      {word} {text}\n')
                prev = kw
    return ''.join(L)


# ---------------------------------------------------------------------- driver

def main(argv):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('paths', nargs='*', help='.examplemap files (default: all of them)')
    ap.add_argument('--src', default='docs/design/examplemap', help='example map root')
    ap.add_argument('--out', default='docs/design/features', help='output root')
    ap.add_argument('--check', action='store_true',
                    help='do not write; exit 1 if any output is missing or stale')
    ap.add_argument('-v', '--verbose', action='store_true')
    a = ap.parse_args(argv)

    paths = a.paths or sorted(glob.glob(os.path.join(a.src, '*', '*.examplemap')))
    if not paths:
        print(f'no .examplemap files under {a.src}', file=sys.stderr); return 2

    written = stale = failed = 0
    for path in sorted(paths):
        try:
            m = Parser(tokenize(open(path, encoding='utf-8').read(), path), path).file()
            if m['story'] is None: raise SyntaxError(f'{path}: no story')
        except SyntaxError as e:
            print(f'ERROR {e}', file=sys.stderr); failed += 1; continue

        rel = os.path.relpath(path, a.src)
        dest = os.path.join(a.out, os.path.splitext(rel)[0] + '.feature')
        text = render(m, os.path.join(a.src, rel).replace(os.sep, '/'))

        current = open(dest, encoding='utf-8').read() if os.path.exists(dest) else None
        if current == text:
            if a.verbose: print(f'  ok    {dest}')
            continue
        if a.check:
            print(f'STALE {dest}' if current is not None else f'MISSING {dest}')
            stale += 1; continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, 'w', encoding='utf-8') as f: f.write(text)
        written += 1
        if a.verbose: print(f'  write {dest}')

    if a.check:
        print(f'checked={len(paths)} stale-or-missing={stale} invalid={failed}')
        return 1 if (stale or failed) else 0
    print(f'features={len(paths) - failed} written={written} '
          f'unchanged={len(paths) - failed - written} invalid={failed}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
