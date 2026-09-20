# Journey map — access to account through a TPP

> **Status:** proposal. Derived from the specification (`SRC-IG`) and the technical context
> (`SRC-ADR`). **No UX research was supplied (`Q-21`)**, so every pain point below is a
> hypothesis (`H-`), not an observation. Product and UX review this map first (gate G1).

## Actors

`ACT-PSU`, `ACT-AISP`, `ACT-PISP`, `ACT-TPP` — see [problem-analysis.md](problem-analysis.md#actors).

## `JRN-AIS-CONNECT` — a PSU lets an AISP see their account data

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Choose to connect | `JRN-AIS-CONNECT.S1` | Asks the AISP to connect a bank account | Presents what it will access and for how long | — (TPP channel) | — | `SRC-IG` §6 "Consent Models" |
| TPP reaches the bank | `JRN-AIS-CONNECT.S2` | — | Opens mTLS with its QWAC, posts `POST /v1/consents` | `TP-XS2A-API` | `EVT-TPP-IDENTIFIED` | `SRC-IG` §3, §6.3.1 |
| Authorise at the bank | `JRN-AIS-CONNECT.S3` | Logs in at the bank, sees what the TPP asks for, approves, then confirms identity on the SCA screen on the enrolled device | Follows `scaRedirect` | `TP-LOGIN-SCREEN`, `TP-CONSENT-SCREEN`, `TP-SCA-SCREEN` | `EVT-CONSENT-AUTHORISED` | `SRC-IG` §6.1.1; `SRC-ADR` |
| Back at the TPP | `JRN-AIS-CONNECT.S4` | Returns to the AISP | Checks `state`, reads the consent status | `TP-XS2A-API` | — | `SRC-IG` §7.6, §6.3.2 |
| Use the data | `JRN-AIS-CONNECT.S5` | Sees accounts, balances and transactions in the AISP | Reads `/accounts`, balances and transactions within `frequencyPerDay` | `TP-XS2A-API` | `EVT-ACCOUNT-DATA-DELIVERED` | `SRC-IG` §6.5 |

**Hypothesised pain points** (research needed, `Q-21`):

- `H-01`: the PSU abandons the authorisation at the hand-over from the browser to the bank app, which often sits on another device.
- `H-02`: the PSU does not recognise the TPP's legal name shown by the bank, because its brand differs (`SRC-IG` §4.9).

## `JRN-PIS-PAY` — a PSU pays through a PISP

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Checkout | `JRN-PIS-PAY.S1` | Chooses "pay by bank" at a merchant or PISP | Posts `POST /v1/payments/sepa-credit-transfers` | `TP-XS2A-API` | `EVT-TPP-IDENTIFIED` | `SRC-IG` §5.3.1 |
| Authorise at the bank | `JRN-PIS-PAY.S2` | Logs in at the bank, sees the amount and payee **somewhere** — `SRC-ADR` names no surface for it (`Q-46`) — and confirms identity on the SCA screen | Follows `scaRedirect` | `TP-LOGIN-SCREEN`, `TP-SCA-SCREEN`, and the surface `Q-46` settles | `EVT-PAYMENT-AUTHORISED` | `SRC-IG` §5.1; `SRC-ADR` |
| Learn the outcome | `JRN-PIS-PAY.S3` | Sees "payment initiated" or "failed" | Reads `…/status` | `TP-XS2A-API` | `EVT-PAYMENT-FINAL-STATUS-REACHED` | `SRC-IG` §5.4, §4.14.1 |
| Change of mind | `JRN-PIS-PAY.S4` | Asks to cancel a future-dated payment | `DELETE` the payment (optional in the spec) | `TP-XS2A-API` | — | `SRC-IG` §5.7 — *unscheduled*, `Q-15` |

**Hypothesised pain points:**

- `H-04`: the PSU cannot tell whether the money has left the account, because the status the bank reports (`ACTC` versus `ACSC`) depends on its booking type (`Q-28`).
- `H-05`: Verification of Payee interrupts the payment with a name-mismatch confirmation (`SRC-IG` §1.4 v1.3.15, §14.6 `creditorNameConfirmation`; `Q-16`).

## `JRN-ACCESS-CONTROL` — access to the accounts ends

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Review access | `JRN-ACCESS-CONTROL.S1` | Logs in and looks at what one TPP can see | Offers a way to the consent screen (`Q-43`) | `TP-LOGIN-SCREEN`, `TP-CONSENT-SCREEN` | — | `SRC-ADR` consent screen |
| Withdraw | `JRN-ACCESS-CONTROL.S2` | Revokes that TPP's access | — | `TP-CONSENT-SCREEN` | `EVT-CONSENT-ENDED` (`revokedByPsu`) | `SRC-IG` §4.14.2; `SRC-ADR` |
| TPP ends it | `JRN-ACCESS-CONTROL.S3` | — | `DELETE /v1/consents/{consentId}` | `TP-XS2A-API` | `EVT-CONSENT-ENDED` (`terminatedByTpp`) | `SRC-IG` §6.4 |
| Time ends it | `JRN-ACCESS-CONTROL.S4` | — | Its next read is refused | `TP-XS2A-API` | `EVT-CONSENT-ENDED` (`expired`) | `SRC-IG` §4.14.2, §14.11.1 |

**Hypothesised pain point:** `H-03` — the PSU expects a withdrawal to stop the TPP at once, but
the TPP only finds out on its next read (`Q-09`, `Q-24`).

## Touchpoints

| ID | Touchpoint | Owner |
| --- | --- | --- |
| `TP-XS2A-API` | The TPP-facing XS2A endpoint | Finologee, with the ASPSP gateway behind it (`D-05`) |
| `TP-LOGIN-SCREEN` | The bank login screen the PSU lands on from `scaRedirect` | Ping Federate, in house (`SRC-ADR`) |
| `TP-CONSENT-SCREEN` | The page where the PSU grants or revokes a TPP's access | Bank ASPSP (`SRC-ADR`) |
| `TP-SCA-SCREEN` | The SCA screen in the bank app, on the enrolled device: the PSU confirms identity with the final authentication method | Bank mobile app, asked by the CIAM (`SRC-ADR`) |

## Screens and read models

Every stage above breaks down into the screens the PSU sees, the read models behind them and the
components that manage them: see the [service blueprint](service-blueprint.md).

## Accessibility

No accessibility constraints were supplied. All three bank surfaces — login screen, consent
screen and SCA screen — are PSU-facing and must be reviewed against the applicable standard
(`Q-42`). The MVP pack asks for that evidence.
