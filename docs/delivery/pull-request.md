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

## Iteration 2 — UX: screens and read models

After review of the first iteration, UX considerations were asked for: which read models each
actor or component needs to decide, which screens the PSU sees, and which component manages
each one.

- **[Service blueprint](../journeys/service-blueprint.md)** — the single definition of:
  - 13 screens: 11 bank-managed and 2 TPP context screens;
  - 15 read models, each with its consumer and the decision it supports, its fields and sources, its owning component and its consistency need.

  It also proposes UX requirements `UX-01`…`UX-07` and an accessibility baseline.
- **Screen ownership:**
  - `CMP-MOBILE-APP` manages authenticate, approve access, approve payment, outcome, request unavailable, and the three TPP-access screens;
  - `CMP-SCA-REDIRECT-UI` manages the hand-off page, the invalid-link page, and the unscheduled no-app page;
  - TPP screens stay with the TPP.
- **New component `CMP-PSU-CHANNEL-API` and contract `API-PSU-CHANNEL`** serve the PSU-facing read models and take approve, decline and revoke (6 operations). This closes the earlier gap `W-API-03`. Approval read models carry a `subjectDigest` that the decision echoes, which binds what the PSU saw to what SCA signs (`INV-AUT-05`).
- **Event storms:** the process storms gain `readmodel` and `ui` cards tagged `RM-*` / `SCR-*`, plus 6 new hotspots.
- **C4:** screens are nested in the containers that manage them; new view `psuScreens`.
- **Diagrams:** `docs/system/uml/ux/` holds two screen flows and three low-fi wireframes.
- **New stories:**
  - `STORY-SCA-OUTCOME` and `STORY-SCA-REQUEST-UNAVAILABLE`, both MVP;
  - `STORY-SCA-NO-APP`, unscheduled.
- **New ledger entries:**
  - questions `Q-35`…`Q-42`: partial approval, account labels, TPP brand, outcome screen, last-read info, fees, accessibility standard and languages;
  - assumptions `A-14` and `A-15`;
  - decision **`D-09`** — who renders the approval screens.
- **Validator:** also checks every `SCR-`/`RM-` reference and that each screen's owner matches the C4 model (mutation-tested).

## Iteration 3 — ADR revision: mobile app = last SCA factor; consent screen

Your ADR revision (`87c72b8`, committed separately) limits the bank mobile app to "a channel for
the last authentication factor". Granting and revoking a TPP's access now happens on a **consent
screen** presented in the TPP web application. Its frontend and backend come from the ASPSP
gateway or Finologee, which is still undecided.

- **Screens:** the approval, outcome and revoke screens move from the app to the consent screen (`CMP-CONSENT-SCREEN`, 9 screens). The app keeps a single screen, `SCR-APP-LAST-FACTOR`, fed by the new `RM-LAST-FACTOR-PROMPT`. The 11 former ids and `CMP-SCA-REDIRECT-UI` are **withdrawn** (blueprint §7), and the validator refuses them.
- **Scope:** the cross-TPP overview lost its channel. `STORY-PSU-ACCESS-OVERVIEW` is now unscheduled; `STORY-PSU-REVOKE` stays in the MVP, on the consent screen. Stories and example maps were re-worded; their rules are unchanged and the features were regenerated.
- **Models:**
  - storms: a "Consent screen" lane and a "Mobile app (last factor only)" lane;
  - context map: Mobile Banking reduced; the Consent → Mobile Banking relationship removed;
  - C4: the consent screen is a neutral element tagged `#undecided`;
  - sequences, screen flows and wireframes redrawn, plus a new app last-factor wireframe.
- **Contract:** `API-PSU-CHANNEL` is now the consent-screen backend. Its operations are tagged `x-conditional-on: D-01`, because Finologee may provide them instead. It adds `getAuthorisationOutcome` and `getLastFactorPrompt` and drops `listTppAccess`.
- **Decisions:**
  - **`D-01` recommendation revised to "no preference until a capability check"**, because the old argument (the app overview needed bank data) no longer holds;
  - `D-03` now means redirect to the consent screen, with the last factor pushed to the app;
  - `D-09` superseded;
  - **new `D-10`**: how SCA factors are split and how the app is triggered.
- **Ledger:**
  - `Q-26` answered in part;
  - `A-14` and `A-15` withdrawn; `A-03` is now a fact;
  - new questions `Q-43`…`Q-47` (how the PSU reaches the consent screen to revoke; redirect or embedded; factor split; payments on the consent screen; domain and branding);
  - new contradictions `C-11` and `C-12`, and new risks `RSK-06` (two-device drop-off) and `RSK-07` (embedding).

## Iteration 4 — reworked context: answers and evaluations

You reworked `docs/context/**` (committed as `7ed3eb1`) and asked for the options to be evaluated
and the questions answered.

**Answers delivered:**

| Asked in | Answer |
| --- | --- |
| `evaluations.md` — consent management, make or buy | [`D-01`](../system/decisions/d-01-consent-management.md): 11 weighted criteria, both options scored. **Recommendation: Make**, because the bank must decide every account read and every revocation without calling a vendor. Buy wins on standard fit and time to market. Conditional on a two-day verification of Finologee's capabilities; the document says what evidence would flip it |
| `questions.md` — token compatibility | [`D-02`](../system/decisions/d-02-token-compatibility.md): do **not** make the tokens compatible. Keep two trust domains — Finologee's token for the TPP, a Ping token inside — bridged once by RFC 8693 token exchange over mTLS, with the claim set spelled out. Four items to verify, and a fallback if Ping cannot do it |

**Answered by the ADR itself** (recorded in the ledger): who owns the login screen and the SCA
screen (`Q-07`, `Q-45`), that the screens are browser pages rather than embedded (`Q-44`), and the
consent-screen domain question (`Q-47`). Narrowed: `Q-04`, `Q-05`, `Q-06` (core banking is DCP),
`Q-21`.

**Proposed answers awaiting confirmation:** SCA approach is REDIRECT (`Q-03`), `PSU-ID` is not
required from TPPs (`Q-31`), the consent screen is reached after the login screen from the TPP and
from bank channels (`Q-43`), and a payment is approved on the SCA screen with no browser page
(`Q-46`, new `Q-48`).

**Artefacts reworked:** three PSU surfaces now — `SCR-IDP-LOGIN` (Ping), the consent screen
(access only), and `SCR-APP-SCA` (bank app, where payments are approved). `RM-SCA-PROMPT` replaces
the last-factor prompt; five more ids are withdrawn. Storms, story map, example maps, context map,
C4, sequences, screen flows, wireframes, the PSU-channel API, both packs and the manifest follow.
New: `Q-48`, `Q-49`, `A-16`…`A-18`, `RSK-08`; `RSK-07` closed.

## Artefacts added

| Area | Files |
| --- | --- |
| Problem & journeys | `docs/journeys/problem-analysis.md`, `docs/journeys/journey-map.md`, `docs/journeys/service-blueprint.md` (iteration 2) |
| Event Storming | `docs/journeys/xs2a-big-picture.eventstorm` (Big Picture: 6 pivotal events, 13 hotspots); `ais-consent-lifecycle.eventstorm`, `pis-payment-initiation.eventstorm` (process + system design) |
| Story Mapping | `docs/stories/xs2a-access-to-account.storymap`: 7 activities, 47 stories; proposed bands "Walking skeleton" and "MVP"; 22 stories deliberately unscheduled |
| Example Mapping | 8 × `docs/stories/*.examplemap`: 36 rules, 51 examples, 38 red cards |
| Context Mapping & Domain Modelling | `docs/domain/xs2a-access-to-account.ddd` (9 contexts); 4 × `.ddm` (Consent, Transaction Authorisation, Payment Initiation, Account Information; 20 invariants) |
| Architecture | `docs/system/README.md` (solution design and decisions `D-01`…`D-10`, `D-09` superseded); `docs/system/c4/xs2a.likec4` (6 views); 13 × `docs/system/uml/**.puml` (6 of them UX) |
| Contracts | `docs/system/api/openapi/xs2a-profile.yaml` (19 operations, OAS 3.1); `docs/system/api/openapi/psu-channel.yaml` (7 operations, internal, largely conditional on `D-01`); `docs/system/api/asyncapi/xs2a-domain-events.yaml` (internal, conditional on `D-04`) |
| Delivery packs | `docs/delivery/walking-skeleton.md` (WS-01), `docs/delivery/mvp.md` (MVP-01) |
| Decisions | `docs/system/decisions/d-01-consent-management.md` (make or buy), `d-02-token-compatibility.md` (token bridge) |
| Traceability | `docs/traceability/manifest.yaml`, `docs/traceability/questions-and-assumptions.md`, `docs/traceability/validation-report.md` |
| Projections | 8 × `tests/acceptance/features/*.feature`: generated from the example maps, each recording its source sha256 |
| Tooling | `tools/sdlc/dsl.py`, `validate.py`, `examplemap_to_feature.py` |
| Index | `docs/README.md` |

`docs/psd2/` and `docs/ai/` are untouched. `docs/context/adr.md` changed in one commit of its
own (`87c72b8`, authored by the repository owner): it is an *input* that iteration 3 follows,
not a generated artefact.

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

Each of the 25 scheduled stories has a complete chain in `manifest.yaml`: objective → journey
stage → pivotal event → story and slice → rules → context and invariants → components →
OpenAPI operations → **screens and read models** → delivery pack → generated feature →
expected evidence.
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

It is **blocked by `D-01`, `D-02`, `D-03`, `D-05`, `D-10`**. Screens involved:

- on the consent screen: `SCR-CONSENT-IDENTIFY`, a minimal `SCR-CONSENT-ACCESS` / `SCR-CONSENT-PAYMENT`, and `SCR-CONSENT-AWAIT-APP`;
- in the app: `SCR-APP-LAST-FACTOR`. Completion evidence: `EVID-WS-E2E`, `-TRACE`, `-CONTRACT`, `-DEPLOY`, `-DECISIONS`.

## MVP — MVP-01

**Outcome:** a PSU lets an AISP see chosen accounts and a PISP pay a merchant, approving both in the bank app, and can see and withdraw TPP access in the app.

**Hypothesis:** app-to-app SCA completes without abandonment. X/Y/Z targets are left to product (`Q-20`).

**Excluded:** everything optional in the spec, plus funds confirmation. Funds confirmation is **Mandatory** (§4.11.6), so leaving it out is flagged for compliance (`Q-14`, `RSK-04`).

## Validation

**0 errors.** All tools passed:

- the in-house DSL parsers;
- LikeC4 1.59.3 `validate` and `export`;
- PlantUML 1.2025.4 `-checkonly` (12/12);
- openapi-spec-validator 0.9.0 and Redocly 2.53.3 on both OpenAPI files (0 warnings);
- @asyncapi/parser 3.6.3;
- @cucumber/gherkin 42.0.1 (51/51 scenarios).

29 warnings are documented in [`validation-report.md`](../traceability/validation-report.md). The most important:

- `W-DSL-01` — the DSL parsers are re-implementations: **open every notation file in doc-es / doc-sm / doc-em / ba-cm before merging**;
- `W-SM-01` — funds confirmation is empty in every slice;
- `W-EM-01` — the consent example map is too big;
- `W-API-02` — no compatibility diff against the official Berlin Group OpenAPI yet;
- `W-UX-01` — screens and wireframes are not backed by UX research, and the wireframe copy is placeholder.

## Assumptions and unresolved questions

- 16 active assumptions and 39 fully open questions of `Q-01`…`Q-49` are in [`questions-and-assumptions.md`](../traceability/questions-and-assumptions.md).
- 31 hotspots on the storms and 39 red cards on the example maps stay red. None was answered by the AI.
- Questions that block WS-01: `Q-01`, `Q-02`, `Q-03`, `Q-04`, `Q-05`, `Q-07`, `Q-22`.
- `Q-23` (can a CC BY-ND-derived profile be published here?) needs legal before this repository is shared.

## Required reviewers

| Gate | Reviewers | Scope |
| --- | --- | --- |
| G1 | Product owner, UX | Problem analysis, journeys, **service blueprint, screen flows, wireframes**, objectives, slices (`D-07`, `D-08`), MVP hypothesis and targets |
| G2 | Domain experts: payments, compliance | Event storms, hotspots, context map (power and ownership), domain models, invariants |
| G3 | Product + QA + development | Run the 8 Example Mapping sessions, vote readiness, regenerate features |
| G4 | Architecture board, IAM, security, Finologee contact | C4, UML, OpenAPI (incl. `API-PSU-CHANNEL`), AsyncAPI, decisions `D-01`…`D-06`, `D-10` |
| G5 | Delivery, operations | WS-01 / MVP-01 packs, deployment path, observability, evidence |

After approval, the merge records the accepted intent. Decisions taken in review go to
`docs/context/adr.md`, and answered questions are closed in the ledger with their source.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
