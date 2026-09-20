# PR: Proposal — PSD2 XS2A solution design (walking skeleton WS-01, MVP-01)

**Branch:** `proposal/xs2a-solution-design` → `main` · **Base:** `56c8482` · **Type:** proposal —
nothing here is accepted intent until the review gates below pass.

## Problem and outcome

The bank must give licensed TPPs PSD2 access to its customers' payment accounts through a Berlin
Group NextGenPSD2 v1.3.16 XS2A interface. The building blocks are partly bought and partly built
(`docs/context/adr.md`):

- bought: **Finologee** as PSD2 gateway, **Ping Federate** as IDP (login screen and tokens),
  **Transmit** as CIAM (device enrolment, SCA trigger);
- built in house: the **ASPSP gateway**, the **consent screen** and the **mobile banking app**;
- core banking is the in-house **DCP** platform.

This PR proposes a connected design from journey to contract:

- a thin **walking skeleton (WS-01)** that proves the unknown hops end to end;
- an **MVP (MVP-01)**: AIS on dedicated accounts plus a single SEPA credit transfer, both
  authorised with redirect SCA, plus review and revoke of a TPP's access on the consent screen.

No business objectives, UX research or delivery context were supplied. Objectives are marked fact,
claim or hypothesis, and all targets are left to product.

## What the bank asked this proposal to answer

| Asked in | Answer |
| --- | --- |
| `context/evaluations.md` — consent management, make or buy | [`D-01`](../system/decisions/d-01-consent-management.md): weighted criteria, both options scored. **Recommendation: Make**, because the bank must decide every account read and every revocation without calling a vendor. Buy wins on standard fit and time to market. Conditional on a two-day verification of Finologee's capabilities; the write-up says what evidence would flip it |
| `context/questions.md` — token compatibility | [`D-02`](../system/decisions/d-02-token-compatibility.md): do **not** make the tokens compatible. Keep two trust domains — Finologee's token for the TPP, a Ping token inside — bridged once by RFC 8693 token exchange over mTLS, with the claim set spelled out. Four items to verify (`V1`…`V4`), and a fallback if Ping cannot do it |

Both are **recommendations, not decisions**: `docs/ai/20-review-and-delivery-policy.md` reserves
consequential architecture trade-offs for the architecture board (gate G4).

The rephrased ADRs (`ca518a7`) settle one half of `D-01` on their own: the **Bank ASPSP manages
the consent screen**, so `D-01` now decides only where the consent **state** is mastered (`A-19`).

## The gap the rephrased ADRs opened — `Q-46`

`ca518a7` describes the SCA screen as where the PSU *"confirms his identity using the final
authentication method"*; the earlier *"and his consent"* is gone. The consent screen has no role in
payments. **So no surface is defined on which the PSU sees a payment's amount and payee before
confirming** — which dynamic linking requires (`SRC-IG` §5.1.9).

This proposal does not close the gap by assuming an answer. It:

- **withdraws** the earlier assumption `A-17` (that the SCA screen carries amount and payee);
- records the gap as contradiction `C-06` and rewrites `Q-46` with the three candidate surfaces;
- adds `UX-09` — *a payment is never confirmed on a screen that does not show its amount and payee*
  — as the constraint any answer must satisfy;
- marks the PIS artefacts accordingly: the journey stage, the storm hotspot, the PIS sequence, the
  SCA wireframe (payment variant drawn as *one candidate*), `RM-PAYMENT-APPROVAL`, rule `R-PIS-05`
  and the generated scenario, which now reads *"the surface on which the payment is confirmed"*;
- flags it in the validation report as `W-ADR-02`, blocking the PIS half of WS-01.

`Q-46` belongs to compliance, product and IAM.

## Artefacts

| Area | Files |
| --- | --- |
| Problem & journeys | `docs/journeys/problem-analysis.md`, `journey-map.md`, `service-blueprint.md` |
| Event Storming | `xs2a-big-picture.eventstorm` (6 pivotal events); `ais-consent-lifecycle.eventstorm`, `pis-payment-initiation.eventstorm` (process + system design) |
| Story Mapping | `docs/stories/xs2a-access-to-account.storymap`: 7 activities, 48 stories, bands "Walking skeleton" and "MVP", 23 stories deliberately unscheduled |
| Example Mapping | 8 × `docs/stories/*.examplemap`: 36 rules, 51 examples, 39 red cards |
| Context & Domain Modelling | `docs/domain/xs2a-access-to-account.ddd` (9 contexts); 4 × `.ddm` (Consent, Transaction Authorisation, Payment Initiation, Account Information; 20 invariants) |
| Architecture | `docs/system/README.md` (decisions `D-01`…`D-08`); `docs/system/c4/xs2a.likec4` (19 components, 6 views); 13 × `docs/system/uml/**.puml`, 6 of them UX |
| Contracts | `api/openapi/xs2a-profile.yaml` (19 operations, OAS 3.1); `api/openapi/psu-channel.yaml` (7 operations, internal); `api/asyncapi/xs2a-domain-events.yaml` (internal, conditional on `D-04`) |
| Delivery packs | `docs/delivery/walking-skeleton.md` (WS-01), `docs/delivery/mvp.md` (MVP-01) |
| Decisions | `docs/system/decisions/d-01-consent-management.md`, `d-02-token-compatibility.md` |
| Traceability | `docs/traceability/manifest.yaml`, `questions-and-assumptions.md`, `validation-report.md` |
| Projections | 8 × `tests/acceptance/features/*.feature`, each recording the sha256 of its example map |
| Tooling | `tools/sdlc/dsl.py`, `validate.py`, `examplemap_to_feature.py` |
| Index | `docs/README.md` |

`docs/psd2/` and `docs/ai/` are untouched. `docs/context/**` are **inputs**, not generated
artefacts; they changed in their own commits, authored by the repository owner: `87c72b8` and
`7ed3eb1` carry the decisions this proposal follows, `dab96b2` and `44ea858` rephrase them and grow
the terminology, and `ca518a7` rephrases the ADRs again — two of those changes are substantive and
are handled above.

## UX: screens, read models and ownership

[`service-blueprint.md`](../journeys/service-blueprint.md) is the single definition of:

- **12 PSU-facing screens** — 1 on the IDP (`CMP-PING`), 7 on the consent screen
  (`CMP-CONSENT-SCREEN`, a Bank ASPSP surface), 2 in the bank app (`CMP-MOBILE-APP`), 2 at the TPP;
- **16 read models**, each with the decision it supports, its fields and sources, its owning
  component and its consistency need;
- **UX requirements `UX-01`…`UX-09`** and an accessibility baseline (`Q-42`).

The three bank surfaces come straight from the ADRs: Ping owns the login screen, the Bank ASPSP
manages the consent screen in the browser, and the CIAM asks the app to present the SCA screen on
the enrolled device. Approval read models carry a `subjectDigest` that the decision echoes, binding
what the PSU saw to what SCA signs (`INV-AUT-05`).

## Traceability and impact

Each of the **25 scheduled stories** has a complete chain in `manifest.yaml`: objective → journey
stage → pivotal event → activity → story → example map → rule → context → invariant → component →
OpenAPI operation → screen and read model → delivery pack → generated feature → expected evidence.
`tools/sdlc/validate.py` checks it in both directions: every scheduled story has a chain, every
operation traces to a story, every component names its context, every `SCR-`/`RM-` id is defined in
the blueprint, and each screen's owner matches the C4 element that nests it.

**Impact:** new artefacts only. Proposed new components: the ASPSP gateway modules (XS2A adapter,
consent, authorisation, payment, account information, core adapter, outbox, store), the PSU channel
API, and the consent screen. Where the **consent state** lives is `D-01`.

## Walking skeleton — WS-01

Proves the path test TPP (test QWAC) → Finologee → ASPSP gateway → redirect → Ping login → consent
screen → Transmit → bank app → DCP **stub**, deployed by the pipeline and traced by `X-Request-ID`.

- **AIS:** consent → approve → account list → delete.
- **PIS:** 123.50 EUR SCT → confirm → `ACTC`.

Blocked by `D-01`, `D-02`, `D-03`, `D-05` — and, for the PIS scenario, by **`Q-46`**. Completion
evidence: `EVID-WS-E2E`, `-TRACE`, `-CONTRACT`, `-DEPLOY`, `-DECISIONS`.

## MVP — MVP-01

**Outcome:** a PSU lets an AISP see chosen accounts and a PISP pay a merchant, and can review and
withdraw a TPP's access on the consent screen.

**Learning hypothesis:** the browser-to-app hand-over completes without abandonment (`H-01`).
Targets are left to product (`Q-20`).

**Excluded:** everything optional in the spec, plus funds confirmation — which is **Mandatory**
(§4.11.6), so its exclusion is flagged for compliance (`Q-14`, `RSK-04`) rather than hidden.

## Validation

**0 errors** from `tools/sdlc/validate.py`. External validators passed at the last full run:
LikeC4 1.59.3, PlantUML 1.2025.4 (12/12), openapi-spec-validator 0.9.0 and Redocly 2.53.3 (0
warnings), @asyncapi/parser 3.6.3, @cucumber/gherkin 42.0.1 (51/51 scenarios).

24 warnings are documented in [`validation-report.md`](../traceability/validation-report.md). The
ones that matter most:

- `W-ADR-02` — the payment-approval surface is undefined (`Q-46`), as described above;
- `W-DSL-01` — the DSL parsers are re-implementations from the published EBNF: **open every
  notation file in doc-es / doc-sm / doc-em / ba-cm before merging**;
- `W-DEC-01` — `D-01` and `D-02` are recommendations with verification steps, not decisions;
- `W-SM-01` — funds confirmation is empty in every slice;
- `W-EM-01` — the consent example map is too big to be ready;
- `W-API-02` — no compatibility diff against the official Berlin Group OpenAPI file yet;
- `W-UX-01` — screens and wireframes are not backed by UX research; wireframe copy is placeholder.

## Assumptions and unresolved questions

- **45 open questions**, 16 assumptions and 5 hypotheses in
  [`questions-and-assumptions.md`](../traceability/questions-and-assumptions.md).
- **31 hotspots** on the storms and **39 red cards** on the example maps stay red. None was
  answered by the AI; each names the role that closes it.
- Questions that block WS-01: `Q-03`, `Q-04`, `Q-05`, `Q-07`, `Q-22`, `Q-34`, `Q-45`, **`Q-46`**,
  `Q-48`.
- `Q-23` (may a CC BY-ND-derived profile be published here?) needs legal before this repository is
  shared.

## Required reviewers

| Gate | Reviewers | Scope |
| --- | --- | --- |
| G1 | Product owner, UX | Problem analysis, journeys, service blueprint, screen flows, wireframes, objectives, slices (`D-07`, `D-08`), MVP hypothesis and targets |
| G2 | Domain experts: payments, compliance | Event storms, hotspots, context map (power and ownership), domain models, invariants, **`Q-46`** |
| G3 | Product + QA + development | Run the 8 Example Mapping sessions, vote readiness, regenerate the features |
| G4 | Architecture board, IAM, security, Finologee contact | C4, UML, OpenAPI (incl. `API-PSU-CHANNEL`), AsyncAPI, decisions `D-01`…`D-06` |
| G5 | Delivery, operations | WS-01 / MVP-01 packs, deployment path, observability, evidence |

After approval, the merge records the accepted intent. Decisions taken in review go to
`docs/context/adr.md`, and answered questions are closed in the ledger with their source.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
