# Tools

Small, dependency-free scripts that check the models and generate from them.
Python 3 and its standard library are all they need.

| Script | Does |
|---|---|
| [`emcheck.py`](emcheck.py) | Validates the `.examplemap` files in [`../docs/design/examplemap/`](../docs/design/examplemap/) |
| [`emgherkin.py`](emgherkin.py) | Generates a Gherkin `.feature` for each of them into [`../docs/design/features/`](../docs/design/features/) |

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

## emgherkin.py

Generates [`../docs/design/features/`](../docs/design/features/) from the
example maps, following the mapping stated in
[the example map README](../docs/design/examplemap/README.md): story to
`Feature:`, rule to `Rule:`, example to `Scenario:`; questions are not exported.
It reuses `emcheck.py`'s tokeniser — one grammar, one reader — and adds the
AST that generation needs but checking did not.

```sh
python3 tools/emgherkin.py                 # regenerate all 126
python3 tools/emgherkin.py --check         # exit 1 if any output is stale
python3 tools/emgherkin.py -v <files...>   # a subset, reporting each file
python3 tools/emgherkin.py --out /tmp/x    # somewhere else
```

Output is deterministic and the writer is idempotent: a second run reports
`written=0 unchanged=126`. That makes `--check` usable as a CI or pre-commit
gate — it fails when someone edits a generated `.feature` instead of the map it
came from, and when a map changed but the features were not regenerated.

The generated files are committed, so a change to a map shows up in review as a
change to its scenarios.
