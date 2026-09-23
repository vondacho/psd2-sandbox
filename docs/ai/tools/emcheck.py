#!/usr/bin/env python3
"""Structural checker for .examplemap files against the grammar at doc-em.obya.ch/dsl."""
import sys, re, glob, os

KW = {'examplemap','product','space','delivery','sprint','release','points','story','as','want','so',
      'rule','example','given','when','then','question','note'}
STATUS = {'open','analysing','ready','in-progress','done','closed'}

def tokenize(src, path):
    i, n, line = 0, len(src), 1
    toks = []
    while i < n:
        c = src[i]
        if c == '\n': line += 1; i += 1; continue
        if c in ' \t\r': i += 1; continue
        if src.startswith('//', i):
            while i < n and src[i] != '\n': i += 1
            continue
        if c == '"':
            j = i + 1; buf = []
            while True:
                if j >= n: raise SyntaxError(f'{path}:{line}: unterminated string')
                d = src[j]
                if d == '\\':
                    if j+1 < n and src[j+1] in '"\\nt': buf.append(src[j+1]); j += 2; continue
                    if j+1 < n and src[j+1] == '\n':
                        line += 1; j += 2
                        while j < n and src[j] in ' \t': j += 1
                        buf.append(' '); continue
                    raise SyntaxError(f'{path}:{line}: bad escape')
                if d == '"': break
                if d == '\n': raise SyntaxError(f'{path}:{line}: newline inside string (use a backslash splice)')
                buf.append(d); j += 1
            toks.append(('str', ''.join(buf), line)); i = j + 1; continue
        if c in '{}#~@+': toks.append((c, c, line)); i += 1; continue
        m = re.match(r'[A-Za-z0-9_.\-]+', src[i:])
        if m:
            w = m.group(0); i += len(w)
            if w.isdigit(): toks.append(('int', int(w), line))
            elif w in KW: toks.append(('kw', w, line))
            else: toks.append(('ident', w, line))
            continue
        raise SyntaxError(f'{path}:{line}: unexpected character {c!r}')
    toks.append(('eof', None, line))
    return toks

class P:
    def __init__(s, toks, path): s.t = toks; s.i = 0; s.path = path; s.errs = []
    def peek(s, k=0): return s.t[s.i+k]
    def next(s): tok = s.t[s.i]; s.i += 1; return tok
    def err(s, msg): s.errs.append(f'{s.path}:{s.peek()[2]}: {msg}')
    def expect(s, kind, val=None):
        tok = s.next()
        if tok[0] != kind or (val is not None and tok[1] != val):
            raise SyntaxError(f'{s.path}:{tok[2]}: expected {val or kind}, got {tok[1]!r}')
        return tok
    def string(s): return s.expect('str')[1]
    def is_kw(s, *vals): tok = s.peek(); return tok[0]=='kw' and tok[1] in vals
    def name_or_str(s):
        tok = s.next()
        if tok[0] in ('ident','str','int','kw'): return str(tok[1])
        raise SyntaxError(f'{s.path}:{tok[2]}: expected name, got {tok[1]!r}')

    def file(s):
        s.expect('kw','examplemap'); s.title = s.string()
        s.deliveries = []; s.stories = 0; s.rules = 0; s.examples = 0; s.questions = 0; s.steps = 0
        s.unexemplified = 0; s.no_step_examples = 0
        s.ships = []
        product = space = 0
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                tok = s.peek()
                if tok[0] != 'kw': raise SyntaxError(f'{s.path}:{tok[2]}: unexpected {tok[1]!r} in map body')
                k = tok[1]
                if k == 'product': s.next(); s.string(); product += 1
                elif k == 'space': s.next(); s.string(); space += 1
                elif k == 'delivery': s.delivery()
                elif k == 'story': s.story()
                elif k == 'rule': s.rule()
                elif k == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}:{tok[2]}: {k} not allowed at map level')
            s.expect('}')
        s.expect('eof')
        if product > 1: s.errs.append(f'{s.path}: more than one product')
        if space > 1: s.errs.append(f'{s.path}: more than one space')
        if s.stories != 1: s.errs.append(f'{s.path}: a map needs exactly one story, found {s.stories}')
        for name, line in s.ships:
            if name not in s.deliveries: s.errs.append(f'{s.path}:{line}: @{name} names no declared delivery')

    def tags(s):
        while s.peek()[0] == '+': s.next(); s.name_or_str()

    def delivery(s):
        s.next(); name = s.string(); kind = s.next()
        if kind[0] != 'kw' or kind[1] not in ('sprint','release'): raise SyntaxError(f'{s.path}:{kind[2]}: delivery needs sprint or release')
        ticket = points = 0
        while s.peek()[0] == '#' or s.is_kw('points'):
            if s.peek()[0] == '#': s.next(); s.name_or_str(); ticket += 1
            else:
                s.next(); s.expect('int'); points += 1
                if kind[1] != 'sprint': s.err('points only on sprints')
        if ticket > 1: s.err('more than one ticket'); 
        if points > 1: s.err('more than one points')
        if s.peek()[0] == '{':
            s.next()
            while s.is_kw('note'): s.next(); s.string()
            s.expect('}')
        s.deliveries.append(name)

    def story(s):
        s.next(); s.string(); s.stories += 1
        ticket = status = ships = 0
        while True:
            tok = s.peek()
            if tok[0] == '#': s.next(); s.name_or_str(); ticket += 1
            elif tok[0] == '~':
                s.next(); v = s.name_or_str(); status += 1
                if v not in STATUS: s.err(f'unknown status {v}')
            elif tok[0] == '@': s.next(); s.ships.append((s.name_or_str(), tok[2])); ships += 1
            elif tok[0] == '+': s.next(); s.name_or_str()
            else: break
        if ticket > 1: s.err('more than one ticket on story')
        if status > 1: s.err('more than one status on story')
        if ships > 1: s.err('more than one @ on story')
        if s.peek()[0] == '{':
            s.next(); seen = set()
            while s.peek()[0] != '}':
                tok = s.peek()
                if tok[0] != 'kw': raise SyntaxError(f'{s.path}:{tok[2]}: unexpected {tok[1]!r} in story')
                k = tok[1]
                if k in ('as','want','so'):
                    s.next(); s.string()
                    if k in seen: s.err(f'more than one {k}')
                    seen.add(k)
                elif k == 'question': s.question()
                elif k == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}:{tok[2]}: {k} not allowed in story')
            s.expect('}')

    def rule(s):
        s.next(); s.string(); s.rules += 1; s.tags()
        ex = 0
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                tok = s.peek()
                if tok[0] != 'kw': raise SyntaxError(f'{s.path}:{tok[2]}: unexpected {tok[1]!r} in rule')
                k = tok[1]
                if k == 'example': s.example(); ex += 1
                elif k == 'question': s.question()
                elif k == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}:{tok[2]}: {k} not allowed in rule')
            s.expect('}')
        if ex == 0: s.unexemplified += 1

    def example(s):
        s.next(); s.string(); s.examples += 1
        ships = 0
        while True:
            tok = s.peek()
            if tok[0] == '@': s.next(); s.ships.append((s.name_or_str(), tok[2])); ships += 1
            elif tok[0] == '+': s.next(); s.name_or_str()
            else: break
        if ships > 1: s.err('more than one @ on example')
        steps = 0
        if s.peek()[0] == '{':
            s.next()
            while s.peek()[0] != '}':
                tok = s.peek()
                if tok[0] == 'kw' and tok[1] in ('given','when','then'): s.next(); s.string(); steps += 1
                elif tok[0] == 'kw' and tok[1] == 'note': s.next(); s.string()
                else: raise SyntaxError(f'{s.path}:{tok[2]}: {tok[1]!r} not allowed in example')
            s.expect('}')
        s.steps += steps
        if steps == 0: s.no_step_examples += 1

    def question(s):
        s.next(); s.string(); s.questions += 1; s.tags()
        if s.peek()[0] == '{':
            s.next()
            while s.is_kw('note'): s.next(); s.string()
            s.expect('}')

def main(paths):
    tot = dict(files=0, rules=0, examples=0, questions=0, steps=0, unex=0, nostep=0); bad = 0
    for path in paths:
        src = open(path, encoding='utf-8').read()
        try:
            p = P(tokenize(src, path), path); p.file()
        except SyntaxError as e:
            print('ERROR', e); bad += 1; continue
        for e in p.errs: print('ERROR', e)
        bad += bool(p.errs)
        tot['files'] += 1; tot['rules'] += p.rules; tot['examples'] += p.examples; tot['questions'] += p.questions
        tot['steps'] += p.steps; tot['unex'] += p.unexemplified; tot['nostep'] += p.no_step_examples
        if '-v' in sys.argv: print(f'{path}: {p.rules} rules, {p.examples} examples, {p.questions} questions, {p.unexemplified} rules without example, {p.no_step_examples} examples without steps')
    print(f"files={tot['files']} rules={tot['rules']} examples={tot['examples']} steps={tot['steps']} questions={tot['questions']} rules-without-example={tot['unex']} examples-without-steps={tot['nostep']} invalid={bad}")
    return 1 if bad else 0

if __name__ == '__main__':
    files = [a for a in sys.argv[1:] if not a.startswith('-')]
    sys.exit(main(files))
