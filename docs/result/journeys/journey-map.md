# Journey map — access to account through a TPP

> **Status:** proposal. Derived from the specification (`SRC-IG`) and the technical context
> (`SRC-ADR`). **No UX research was supplied (`Q-02`)**, so every pain point below is a
> hypothesis (`H-`), not an observation. Product and UX review this map first (gate G1).

## Actors

`ACT-PSU`, `ACT-AISP`, `ACT-PISP`, `ACT-TPP` — see
[problem-analysis.md](problem-analysis.md#actors).

## The shape the revised context gives every journey

Three facts from `SRC-ADR` decide the shape of all three journeys, and they are worth stating
before the tables:

1. **The consent screen belongs to the TPP.** The PSU reads what is being asked for, and grants
   or revokes it, on a page the bank does not design.
2. **The bank has one browser surface: the CIAM login screen.** Everything the PSU confirms
   happens afterwards on the enrolled device — an OTP, QR or biometric step, then the consent
   confirmation panel.
3. **Finologee masters the consent record.** The bank's own copy exists to decide reads
   (`A-16`), and whether it or the vendor's is authoritative is `D-01`.

Consequence, stated once and not repeated: the AIS journey has a bank-side surface where the PSU
sees what is being granted — the consent confirmation panel, which is exactly what the Detailed
Consent model expects of an ASPSP (`A-15`). The PIS journey has **no such surface named**
(`C-09`, `Q-17`), and this map refuses to invent one.

## `JRN-AIS-CONNECT` — a PSU lets an AISP see their account data

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Choose to connect | `JRN-AIS-CONNECT.S1` | Reads on the TPP's consent screen what will be accessed and for how long, and grants it | Presents its consent screen and collects the detailed consent | — (TPP surface) | — | `SRC-ADR` consent screen; `SRC-IG` §6 "Detailed Consent" |
| TPP reaches the bank | `JRN-AIS-CONNECT.S2` | — | Opens mTLS with its QWAC, posts `POST /v1/consents` | `TP-XS2A-API` | `EVT-TPP-IDENTIFIED` | `SRC-IG` §3, §6.3.1 |
| Authenticate at the bank | `JRN-AIS-CONNECT.S3` | Follows the redirect and logs in on the bank's CIAM login screen in the browser | Follows `scaRedirect` | `TP-CIAM-LOGIN` | — | `SRC-IG` §6.1.1.1; `SRC-ADR` SCA journey |
| Confirm on the enrolled device | `JRN-AIS-CONNECT.S4` | Confirms identity with an OTP, a QR code or a biometric method, then confirms the items of the consent on the panel | Waits | `TP-APP-SCA`, `TP-APP-CONSENT-PANEL` | `EVT-CONSENT-AUTHORISED` | `SRC-ADR` SCA journey; `SRC-IG` §6 (ASPSP displays consent details during SCA) |
| Use the data | `JRN-AIS-CONNECT.S5` | Sees accounts, balances and transactions in the AISP | Reads the consent status, then `/accounts`, balances and transactions within `frequencyPerDay` | `TP-XS2A-API` | `EVT-ACCOUNT-DATA-DELIVERED` | `SRC-IG` §6.3.2, §6.5 |

**Hypothesised pain points** (research needed, `Q-02`):

- `H-01`: the PSU abandons at the hand-over from the browser to the enrolled device, which is often a second device.
- `H-02`: the PSU does not recognise the TPP's legal name on the confirmation panel, because its brand differs (`SRC-IG` §4.9, `Q-33`).

## `JRN-PIS-PAY` — a PSU pays through a PISP

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Checkout | `JRN-PIS-PAY.S1` | Chooses "pay by bank" at a merchant or PISP | Posts `POST /v1/payments/sepa-credit-transfers` | `TP-XS2A-API` | `EVT-TPP-IDENTIFIED` | `SRC-IG` §5.3.1 |
| Authenticate at the bank | `JRN-PIS-PAY.S2` | Logs in on the CIAM login screen | Follows `scaRedirect` | `TP-CIAM-LOGIN` | — | `SRC-IG` §5.1.1; `SRC-ADR` |
| Confirm the payment | `JRN-PIS-PAY.S3` | Confirms identity on the enrolled device — and sees the amount and payee **on a surface `SRC-ADR` does not name** (`Q-17`) | Waits | `TP-APP-SCA`, and the surface `Q-17` settles | `EVT-PAYMENT-AUTHORISED` | `SRC-IG` §5.1; `SRC-ADR` |
| Learn the outcome | `JRN-PIS-PAY.S4` | Sees "payment initiated" or "failed" at the TPP | Reads `…/status` | `TP-XS2A-API` | `EVT-PAYMENT-FINAL-STATUS-REACHED` | `SRC-IG` §5.4, §4.14.1 |

**Hypothesised pain points:**

- `H-04`: the PSU cannot tell whether the money has left the account, because the status the bank reports (`ACTC` versus `ACSC`) depends on DCP's booking behaviour (`Q-31`).
- A payment confirmed on a device panel that shows no amount is a dynamic-linking failure before it is a UX one — see `UX-09` in the blueprint.

## `JRN-ACCESS-CONTROL` — access to the accounts ends

| Stage | ID | PSU does | TPP does | Bank touchpoint | Pivotal event reached | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Review access | `JRN-ACCESS-CONTROL.S1` | Looks at what one TPP can see — **on the TPP's own consent screen** | Shows what it holds | — (TPP surface) | — | `SRC-ADR` consent screen |
| Withdraw at the TPP | `JRN-ACCESS-CONTROL.S2` | Revokes that TPP's access on the TPP screen | `DELETE /v1/consents/{consentId}` | `TP-XS2A-API` | `EVT-CONSENT-ENDED` (`terminatedByTpp`) | `SRC-IG` §6.4, §14.15 |
| Withdraw at the bank | `JRN-ACCESS-CONTROL.S3` | **No bank surface is named** (`C-07`, `D-09`). `revokedByPsu` is defined as revocation towards the ASPSP | — | — | `EVT-CONSENT-ENDED` (`revokedByPsu`) — *unreachable as drawn* | `SRC-IG` §14.15 |
| Time ends it | `JRN-ACCESS-CONTROL.S4` | — | Its next read is refused | `TP-XS2A-API` | `EVT-CONSENT-ENDED` (`expired`) | `SRC-IG` §4.14.2, §14.11.1 |

**Hypothesised pain points:** `H-03` — the PSU expects a withdrawal to stop the TPP at once, but
the TPP only finds out on its next read (`Q-22`, `Q-42`). `H-05` — a PSU who revokes on the TPP's
screen believes they have revoked at the bank.

`JRN-ACCESS-CONTROL.S3` is deliberately left as a stage with no touchpoint. It is the journey
stage the regulation implies and the supplied context does not staff; `D-09` decides who does.

## Touchpoints

| ID | Touchpoint | Owner |
| --- | --- | --- |
| `TP-XS2A-API` | The TPP-facing XS2A endpoint | Finologee, with the ASPSP gateway behind it (`D-05`) |
| `TP-TPP-CONSENT` | The consent screen where the PSU grants or revokes a TPP's access | **The TPP** (`SRC-ADR`) — the bank does not design it |
| `TP-CIAM-LOGIN` | The bank login screen the PSU lands on from `scaRedirect` | Transmit, the CIAM, in house (`SRC-ADR`, `A-08`) |
| `TP-APP-SCA` | The OTP, QR-code or biometric screen on the enrolled device | Bank mobile app, asked by the CIAM (`SRC-ADR`) |
| `TP-APP-CONSENT-PANEL` | The consent confirmation panel on the enrolled device, where the PSU confirms the items of the consent | Bank mobile app, asked by the CIAM (`SRC-ADR`) |

## Screens and read models

Every stage above breaks down into the screens the PSU sees, the read models behind them and the
components that manage them: see the [service blueprint](service-blueprint.md).

## Accessibility

No accessibility constraints were supplied. The bank's two surface families — the CIAM login
screen in the browser and the app panels on the enrolled device — are both PSU-facing and must be
reviewed against the applicable standard (`Q-38`). The MVP pack asks for that evidence.
