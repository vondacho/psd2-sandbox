# PR: Proposal — PSD2 XS2A solution design (walking skeleton WS-01, MVP-01)

**Branch:** `proposal/xs2a-solution-design` → `main` · **Base:** `56c8482` · **Type:** proposal — nothing here is accepted intent until the review gates below pass.

## Problem and outcome

The bank must give licensed TPPs PSD2 access to its customers' payment accounts through a
Berlin Group NextGenPSD2 v1.3.16 XS2A interface. The building blocks are partly bought and
partly built:

- bought: Finologee as PSD2 gateway, Ping Federate as IDP, Transmit as CIAM;
- built in house: the ASPSP gateway and the mobile app.

Two allocations are explicitly undecided: where consent lifecycle management lives, and how
TPP tokens reach bank APIs.

This PR proposes a connected design from journey to contract. It includes:

- a thin walking skeleton (WS-01) that proves the unknown hops end to end;
- an MVP (MVP-01): AIS on dedicated accounts plus a single SEPA credit transfer, both
  authorised with redirect SCA in the bank app, plus TPP-access review and revoke in the app.

No business objectives, UX research or delivery context were supplied. Objectives are
therefore marked fact, claim or hypothesis, and all targets are left to product.

## Artefacts added

| Area | Files |
| --- | --- |
| Problem & journeys | `docs/journeys/problem-analysis.md`, `docs/journeys/journey-map.md` |
| Event Storming | `docs/journeys/xs2a-big-picture.eventstorm` (Big Picture: 6 pivotal events, 13 hotspots); `ais-consent-lifecycle.eventstorm`, `pis-payment-initiation.eventstorm` (process + system design) |
| Story Mapping | `docs/stories/xs2a-access-to-account.storymap`: 7 activities, 44 stories; proposed bands "Walking skeleton" and "MVP"; 20 stories deliberately unscheduled |
| Example Mapping | 8 × `docs/stories/*.examplemap`: 36 rules, 51 examples, 38 red cards |
| Context Mapping & Domain Modelling | `docs/domain/xs2a-access-to-account.ddd` (9 contexts); 4 × `.ddm` (Consent, Transaction Authorisation, Payment Initiation, Account Information; 20 invariants) |
| Architecture | `docs/system/README.md` (solution design and decisions `D-01`…`D-08`); `docs/system/c4/xs2a.likec4` (5 views); 7 × `docs/system/uml/**.puml` |
| Contracts | `docs/system/api/openapi/xs2a-profile.yaml` (19 operations, OAS 3.1); `docs/system/api/asyncapi/xs2a-domain-events.yaml` (internal, conditional on `D-04`) |
| Delivery packs | `docs/delivery/walking-skeleton.md` (WS-01), `docs/delivery/mvp.md` (MVP-01) |
| Traceability | `docs/traceability/manifest.yaml`, `docs/traceability/questions-and-assumptions.md`, `docs/traceability/validation-report.md` |
| Projections | 8 × `tests/acceptance/features/*.feature`: generated from the example maps, each recording its source sha256 |
| Tooling | `tools/sdlc/dsl.py`, `validate.py`, `examplemap_to_feature.py` |
| Index | `docs/README.md` |

Nothing existing is modified. `docs/psd2/`, `docs/context/` and `docs/ai/` are untouched.

## Instruction files and versions used

Revision `56c8482` (2026-09-19). sha256 prefixes:

| File | sha256 |
| --- | --- |
| `docs/ai/00-ai-driven-sdlc-orchestration.md` | `57616bc706b8` |
| `docs/ai/10-artifact-contract.md` | `b9286c31bdf0` |
| `docs/ai/20-review-and-delivery-policy.md` | `da158ebd845b` |
| `docs/ai/doctrines/eventstorm-doctrine.md` | `60575c54a718` |
| `docs/ai/doctrines/storymap-doctrine.md` | `92872c52d42d` |
| `docs/ai/doctrines/examplemap-doctrine.md` | `35b351753382` |
| `docs/ai/doctrines/ba-cm-doctrine.md` | `e58c35775fb4` |
| `docs/ai/notations/eventstorm-notation.md` | `70705c71c02a` |
| `docs/ai/notations/storymap-notation.md` | `1575cbd10615` |
| `docs/ai/notations/examplemap-notation.md` | `5fddd0163cb9` |
| `docs/ai/notations/ba-cm-notation.md` | `1313fd27b967` |

The online DSL pages were also consulted on 2026-09-19:

- `doc-es.obya.ch/dsl` matches the local export.
- `ba-cm.obya.ch/dsl` is stricter for `.ddm`, and the stricter form was followed (`W-DSL-02`).

**Specification:** NextGenPSD2 XS2A Framework Implementation Guidelines v1.3.16 (27 Nov 2025).

## Traceability and impact

Each of the 24 scheduled stories has a complete chain in `manifest.yaml`: objective → journey
stage → pivotal event → story and slice → rules → context and invariants → components →
OpenAPI operations → delivery pack → generated feature → expected evidence.
`tools/sdlc/validate.py` checks the chain in both directions:

- every scheduled story has a chain;
- every operation traces to a story;
- every component names its context.

**Impact:** new artefacts only. Proposed new components:

- ASPSP gateway modules: adapter, consent, authorisation, payment, account information, core adapter, outbox, store;
- the SCA redirect entry point;
- the TPP access overview in the mobile app.

The **consent module's placement is undecided** (`D-01`).

## Walking skeleton — WS-01

Proves the path TPP (test QWAC) → Finologee → ASPSP gateway → redirect → mobile app → Transmit/Ping → consent/payment → core-banking **stub**, deployed by the pipeline and traced by `X-Request-ID`. There are two scenarios:

- **AIS:** consent → approve → account list → delete.
- **PIS:** 123.50 EUR SCT → approve → `ACTC`.

It is **blocked by `D-01`, `D-02`, `D-03`, `D-05`**. Completion evidence: `EVID-WS-E2E`, `-TRACE`, `-CONTRACT`, `-DEPLOY`, `-DECISIONS`.

## MVP — MVP-01

**Outcome:** a PSU lets an AISP see chosen accounts and a PISP pay a merchant, approving both in the bank app, and can see and withdraw TPP access in the app.

**Hypothesis:** app-to-app SCA completes without abandonment. X/Y/Z targets are left to product (`Q-20`).

**Excluded:** everything optional in the spec, plus funds confirmation. Funds confirmation is **Mandatory** (§4.11.6), so leaving it out is flagged for compliance (`Q-14`, `RSK-04`).

## Validation

**0 errors.** All tools passed:

- the in-house DSL parsers;
- LikeC4 1.59.3 `validate` and `export`;
- PlantUML 1.2025.4 `-checkonly` (7/7);
- openapi-spec-validator 0.9.0 and Redocly 2.53.3 (0 warnings);
- @asyncapi/parser 3.6.3;
- @cucumber/gherkin 42.0.1 (51/51 scenarios).

24 warnings are documented in [`validation-report.md`](../traceability/validation-report.md). The most important:

- `W-DSL-01` — the DSL parsers are re-implementations: **open every notation file in doc-es / doc-sm / doc-em / ba-cm before merging**;
- `W-SM-01` — funds confirmation is empty in every slice;
- `W-EM-01` — the consent example map is too big;
- `W-API-02` — no compatibility diff against the official Berlin Group OpenAPI yet;
- `W-API-03` — the mobile ↔ gateway consent API is not yet specified.

## Assumptions and unresolved questions

- 13 assumptions (`A-01`…`A-13`) and 34 open questions (`Q-01`…`Q-34`) are in [`questions-and-assumptions.md`](../traceability/questions-and-assumptions.md).
- 22 hotspots on the storms and 38 red cards on the example maps stay red. None was answered by the AI.
- Questions that block WS-01: `Q-01`, `Q-02`, `Q-03`, `Q-04`, `Q-05`, `Q-07`, `Q-22`.
- `Q-23` (can a CC BY-ND-derived profile be published here?) needs legal before this repository is shared.

## Required reviewers

| Gate | Reviewers | Scope |
| --- | --- | --- |
| G1 | Product owner, UX | Problem analysis, journeys, objectives, slices (`D-07`, `D-08`), MVP hypothesis and targets |
| G2 | Domain experts: payments, compliance | Event storms, hotspots, context map (power and ownership), domain models, invariants |
| G3 | Product + QA + development | Run the 8 Example Mapping sessions, vote readiness, regenerate features |
| G4 | Architecture board, IAM, security, Finologee contact | C4, UML, OpenAPI, AsyncAPI, decisions `D-01`…`D-06` |
| G5 | Delivery, operations | WS-01 / MVP-01 packs, deployment path, observability, evidence |

After approval, the merge records the accepted intent. Decisions taken in review go to
`docs/context/adr.md`, and answered questions are closed in the ledger with their source.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
