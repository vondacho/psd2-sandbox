# D-02 — Token compatibility between Finologee and Ping Federate

> **Status:** answer and recommendation produced by AI on 2026-09-19 (iteration 4), answering
> [`docs/context/questions.md`](../../context/questions.md) "Token compatibility".
> **A recommendation, not a decision.** Architecture and IAM decide; sign-off at gate G4.
> Two facts below are marked **to verify** because they are product capabilities nobody has
> confirmed in the supplied material.

## The question, as the context states it

> *Finologee authenticates TPP from its eIDAS certificate, and supports OIDC to authorize TPP to
> access PSU's accounts and initiate payments. Inside the Bank, Ping Federate is the token
> issuance solution to access the Bank's APIs. How to ensure the compatibility between the tokens
> issued by Finologee and the tokens accepted by Ping Federate?*

## Short answer

**Do not make the two token systems compatible. Keep them as two trust domains and bridge them
once, at a single controlled point.**

- **Outside** (TPP ↔ Finologee): a Finologee-issued OAuth 2.0 / OIDC access token, bound to the TPP's eIDAS certificate, whose scope names the XS2A resource — `AIS:{consentId}`, `PIS:{paymentId}` (`SRC-IG` §13.1).
- **Inside** (Finologee ↔ ASPSP gateway): a **Ping-issued** access token, obtained by **OAuth 2.0 Token Exchange (RFC 8693)**, sent over a mutually authenticated TLS connection. The gateway accepts bank tokens only.
- **The PSU leg** is already bank-side: Ping owns the login screen (`SRC-ADR`), so Ping — not Finologee — is the authority on *who the PSU is* and *that SCA happened*.

There is then nothing to make "compatible": no bank API ever validates a Finologee token, and no
TPP ever sees a Ping token.

## Why not the obvious alternatives

| Option | What it means | Assessment |
| --- | --- | --- |
| **A — Pass-through** | The ASPSP gateway accepts the Finologee token directly (introspection or JWKS) | **Not recommended.** It makes a vendor an issuer for bank APIs: the vendor's claim set becomes the bank's authorisation model, revocation and key rotation follow the vendor's schedule, and the audit trail for "who authorised this read" sits outside the bank. It also spreads to every future bank API the gateway fronts |
| **B — Token exchange (recommended)** | Finologee exchanges its token for a Ping token scoped to the ASPSP gateway | Single trust anchor inside the bank; the exchange is the one place where vendor identity becomes bank identity; claims are normalised by Ping; revocation is a bank operation |
| **C — No token inside** | mTLS plus a signed request-context header (JWS) from Finologee | Workable fallback if Ping cannot do RFC 8693. Weaker: the bank then validates a vendor signature per request and must define the context format itself (`Q-04`) |
| **D — Finologee as a Ping client only** | Finologee uses `client_credentials` at Ping, with no per-request subject | Loses the link between the call and the PSU or consent that authorised it, which the audit trail needs. Only acceptable combined with C's signed context |

## Recommended mechanism, step by step

1. **TPP → Finologee.** The TPP authenticates with its eIDAS QWAC (mTLS) and obtains a Finologee access token whose scope references the consent or payment (`SRC-IG` §13.1). Sender-constrain that token to the TPP certificate (RFC 8705) so a stolen token is useless without the key.
2. **PSU authentication and SCA (bank side).** For the authorisation of a consent or payment, the PSU is sent to the bank: Ping's **login screen**, then the **SCA screen** in the bank app, triggered on demand by the CIAM on an enrolled device (`SRC-ADR`). Ping issues the evidence that SCA happened — an `id_token` / assertion carrying the authentication context and the authorisation sub-resource id.
3. **Finologee → Ping (the bridge).** For each TPP request to be forwarded, Finologee calls Ping's token endpoint:
   - `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`
   - `subject_token` = the Finologee access token (or a short-lived assertion Finologee signs about it), `subject_token_type` accordingly
   - `audience` = the ASPSP gateway
   - Finologee authenticates to Ping with mTLS client authentication.
4. **Ping → Finologee.** Ping returns a short-lived bank access token (JWT), with at least:

   | Claim | Meaning |
   | --- | --- |
   | `aud` | the ASPSP gateway |
   | `azp` / `act` | Finologee, as the acting party |
   | `tpp_id` | `organizationIdentifier` from the eIDAS certificate (`PSDXX-NCA-nnnn`) |
   | `tpp_roles` | PSP_AI, PSP_PI, … from the certificate |
   | `consent_id` / `payment_id` | the XS2A resource the TPP's scope referenced |
   | `psu_sub` | the PSU subject, for authorisation-bound calls |
   | `acr` / `auth_time` | present when the call follows an SCA |
   | `x_request_id` | echoed for traceability |

5. **Finologee → ASPSP gateway.** The request goes over mTLS with the Ping token in `Authorization: Bearer`. The gateway validates it against Ping's JWKS: issuer, audience, expiry, and that `tpp_id` matches the resource owner (`INV-CNS-04`, `INV-PAY-05`).
6. **Gateway decisions.** The gateway authorises from its own consent state (`RM-ACCESS-DECISION`, `D-01` Make), never from a claim the vendor asserted alone. The token says *who is calling for whom*; the consent says *what they may read today*.

## What must be verified

| # | To verify | With whom |
| --- | --- | --- |
| V1 | PingFederate supports the RFC 8693 token-exchange grant in the installed version, with a custom claim mapping from the Finologee subject token | IAM |
| V2 | Finologee can call an external token endpoint per forwarded request, or per session with caching, and can be configured as an OIDC client of Ping for the PSU leg | Finologee (`Q-04`) |
| V3 | Token lifetimes and caching: a per-request exchange adds latency to the hot read path; a cached bank token per (TPP, consent) is the middle ground | IAM, architecture |
| V4 | Whether the bank wants sender-constrained bank tokens too (mTLS-bound, RFC 8705) between Finologee and the gateway | Security |

If V1 fails, fall back to **option C**: mTLS plus a JWS request context signed by Finologee, with
the same claim set, validated by the gateway. Everything else in the design stays.

## Consequences

- The ASPSP gateway has exactly one token issuer to trust: Ping. This is also the answer for bank channels (the mobile app's session token) — one issuer, different audiences.
- Berlin Group's OAuth 2.0 usage (`SRC-IG` §13) stays entirely on the TPP side of Finologee. Which SCA approach the TPP sees is `D-03` (redirect); the bank's token bridge is invisible to the TPP.
- A revoked consent must invalidate bank tokens that reference it, or the tokens must be short-lived enough that the gateway's consent check is the real gate. The recommendation relies on the consent check, so token lifetime is a performance choice, not a security one.
