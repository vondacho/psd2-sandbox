# Pull request — PSD2 XS2A solution-design proposal

> Proposed title: **Propose a PSD2 XS2A solution design from the revised context**
> Branch: `proposal/xs2a-solution-design` → `main`
> Everything in this pull request is a **proposal**. Merging records reviewed intent, not
> accepted architecture: the decisions in `docs/result/system/README.md` §4 remain open and
> belong to the people named beside them.

## Problem and outcome

The bank is an ASPSP building its own XS2A gateway, and must expose PSD2 access to licensed TPPs
to Berlin Group NextGenPSD2 v1.3.16. This pull request studies that specification against the
bank's own decisions (`docs/context/adr.md` @ `7c44c2d`) and proposes a connected design: what
the domain is, what the PSU journey looks like, how the work slices, what the bank owes TPPs, and
what nobody has decided yet.

Derived objectives — none were supplied, and each states its evidence (`OBJ-01` fact, `OBJ-02`
and `OBJ-03` stakeholder claims, `OBJ-04` hypothesis) — are in
`docs/result/journeys/problem-analysis.md` §1.

## What the revised context changed, and why this is not a refinement

Four statements in the ADR moved the design. Reviewers who read nothing else should read this
section:

1. **The consent screen belongs to the TPP.** The surface where a PSU grants or revokes access is outside the bank.
2. **Finologee manages the consent state.** The bank must decide every account read against a record it does not master.
3. **The SCA journey is a CIAM login in the browser, then OTP / QR / biometrics and a consent confirmation panel on the enrolled device.** The bank has one browser surface and one device surface.
4. **DCP consumes only PingFederate tokens**, so a Transmit token must be exchanged.

Together they leave four holes that this proposal **records rather than fills**:

| | Hole | Where it is carried |
| --- | --- | --- |
| `C-07` | A PSU cannot withdraw access *at the bank*. `revokedByPsu` is a revocation towards the ASPSP (§14.15) and has no surface | `JRN-ACCESS-CONTROL.S3` has no touchpoint; `STORY-PSU-REVOKE` unscheduled; `D-09` |
| `C-08` | The bank answers to the regulator for a consent record the vendor holds | `INV-CNS-06` fails closed; `D-01`; `RSK-07`; `EVID-WS-CONSENT-PUSH` |
| `C-09` | Nothing shows a payment's amount and payee before the PSU confirms, which dynamic linking requires | `RM-PAYMENT-APPROVAL` has no screen; `getPaymentApproval` is `x-conditional-on: Q-17` and answers `501`; `R-PIS-05` has named-but-unwritten examples; `STORY-PIS-PAYMENT-CONFIRM` unscheduled; `RSK-08` |
| `C-06` | The ADR calls the SCA journey app-managed while putting its first step in the browser | Drawn under `A-08`; `Q-12` |

The AIS side, by contrast, came out **more** coherent than before: the consent confirmation panel
is exactly what §6 expects of an ASPSP under the Detailed Consent model (`A-15`), so the
TPP-managed consent screen and the bank-side panel are two halves of one recognised pattern
rather than a contradiction.

## Generated artefacts

All under `docs/result/`, which mirrors the layout of `docs/ai/10-artifact-contract.md` and is
meant to be promoted to the repository root on acceptance.

| Area | Files |
| --- | --- |
| Problem and journeys | `journeys/problem-analysis.md`, `journeys/journey-map.md`, `journeys/service-blueprint.md` |
| Event storming | `journeys/xs2a-big-picture.eventstorm` (6 pivotal events), `journeys/ais-consent-lifecycle.eventstorm`, `journeys/pis-payment-initiation.eventstorm` — 34 hotspots, every one with a ledger id and an owner |
| Story mapping | `stories/xs2a-access-to-account.storymap` — 6 activities, 50 stories, 25 scheduled, 25 deliberately not |
| Example mapping | 8 `stories/*.examplemap` — 34 rules, 55 examples, 31 red cards |
| Domain | `domain/xs2a-access-to-account.ddd` (9 contexts), 4 `.ddm` with 20 invariants |
| Architecture | `system/README.md`, `system/c4/xs2a.likec4`, 9 PlantUML diagrams, 2 decision write-ups |
| Contracts | `system/api/openapi/xs2a-profile.yaml` (17 operations), `system/api/openapi/psu-channel.yaml` (7), `system/api/asyncapi/xs2a-domain-events.yaml` |
| Delivery | `delivery/walking-skeleton.md`, `delivery/mvp.md`, this file |
| Traceability | `traceability/manifest.yaml` (25 chains), `traceability/questions-and-assumptions.md`, `traceability/validation-report.md` |
| Projections | 8 regenerated `tests/acceptance/features/*.feature` |

## Instruction files and versions used

`docs/ai/00-ai-driven-sdlc-orchestration.md`, `10-artifact-contract.md`,
`20-review-and-delivery-policy.md`, and all four doctrine/notation pairs under `docs/ai/`.
Inputs: `SRC-IG` (NextGenPSD2 XS2A Implementation Guidelines v1.3.16, 27 Nov 2025) and `SRC-ADR`
at `7c44c2d`. Pinned in `traceability/manifest.yaml` under `input_revisions`.

## Traceability and impact

Every scheduled story has a chain through *objective → journey stage → pivotal event → story →
rules → bounded context → invariants → components → operations → tests → expected evidence*.
25 chains; 25 unscheduled stories each recorded with what would have to close first.

Impact on existing accepted intent: **none**. `docs/context/` and `docs/ai/` are untouched, and
`docs/result/` is new.

## Walking skeleton and MVP

**WS-01** (`delivery/walking-skeleton.md`) proves four hops the revised context makes uncertain: a
TPP request through Finologee; an account read decided against a vendor-mastered consent; a PSU
authenticated in the browser and confirming on an enrolled device with the result bound to what
they saw; and a DCP call with an exchanged PingFederate token. Nine `+skeleton` stories, one in
each of the six activities, so the first slice crosses the whole backbone.

**MVP-01** (`delivery/mvp.md`) is the smallest coherent slice: an AISP can be granted named
accounts, the PSU confirms them on their device, data is read within the agreed frequency, and
access ends. Its learning hypothesis is `H-01` — that PSUs abandon at the hand-over from browser
to device — which the revised context makes the central product risk.

## Validation results

`0 errors, 2 warnings, 9 info`, plus every external validator that could be installed:
`openapi-spec-validator` on both OpenAPI documents, PlantUML `-checkonly` on all nine diagrams,
and the AsyncAPI 3.0.0 schema — all passed. `likec4 validate` **could not be run** (no working
`npm` in the environment), so the LikeC4 grammar is unverified; its metadata was checked with a
local extractor. Details, including both warnings and every doctrine finding, in
`traceability/validation-report.md`.

`W-EM-02` is the one warning that is a real gap rather than an accepted one:
`STORY-SCA-METHOD-CHOICE` has no example map, and the choice between OTP, QR code and biometrics
is behaviour that nobody has examined.

## Assumptions and unresolved questions

18 assumptions, 47 open questions, 5 hypotheses, 9 decisions, 9 contradictions, 8 risks — in
`traceability/questions-and-assumptions.md`, `system/README.md` §4 and §6, and
`journeys/problem-analysis.md` §5.

The four assumptions carrying the most weight are `A-08` (the shape of the SCA journey), `A-15`
(the confirmation panel is the Detailed Consent model's ASPSP display), `A-16` (the bank keeps an
enforcing projection) and `A-17` (who signs the SCA assertion). If any is wrong, artefacts change
rather than get annotated.

Nothing in this pull request answers a red card. Where the AI had an opinion, it is written as a
recommendation in prose beside the question, and the question stays open.

## Required reviewers

| Gate | Reviewers | What they own here |
| --- | --- | --- |
| G1 | Product and UX | The journey map, the service blueprint, the slices, `H-01`, and whether the three proposed browser pages exist at all (`Q-18`) |
| G2 | Domain experts | The three storms, the context map, the invariants — especially `conformist` on `TPP Access -> Consent` (`W-DDD-02`) |
| G3 | Product, QA and development | The 34 rules and 55 examples, and the 31 red cards. None has been through a Three Amigos session |
| G4 | Architects and engineers | `system/README.md`, the C4 model, the three contracts, and `D-01` to `D-06` |
| G5 | Delivery and operations | WS-01 and MVP-01, the deployment path, and the six pieces of expected evidence |
| — | **Compliance** | `D-09` (a PSU cannot withdraw at the bank), `Q-17` (a payment confirmed with nothing shown), `Q-21` (a mandatory endpoint omitted), `Q-20`. These are not architecture trade-offs and no recommendation is offered on `D-09` |

## Merge criteria

Merge when the reviewers above have read the artefacts and the register reflects their
corrections — not when the questions are answered. The register is the deliverable; an empty one
at this stage would mean the proposal had stopped being honest.
