# Validation report — PSD2 XS2A solution-design proposal

> Generated 2026-09-19 on branch `proposal/xs2a-solution-design` (base `56c8482`), per
> [`docs/ai/20-review-and-delivery-policy.md`](../ai/20-review-and-delivery-policy.md) §Validation.
> A clean result below is **evidence, not acceptance**. Acceptance happens only at the human
> review gates G1–G5 (end of this report).
>
> **Iteration 2 (UX)** added:
> - the [service blueprint](../journeys/service-blueprint.md): 13 screens and 15 read models;
> - `readmodel` and `ui` cards on both process storms;
> - three stories;
> - screens in the C4 model (view `psuScreens`), with the new component `CMP-PSU-CHANNEL-API`;
> - `API-PSU-CHANNEL`;
> - two screen flows and three wireframes;
> - `Q-35`…`Q-42`, `A-14`, `A-15` and `D-09`.
>
> **Iteration 3** followed your ADR revision `87c72b8`: the mobile app carries only the last SCA
> factor, and a consent screen (ASPSP gateway or Finologee) handles grant and revoke. It:
>
> - re-homed 11 screens onto the consent screen and withdrew their ids (blueprint §7) together with `CMP-SCA-REDIRECT-UI`;
> - added `SCR-APP-LAST-FACTOR`, `RM-LAST-FACTOR-PROMPT` and two PSU-channel operations, and removed `listTppAccess`;
> - moved `STORY-PSU-ACCESS-OVERVIEW` to unscheduled;
> - recorded `Q-26` as answered in part, withdrew `A-14`/`A-15`, superseded `D-09`, and added `Q-43`…`Q-47`, `D-10`, `RSK-06` and `RSK-07`;
> - taught the validator to refuse withdrawn ids in active artefacts (mutation-tested).
>
> **Iteration 4** follows your reworked context (`7ed3eb1`) and **answers the questions it asks**:
>
> - [`D-01`](../system/decisions/d-01-consent-management.md) evaluates consent management make-or-buy against 11 weighted criteria — recommendation **Make**, conditional on a two-day check of the Buy option;
> - [`D-02`](../system/decisions/d-02-token-compatibility.md) answers token compatibility — two trust domains bridged by RFC 8693 token exchange at Ping, with `V1`…`V4` to verify;
> - the ADR itself answered `Q-44`, `Q-45`, `Q-46`, `Q-47` and the `Q-07` split, and narrowed `Q-04`, `Q-05`, `Q-06` and `Q-21`; `Q-03`, `Q-31` and `Q-43` have proposed answers awaiting confirmation;
> - screens were re-homed again — an IDP login screen, a consent screen for access only, and the app SCA screen (which is where a payment is approved) — withdrawing 5 more ids;
> - new: `Q-48`, `Q-49`, `A-16`…`A-18`, `RSK-08`; `RSK-07` closed; `D-03` and `D-10` answered.
>
> The counts below are after iteration 4.

## Result

| | Count |
| --- | --- |
| Errors | **0** |
| Warnings from the automated run | 9 (grouped below with manual findings as `W-*`) |
| Manual warnings (review, not tooling) | 20 |
| Open questions | 39 fully open of `Q-01`…`Q-49`; 6 answered (`Q-26`, `Q-44`, `Q-45`, `Q-46`, `Q-47`, plus `Q-01`/`Q-02` evaluated), 4 narrowed |
| Assumptions | 16 active of `A-01`…`A-18` (`A-14`, `A-15` withdrawn; `A-03` now a fact) |
| Decisions needing human authority | 6 open (`D-01`, `D-02`, `D-04`, `D-05`, `D-06`, plus product `D-07`, `D-08`); `D-03` and `D-10` answered by the ADR; `D-09` superseded |

**Inventory checked:**

| Artefact | Count |
| --- | --- |
| Notation files | 17 |
| Pivotal events | 6 |
| Hotspots | 31 (3 closed by the ADR) |
| Stories (25 scheduled, 23 unscheduled) | 48 |
| Example maps | 8 |
| Rules | 36 |
| Examples / generated scenarios | 51 |
| Red cards | 39 |
| Bounded contexts | 9 |
| Invariants | 20 |
| Components | 19 |
| PSU-facing screens (1 IDP, 7 consent screen, 2 app, 2 TPP) | 12 |
| Read models | 16 |
| Withdrawn ids (15 screens, 1 read model, 1 component) | 17 |
| OpenAPI operations (19 XS2A + 7 PSU channel) | 26 |

## How it was run (reproducible)

```sh
# internal checks: DSL parsing, identifiers, referential integrity, ledger, projections
python3 tools/sdlc/validate.py            # needs PyYAML; add LIKEC4_JSON=… for component checks
# regenerate / check the Gherkin projections
python3 tools/sdlc/examplemap_to_feature.py --check
# with third-party validators (paths via env vars, see the docstring of validate.py)
LIKEC4_JSON=… LIKEC4=… PLANTUML_JAR=… OPENAPI_VALIDATOR=… REDOCLY=… ASYNCAPI_VALIDATOR=… \
  python3 tools/sdlc/validate.py --external
```

| Validator | Version | Scope | Result |
| --- | --- | --- | --- |
| `tools/sdlc/dsl.py` (this proposal) | — | 3 `.eventstorm`, 1 `.storymap`, 8 `.examplemap`, 1 `.ddd`, 4 `.ddm` | passed — see `W-DSL-01` |
| `tools/sdlc/validate.py` (this proposal) | — | identifiers, references, manifest chains, ledger, projections; **iteration 2:** every `SCR-`/`RM-` reference resolves to the blueprint, each screen's "managed by" matches its parent in C4 (mutation-tested), `ui`/`readmodel` card kinds, orphan read models | 0 errors |
| LikeC4 CLI `validate` + `export json` | 1.59.3 | `docs/system/c4/xs2a.likec4` (6 views resolve) | passed |
| PlantUML `-checkonly` | 1.2025.4 | 12 diagrams (7 + 5 UX) | passed |
| openapi-spec-validator | 0.9.0 | `xs2a-profile.yaml`, `psu-channel.yaml` (OAS 3.1.0) | passed |
| Redocly CLI `lint` (recommended ruleset) | 2.53.3 | `xs2a-profile.yaml`, `psu-channel.yaml` | passed, 0 warnings |
| @asyncapi/parser | 3.6.3 | `xs2a-domain-events.yaml` (AsyncAPI 3.0.0) | passed (info: 3.1.0 available) |
| @cucumber/gherkin | 42.0.1 | 8 generated `.feature` files, 51 scenarios | passed |

## Checks required by the policy

| Check | Status | Notes |
| --- | --- | --- |
| Every file against its DSL or schema | ✅ | All notation files, C4, UML, OpenAPI, AsyncAPI and Gherkin. See `W-DSL-01` for the limits of the in-house parsers |
| Identifier uniqueness | ✅ | `EVT`, `STORY`, `R`, `INV`, `CMP` and `operationId` checked by `validate.py` |
| Referential integrity | ✅ | Manifest chain: objective → stage → pivotal event → activity → story → example map → rule → context → invariant → component → operation → delivery pack → test file → evidence |
| Vocabulary consistency within contexts | ⚠️ manual | Collisions resolved in the [problem analysis §3](../journeys/problem-analysis.md#3-shared-vocabulary); `W-TERM-01`, `W-SPEC-01`, `W-SPEC-02` |
| Compatibility of changed technical contracts | ⚠️ | No prior contract exists, so there is nothing to break. Compatibility with the official Berlin Group files was **not** checked: `W-API-02` |
| Traceability from delivery scope to source intent | ✅ | All 24 scheduled stories have a full chain. All 20 unscheduled stories are listed with their blocking question |
| Examples and tests tied to their source revision | ✅ / ⚠️ | Every `.feature` records the `sha256` of its example map, and `--check` detects drift. Git revision is recorded after merge (`W-SRC-01`) |
| Architecture relationships vs agreed policies | ⛔ not possible | No architecture policies were supplied (`Q-22`) |
| Required production evidence | ⛔ none yet | Nothing is built. The packs name the *expected* evidence (`EVID-*`), and the manifest links it |

## Warnings

### From the automated run

| ID | Finding | Owner | Ledger |
| --- | --- | --- | --- |
| `W-SM-01` | Activity "Confirm available funds" has no pivotal event on the Big Picture and is **empty in both WS-01 and MVP-01**, although `POST /funds-confirmations` is Mandatory (§4.11.6). Left visible on purpose; the doctrine forbids hiding it | compliance | `Q-14`, `RSK-04` |
| `W-EM-01` | `EXMAP-CONSENT-DEDICATED` has 7 rules and 7 red cards: the story is too big and not ready. Suggested split: *consent shape* (R-CNS-01..04) and *validity and replacement* (R-CNS-05..07) | product, QA, dev | — |
| `W-EM-02` | 4 scheduled stories have no example map: `STORY-XS2A-PROFILE`, `STORY-READ-BALANCES`, `STORY-READ-TRANSACTIONS`, `STORY-CONSENT-DELETE`. Run one for `STORY-READ-TRANSACTIONS` before refinement | product, QA, dev | — |

### From review

| ID | Finding | Owner | Ledger |
| --- | --- | --- | --- |
| `W-DSL-01` | The `.eventstorm`, `.storymap`, `.examplemap`, `.ddd` and `.ddm` parsers are re-implementations written from the published EBNF. They were negative-tested against 15 invalid inputs, but they are not the reference parsers. **Open each file in doc-es, doc-sm, doc-em and ba-cm before merging**; where they disagree, the board's parser is right | reviewers | — |
| `W-DSL-02` | Online `.ddm` grammar (ba-cm.obya.ch/dsl, fetched 2026-09-19) is stricter than the exported `docs/ai/notations/ba-cm-notation.md`: aggregate and enum bodies are required, and an enum needs at least one value. The files follow the stricter form. The exported notation should be refreshed | repo owner | — |
| `W-DSL-03` | The artefact contract asks tactical models to show *domain events and policies*, but `.ddm` has no syntax for them. They live in the process-level event storms instead, and each `.ddm` points there | repo owner | — |
| `W-DDD-01` | No subdomain is classified `core`. For the bank, XS2A is a regulatory obligation built around bought products, and calling part of it core would be an unfunded claim. If product sees the in-app SCA experience as differentiating, that is a budget decision for them | domain experts, product | `Q-20` |
| `W-DDM-01` | "A new recurring consent ends the former one" (§6.3.1.1) spans two `Consent` aggregates. It is modelled as an eventually consistent policy, not as an invariant, and its target status is disputed | domain experts | `Q-08` |
| `W-API-01` | The profile uses OpenAPI **3.1** (`mutualTLS` security scheme). The Berlin Group publishes 3.0.x files, so check that the Finologee and bank tooling accept 3.1 | architecture | `Q-04` |
| `W-API-02` | The official Berlin Group v1.3.16 OpenAPI file was not supplied, so the profile was written from the IG text. Before implementation, run a compatibility diff against the official file. `TransactionDetails` is a deliberate minimal subset of §14.25 | architecture | `Q-23` |
| `W-API-03` | ~~The mobile app ↔ gateway API is not specified~~. **Resolved in iteration 2** by `API-PSU-CHANNEL`, which still assumes `D-01` option A and `A-14` | architecture | `Q-26`, `D-01`, `D-09` |
| `W-UX-01` | Screens, flows and wireframes are derived from the spec and the models, **not from UX research** (`Q-21`). Wireframe copy is placeholder, and "Sandbox PISP Ltd" and "Budget Buddy" are invented labels (`A-09`) | UX | `Q-21` |
| `W-UX-02` | `SCR-`/`RM-` ids are defined in Markdown tables that the validator parses. Changing the first-column format breaks the check silently. Consider moving the definitions to YAML if the blueprint grows | repo owner | — |
| `W-UX-03` | The owner of `RM-SCA-CONTEXT`, and the factor split between `SCR-CONSENT-IDENTIFY` and `SCR-APP-LAST-FACTOR`, are open. The C4 model tags them `#undecided` | iam, UX | `Q-07`, `Q-45`, `D-10` |
| `W-ADR-01` | Your ADR revision `87c72b8` removed two things the earlier iterations had built on: the in-app approval screens and the cross-TPP overview. Iteration 3 withdrew or re-homed them rather than keeping both versions. Check that `STORY-PSU-ACCESS-OVERVIEW` being unscheduled matches your intent | product | `Q-26`, `Q-43` |
| `W-ADR-02` | ~~"Presented in the TPP web application" read as a redirect~~ — **resolved**: the reworked ADR says login and consent screens are "presented to PSU in the web browser". `C-11` and `RSK-07` are closed | — | `Q-44` |
| `W-ADR-03` | Three readings in iteration 4 are **inferences from the ADR, not statements in it**: that a payment is approved on the SCA screen with no browser page (`A-17`, `Q-46`), that a payment redirect lands on the same bank web journey (`Q-48`), and that Ping signs the SCA assertion (`A-18`, `Q-07`). Each is flagged where it is used | compliance, iam | `Q-46`, `Q-48`, `Q-07` |
| `W-DEC-01` | `D-01` and `D-02` are **AI recommendations with explicit criteria and verification steps**, not decisions. `D-01` depends on capabilities of Finologee and `D-02` on PingFederate's RFC 8693 support — neither verified in the supplied material | architecture, iam | `D-01`, `D-02` |
| `W-UML-01` | §14.16 lists `scaStatus` codes but not every transition. The transitions in `sca-status.puml` are this proposal's reading | architecture | — |
| `W-TERM-01` | `SRC-TERM` lists "eDAS"; the spec says eIDAS. Treated as a typo | author of `terminology.md` | — |
| `W-SPEC-01` | The spec's flow diagrams use `ACCT`, `REJT` and `ACTV` (§5.1.8–5.1.10, §6.1.1), which do not exist in the code lists (§14.13, §14.15). The code lists were used | — | `C-07` |
| `W-SPEC-02` | The spec is inconsistent about the method-selection link name (`selectAuthenticationMethods` in §6.3.1.1 vs the §4.15/§14.6 names). It is irrelevant for redirect-only MVP scope | — | `C-08` |
| `W-DATA-01` | Test labels "Sandbox AISP Ltd", "PSU-1234", "PSU-5678", "PSDFR-ACPR-12345", "BrandA" and "BrandB" are invented placeholders. All other values are spec examples | QA | `A-09` |
| `W-INF-01` | Rule R-FRQ-02 ("PSU-initiated reads don't count") is an **inference**, tagged `+inferred` on the map and reflected in `INV-ACC-04` | compliance | — |
| `W-SRC-01` | Projections record the source `sha256`, because no commit exists until this branch is committed. After merge, the accepted commit becomes the source revision for GitOps projections | repo owner | — |

## Example-map readiness

"Ready" is decided by the room's vote, not by the AI. This is only a reading of card counts
against the doctrine.

| Map | Rules | Examples | Edge cases | Red cards | Reading |
| --- | --- | --- | --- | --- | --- |
| `tpp-identify` | 4 | 6 | 3 | 5 | not ready |
| `consent-dedicated` | 7 | 11 | 5 | 7 | too big, not ready |
| `sca-redirect-app` | 5 | 9 | 6 | 6 | not ready (`D-03`, `Q-07`) |
| `read-account-list` | 4 | 7 | 5 | 2 | nearest to ready |
| `enforce-frequency` | 3 | 4 | 2 | 3 | not ready (`W-INF-01`) |
| `psu-revoke` | 4 | 5 | 2 | 6 | not ready (`Q-26`, `D-01`) |
| `pis-initiate-sct` | 5 | 5 | 3 | 5 | not ready |
| `pis-status` | 4 | 4 | 2 | 4 | not ready (`Q-28`, `Q-29`) |

## Decisions that require human authority

| ID | Decision | Decides | Blocks |
| --- | --- | --- | --- |
| `D-01` | Where the AIS consent lifecycle lives | Architecture board + product + compliance | WS-01 |
| `D-02` | Token model Finologee → gateway | Architecture board + IAM | WS-01 |
| `D-03` | SCA approach(es) offered | Product + architecture + compliance | WS-01 |
| `D-04` | Status propagation between contexts | Engineering lead | MVP-01 |
| `D-05` | Responsibility split at the TPP edge | Architecture board + Finologee | WS-01 |
| `D-06` | Deployment shape of the gateway | Engineering lead | WS-01 |
| `D-07` | Accept or change the WS-01 / MVP-01 slices | Product owner | both |
| `D-08` | MVP-01 as production go-live or testing facility | Product owner + compliance | MVP-01 |
| ~~`D-09`~~ | ~~Who renders the approval screens~~ — **superseded** | — | — |
| ~~`D-10`~~ | ~~How SCA is split~~ — **answered by `SRC-ADR` `7ed3eb1`**: IDP login screen, then the SCA screen in the app on an enrolled device. Factor categories and the assertion signer remain (`Q-45`, `Q-07`) | IAM | WS-01 |

The AI's recommendations for `D-01`…`D-06` and `D-10` are in [`docs/system/README.md` §4](../system/README.md#4-decisions-that-need-human-authority).
They are recommendations only.

## Review gates

| Gate | Reviewers | Reviews |
| --- | --- | --- |
| G1 | Product, UX | Problem analysis, journey map, **service blueprint, screen flows, wireframes, `UX-01`…`UX-07`**, objectives, story map slices, MVP hypothesis |
| G2 | Domain experts (payments, compliance) | Event storms, context map, domain models, invariants, hotspots |
| G3 | Product, QA, development (Three Amigos) | Example maps — run each session and vote; regenerate the features |
| G4 | Architects, engineers, security, IAM | C4, UML, OpenAPI (incl. `API-PSU-CHANNEL`), AsyncAPI, `D-01`…`D-06`, `D-10` |
| G5 | Delivery, operations | Walking-skeleton and MVP packs, evidence, observability |

Reviewers may edit the models on the boards (doc-es, doc-sm, doc-em, ba-cm). The as-code files
in this branch must be re-exported from those boards so the edits are captured.
