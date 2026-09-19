# Journey map — access to account through a TPP

> **Status:** proposal. This map is derived from the specification (`SRC-IG`) and the
> technical context (`SRC-ADR`). **No UX research was supplied (`Q-21`).** Every pain point
> and emotion below is a hypothesis (`H-`), not an observation. Product and UX review this
> map first (review gate G1).

## Actors

`ACT-PSU`, `ACT-AISP`, `ACT-PISP`, `ACT-TPP` — see [problem-analysis.md](problem-analysis.md#actors).

## `JRN-AIS-CONNECT` — a PSU lets an AISP see their account data

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Choose to connect | `JRN-AIS-CONNECT.S1` | Asks the AISP app to connect a bank account | Presents what it will access and for how long | — (TPP channel) | — | `SRC-IG` §6 "Consent Models" |
| TPP reaches the bank | `JRN-AIS-CONNECT.S2` | — | Opens mTLS with its QWAC, posts `POST /v1/consents` | `TP-XS2A-API` | `EVT-TPP-IDENTIFIED` | `SRC-IG` §3, §6.3.1 |
| Authorise at the bank | `JRN-AIS-CONNECT.S3` | Sees the consent details on the consent screen, approves, confirms with the last factor in the bank app | Follows `scaRedirect` / `scaOAuth` to the consent screen | `TP-CONSENT-SCREEN`, `TP-MOBILE-APP` (last factor only) | `EVT-CONSENT-AUTHORISED` | `SRC-IG` §6.1.1; `SRC-ADR` Consent screen, Mobile App, SCA |
| Back at the TPP | `JRN-AIS-CONNECT.S4` | Returns to the AISP | Checks `state`, confirms if asked, reads consent status | `TP-XS2A-API` | — | `SRC-IG` §7.6, §6.3.2 |
| Use the data | `JRN-AIS-CONNECT.S5` | Sees accounts, balances, transactions in the AISP | Reads `/accounts`, balances, transactions within `frequencyPerDay` | `TP-XS2A-API` | `EVT-ACCOUNT-DATA-DELIVERED` | `SRC-IG` §6.5 |

**Hypothesised pain points** (research needed, `Q-21`):

- `H-01`: abandonment during SCA, especially at the switch from the consent screen (browser) to the last factor in the bank app, which is often on another device.
- `H-02`: the PSU does not recognise the TPP legal name shown at the bank, because the brand differs (`SRC-IG` §4.9).

## `JRN-ACCESS-CONTROL` — a PSU or TPP ends account access

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Review access | `JRN-ACCESS-CONTROL.S1` | Looks at what one TPP can see | Offers the way to the consent screen (how: `Q-43`) | `TP-CONSENT-SCREEN` | — | `SRC-ADR` Consent screen ("grant or revoke") |
| Withdraw | `JRN-ACCESS-CONTROL.S2` | Revokes the TPP's access on the consent screen | — | `TP-CONSENT-SCREEN` | `EVT-CONSENT-ENDED` (`revokedByPsu`) | `SRC-IG` §4.14.2; `SRC-ADR` |
| TPP ends it | `JRN-ACCESS-CONTROL.S3` | — | `DELETE /v1/consents/{consentId}` | `TP-XS2A-API` | `EVT-CONSENT-ENDED` (`terminatedByTpp`) | `SRC-IG` §6.4 |
| Time ends it | `JRN-ACCESS-CONTROL.S4` | — | Next read is refused | `TP-XS2A-API` | `EVT-CONSENT-ENDED` (`expired`) | `SRC-IG` §4.14.2, §14.11.1 |

**Hypothesised pain point:** `H-03` — a PSU who revokes access in the bank app expects the
AISP to stop immediately, but the AISP only learns about it on its next read (`Q-09`, `Q-24`).

## `JRN-PIS-PAY` — a PSU pays through a PISP

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Checkout | `JRN-PIS-PAY.S1` | Chooses "pay by bank" at a merchant / PISP | Posts `POST /v1/payments/sepa-credit-transfers` | `TP-XS2A-API` | `EVT-TPP-IDENTIFIED` | `SRC-IG` §5.3.1 |
| Authorise at the bank | `JRN-PIS-PAY.S2` | Sees amount and payee, approves, confirms with the last factor in the bank app | Follows the SCA links | `TP-CONSENT-SCREEN` (for payments too? `Q-46`), `TP-MOBILE-APP` (last factor only) | `EVT-PAYMENT-AUTHORISED` | `SRC-IG` §5.1; `SRC-ADR` |
| Learn the outcome | `JRN-PIS-PAY.S3` | Sees "payment initiated" or "failed" | Reads `…/status` | `TP-XS2A-API` | `EVT-PAYMENT-FINAL-STATUS-REACHED` | `SRC-IG` §5.4, §4.14.1 |
| Change of mind | `JRN-PIS-PAY.S4` | Asks to cancel a future-dated payment | `DELETE` the payment (optional in spec) | `TP-XS2A-API` | — | `SRC-IG` §5.7 — *unscheduled*, `Q-15` |

**Hypothesised pain points:**

- `H-04`: the PSU does not know whether the money has left their account, because the status the bank reports (`ACTC` vs `ACSC`) depends on its booking type (`Q-28`).
- `H-05`: Verification of Payee may interrupt the payment with a name-mismatch confirmation (`SRC-IG` §1.4 v1.3.15, §14.6 `creditorNameConfirmation`; `Q-16`).

## Screens and read models

Iteration 2: every stage above is broken down into the PSU screens, the read models behind
them and the components that manage them in the [service blueprint](service-blueprint.md).

## Touchpoints

| ID | Touchpoint | Owner (proposed) |
| --- | --- | --- |
| `TP-XS2A-API` | The TPP-facing XS2A HTTPS endpoint | Unassigned between `SYS-FINOLOGEE` and `SYS-ASPSP-GW` (`D-05`) |
| `TP-CONSENT-SCREEN` | The consent screen the PSU lands on from `scaRedirect`: grant or revoke access (`SRC-ADR`) | ASPSP gateway **or** Finologee (`D-01`); "presented in the TPP web application" (`C-11`) |
| `TP-MOBILE-APP` | The bank mobile app — last SCA authentication factor only (`SRC-ADR`) | Bank mobile team |

## Accessibility

No accessibility constraints were supplied. `TP-CONSENT-SCREEN` and the app's last-factor
prompt are PSU-facing and must be reviewed against the applicable standard (`Q-42`). The MVP
pack asks for this evidence.
