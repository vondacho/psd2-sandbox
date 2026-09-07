# Feature files

**Generated. Do not edit by hand.** One `.feature` per example map in
[`../examplemap/`](../examplemap/), same directory, same basename. Produced by
[`tools/emgherkin.py`](../../../tools/README.md); the example map is the source
of truth.

```sh
python3 tools/emgherkin.py           # regenerate all 126
python3 tools/emgherkin.py --check   # exit 1 if any file is stale or missing
```

126 features, 426 rules, 1594 scenarios, 5052 steps — the same counts
[`emcheck.py`](../../../tools/README.md) reports for the maps, because every
rule and example crosses over and nothing else is added.

## The mapping

| Example map | Gherkin |
|---|---|
| `story` (yellow card) | `Feature:`, with `as` / `want` / `so` as the narrative |
| `rule` (blue card) | `Rule:` |
| `example` (green card) | `Scenario:` |
| `given` / `when` / `then` | `Given` / `When` / `Then`, repeats becoming `And` |
| `question` (red card) | **not exported** — counted in a header comment instead |
| `+tag`, `@delivery`, `~status` | Gherkin tags, lowercased and hyphenated |

Steps keep their source order, so the fourteen scenarios that return to a
`When` after a `Then` stay that shape rather than being rearranged.

Questions are the one thing deliberately dropped: a red card is a question
nobody could answer, and a scenario that encodes a guess would look like a
decision. Where a map had to assume an answer, the assumption is stated in the
question, and the count in each file's header comment says how many such
assumptions stand behind it.

## Tags

Tags carry through so a runner can select slices of the suite:

| Kind | Examples |
|---|---|
| Delivery band | `@walking-skeleton`, `@mvp`, `@hardening`, `@pis-core`, `@pis-cancellation`, `@ais-reads`, `@consent-models`, `@authorisation-resources`, `@access-rules`, `@conformance` |
| Example kind | `@nominal`, `@edge`, `@error` |
| Component | `@bank-xs2a`, `@bank-ciam`, `@bank-app`, `@tpp`, `@oidc-provider` |
| Concern | `@security`, `@sca` |
| Citation | `@spec-6.3.1`, `@rts-art-5`, `@rfc-8705`, `@oidc-core` |
| Map status | `@ready`, `@analysing` |

111 distinct tags in all. A section number keeps its dots (`@spec-6.5.4`); an
abbreviation loses its full stop (`RTS art. 7` becomes `@rts-art-7`).

```sh
cucumber-js --tags '@walking-skeleton and @nominal'
cucumber-js --tags '@security'
```

## Status

These are **specifications, not a passing suite**. No step definitions exist
yet — the sandbox is not implemented. Every scenario is written against
[the shared fixtures](../examplemap/README.md#shared-fixtures), so the step
definitions, when written, are shared across both journeys rather than one set
per feature.
