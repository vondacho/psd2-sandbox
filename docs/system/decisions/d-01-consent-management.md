# D-01 — Consent management: make or buy

> **Status:** evaluation and recommendation produced by AI, answering
> [`docs/context/evaluations.md`](../../context/evaluations.md) "Consent management".
> Revised after the ADR rephrasing of 2026-09-20, which narrows the question — see below.
> **It is a recommendation, not a decision** (`docs/ai/20-review-and-delivery-policy.md`: AI must
> not decide consequential architecture trade-offs). The architecture board decides, with product
> and compliance. Sign-off belongs at review gate G4.

## The question, as the context states it

> *Consent management … includes the consent screen and the consent state management.*
> **Make:** in-house, by the ASPSP gateway, IDP and CIAM solutions.
> **Buy:** Finologee's PSD2 gateway, which provides a built-in consent management feature.

Two things are bundled in the wording: the **consent screen** (the browser page where the PSU
grants or revokes a TPP's access) and the **consent state** (the AIS consent resource, its
status, validity, per-account access rights and daily frequency).

**The ADR has since settled the screen.** `SRC-ADR` now states that the **Bank ASPSP manages**
the consent screen. So this decision is about **where the consent state is mastered**, and Buy
means *Finologee holds the consent state behind a bank-managed screen* — not *Finologee shows the
PSU a screen* (`A-19`). The evaluation below is read in that light: the criteria about the screen
itself (C8) no longer separate the options.

## What the decision must satisfy

From the specification (`SRC-IG`) and the context (`SRC-ADR`):

| # | Requirement | Source |
| --- | --- | --- |
| R1 | Hold the consent resource exactly as the standard defines it: `access`, `recurringIndicator`, `validUntil`, `frequencyPerDay`, `consentStatus` and its transitions | `SRC-IG` §6.3.1, §14.15, `INV-CNS-01`…`INV-CNS-06` |
| R2 | Decide **on every account read** whether the read is allowed, and count unattended reads per account per day | `SRC-IG` §6, §14.11.3, `RM-ACCESS-DECISION`, `INV-ACC-03` |
| R3 | Show the PSU what a TPP asks for, and take approve or decline in the browser, **on a screen the Bank ASPSP manages** | `SRC-ADR` Consent screen |
| R4 | Bind that approval to the bank's own SCA: IDP login, then the SCA screen in the bank app on an enrolled device | `SRC-ADR` IDP, CIAM, Mobile App |
| R5 | Let the PSU revoke, with effect on the TPP's **next** read | `SRC-ADR`; `SRC-IG` §14.15 `revokedByPsu` |
| R6 | Produce audit evidence the bank can show a supervisor | `OBJ-04`, PSD2 accountability |
| R7 | Apply the recurring-consent side effect across consents of one TPP and PSU | `SRC-IG` §6.3.1.1 |

## Criteria, weights and scoring

Weights reflect what is hard to reverse later, not what is loudest today. Scores: **+2** clearly
better, **+1** better, **0** equivalent, **−1** worse, **−2** clearly worse — Make relative to Buy.

| # | Criterion | Weight | Make | Buy | Why |
| --- | --- | --- | --- | --- | --- |
| C1 | **Access decision on the hot path** (R2): every `/accounts`, balances and transactions read needs a consent verdict | 5 | **+2** | −1 | Make keeps the verdict in the same process as the data. Buy puts it at the vendor: either the gateway calls Finologee per read (latency and an availability dependency on the PSD2 path), or the gateway trusts a vendor assertion and has no independent check |
| C2 | **Revocation takes effect immediately at the bank** (R5) | 4 | **+2** | −1 | Same reason. With Buy, a revocation recorded at the vendor must reach the bank before the next read, so the bank needs a webhook or per-read call — and must still refuse if that channel is down |
| C3 | **Binding approval to the bank's SCA** (R4) | 4 | **+1** | 0 | Make: the consent screen and the SCA trigger are both bank-side, so the approved subject digest never leaves the bank. Buy: workable if Finologee acts as an OIDC client of Ping (a standard integration the vendor already supports per `SRC-ADR`), but the binding then crosses a vendor boundary |
| C4 | **Fit to the XS2A consent semantics out of the box** (R1, R7) | 4 | −2 | **+2** | This is Buy's strongest point. Finologee's module is built for this exact standard; Make means implementing `INV-CNS-01`…`06`, the frequency counter and the recurring side effect ourselves, including the parts the spec leaves ambiguous |
| C5 | **Time to first TPP integration** | 3 | −2 | **+2** | Buy is faster: no consent store, no screen, no lifecycle jobs to build |
| C6 | **Audit and supervisory evidence** (R6) | 3 | **+1** | 0 | Make keeps consent history in bank systems. Buy is acceptable if the vendor exports an immutable audit trail — a contract question |
| C7 | **Personal data footprint** | 3 | **+1** | −1 | Buy puts PSU identifiers, account references and consent history at a processor: DPIA, retention and cross-border checks |
| ~~C8~~ | **PSU trust in the screen** (`UX-03`, phishing resistance) | — | — | — | **Settled by `SRC-ADR`, not by this decision**: the Bank ASPSP manages the screen either way, so it is served from a bank domain with bank branding (`Q-47` confirms the domain). Excluded from the totals |
| C9 | **Vendor lock-in / exit** | 2 | **+2** | −2 | Consent state is the asset with the longest life here. Held by the vendor, it must be migrated with its history if the bank ever changes gateway |
| C10 | **Cost of ownership** | 2 | −1 | **+1** | Buy: licence and change requests. Make: build and run, but on a codebase the bank already staffs for the ASPSP gateway |
| C11 | **Bank-channel revocation later** (online banking, app) | 2 | **+2** | −1 | A bank channel calling a bank service is trivial; calling the vendor is another integration |

**Weighted totals** (weight × score):

- **Make:** (5×2) + (4×2) + (4×1) + (4×−2) + (3×−2) + (3×1) + (3×1) + (2×2) + (2×−1) + (2×2) = **+24**
- **Buy:** (5×−1) + (4×−1) + (4×0) + (4×2) + (3×2) + (3×0) + (3×−1) + (2×−2) + (2×1) + (2×−1) = **+4**

(C8 excluded: the ADR settles it. Before the rephrasing the totals were Make +27 / Buy +1; the
gap narrows, the conclusion does not change.)

The arithmetic is a way to show the weighting, not a proof. The result turns on C1 and C2: the
bank must be able to answer "may this TPP read this account right now?" without asking a vendor.

## Recommendation

**Make** — the ASPSP gateway masters the consent state and is the backend of the bank-managed
consent screen, with PSU authentication delegated to Ping (login screen) and SCA to the CIAM and
the bank app.

Three conditions:

1. **Verify the Buy option before committing** (two days, as part of WS-01 preparation). Buy becomes preferable if Finologee can show all of: a webhook or equivalent that reaches the bank *before* the next read after a revocation; an API rich enough for the bank's own consent screen to drive it; an exportable audit trail; and OIDC delegation of PSU authentication to Ping. Record the evidence either way.
2. **Do not reimplement what the standard already fixes.** The consent invariants come from the spec; the example maps `EXMAP-CONSENT-DEDICATED`, `EXMAP-ENFORCE-FREQUENCY` and `EXMAP-PSU-REVOKE` are the acceptance criteria. C4's disadvantage is mitigated by writing those tests first.
3. **Keep the screen separable from the state.** The bank manages the screen (`SRC-ADR`); the state behind it must be replaceable without rebuilding it. `API-PSU-CHANNEL` is that seam.

### If the board chooses Buy instead

The design changes as follows, and the artefacts say so:

- `CMP-CONSENT` becomes a **mirror** of Finologee's consent state, not the system of record, and `RM-ACCESS-DECISION` must still be answerable locally — otherwise every account read depends on the vendor being up.
- `CMP-CONSENT-SCREEN` stays a bank surface (`SRC-ADR`); `CMP-PSU-CHANNEL-API` stays its backend but becomes a **pass-through to Finologee** for consent details, approval and revocation. The screen's contract does not change.
- Finologee integrates with Ping over OIDC for PSU authentication, and with the CIAM for the SCA screen.
- New questions: revocation propagation latency, audit export, and the data processing agreement.

## Consequences of the recommendation

- The gateway needs a consent store, a daily-frequency counter and two scheduled jobs (expiry, SCA window).
- The consent screen — a bank-hosted web application either way (`SRC-ADR`) — is backed by `CMP-PSU-CHANNEL-API` alone, with no vendor hop.
- Finologee stays what `SRC-ADR` says it is: the TPP-facing intermediary, doing eIDAS identification, OIDC/OAuth for TPPs, and forwarding identified requests. It does not hold consent state.
- WS-01 must prove the consent verdict, the screen and the SCA binding end to end.

## What would change this recommendation

- Finologee demonstrating C1 and C2 convincingly (a local enforcement hook or a bank-side cache it keeps fresh).
- A regulatory or contractual requirement that the gateway provider hold the consent record.
- A time-to-market constraint that outranks C1, C2 and C9 — a product decision, not an architecture one.
