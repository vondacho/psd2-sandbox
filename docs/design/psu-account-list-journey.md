# PSU account-list journey — system design

**Journey.** A Payment Service User (PSU) opens third-party application **A** (a TPP acting as AISP), selects **Bank B** from a list of registered banks, gives consent, authenticates at Bank B with strong customer authentication (password + a QR challenge approved on a registered mobile device), and then views the list of accounts held at Bank B and the details of the accounts they pick.

**Basis.** NextGenPSD2 XS2A Framework Implementation Guidelines v1.3.16 (`docs/xs2a/NextGenPSD2 XS2A Framework.pdf`). Section numbers below (e.g. §6.3.1) refer to that document. OAuth 2.0 / OpenID Connect references are given by RFC number.

**Contents**

1. [Roles](#1-roles)
2. [Key design decisions](#2-key-design-decisions)
3. [System context](#3-system-context)
4. [Containers](#4-containers)
5. [User journey, step by step](#5-user-journey-step-by-step)
6. [Sequence diagrams](#6-sequence-diagrams)
7. [Message contracts](#7-message-contracts)
8. [Data model](#8-data-model)
9. [State machines](#9-state-machines)
10. [Security controls](#10-security-controls)
11. [Error handling](#11-error-handling)
12. [Reuse for PIS](#12-reuse-for-pis)
13. [Sandbox realisation](#13-sandbox-realisation)
14. [Assumptions and open points](#14-assumptions-and-open-points)
15. [Business analysis of the domain](#15-business-analysis-of-the-domain)
16. [PlantUML attachments](#16-plantuml-attachments)

**Models as code.** The journey, the backlog and the domain are kept as text next to this document, in grammars that diff and review like code:

| Model | File | Grammar |
|---|---|---|
| Event storm of the PSU journey (software-design level; lanes per party, one column per moment) | [`eventstorming/psu-account-list-journey.eventstorm`](eventstorming/psu-account-list-journey.eventstorm) | `.eventstorm`, doc-es.obya.ch/dsl |
| Story map whose backbone is that event storm: one activity per phase between pivotal events, one step per timeline column, stories sliced into three deliveries | [`storymap/psu-account-list-journey.storymap`](storymap/psu-account-list-journey.storymap) | `.storymap`, doc-sm.obya.ch/dsl |
| Context map: domains, subdomains, bounded contexts and their relationships | [`domain/psd2-access-to-account.ddd`](domain/psd2-access-to-account.ddd) | `.ddd`, ba-cm.obya.ch/dsl |
| Domain models, one per bounded context: aggregates, roots, entities, values, enums, invariants | [`domain/consent-management.ddm`](domain/consent-management.ddm), [`domain/account-information.ddm`](domain/account-information.ddm), [`domain/customer-identity-and-sca.ddm`](domain/customer-identity-and-sca.ddm), [`domain/token-issuance.ddm`](domain/token-issuance.ddm), [`domain/bank-connection.ddm`](domain/bank-connection.ddm) | `.ddm`, ba-cm.obya.ch/dsl#ddm |
| C4 model in LikeC4: notation, model (people, systems, containers, components, relationships) and views (landscape, one per system, CIAM components, and the five journey sequences as dynamic views) | [`likec4/specs.c4`](likec4/specs.c4), [`likec4/model.c4`](likec4/model.c4), [`likec4/views.c4`](likec4/views.c4) | LikeC4 DSL, likec4.dev/dsl |

**How the story map follows the event storm.** Each activity of the story map is a phase of the event storm between two pivotal events, and each step is one timeline column:

| Event storm columns | Pivotal event closing the phase | Story map activity |
|---|---|---|
| 1 | Device enrolled at Bank B | Enrol a device at Bank B |
| 2 to 4 | Bank B selected, Consent created with status received | Connect Bank B from application A |
| 5 to 9 | Challenge response verified against the registered device key | Authenticate and approve at Bank B |
| 10 to 11 | Access token issued, Consent valid, Bank B connected | Complete the connection |
| 12 to 13 | Account list read, Account details read | View my accounts |
| 14 | Consent expired or revoked | Come back later |

The PlantUML sources of every diagram in this document are listed in [section 16](#16-plantuml-attachments). The LikeC4 model is browsed with `npx likec4 start docs/design/likec4` and checked with `npx likec4 validate docs/design/likec4`; its dynamic views can be switched to the sequence variant in the viewer.

---

## 1. Roles

| Party | PSD2 role | OAuth2 / OIDC role | Responsibility in this journey |
|---|---|---|---|
| **PSU** | Payment service user | Resource owner | Selects the bank, approves the consent, performs SCA. |
| **TPP application A** | AISP (also licensed PISP) | Confidential OAuth2 client, authenticated by mTLS with its eIDAS QWAC | Creates the consent at Bank B, drives the authorisation-code flow with F, calls the XS2A API with the access token. |
| **OpenID Connect provider F** | Part of the ASPSP's access infrastructure | Authorization Server (RFC 6749, RFC 8414 metadata) and OpenID Provider towards A | Validates the TPP client, delegates PSU authentication and consent approval to Bank B's CIAM, issues certificate-bound access and refresh tokens scoped to one consent. |
| **Bank B XS2A API** | ASPSP interface | Resource Server | Exposes `/v1/consents` and `/v1/accounts` (and `/v1/payments` for PIS). Validates QWAC, token and consent on every call. |
| **Bank B CIAM** | ASPSP | Identity Provider upstream of F | Owns customer identities, credentials, the device registry, the SCA engine (QR / push challenges) and the consent-approval user interface. |
| **Bank B mobile app on a registered device** | Possession element of SCA | Authenticator | Scans the QR code, shows what is being approved, signs the challenge with a device-bound key. |
| **Bank B consent management** | ASPSP | — | Stores consents and authorisation sub-resources, enforces access rights, validity and access frequency. |
| **Bank B core banking** | ASPSP | — | Source of accounts, balances, transactions. |

Bank B is a **CIAM** (customer identity and access management) rather than a plain IdP because a PSU identity carries a set of enrolled devices, and the possession factor of SCA is a cryptographic key held by one of those devices.

---

## 2. Key design decisions

| # | Decision | Rationale and spec reference |
|---|---|---|
| **D1** | **SCA approach: integrated OAuth2 SCA approach.** The consent is first created on the XS2A API, then authorised through an OAuth2 authorization-code flow at F with `scope=AIS:<consentId>`. | This is exactly the second OAuth2 integration described in §4.3 and the AIS flow in §6.1.1.2, with the OAuth2 profile of §13. It satisfies the requirement that the access token is issued by F, keeps PSU credentials away from the TPP, and lets Bank B show the consent details itself (§6, "consent models"). The XS2A response announces it with `ASPSP-SCA-Approach: REDIRECT` and a `scaOAuth` link (§6.3.1.1). |
| **D2** | **Consent model: bank-offered consent** (`access.accounts: []`, `access.balances: []`, recurring). The PSU chooses at Bank B which accounts the TPP may see. | §6.3.1.2 "Consent Request without Indication of Accounts". One SCA covers both the account list and the later account-detail calls. An alternative with two consents is described in §14 of this document. |
| **D3** | **F brokers authentication to Bank B's CIAM** (OIDC identity brokering). The login, account selection, consent screen and QR challenge all run on Bank B's pages. F only sees the result (ID token with `acr`, `amr`, `consent_id`). | Bank B must display the consent to the PSU during SCA (§6, consent models) and only Bank B owns the device registry. F stays a generic authorization server. |
| **D4** | **Tokens are JWTs, certificate-bound, short-lived; refresh tokens are bound to the consent.** Access token ≈ 10 min, refresh token until `validUntil` of the consent. | §13.3 mandates "OAuth 2.0 Mutual TLS Client Authentication and Certificate Bound Access Tokens" (RFC 8705). §13.5 allows refresh tokens for AIS when `offline_access` is requested or `recurringIndicator` is true. |
| **D5** | **A token is necessary but not sufficient.** The XS2A API checks the consent (status, access rights, TPP ownership, frequency) on every call, and the `Consent-ID` header must equal the `consentId` in the token scope. | §6.5.1: "the addressed list of accounts depends on the PSU ID and the stored consent addressed by consent Id, respectively the OAuth2 access token". Consent revocation by the PSU takes effect immediately even while a token is still valid. |
| **D6** | **SCA = knowledge + possession with dynamic linking.** Factor 1: PSU-ID and password on Bank B's page. Factor 2: a challenge shown as a QR code (and optionally pushed) that the registered Bank B app signs with a hardware-backed key after the PSU approves on the device. The challenge hash covers the consent id, TPP name, selected accounts and validity. | EBA RTS on SCA (Art. 4–9): two independent elements, dynamic linking, possession proven by a device-bound key. Maps to the spec's `PHOTO_OTP` / `PUSH_OTP` authentication types (§14.9) but is executed entirely on Bank B's side, so the TPP never handles the challenge. |
| **D7** | **Implicit start of the authorisation process.** `POST /v1/consents` creates the authorisation sub-resource automatically and returns its `scaStatus` link. | §4.6 "optimisation process", §6.1.1.2, and the example "OAuth2 approach with an implicit generated authorisation resource" in §6.3.1.1. Multilevel SCA (corporate accounts) is out of scope. |
| **D8** | **Confirmation call is supported** (`confirmation` link). After the token is obtained, A calls `PUT /v1/consents/{id}/authorisations/{authId}` with the bearer token. | §7.6 and §7.6.4 ("example for integrated OAuth solution"). It gives Bank B a proof that the party holding the token is the party that created the consent, and gives A an explicit `finalised` result. Bank B may omit the link, in which case A goes straight to the status call. |
| **D9** | **Every XS2A and OAuth2 endpoint requires mTLS with the TPP's QWAC.** `client_id` is the `organizationIdentifier` of the QWAC (e.g. `PSDDE-BAFIN-123456`). | §3 (transport), §13 (also applies to OAuth2 messages), §13.1 (`client_id` format). |

---

## 3. System context

```mermaid
flowchart LR
    PSU((PSU))
    Device[["Bank B mobile app<br/>on registered device"]]

    subgraph A["TPP application A (AISP / PISP)"]
        AFE["Web front end"]
        ABE["Back end<br/>(consent orchestrator, OAuth2 client, XS2A client)"]
    end

    subgraph F["OpenID Connect provider F"]
        AS["Authorization Server<br/>/authorize /token /jwks /.well-known"]
    end

    subgraph B["Bank B (ASPSP)"]
        XS2A["XS2A API<br/>(Resource Server)"]
        CIAM["CIAM<br/>(identity, devices, SCA, consent UI)"]
        CM["Consent management"]
        CORE["Core banking"]
    end

    PSU -->|browser| AFE
    AFE --> ABE
    ABE -->|"mTLS (QWAC)<br/>POST /v1/consents, GET /v1/accounts"| XS2A
    ABE -->|"mTLS (QWAC)<br/>POST /token"| AS
    PSU -->|"browser redirect<br/>/authorize"| AS
    AS -->|"OIDC brokering<br/>(browser redirect)"| CIAM
    AS -->|"validate scope AIS:consentId"| CM
    PSU -->|"login, account selection,<br/>consent screen, QR page"| CIAM
    PSU -->|"scan QR, approve"| Device
    Device -->|"signed challenge response<br/>(device-authenticated API)"| CIAM
    CIAM -->|"authorisation result"| CM
    XS2A --> CM
    XS2A --> CORE
```

---

## 4. Containers

### 4.1 TPP application A

| Container | Responsibility |
|---|---|
| **Web front end** | Bank picker, "connect bank" button, account list and account detail screens, status page while SCA is pending. |
| **Bank registry** | Configured list of registered ASPSPs: id, display name, XS2A base URL, OAuth2 metadata URL (also delivered dynamically in the `scaOAuth` link), supported consent models, whether request signing is required. In production this is fed from NCA registers or a directory service. |
| **Consent orchestrator** | Creates the consent, tracks its state, persists `consentId`, `authorisationId`, the hyperlinks returned by Bank B, and the PSU-to-consent mapping. |
| **OAuth2 client** | Reads AS metadata (RFC 8414), generates `state` and PKCE verifier (RFC 7636), builds the authorization request, exchanges the code with mTLS client authentication, refreshes tokens. |
| **XS2A client** | Adds `X-Request-ID`, `Consent-ID`, `Authorization`, PSU context headers (§4.8), optional `Digest`/`Signature`/`TPP-Signature-Certificate` (§4.2, §12). |
| **Token vault** | Encrypted storage of access and refresh tokens keyed by (PSU, bank, consentId). |
| **Key material** | QWAC (TLS client cert) and QSEAL (request signing) with private keys in an HSM or KMS. |

### 4.2 OpenID Connect provider F

| Container | Responsibility |
|---|---|
| **Metadata and keys** | `/.well-known/oauth-authorization-server` and `/.well-known/openid-configuration` (§13, RFC 8414), `/jwks`. Advertises `tls_client_certificate_bound_access_tokens: true`, `token_endpoint_auth_methods_supported: ["tls_client_auth"]`, `code_challenge_methods_supported: ["S256"]`. |
| **Client registry** | One client per TPP, `client_id` = QWAC `organizationIdentifier`, bound to the certificate subject DN (RFC 8705 `tls_client_auth_subject_dn`), with registered redirect URIs that must lie in the QWAC's domain (§4.10). Roles read from the QWAC's PSD2 QcStatement (AISP / PISP / PIISP). |
| **Scope handler** | Parses `AIS:<consentId>`, `PIS:<paymentId>`, `PIIS:<consentId>`, `offline_access`. Before starting authentication it asks Bank B's consent management whether the resource exists, is in status `received`, and was created by this `client_id`. |
| **Identity broker** | Redirects the PSU to Bank B's CIAM (OIDC), passing the consent context and `acr_values=urn:bank-b:psd2:sca`. Validates the returned ID token: `acr` equals the required value, `consent_id` claim equals the requested scope, `consent_status` is `authorised`. |
| **Token service** | Issues JWT access tokens (see §7.4 below), refresh tokens, handles `refresh_token` grant (§13.5), `/revoke`, `/introspect`. Access-token lifetime short; refresh-token lifetime capped by the consent's `validUntil`. Exposes an admin API so Bank B can revoke all tokens of a consent. |

### 4.3 Bank B

| Container | Responsibility |
|---|---|
| **XS2A gateway** | TLS termination with client-certificate request; QWAC validation (chain to a qualified trust service provider, revocation, PSD2 QcStatement roles per ETSI TS 119 495); optional HTTP-signature verification with the QSEAL; JWT validation against F's JWKS; rate limiting; `X-Request-ID` logging. |
| **XS2A service (AIS + PIS)** | `POST /v1/consents`, `GET /v1/consents/{id}`, `GET /v1/consents/{id}/status`, `DELETE /v1/consents/{id}`, `GET /v1/consents/{id}/authorisations/{authId}`, `PUT /v1/consents/{id}/authorisations/{authId}`, `GET /v1/accounts`, `GET /v1/accounts/{id}`, `GET /v1/accounts/{id}/balances`, `GET /v1/accounts/{id}/transactions` and the payment endpoints (§4.11). Produces the `_links` steering (§4.15). |
| **Consent management** | Consent store and state machine (§14.15), authorisation sub-resources with `scaStatus` (§14.16), accessible-account list per consent, per-account daily usage counters, side effects on new recurring consents (§6.3.1.1). Internal API for F and CIAM. |
| **CIAM: identity store** | PSU identities (PSU-ID, PSU-ID-Type, credential hashes, status), corporate identities if any. |
| **CIAM: device registry** | Enrolled devices per PSU: device id, app instance id, public key (P-256, hardware-backed), attestation, push token, status, enrolment date, last use. |
| **CIAM: authentication orchestration** | Journey engine: identify → first factor → risk assessment → account selection and consent screen → SCA challenge → result. Acts as OpenID Provider towards F. |
| **CIAM: SCA engine** | Creates challenges with dynamic linking, renders QR payloads, sends push notifications, verifies device signatures, enforces expiry and retry limits. |
| **CIAM: risk engine** | Consumes PSU context data forwarded by the TPP (§4.8: `PSU-IP-Address`, `PSU-User-Agent`, `PSU-Device-ID`, `PSU-Geo-Location`) plus device signals; can step up or refuse. |
| **CIAM: consent user interface** | Login page, account selection, consent summary ("A wants to read the list, details and balances of these accounts until date X"), QR page with live status. |
| **Mobile authenticator app** | Enrolment (key generation in secure enclave / keystore), QR scanning, push handling, approval screen with the dynamic-link details, local biometric or PIN, challenge signing. |
| **Core banking adapter** | Accounts, balances, transactions for a PSU. Issues opaque `resourceId` values so IBANs never appear in URL paths (§4.11.2 remark). |
| **PSU consent dashboard** | Bank-side page where the PSU sees and revokes consents; revocation sets `revokedByPsu` and triggers token revocation at F. |

---

## 5. User journey, step by step

**Prerequisite (once, in Bank B's own channel).** The PSU has enrolled at least one device: the Bank B app generated a key pair in the device's secure hardware and registered the public key, attestation and push token with the CIAM, protected by an existing SCA (for example an activation code sent by letter plus the online-banking password). Devices are never enrolled through the TPP journey.

| Step | Actor | What happens | Spec |
|---|---|---|---|
| 1 | PSU, A | PSU signs in to A (A's own authentication, out of scope) and opens "Add a bank". A shows its bank registry; PSU selects **Bank B**. | — |
| 2 | A → XS2A | A sends `POST /v1/consents` over mTLS with `access: {accounts: [], balances: []}`, `recurringIndicator: true`, `validUntil` (≤ 180 days), `frequencyPerDay: 4`, `TPP-Redirect-URI`, `TPP-Nok-Redirect-URI`, `PSU-IP-Address` and other PSU context headers. | §6.3.1.1, §6.3.1.2, §4.8 |
| 3 | XS2A | Validates the QWAC (role AISP), request syntax, semantics; creates the consent (`received`) and an authorisation sub-resource (`received`); replies `201` with `consentId`, `ASPSP-SCA-Approach: REDIRECT`, `_links.scaOAuth` (F's metadata URL), `scaStatus`, `self`, `status`, `confirmation`. | §6.3.1.1, §4.6 |
| 4 | A | Fetches F's metadata from the `scaOAuth` link, creates `state` (bound to the PSU's session at A) and a PKCE verifier, stores them with the `consentId`, and redirects the browser to F's authorization endpoint with `scope=AIS:<consentId> offline_access`. | §13.1, §7.6.1 |
| 5 | F | Validates `client_id`, `redirect_uri`, PKCE method; asks consent management that `<consentId>` belongs to this client and is `received`; redirects the browser to Bank B's CIAM with the consent context and `acr_values=urn:bank-b:psd2:sca`. | §13.1 |
| 6 | PSU, CIAM | **Identification and first factor.** PSU enters PSU-ID and password on Bank B's page. Authorisation sub-resource moves to `psuIdentified` then `psuAuthenticated`. Risk engine evaluates context. | §14.16 |
| 7 | PSU, CIAM | **Account selection and consent summary.** CIAM lists the PSU's payment accounts; PSU ticks the accounts to share; CIAM shows the summary (TPP A, access types, selected accounts, validity, frequency). | §6 "Bank Offered Consent" |
| 8 | CIAM | **Second factor.** SCA engine creates a challenge whose dynamic-link hash covers `consentId`, TPP name, selected accounts and `validUntil`; renders it as a QR code (challenge id, nonce, Bank B endpoint, signed) and optionally pushes it to the PSU's active devices. The page polls the challenge status. `scaStatus` → `started`. | §14.9 (`PHOTO_OTP`, `PUSH_OTP`) |
| 9 | PSU, app | PSU opens the Bank B app on a registered device, scans the QR (or taps the push). The app fetches the challenge over a device-authenticated channel, displays the same summary, asks for biometric or PIN, signs the challenge hash with the device key and posts the signature. | RTS Art. 5 dynamic linking |
| 10 | CIAM | Verifies the signature against the registered public key of that device, checks expiry and that the device belongs to the identified PSU; marks the challenge approved; tells consent management: authorisation `unconfirmed` (or `finalised` when no confirmation step), consent accessible accounts = selection, consent status stays `received` until confirmation, or becomes `valid` directly. | §14.15, §14.16 |
| 11 | CIAM → F | CIAM finishes its OIDC flow towards F: F obtains an ID token (`sub`, `acr`, `amr: ["pwd","hwk"]`, `consent_id`, `consent_status: "authorised"`). F verifies it matches the requested scope and issues an authorization code to A's redirect URI with the original `state`. | §13.2 |
| 12 | A | Checks that `state` matches the session (session-fixation control); sends the token request over mTLS with `code`, `redirect_uri`, `code_verifier`. | §7.6.3, §13.3 |
| 13 | F → A | Returns a certificate-bound JWT access token with `scope: "AIS:<consentId> offline_access"`, plus a refresh token. | §13.4, RFC 8705 |
| 14 | A → XS2A | If a `confirmation` link was returned in step 3: `PUT /v1/consents/{id}/authorisations/{authId}` with `Authorization: Bearer`. XS2A checks that the token's `consent_id` and `client_id` match the resource and replies `scaStatus: finalised`; consent becomes `valid`. Then `GET /v1/consents/{id}/status` → `valid`. | §7.6.4, §6.3.2 |
| 15 | A → XS2A | **Account list.** `GET /v1/accounts?withBalance=true` with `Consent-ID`, `Authorization: Bearer`, `X-Request-ID`, `PSU-IP-Address` (PSU is present). XS2A validates QWAC, token and consent, returns the accessible accounts with opaque `resourceId` values and `_links` to balances and transactions. A renders the list. | §6.5.1, §14.20 |
| 16 | PSU, A → XS2A | **Account details.** PSU clicks an account; A calls `GET /v1/accounts/{resourceId}?withBalance=true`. XS2A checks the account is in the consent's accessible list and returns the details, balances included when consented. | §6.5.2, §6.5.3 |
| 17 | later | On a later visit A reuses the consent. If the access token has expired A uses the refresh token (mTLS). Calls without PSU presence (no `PSU-IP-Address`) are limited to `frequencyPerDay` per account; calls with the PSU present are not. When the consent is `expired` or `revokedByPsu` (401 `CONSENT_EXPIRED` / `CONSENT_INVALID`), A restarts at step 2. | §13.5, §6, §14.11.3 |

---

## 6. Sequence diagrams

### 6.1 Device enrolment (prerequisite, Bank B channel only)

```mermaid
sequenceDiagram
    autonumber
    actor PSU
    participant App as Bank B app (new device)
    participant CIAM as Bank B CIAM
    participant Reg as Device registry

    PSU->>App: install, "activate this device"
    App->>App: generate P-256 key pair in secure hardware,<br/>obtain platform attestation
    App->>CIAM: POST /devices {publicKey, attestation, appInstanceId, pushToken}<br/>(PSU logged in with online-banking credentials)
    CIAM-->>PSU: existing SCA (e.g. activation code by letter or current device)
    PSU->>App: enter activation code
    App->>CIAM: POST /devices/{id}/activate {code}
    CIAM->>Reg: store device (status active, enrolledAt)
    CIAM-->>App: 201 device active
```

### 6.2 Consent creation and start of authorisation

```mermaid
sequenceDiagram
    autonumber
    actor PSU
    participant Br as PSU browser
    participant A as TPP A back end
    participant XS2A as Bank B XS2A API
    participant CM as Bank B consent mgmt
    participant F as OIDC provider F

    PSU->>Br: select "Bank B", click Connect
    Br->>A: POST /banks/B/connect
    A->>XS2A: POST /v1/consents (mTLS QWAC)<br/>access {accounts:[], balances:[]}, recurring, validUntil,<br/>TPP-Redirect-URI, PSU-IP-Address, X-Request-ID
    XS2A->>XS2A: validate QWAC (AISP role), syntax, semantics
    XS2A->>CM: create consent (received) + authorisation (received)
    XS2A-->>A: 201 consentId, ASPSP-SCA-Approach: REDIRECT,<br/>_links: scaOAuth, scaStatus, self, status, confirmation
    A->>F: GET /.well-known/oauth-authorization-server
    F-->>A: metadata (authorization_endpoint, token_endpoint, jwks_uri, ...)
    A->>A: generate state + PKCE verifier, bind to session and consentId
    A-->>Br: 302 F/authorize?response_type=code&client_id=PSDDE-BAFIN-123456<br/>&scope=AIS:{consentId} offline_access&state&redirect_uri&code_challenge&code_challenge_method=S256
    Br->>F: GET /authorize
    F->>F: validate client_id, redirect_uri, PKCE
    F->>CM: is consent {consentId} owned by client and in status received?
    CM-->>F: yes
    F-->>Br: 302 Bank B CIAM /authorize (broker)<br/>acr_values=urn:bank-b:psd2:sca, consent context
```

### 6.3 Authentication and SCA at Bank B (password + QR on registered device)

```mermaid
sequenceDiagram
    autonumber
    actor PSU
    participant Br as PSU browser
    participant CIAM as Bank B CIAM
    participant SCA as SCA engine
    participant App as Bank B app (registered device)
    participant CM as Bank B consent mgmt
    participant F as OIDC provider F

    Br->>CIAM: GET /authorize (from F)
    CIAM-->>Br: login page
    PSU->>Br: PSU-ID + password
    Br->>CIAM: POST /login
    CIAM->>CIAM: verify first factor, risk assessment
    CIAM->>CM: authorisation scaStatus = psuAuthenticated
    CIAM->>CM: load consent {consentId}
    CIAM-->>Br: account selection + consent summary
    PSU->>Br: tick accounts, Continue
    Br->>CIAM: POST /consent/{consentId}/selection
    CIAM->>SCA: create challenge (dynamic link: consentId, TPP, accounts, validUntil)
    SCA-->>CIAM: challengeId, QR payload, expiry (3 min)
    CIAM->>CM: authorisation scaStatus = started
    CIAM-->>Br: QR page (polls /challenge/{id}/status)
    SCA-)App: push notification (optional)
    PSU->>App: open app, scan QR
    App->>SCA: GET /sca/challenges/{id} (device-authenticated)
    SCA-->>App: challenge details
    App-->>PSU: "A wants to read accounts X, Y until date; approve?"
    PSU->>App: approve (biometric / PIN)
    App->>App: sign challenge hash with device key
    App->>SCA: POST /sca/challenges/{id}/response {signature, deviceId}
    SCA->>SCA: verify signature vs registered key, expiry, device belongs to PSU
    SCA-->>App: 200 approved
    Br->>CIAM: poll status
    CIAM->>CM: authorisation scaStatus = unconfirmed,<br/>accessible accounts = selection
    CIAM-->>Br: 302 F broker callback (code)
    Br->>F: GET /broker/callback?code
    F->>CIAM: POST /token (back channel)
    CIAM-->>F: ID token {sub, acr, amr:[pwd,hwk], consent_id, consent_status:authorised}
    F->>F: consent_id == requested scope? acr ok?
    F-->>Br: 302 A redirect_uri?code&state
```

### 6.4 Token exchange, confirmation, account list, account details

```mermaid
sequenceDiagram
    autonumber
    actor PSU
    participant Br as PSU browser
    participant A as TPP A back end
    participant F as OIDC provider F
    participant XS2A as Bank B XS2A API
    participant CM as Bank B consent mgmt
    participant Core as Core banking

    Br->>A: GET /callback?code&state
    A->>A: state matches session? (else abort)
    A->>F: POST /token (mTLS QWAC)<br/>grant_type=authorization_code, code, redirect_uri, code_verifier, client_id
    F->>F: cert matches client, PKCE ok
    F-->>A: access_token (JWT, scope AIS:{consentId}, cnf.x5t#S256),<br/>refresh_token, expires_in
    A->>XS2A: PUT /v1/consents/{id}/authorisations/{authId}<br/>Authorization: Bearer
    XS2A->>CM: token.consent_id == id, client == consent owner → finalised, consent valid
    XS2A-->>A: 200 {scaStatus: finalised}
    A->>XS2A: GET /v1/consents/{id}/status
    XS2A-->>A: 200 {consentStatus: valid}
    A-->>Br: "Bank B connected"

    PSU->>Br: open accounts at Bank B
    Br->>A: GET /banks/B/accounts
    A->>XS2A: GET /v1/accounts?withBalance=true<br/>Consent-ID, Authorization: Bearer, X-Request-ID, PSU-IP-Address
    XS2A->>XS2A: QWAC (AISP), JWT sig/exp/aud, cnf == client cert,<br/>scope consentId == Consent-ID
    XS2A->>CM: consent valid? access rights? frequency (PSU present → not counted)
    XS2A->>Core: accounts of psuId ∩ accessible accounts
    XS2A-->>A: 200 {accounts: [{resourceId, iban, currency, name, balances, _links}]}
    A-->>Br: account list

    PSU->>Br: click an account
    Br->>A: GET /banks/B/accounts/{resourceId}
    A->>XS2A: GET /v1/accounts/{resourceId}?withBalance=true
    XS2A->>CM: resourceId in accessible accounts of this consent?
    XS2A->>Core: account details + balances
    XS2A-->>A: 200 {account: {...}}
    A-->>Br: account details
```

### 6.5 Later access and token refresh

```mermaid
sequenceDiagram
    autonumber
    participant A as TPP A back end
    participant F as OIDC provider F
    participant XS2A as Bank B XS2A API
    participant CM as Bank B consent mgmt

    A->>XS2A: GET /v1/accounts (expired access token)
    XS2A-->>A: 401 TOKEN_EXPIRED
    A->>F: POST /token (mTLS) grant_type=refresh_token
    F->>CM: consent still valid?
    CM-->>F: valid
    F-->>A: new access_token (+ rotated refresh_token)
    A->>XS2A: GET /v1/accounts (new token, no PSU-IP-Address)
    XS2A->>CM: usage today for each account < frequencyPerDay?
    XS2A-->>A: 200 accounts  (or 429 ACCESS_EXCEEDED)
```

---

## 7. Message contracts

Base URL of the sandbox XS2A API: `https://api.bank-b.sandbox/psd2` (the `{provider}` part of §4.4). All calls: TLS 1.2+ with client certificate.

### 7.1 Create consent (step 2–3)

```http
POST /psd2/v1/consents HTTP/1.1
Host: api.bank-b.sandbox
Content-Type: application/json
X-Request-ID: 99391c7e-ad88-49ec-a2ad-99ddcb1f7756
PSU-IP-Address: 192.168.8.78
PSU-User-Agent: Mozilla/5.0 ...
PSU-Device-ID: 3f1d2c3a-...
TPP-Redirect-URI: https://a.tpp.sandbox/xs2a/callback/bank-b
TPP-Nok-Redirect-URI: https://a.tpp.sandbox/xs2a/callback/bank-b?outcome=nok
TPP-Redirect-Preferred: true
TPP-Brand-Logging-Information: App A

{
  "access": { "accounts": [], "balances": [] },
  "recurringIndicator": true,
  "validUntil": "2026-12-05",
  "frequencyPerDay": 4,
  "combinedServiceIndicator": false
}
```

```http
HTTP/1.1 201 Created
X-Request-ID: 99391c7e-ad88-49ec-a2ad-99ddcb1f7756
ASPSP-SCA-Approach: REDIRECT
Location: /psd2/v1/consents/123cons456
Content-Type: application/json

{
  "consentStatus": "received",
  "consentId": "123cons456",
  "_links": {
    "self":         { "href": "/psd2/v1/consents/123cons456" },
    "status":       { "href": "/psd2/v1/consents/123cons456/status" },
    "scaStatus":    { "href": "/psd2/v1/consents/123cons456/authorisations/123auth567" },
    "confirmation": { "href": "/psd2/v1/consents/123cons456/authorisations/123auth567" },
    "scaOAuth":     { "href": "https://f.sandbox/.well-known/oauth-authorization-server" }
  }
}
```

### 7.2 Authorization request to F (step 4)

```http
GET /authorize?response_type=code
  &client_id=PSDDE-BAFIN-123456
  &scope=AIS%3A123cons456%20offline_access
  &state=S8NJ7uqk5fY4EjNvP_G_FtyJu6pUsvH9jsYni9dMAJw
  &redirect_uri=https%3A%2F%2Fa.tpp.sandbox%2Fxs2a%2Fcallback%2Fbank-b
  &code_challenge=5c305578f8f19b2dcdb6c3c955c0aa709782590b4642eb890b97e43917cd0f36
  &code_challenge_method=S256 HTTP/1.1
Host: f.sandbox
```

Hardening options: pushed authorization requests (RFC 9126) so the request parameters travel over the mTLS back channel, and `nonce` when an ID token is requested.

### 7.3 Token request and response (step 12–13)

```http
POST /token HTTP/1.1
Host: f.sandbox
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&client_id=PSDDE-BAFIN-123456
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https%3A%2F%2Fa.tpp.sandbox%2Fxs2a%2Fcallback%2Fbank-b
&code_verifier=7814hj4hjai87qqhjz9hahdeu9qu771367647864676787878
```

```json
{
  "access_token": "eyJhbGciOiJFUzI1NiIsImtpZCI6ImYtMjAyNiJ9...",
  "token_type": "Bearer",
  "expires_in": 600,
  "refresh_token": "tGzv3JokF0XG5Qx2TlKWIA",
  "scope": "AIS:123cons456 offline_access"
}
```

### 7.4 Access token claims (JWT issued by F)

```json
{
  "iss": "https://f.sandbox",
  "sub": "8f6c2b1e-pairwise-psu-id",
  "aud": "https://api.bank-b.sandbox/psd2",
  "client_id": "PSDDE-BAFIN-123456",
  "scope": "AIS:123cons456 offline_access",
  "consent_id": "123cons456",
  "acr": "urn:bank-b:psd2:sca",
  "amr": ["pwd", "hwk"],
  "cnf": { "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2" },
  "iat": 1757150000,
  "exp": 1757150600,
  "jti": "c1f2..."
}
```

`sub` is a pairwise pseudonymous identifier, so the TPP never learns the bank-internal PSU-ID.

### 7.5 XS2A validation of an API call

For every call carrying `Authorization: Bearer` and `Consent-ID` the gateway and service check, in order:

1. TLS client certificate present, chain valid, not revoked, PSD2 QcStatement contains the role needed (AISP for `/accounts`).
2. `Digest` / `Signature` valid when Bank B mandates request signing.
3. JWT signature against F's JWKS, `iss`, `aud`, `exp`, `nbf`.
4. `cnf.x5t#S256` equals the SHA-256 thumbprint of the presented client certificate (RFC 8705 §3).
5. `client_id` in the token equals the `organizationIdentifier` of the certificate.
6. `scope` contains `AIS:<id>` with `<id>` equal to the `Consent-ID` header.
7. Consent exists, was created by this `client_id`, status is `valid`, `validUntil` not passed.
8. Requested resource and access type are covered by the consent (account in accessible list; `withBalance` only if `balances` granted).
9. If `PSU-IP-Address` is absent: usage counter for (consent, account, today) is below `frequencyPerDay`; increment it.

### 7.6 Account list response (step 15)

```json
{
  "accounts": [
    {
      "resourceId": "3dc3d5b3-7023-4848-9853-f5400a64e80f",
      "iban": "DE2310010010123456789",
      "currency": "EUR",
      "product": "Girokonto",
      "cashAccountType": "CACC",
      "name": "Main Account",
      "balances": [
        { "balanceType": "closingBooked", "balanceAmount": { "currency": "EUR", "amount": "1250.30" } }
      ],
      "_links": {
        "balances":     { "href": "/psd2/v1/accounts/3dc3d5b3-7023-4848-9853-f5400a64e80f/balances" },
        "transactions": { "href": "/psd2/v1/accounts/3dc3d5b3-7023-4848-9853-f5400a64e80f/transactions" }
      }
    }
  ]
}
```

`transactions` links appear only when the consent grants `transactions` (§14.20, `_links`).

### 7.7 Internal contracts (not part of XS2A)

| Interface | Direction | Purpose |
|---|---|---|
| `GET /internal/consents/{id}?client_id=` | F → consent mgmt | Scope validation before authentication. |
| `POST /internal/consents/{id}/authorisations/{authId}` | CIAM → consent mgmt | Update `scaStatus`, set accessible accounts, PSU-ID. |
| `POST /internal/tokens/revoke?consent_id=` | consent mgmt → F | Revoke refresh and access tokens when the PSU revokes or the TPP deletes a consent. |
| `POST /sca/challenges` / `GET /sca/challenges/{id}` / `POST /sca/challenges/{id}/response` | CIAM ↔ SCA engine ↔ app | Challenge lifecycle. App calls are authenticated with the device key (signed request or mTLS with a device certificate). |
| `POST /devices`, `POST /devices/{id}/activate`, `DELETE /devices/{id}` | app → CIAM | Enrolment and de-enrolment. |

QR payload (JSON, base64url, signed by the SCA engine):

```json
{
  "v": 1,
  "challengeId": "chl_01J8...",
  "nonce": "m3A9...",
  "endpoint": "https://ciam.bank-b.sandbox/sca",
  "exp": 1757150180,
  "dl": "sha256(consentId|tppName|accounts|validUntil)"
}
```

The app never trusts the QR content alone: it fetches the challenge from the endpoint and shows the server-side details.

---

## 8. Data model

```mermaid
erDiagram
    TPP ||--o{ CONSENT : creates
    PSU ||--o{ CONSENT : authorises
    CONSENT ||--o{ AUTHORISATION : has
    CONSENT ||--o{ CONSENT_ACCOUNT : "accessible accounts"
    CONSENT ||--o{ USAGE_COUNTER : "per account per day"
    PSU ||--o{ DEVICE : enrols
    AUTHORISATION ||--o| SCA_CHALLENGE : "authorised by"
    DEVICE ||--o{ SCA_CHALLENGE : answers
    CONSENT ||--o{ TOKEN : "scoped to"

    TPP {
        string tppId PK "organizationIdentifier from QWAC"
        string legalName
        string[] roles "AISP PISP PIISP"
        string[] redirectUris
    }
    PSU {
        string psuId PK
        string psuIdType
        string credentialHash
        string status
    }
    CONSENT {
        string consentId PK
        string tppId FK
        string psuId FK "set during SCA"
        json access "accounts balances transactions availableAccounts allPsd2"
        bool recurringIndicator
        date validUntil
        int frequencyPerDay
        bool combinedServiceIndicator
        string consentStatus "received valid rejected expired revokedByPsu terminatedByTpp"
        date lastActionDate
    }
    AUTHORISATION {
        string authorisationId PK
        string consentId FK
        string scaStatus "received psuIdentified psuAuthenticated started unconfirmed finalised failed"
        string challengeId FK
        datetime finalisedAt
    }
    CONSENT_ACCOUNT {
        string consentId FK
        string resourceId
        string iban
        string currency
        string[] accessTypes "accounts balances transactions"
    }
    USAGE_COUNTER {
        string consentId FK
        string resourceId
        date day
        int count
    }
    DEVICE {
        string deviceId PK
        string psuId FK
        string name
        string platform
        string appInstanceId
        string publicKey "P-256"
        string attestation
        string pushToken
        string status "active blocked"
        datetime enrolledAt
    }
    SCA_CHALLENGE {
        string challengeId PK
        string psuId FK
        string subjectType "AIS_CONSENT PIS_PAYMENT"
        string subjectId
        string dynamicLinkHash
        string nonce
        datetime expiresAt
        string status "pending approved denied expired"
        string deviceId FK
        string signature
    }
    TOKEN {
        string jti PK
        string consentId FK
        string clientId
        string cnfThumbprint
        string type "access refresh"
        datetime expiresAt
        bool revoked
    }
```

The `resourceId` is an opaque, per-consent token for (IBAN, currency); it is stable for the life of the consent (§6.5.2) and never reveals the IBAN in a path.

---

## 9. State machines

### 9.1 Consent (`consentStatus`, §14.15)

```mermaid
stateDiagram-v2
    [*] --> received: POST /v1/consents
    received --> valid: SCA finalised (and confirmation if required)
    received --> rejected: SCA failed / PSU declined / challenge expired
    valid --> expired: validUntil passed, or one-off consent used
    valid --> revokedByPsu: PSU revokes at Bank B
    valid --> terminatedByTpp: DELETE /v1/consents/{id}, or replaced by a new recurring consent of the same TPP for the same PSU
    rejected --> [*]
    expired --> [*]
    revokedByPsu --> [*]
    terminatedByTpp --> [*]
```

### 9.2 Authorisation sub-resource (`scaStatus`, §14.16)

```mermaid
stateDiagram-v2
    [*] --> received: created implicitly with the consent
    received --> psuIdentified: PSU-ID entered at CIAM
    psuIdentified --> psuAuthenticated: password verified
    psuAuthenticated --> started: QR challenge issued (method implicitly selected)
    started --> unconfirmed: device signature verified, confirmation link was returned
    started --> finalised: device signature verified, no confirmation step
    unconfirmed --> finalised: PUT .../authorisations/{id} with bearer token
    started --> failed: challenge denied / expired / too many attempts
    psuAuthenticated --> failed: risk engine refuses
    finalised --> [*]
    failed --> [*]
```

### 9.3 SCA challenge

```mermaid
stateDiagram-v2
    [*] --> pending: created, QR shown, push sent
    pending --> approved: valid signature from an active device of the PSU
    pending --> denied: PSU rejects in app
    pending --> expired: 3 minutes elapsed
    approved --> [*]
    denied --> [*]
    expired --> [*]
```

---

## 10. Security controls

| Control | Where | Reference |
|---|---|---|
| TLS 1.2+ with mandatory client certificate (QWAC) on XS2A and OAuth2 endpoints | Bank B gateway, F | §3, §13 |
| QWAC validation: chain to QTSP, revocation, PSD2 roles in QcStatement, `client_id` = `organizationIdentifier` | Bank B gateway, F client registry | §3, §13.1, ETSI TS 119 495 |
| Optional application-layer signature with QSEAL (`Digest`, `Signature`, `TPP-Signature-Certificate`) | A signs, Bank B verifies | §4.2, §12 |
| Redirect URIs must lie in the QWAC's domain and stay constant for the life of a transaction | F registration, Bank B | §4.10 |
| `state` bound to the user-agent session; abort on mismatch | A | §7.6.1, §7.6.3 |
| PKCE `S256` | A, F | §13.1, RFC 7636 |
| mTLS client authentication and certificate-bound access tokens | F, Bank B gateway | §13.3, RFC 8705 |
| Bearer token only in the `Authorization` header, never in URLs | A | §13.6, RFC 6750 |
| Access token scope limited to one consent; refresh token capped by `validUntil`; revocation on consent revocation | F, consent mgmt | §13.4, §13.5 |
| Consent checked on every call (status, owner, rights, frequency) | Bank B XS2A | §6, §6.5 |
| Two independent SCA elements, dynamic linking, device-bound key in secure hardware, biometric or PIN gate on the device | CIAM, app | EBA RTS Art. 4, 5, 7, 9 |
| Challenge expiry (3 min), single use, retry limit, device must belong to the identified PSU | SCA engine | RTS Art. 4(3) |
| Push and QR carry only a challenge reference; details are fetched over an authenticated channel | app | — |
| PSU context headers forwarded for risk assessment (`PSU-IP-Address`, `PSU-User-Agent`, `PSU-Device-ID`, `PSU-Geo-Location`) | A → Bank B | §4.8 |
| Opaque `resourceId` values; no IBAN or PAN in paths | Bank B | §4.11.2 |
| Pairwise `sub` in tokens; PSU-ID never returned to the TPP | F | OIDC Core §8 |
| Tokens encrypted at rest; private keys of QWAC/QSEAL in HSM or KMS | A | — |
| Audit log with `X-Request-ID` on both sides | A, Bank B | §4.1 |

---

## 11. Error handling

| Situation | Signal | A's behaviour |
|---|---|---|
| PSU declines on the consent screen or in the app | F redirects to `TPP-Nok-Redirect-URI` / `error=access_denied`; consent `rejected` | Show "access not granted", offer retry from step 2. |
| QR challenge expires | Bank B page offers "new code"; after N misses authorisation `failed`, consent `rejected` | Same as above. |
| PSU has no active device | CIAM cannot offer the possession factor; may fall back to another SCA method it supports or abort | Show Bank B's message; device enrolment is done in Bank B's own channel. |
| `state` mismatch on callback | — | Abort, do not call the token endpoint (§7.6.3). |
| Access token expired | `401 TOKEN_EXPIRED` | Refresh; on failure restart consent. |
| Token does not match certificate | `401 TOKEN_INVALID` | Configuration error; alert. |
| Consent expired / revoked / unknown | `401 CONSENT_EXPIRED`, `401 CONSENT_INVALID`, `403 CONSENT_UNKNOWN` | Mark bank connection as needing re-consent; restart at step 2. |
| Daily frequency exceeded without PSU presence | `429 ACCESS_EXCEEDED` | Back off until next day or wait for a PSU-initiated request. |
| Certificate problems | `401 CERTIFICATE_INVALID / EXPIRED / REVOKED / BLOCKED`, `401 ROLE_INVALID` | Operational alert. |
| Bad request | `400 FORMAT_ERROR` with `tppMessages[].path` | Fix and retry. |

Error bodies follow §4.13 (`tppMessages` array with `category`, `code`, `path`, `text`).

---

## 12. Reuse for PIS

Bank B's PISP compliance reuses every component above:

- `POST /v1/payments/{payment-product}` creates the payment resource and an implicit authorisation sub-resource, returns `scaOAuth` (§5.1.5).
- A runs the same authorization-code flow with `scope=PIS:<paymentId>`; F validates the scope against the payment resource; the CIAM journey shows the payment (payee, amount) instead of the consent, and the dynamic link covers amount and payee (RTS Art. 5).
- The app's approval screen renders "Pay 12.50 EUR to Payee X" from the server-side challenge details.
- `GET /v1/payments/{product}/{paymentId}/status` with the bearer token (§5.4).
- Combined AIS + PIS session: A sets `combinedServiceIndicator: true` on the consent and passes `Consent-ID` in the payment initiation, so Bank B does not ask for the first factor again (§9).

---

## 13. Sandbox realisation

Suggested layout for `docker compose`, one container per box in §3:

| Service | Suggestion | Notes |
|---|---|---|
| `tpp-a` | Small web app (any stack) with a server-side back end holding the QWAC and tokens | Bank registry as YAML. |
| `oidc-f` | A headless authorization server with an external login-and-consent app (for example ORY Hydra), or Keycloak with identity brokering to `bank-b-ciam` | Must support `tls_client_auth`, certificate-bound tokens, PKCE, RFC 8414 metadata, custom scope validation hook. |
| `bank-b-xs2a` | XS2A service behind a reverse proxy that terminates mTLS and forwards the client certificate | Implements the endpoints of §4.11 for consents and accounts, then payments. |
| `bank-b-consent` | Consent management with the model of §8 | Internal API for `oidc-f` and `bank-b-ciam`. |
| `bank-b-ciam` | Login, account selection, consent page, QR page, SCA engine, device registry; OpenID Provider towards `oidc-f` | — |
| `bank-b-app` | A browser-based "device simulator" that scans the QR with the camera or accepts a pasted payload, holds a WebCrypto key pair, and signs challenges | Replaces the native app in the sandbox. |
| `bank-b-core` | Mock core banking with a few PSUs and accounts | Seeded IBANs. |
| `pki` | Private CA issuing test QWACs with a PSD2 QcStatement for `tpp-a` | Bank B's gateway trusts this CA in the sandbox instead of the EU trusted list. |

Configuration parameters worth exposing: consent `validUntil` cap, `frequencyPerDay` cap, challenge lifetime, access-token lifetime, whether the `confirmation` link is returned, whether request signing is mandated.

---

## 14. Assumptions and open points

- **Two-consent variant.** If the product wants the PSU to see *all* available accounts in A before deciding which ones to share, use two consents: first `access.availableAccounts: "allAccounts"` (list only, §6.3.1.2; Bank B may decide to require SCA or not, §6.3.1.2 "no assumptions are made for the SCA Approach"), then a dedicated consent on the chosen accounts (`accounts`, `balances`, `transactions` arrays, §6.3.1.1). This costs a second SCA. The recommended single bank-offered consent avoids it because the PSU selects the accounts on Bank B's page.
- **Consent duration.** `validUntil` is capped by Bank B at the regulatory maximum for renewal of SCA on AIS (180 days under the amended RTS; older deployments use 90). A sandbox parameter.
- **Alternative SCA approaches.** Bank B could also expose the decoupled approach (`ASPSP-SCA-Approach: DECOUPLED`, push to the app, TPP polls `scaStatus`, §6.1.1.3) or the embedded approach with `PHOTO_OTP` where A displays the QR image from `challengeData.image` (§6.1.1.4, §14.10). They are not chosen because the requirement is a token issued by F, and because they either bypass F or push credentials through the TPP.
- **Multilevel SCA** for corporate accounts (§6.3.4) is out of scope; the design keeps the authorisation sub-resource model so it can be added.
- **F and Bank B trust boundary.** F must reach Bank B's consent management (scope validation, token revocation) and be a registered relying party of Bank B's CIAM. If F is operated by a third party, these calls need their own mTLS and contracts.
- **Device enrolment** is performed in Bank B's own channels only. The TPP journey never registers or trusts a new device.
- **App-to-app redirection** (opening the Bank B app directly from a mobile browser instead of scanning a QR) can be added later using the `PSU-Device-ID` and user-agent hints (§4.8 note).

---

## 15. Business analysis of the domain

The context map and the domain models are the authoritative form of this section; the text below summarises them.

### 15.1 Domains and subdomains

| Domain | Subdomain | Class | Why that class | Bounded contexts |
|---|---|---|---|---|
| Access to account (Bank B) | Consent and account access | **core** | The reason the sandbox exists: turning a consent given at the bank into an enforceable access right on the XS2A interface, and serving no more than that right. | Consent management, Account information, Payment initiation |
| Access to account (Bank B) | Customer identity and strong customer authentication | **core** | Bank B is a CIAM. Knowing which devices are the customer's and proving presence with two dynamically linked factors is what makes the consent trustworthy. | Customer identity and SCA |
| Access to account (Bank B) | Third-party identification | supporting | Needed on every call, but the rules come from eIDAS and ETSI, not from Bank B. | TPP identification |
| Access to account (Bank B) | Core banking | generic | The ledger already exists; it is wrapped, not modelled. | Accounts ledger |
| Access to account (Bank B) | Push notifications | generic | A delivery channel. No context of its own. | none |
| Authorization (F) | Authorization server | supporting | An OAuth2 server is a commodity; what is bespoke is the scope handler that binds `AIS:<consentId>` to a consent and the brokering to Bank B's CIAM. | Token issuance |
| Account aggregation (TPP A) | Bank connections | supporting | A's differentiator is what it does with the data; the connection lifecycle is necessary plumbing. | Bank connection |

### 15.2 Main aggregates

| Context | Aggregate (root) | What it protects | Key invariants |
|---|---|---|---|
| Consent management | **Consent** | Access rights, validity, frequency, accessible accounts, daily usage | Valid only after every authorisation is finalised. Data served only while valid and only to the creating TPP. Calls without PSU presence stop at `frequencyPerDay`. A new recurring consent terminates the old one. |
| Consent management | **Authorisation** | One PSU's SCA trail for a consent | `scaStatus` moves forward only; `finalised` needs a verified challenge and, when a confirmation link was returned, the TPP's confirmation. |
| Account information | **AccountResource** | The XS2A view of one account under one consent | Opaque, consent-stable `resourceId`; balances and links only for granted access types. |
| Customer identity and SCA | **PsuIdentity** | Who the customer is | Locked or closed identities cannot start a session; credentials lock after too many failures. |
| Customer identity and SCA | **RegisteredDevice** | The possession element | Active only after enrolment confirmed by an existing SCA; one identity per device; keys are never replaced, a new key is a new device. |
| Customer identity and SCA | **ScaChallenge** | One approval | Expires after three minutes, answered once, accepted only with a signature from an active device of the same identity, over the dynamic-link hash. |
| Customer identity and SCA | **AuthenticationSession** | One journey from login to ID token | Second factor only after first factor and risk check; challenge only after account selection; ID token only after approval. |
| Token issuance | **ClientRegistration** | Who may ask for tokens | `client_id` equals the QWAC organization identifier; redirect URIs inside the certificate's domain; scope kinds gated by PSD2 roles. |
| Token issuance | **AuthorizationRequest** | One code flow | Exactly one AIS/PIS/PIIS resource per request; the resource exists, is `received` and belongs to the client; code issued only with the required `acr` and matching consent id; redeemed once, with PKCE, by the same client over mTLS. |
| Token issuance | **TokenGrant** | Everything a redeemed code produced | Same scope, subject and certificate thumbprint on every token; access token at most ten minutes; refresh token capped by `validUntil`; revoked together. |
| Bank connection | **BankConnection** | One user's link to one bank | One per (user, bank); connected only while the consent is valid and a token set exists; re-consent on `CONSENT_EXPIRED` / `CONSENT_INVALID`. |
| Bank connection | **AuthorizationAttempt** | One trip to F | Single-use `state` bound to the session; code exchanged only when `state` matches; verifier only ever sent to the token endpoint. |

### 15.3 Words that change meaning at a boundary

| Word | In | Means | In | Means |
|---|---|---|---|---|
| Account | Accounts ledger | The bank's ledger account | Account information | A tokenised resource under one consent, possibly a currency sub-account |
| Consent | Consent management | The XS2A resource with status and access rights | Bank connection | The handle A stores to know whether a bank is connected |
| Authorisation / Authorization | Consent management | The XS2A authorisation sub-resource of §7 (SCA trail) | Token issuance | An OAuth2 authorization request or grant |
| PSU | Customer identity and SCA | A customer identity with credentials and devices | Token issuance | A pairwise subject; the bank identifier never crosses to A |
| Challenge | Customer identity and SCA | A signed approval on a registered device | Token issuance | The PKCE code challenge |

### 15.4 Context map, in words

- **NextGenPSD2 XS2A is a published language.** Consent management and Account information are upstream of every TPP through it; A conforms to the specification, not to Bank B's internals. The same holds for OAuth2 between F and A.
- **TPP identification is an open host service** consumed by the XS2A gateway and by F's client registry, so "who is calling" has one answer.
- **Consent management and Payment initiation share a kernel:** the authorisation sub-resource and its `scaStatus` vocabulary, because the specification defines one authorisation process for AIS and PIS.
- **Consent management supplies Customer identity and SCA** with the consent to display and receives the outcome; both teams are inside Bank B, so this is customer/supplier rather than conformist.
- **F sees the consent through an anticorruption layer:** existence, owner and status only, so `AIS:<consentId>` stays an opaque handle at F.
- **The CIAM is an open host (OpenID Provider) that F conforms to**, like any other brokered identity provider.
- **The ledger is wrapped by an anticorruption layer** in Account information so that ledger vocabulary never reaches a TPP.

---

## 16. PlantUML attachments

Sources under [`puml/`](puml/), one file per diagram, rendered with PlantUML 1.2026.8. The C4 diagrams use the PlantUML standard library (`!include <C4/...>`), so no network access is needed.

| File | Diagram | Section |
|---|---|---|
| [`01-context.puml`](puml/01-context.puml) | System context (C4 level 1) | 3 |
| [`02-containers.puml`](puml/02-containers.puml) | Containers (C4 level 2) | 4 |
| [`03-seq-device-enrolment.puml`](puml/03-seq-device-enrolment.puml) | Device enrolment | 6.1 |
| [`04-seq-consent-and-authorization-start.puml`](puml/04-seq-consent-and-authorization-start.puml) | Consent creation and start of authorisation | 6.2 |
| [`05-seq-sca-at-bank-b.puml`](puml/05-seq-sca-at-bank-b.puml) | Authentication and SCA at Bank B | 6.3 |
| [`06-seq-token-and-account-read.puml`](puml/06-seq-token-and-account-read.puml) | Token exchange, confirmation, account list and details | 6.4 |
| [`07-seq-later-access.puml`](puml/07-seq-later-access.puml) | Later access and token refresh | 6.5 |
| [`08-state-consent.puml`](puml/08-state-consent.puml) | Consent status | 9.1 |
| [`09-state-authorisation.puml`](puml/09-state-authorisation.puml) | Authorisation sub-resource status | 9.2 |
| [`10-state-sca-challenge.puml`](puml/10-state-sca-challenge.puml) | SCA challenge | 9.3 |
| [`11-data-model.puml`](puml/11-data-model.puml) | Data model | 8 |

Render all of them with:

```sh
java -jar plantuml.jar -tpng -o out docs/design/puml/*.puml
```
