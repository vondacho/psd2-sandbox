# Tools

Small, dependency-free scripts for checking the models. Python 3 and a standard
library are all they need.

| Script | Checks |
|---|---|
| [`emcheck.py`](emcheck.py) | `.examplemap` files in [`../docs/design/examplemap/`](../docs/design/examplemap/) |

## emcheck.py

A hand-written tokeniser and recursive-descent parser for the example-mapping
grammar at [doc-em.obya.ch/dsl](https://doc-em.obya.ch/dsl). It exists because
that DSL has no command-line validator of its own, and 126 hand-written files
are too many to keep correct by reading.

```sh
python3 tools/emcheck.py docs/design/examplemap/*/*.examplemap
python3 tools/emcheck.py -v docs/design/examplemap/*/*.examplemap   # per file
```

It reports a syntax error with its file and line, and beyond parsing it
enforces the conventions the maps rely on:

- at most one ticket, one status and one `@delivery` on a story, one `@` on an
  example, one ticket and one `points` on a delivery;
- `points` only on a `sprint`;
- a status drawn from `open`, `analysing`, `ready`, `in-progress`, `done`,
  `closed`;
- no `as`/`want`/`so` clause repeated;
- only `given`, `when`, `then` and `note` inside an example.

The summary line is the source of the counts quoted in
[`../docs/design/examplemap/README.md`](../docs/design/examplemap/README.md) and
[`../docs/design/README.md`](../docs/design/README.md):

```
files=126 rules=426 examples=1594 steps=5052 questions=100 \
  rules-without-example=0 examples-without-steps=0 invalid=0
```

The last three are the ones to watch. A rule with no example is a rule nobody
has pinned down; an example with no steps is a title pretending to be a
scenario; `invalid` counts files that failed to parse. Exit status is non-zero
if any file was invalid, so it drops into a pre-commit hook or CI step as is.

It does **not** check anything across files — that a story exists in a story
map, that tags match, that a delivery is declared. Those are cross-model
questions, and the model folders describe the rules they follow.
