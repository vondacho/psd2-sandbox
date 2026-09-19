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
> The counts below are after iteration 2.

## Result

| | Count |
| --- | --- |
| Errors | **0** |
| Warnings from the automated run | 9 (grouped below with manual findings as `W-*`) |
| Manual warnings (review, not tooling) | 17 (`W-API-03` resolved in iteration 2) |
| Open questions | 42 (`Q-01`…`Q-42`) |
| Assumptions | 15 (`A-01`…`A-15`) |
| Decisions needing human authority | 9 (`D-01`…`D-09`) |

**Inventory checked:**

| Artefact | Count |
| --- | --- |
| Notation files | 17 |
| Pivotal events | 6 |
| Hotspots | 28 |
| Stories (26 scheduled, 21 unscheduled) | 47 |
| Example maps | 8 |
| Rules | 36 |
| Examples / generated scenarios | 51 |
| Red cards | 38 |
| Bounded contexts | 9 |
| Invariants | 20 |
| Components | 19 |
| PSU-facing screens (11 bank, 2 TPP) | 13 |
| Read models | 15 |
| OpenAPI operations (19 XS2A + 6 PSU channel) | 25 |

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
| LikeC4 CLI `validate` + `export json` | 1.59.3 | `docs/system/c4/xs2a.likec4` (6 views resolve; `psuScreens` 26 nodes) | passed |
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
| `W-UX-03` | The owner of `RM-SCA-CONTEXT`, and who renders `SCR-APP-AUTHENTICATE`, are open. The C4 model tags the screen `#undecided` | iam, UX | `Q-07`, `D-09` |
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
| `D-09` | Who renders the PSU's authentication and approval screens | UX + architecture + IAM | WS-01 |

The AI's recommendations for `D-01`…`D-06` and `D-09` are in [`docs/system/README.md` §4](../system/README.md#4-decisions-that-need-human-authority).
They are recommendations only.

## Review gates

| Gate | Reviewers | Reviews |
| --- | --- | --- |
| G1 | Product, UX | Problem analysis, journey map, **service blueprint, screen flows, wireframes, `UX-01`…`UX-07`**, objectives, story map slices, MVP hypothesis |
| G2 | Domain experts (payments, compliance) | Event storms, context map, domain models, invariants, hotspots |
| G3 | Product, QA, development (Three Amigos) | Example maps — run each session and vote; regenerate the features |
| G4 | Architects, engineers, security, IAM | C4, UML, OpenAPI (incl. `API-PSU-CHANNEL`), AsyncAPI, `D-01`…`D-06`, `D-09` |
| G5 | Delivery, operations | Walking-skeleton and MVP packs, evidence, observability |

Reviewers may edit the models on the boards (doc-es, doc-sm, doc-em, ba-cm). The as-code files
in this branch must be re-exported from those boards so the edits are captured.
