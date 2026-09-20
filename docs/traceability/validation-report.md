# Validation report — PSD2 XS2A solution-design proposal

> Generated on branch `proposal/xs2a-solution-design`, per
> [`docs/ai/20-review-and-delivery-policy.md`](../ai/20-review-and-delivery-policy.md) §Validation.
> A clean result below is **evidence, not acceptance**: acceptance happens only at the human
> review gates G1–G5 at the end of this report.

## Result

| | Count |
| --- | --- |
| Errors | **0** |
| Warnings from the automated run | 9 (grouped below as `W-*`) |
| Warnings from review | 15 |
| Open questions | 45 |
| Assumptions | 16 |
| Decisions needing human authority | 8 (`D-01`…`D-08`; `D-01` and `D-02` written up in full) |

**Inventory checked:**

| Artefact | Count |
| --- | --- |
| Notation files | 17 |
| Pivotal events | 6 |
| Hotspots | 31 |
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
| OpenAPI operations (19 XS2A + 7 PSU channel) | 26 |

## How it was run (reproducible)

```sh
# internal checks: DSL parsing, identifiers, referential integrity, ledger, projections
python3 tools/sdlc/validate.py            # needs PyYAML; add LIKEC4_JSON=… for component checks
# regenerate or check the Gherkin projections
python3 tools/sdlc/examplemap_to_feature.py --check
# with the third-party validators (paths via env vars; see the docstring of validate.py)
LIKEC4_JSON=… LIKEC4=… PLANTUML_JAR=… OPENAPI_VALIDATOR=… REDOCLY=… ASYNCAPI_VALIDATOR=… \
  python3 tools/sdlc/validate.py --external
```

| Validator | Version | Scope | Result |
| --- | --- | --- | --- |
| `tools/sdlc/dsl.py` (this proposal) | — | 3 `.eventstorm`, 1 `.storymap`, 8 `.examplemap`, 1 `.ddd`, 4 `.ddm` | passed — see `W-DSL-01` |
| `tools/sdlc/validate.py` (this proposal) | — | identifiers, references, manifest chains, screens and read models, ledger, projections | 0 errors |
| LikeC4 CLI `validate` + `export json` | 1.59.3 | `docs/system/c4/xs2a.likec4`, 6 views | passed |
| PlantUML `-checkonly` | 1.2025.4 | 12 diagrams | passed |
| openapi-spec-validator | 0.9.0 | `xs2a-profile.yaml`, `psu-channel.yaml` (OAS 3.1.0) | passed |
| Redocly CLI `lint` (recommended ruleset) | 2.53.3 | both OpenAPI files | passed, 0 warnings |
| @asyncapi/parser | 3.6.3 | `xs2a-domain-events.yaml` (AsyncAPI 3.0.0) | passed |
| @cucumber/gherkin | 42.0.1 | 8 generated `.feature` files, 51 scenarios | passed |

## Checks required by the policy

| Check | Status | Notes |
| --- | --- | --- |
| Every file against its DSL or schema | ✅ | All notation files, C4, UML, OpenAPI, AsyncAPI and Gherkin. See `W-DSL-01` for the limits of the in-house parsers |
| Identifier uniqueness | ✅ | `EVT`, `STORY`, `R`, `INV`, `CMP`, `SCR`, `RM` and `operationId` |
| Referential integrity | ✅ | The manifest chain: objective → journey stage → pivotal event → activity → story → example map → rule → context → invariant → component → operation → screen and read model → delivery pack → test file → evidence |
| Vocabulary consistency within contexts | ✅ / ⚠️ manual | Collisions resolved in the [problem analysis §3](../journeys/problem-analysis.md#3-shared-vocabulary); the context terms live in the `.ddd`. `W-SPEC-01` and `W-SPEC-02` record where the specification is inconsistent with itself |
| Compatibility of changed technical contracts | ⚠️ | No prior contract exists, so nothing can break. Compatibility with the official Berlin Group files was **not** checked: `W-API-02` |
| Traceability from delivery scope to source intent | ✅ | All 25 scheduled stories have a full chain; all 23 unscheduled ones are listed with what blocks them |
| Examples and tests tied to their source revision | ✅ | Every `.feature` records the sha256 of its example map, and `--check` detects drift |
| Architecture relationships against agreed policies | ⛔ not possible | No architecture policies were supplied (`Q-22`) |
| Required production evidence | ⛔ none yet | Nothing is built. The packs name the *expected* evidence (`EVID-*`), and the manifest links it |

## Warnings

### From the automated run

| ID | Finding | Owner | Ledger |
| --- | --- | --- | --- |
| `W-SM-01` | The activity "Confirm available funds" has no pivotal event and is **empty in both WS-01 and MVP-01**, although `POST /funds-confirmations` is Mandatory (§4.11.6). Left visible on purpose: the doctrine forbids hiding it | compliance | `Q-14`, `RSK-04` |
| `W-EM-01` | `EXMAP-CONSENT-DEDICATED` carries 7 rules and 7 red cards: the story is too big and not ready. Suggested split: *consent shape* (R-CNS-01…04) and *validity and replacement* (R-CNS-05…07) | product, QA, dev | — |
| `W-EM-02` | Four scheduled stories have no example map: `STORY-XS2A-PROFILE`, `STORY-READ-BALANCES`, `STORY-READ-TRANSACTIONS`, `STORY-CONSENT-DELETE`. Run one for `STORY-READ-TRANSACTIONS` before refinement | product, QA, dev | — |

### From review

| ID | Finding | Owner | Ledger |
| --- | --- | --- | --- |
| `W-DSL-01` | The `.eventstorm`, `.storymap`, `.examplemap`, `.ddd` and `.ddm` parsers are re-implementations written from the published EBNF. They are negative-tested, but they are not the reference parsers. **Open each file in doc-es, doc-sm, doc-em and ba-cm before merging**; where they disagree, the board's parser is right | reviewers | — |
| `W-DSL-02` | The online `.ddm` grammar (ba-cm.obya.ch/dsl) is stricter than the exported `docs/ai/notations/ba-cm-notation.md`: aggregate and enum bodies are required, and an enum needs at least one value. The files follow the stricter form; the exported notation should be refreshed | repo owner | — |
| `W-DSL-03` | The artefact contract asks tactical models to show *domain events and policies*, but `.ddm` has no syntax for either. They live in the process-level storms instead, and each `.ddm` says so | repo owner | — |
| `W-DDD-01` | No subdomain is classified `core`. For the bank, XS2A is a regulatory obligation built around bought products, and calling part of it core would be an unfunded budget claim. If product sees the in-app SCA experience as differentiating, that is their decision to make | domain experts, product | `Q-20` |
| `W-DDM-01` | "A new recurring consent ends the former one" (§6.3.1.1) spans two `Consent` aggregates. It is modelled as an eventually consistent policy, not an invariant, and its target status is disputed | domain experts | `Q-08` |
| `W-API-01` | The profiles use OpenAPI **3.1** (`mutualTLS`). The Berlin Group publishes 3.0.x, so check that the Finologee and bank tooling accept 3.1 | architecture | `Q-04` |
| `W-API-02` | The official Berlin Group v1.3.16 OpenAPI file was not supplied, so the profile was written from the IG text. Run a compatibility diff before implementation. `TransactionDetails` is a deliberate minimal subset of §14.25 | architecture | `Q-23` |
| `W-UX-01` | Screens, flows and wireframes are derived from the specification and the ADR, **not from UX research** (`Q-21`). Wireframe copy is placeholder, and several labels are invented (`A-09`) | UX | `Q-21` |
| `W-UX-02` | `SCR-` and `RM-` ids are defined in Markdown tables that the validator parses. Changing the first-column format breaks the check silently; consider YAML if the blueprint grows | repo owner | — |
| `W-UX-03` | The factor split between `SCR-IDP-LOGIN` and `SCR-APP-SCA`, and who signs the SCA assertion, are open. The C4 model tags the affected elements `#undecided` | iam, UX | `Q-07`, `Q-45` |
| `W-ADR-01` | Two readings in this proposal are **inferences from the ADR, not statements in it**: that a payment redirect lands on the same bank web journey (`Q-48`), and that Ping signs the SCA assertion (`A-18`, `Q-07`). Each is flagged where it is used | compliance, iam | `Q-48`, `Q-07` |
| `W-ADR-02` | **The ADR rephrasing of 2026-09-20 opened a gap.** It states that the Bank ASPSP manages the consent screen (which settles the screen half of `D-01`) and that the SCA screen is where the PSU *confirms his identity using the final authentication method*. The earlier "confirms identity and his consent" is gone. So **no surface is defined on which the PSU sees a payment's amount and payee before confirming**, which dynamic linking requires (`SRC-IG` §5.1.9). The previous assumption (`A-17`, that the SCA screen carries them) has been **withdrawn** rather than kept silently; the PIS artefacts now mark the surface as undecided, and `UX-09` states the constraint any answer must meet. This blocks the PIS half of WS-01 | compliance, product, iam | `Q-46`, `C-06` |
| `W-DEC-01` | `D-01` and `D-02` are **AI recommendations with explicit criteria and verification steps**, not decisions. `D-01` depends on Finologee capabilities and `D-02` on PingFederate's RFC 8693 support; neither is verified in the supplied material | architecture, iam | `D-01`, `D-02` |
| `W-SPEC-01` | The spec's flow diagrams use `ACCT`, `REJT` and `ACTV` (§5.1.8–5.1.10, §6.1.1), which do not exist in the code lists (§14.13, §14.15). The code lists were used | — | `C-03` |
| `W-SPEC-02` | The spec is inconsistent about the method-selection link name (§6.3.1.1 against §4.15 and §14.6). It does not affect the redirect-only MVP | — | `C-04` |
| `W-UML-01` | §14.16 lists the `scaStatus` codes but not every transition. The transitions in `sca-status.puml` are this proposal's reading | architecture | — |
| `W-DATA-01` | Test labels such as "Sandbox AISP Ltd" and "PSU-1234" are invented placeholders; all other values are the spec's examples | QA | `A-09` |
| `W-INF-01` | Rule R-FRQ-02 ("PSU-initiated reads do not count") is an **inference**, tagged `+inferred` on the map and reflected in `INV-ACC-04` | compliance | — |

## Example-map readiness

"Ready" is decided by the room's vote, not by an AI. This is only a reading of the card counts
against the doctrine.

| Map | Rules | Examples | Edge cases | Red cards | Reading |
| --- | --- | --- | --- | --- | --- |
| `tpp-identify` | 4 | 6 | 3 | 5 | not ready |
| `consent-dedicated` | 7 | 11 | 5 | 7 | too big, not ready |
| `sca-redirect-app` | 5 | 9 | 6 | 6 | not ready (`D-03`, `Q-07`) |
| `read-account-list` | 4 | 7 | 5 | 2 | nearest to ready |
| `enforce-frequency` | 3 | 4 | 2 | 3 | not ready (`W-INF-01`) |
| `psu-revoke` | 4 | 5 | 2 | 6 | not ready (`Q-43`, `D-01`) |
| `pis-initiate-sct` | 5 | 5 | 3 | 6 | not ready — `Q-46` now blocks R-PIS-05 (`Q-13`, `Q-16`) |
| `pis-status` | 4 | 4 | 2 | 4 | not ready (`Q-28`, `Q-29`) |

## Decisions that require human authority

| ID | Decision | Decides | Blocks |
| --- | --- | --- | --- |
| `D-01` | Consent management: make or buy — [written up](../system/decisions/d-01-consent-management.md), recommendation **Make** | Architecture board + product + compliance | WS-01 |
| `D-02` | Token compatibility — [written up](../system/decisions/d-02-token-compatibility.md), recommendation token exchange at Ping | Architecture board + IAM | WS-01 |
| `D-03` | SCA approaches offered to TPPs — proposed: redirect only | Product + architecture + compliance | WS-01 |
| `D-04` | Status propagation between contexts | Engineering lead | MVP-01 |
| `D-05` | Responsibility split at the TPP edge | Architecture board + Finologee | WS-01 |
| `D-06` | Deployment shape of the gateway | Engineering lead | WS-01 |
| `D-07` | Accept or change the WS-01 and MVP-01 slices | Product owner | both |
| `D-08` | MVP-01 as production go-live or testing facility | Product owner + compliance | MVP-01 |

The AI's recommendations are in [`../system/README.md` §4](../system/README.md#4-decisions-that-need-human-authority).
They are recommendations only.

## Review gates

| Gate | Reviewers | Reviews |
| --- | --- | --- |
| G1 | Product, UX | Problem analysis, journey map, service blueprint, screen flows, wireframes, `UX-01`…`UX-08`, objectives, slices, the MVP hypothesis |
| G2 | Domain experts (payments, compliance) | Event storms, context map, domain models, invariants, hotspots |
| G3 | Product, QA, development (Three Amigos) | Example maps — run each session, vote, regenerate the features |
| G4 | Architects, engineers, security, IAM | C4, UML, OpenAPI, AsyncAPI, and `D-01`…`D-06` |
| G5 | Delivery, operations | The walking-skeleton and MVP packs, evidence, observability |

Reviewers may edit the models on the boards (doc-es, doc-sm, doc-em, ba-cm). The as-code files in
this branch must then be re-exported from those boards, so the edits are captured.
