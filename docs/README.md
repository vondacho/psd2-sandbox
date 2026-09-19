# PSD2 XS2A — solution-design proposal

A connected, AI-generated **proposal** for the bank's PSD2 XS2A interface (Berlin Group
NextGenPSD2 v1.3.16). It was produced under the SDLC instructions in [`ai/`](ai/). Nothing in
it is accepted intent until the review gates in the
[validation report](traceability/validation-report.md#review-gates) pass.

## Inputs (unchanged)

- [`psd2/`](psd2/) — NextGenPSD2 XS2A Implementation Guidelines v1.3.16
- [`context/`](context/) — bank ADRs, open questions, terminology
- [`ai/`](ai/) — orchestration, artefact contract, review policy, doctrines and notations

## Read in this order

| # | Artefact | What it answers |
| --- | --- | --- |
| 1 | [journeys/problem-analysis.md](journeys/problem-analysis.md) | What problem, which sources, which facts versus claims, what contradicts what |
| 2 | [journeys/journey-map.md](journeys/journey-map.md) | Outside-in journeys (no UX research behind them) |
| 2a | [journeys/service-blueprint.md](journeys/service-blueprint.md) | Which screens the PSU sees, which read models each actor or component decides on, and who manages them |
| 3 | [journeys/xs2a-big-picture.eventstorm](journeys/xs2a-big-picture.eventstorm) | The domain timeline, pivotal events, hotspots |
| 4 | [journeys/ais-consent-lifecycle.eventstorm](journeys/ais-consent-lifecycle.eventstorm), [journeys/pis-payment-initiation.eventstorm](journeys/pis-payment-initiation.eventstorm) | Commands, policies and aggregates for the slices |
| 5 | [stories/xs2a-access-to-account.storymap](stories/xs2a-access-to-account.storymap) | Backbone and proposed slices |
| 6 | [stories/*.examplemap](stories/) | Rules, examples and red cards per story |
| 7 | [domain/xs2a-access-to-account.ddd](domain/xs2a-access-to-account.ddd), [domain/*/*.ddm](domain/) | Boundaries, power, invariants |
| 8 | [system/README.md](system/README.md) | Solution design and the decisions that need you |
| 8a | [system/decisions/](system/decisions/) | The two write-ups: consent management make-or-buy, and token compatibility |
| 9 | [system/c4/](system/c4/), [system/uml/](system/uml/), [system/api/](system/api/) | Structure (LikeC4 view `psuScreens`), dynamics, screen flows and wireframes (`uml/ux/`), contracts |
| 10 | [delivery/walking-skeleton.md](delivery/walking-skeleton.md), [delivery/mvp.md](delivery/mvp.md) | What to build first, and how we will know it worked |
| 11 | [traceability/](traceability/) | Manifest, question ledger, validation report |
| 12 | [delivery/pull-request.md](delivery/pull-request.md) | The pull-request description |

## Tooling

```sh
pip install pyyaml
python3 tools/sdlc/validate.py                       # parse + trace + ledger + projection checks
python3 tools/sdlc/examplemap_to_feature.py          # regenerate tests/acceptance/features
npx likec4 start docs/system/c4                       # browse the C4 views
```
