# Example maps of the PSU account-list journey

One `.examplemap` file per story of the story map
[`../storymap/psu-account-list-journey.storymap`](../storymap/psu-account-list-journey.storymap),
grouped in one directory per story-map activity. The grammar is the
example-mapping DSL documented at [doc-em.obya.ch/dsl](https://doc-em.obya.ch/dsl);
the practice is described at
[dev-portal.obya.ch/doc/practices/example-mapping](https://dev-portal.obya.ch/doc/practices/example-mapping/).

Each map holds the story (yellow card), its business rules (blue cards), the
concrete examples that illustrate each rule (green cards) and the questions
nobody could answer from the design alone (red cards). The examples are written
with Given/When/Then steps and real values so that they can be exported to
Gherkin feature files mechanically: story to `Feature:`, rule to `Rule:`,
example to `Scenario:`; questions are not exported.

## Conventions

- **One story per file, named after the story.** The `examplemap` title, the
  `story` title and the file name (kebab-case) are the story title of the story
  map. The `as`/`want`/`so` clauses and the `+tags` of the story are copied from
  the story map, including the `+"spec x.y"` references to the NextGenPSD2 XS2A
  Implementation Guidelines v1.3.16.
- **Deliveries.** Every map declares the three releases of the story map
  (`Walking skeleton`, `MVP`, `Hardening`) and the story ships (`@`) in the
  same release as in the story map. Examples of a Walking-skeleton story ship
  their nominal cases in the walking skeleton and their edge and error cases in
  the MVP, because the skeleton is the thinnest end-to-end path. Examples of MVP
  and Hardening stories ship with their story. Stories the story map has not
  committed carry no `@`, and neither do their examples.
- **Example tags.** Every example carries exactly one of `+nominal` (the rule
  satisfied in the ordinary case), `+edge` (a boundary, a rare but legitimate
  case, a concurrency or timing case) or `+error` (an input or a state the
  system must refuse, and how). Security-relevant rules are tagged `+security`;
  rules that implement a regulation carry `+"RTS art. n"` (EBA RTS on SCA) or
  an RFC or spec reference.
- **Status.** `~ready` when the map has no open question, `~analysing` when at
  least one red card is left. The status is a cache: the tracker owns it. No
  tickets (`#`) are invented here; the tracker issues them.
- **Questions.** Each red card names who can answer it with a tag such as
  `+"ask bank-b"`, `+"ask f"`, `+"ask product"`, `+"ask tpp-a"`,
  `+"ask sandbox"` or `+"ask fraud"`. Where a map had to assume an answer to
  write its examples (a lifetime, a cap, an error code), the assumption is
  stated in the question so the examples can be corrected in one place.
- **Reading a map.** Following the practice: many red cards means the story is
  not ready to estimate; many blue cards means the story is too large and
  should split along its rules; a rule with many green cards probably hides
  two rules.

## Shared fixtures

The examples use one consistent set of names and values so that scenarios from
different maps can share step definitions.

| Fixture | Value |
|---|---|
| Today | 2026-09-06 (Saturday), Bank B time zone Europe/Berlin |
| PSU Anna | PSU-ID `anna.mueller`, identity active, display name Anna Müller |
| PSU Ben | PSU-ID `ben.weber`, another customer of Bank B |
| Anna's accounts | Main Account `DE23 1001 0010 0123 4567 89` EUR (product Girokonto, resourceId `3dc3d5b3-7023-4848-9853-f5400a64e80f` under consent 123cons456, closingBooked 1250.30); Savings `DE89 3704 0044 0532 0130 00` EUR (resourceId `7a1f…`); optionally a multicurrency account `DE11 …` with EUR and USD sub-accounts, and a loan account that is not a payment account |
| Ben's account | `DE75 5121 0800 1245 1261 99` |
| Anna's devices | `dev-anna-1` "Anna's iPhone" active (key K1); `dev-anna-0` "Old phone" blocked; `dev-anna-2`, `dev-anna-3` used as newly registered or pending devices; `dev-anna-sim` the browser device simulator |
| Ben's device | `dev-ben-1` active (key K2) |
| TPP A | Legal name A Fintech GmbH, brand "App A", `client_id` and QWAC organizationIdentifier `PSDDE-BAFIN-123456`, roles AISP and PISP, QWAC domain `a.tpp.sandbox`, redirect URI `https://a.tpp.sandbox/xs2a/callback/bank-b`, nok URI `…/callback/bank-b?outcome=nok` |
| TPP C | Brand "C Pay", `PSDDE-BAFIN-654321`, PISP only unless stated otherwise, domain `c.tpp.sandbox` |
| Bank B | XS2A API `https://api.bank-b.sandbox/psd2`, CIAM `https://ciam.bank-b.sandbox`, app and simulator `https://app.bank-b.sandbox`, PKI `https://pki.sandbox` |
| OIDC provider F | `https://f.sandbox`, metadata at `/.well-known/oauth-authorization-server`, signing key id `f-2026`, broker client at the CIAM `f-broker` |
| Consents | `123cons456` the consent of the journey (authorisation `123auth567`, validUntil 2026-12-05, frequencyPerDay 4, recurring); `111cons222` an older recurring consent of A for Anna; `333cons444` a consent of C for Anna; `555cons666` a consent of A for Ben or an accounts-only consent; `777cons888` a one-off consent; `900cons001` a corporate consent; `999cons000` never exists |
| OAuth2 values | state `S8NJ7…`, PKCE verifier `dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk` and challenge `E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM` (RFC 7636 test vector), code `SplxlOBeZQQYbYS6WxSbIA`, refresh tokens `R1`, `R2`, access token `T1`, grant `g1`, pairwise subject `8f6c2b1e-…`, certificate thumbprint `bwcK0…` |
| SCA | challenge `chl-01J8` (also `chl-01`, `chl-02`, `chl-03` for retries), nonce `m3A9…`, dynamic-link hash `H1` (another consent: `H2`), lifetime 180 s, at most 3 challenges per session and 3 invalid signatures per challenge |
| Sandbox parameters | validity cap 180 days, frequency cap 4 per day, access-token lifetime 600 s, authorization code lifetime 60 s, login session inactivity 10 min, abandoned consent rejected after 30 min, `confirmationRequired` and `requestSigningRequired` switchable |

## Index

### Enrol a device at Bank B

6 stories, 25 rules, 85 examples, 9 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Generate a device-bound key pair](1-enrol-a-device-at-bank-b/generate-a-device-bound-key-pair.examplemap) | Walking skeleton | analysing | 4 | 13 | 1 |
| [Register the device with the CIAM](1-enrol-a-device-at-bank-b/register-the-device-with-the-ciam.examplemap) | Walking skeleton | analysing | 5 | 17 | 2 |
| [Protect enrolment with an existing SCA](1-enrol-a-device-at-bank-b/protect-enrolment-with-an-existing-sca.examplemap) | MVP | analysing | 4 | 14 | 2 |
| [Verify platform attestation at enrolment](1-enrol-a-device-at-bank-b/verify-platform-attestation-at-enrolment.examplemap) | Hardening | analysing | 4 | 14 | 2 |
| [List and remove my devices](1-enrol-a-device-at-bank-b/list-and-remove-my-devices.examplemap) | MVP | analysing | 4 | 13 | 2 |
| [Device simulator in the browser](1-enrol-a-device-at-bank-b/device-simulator-in-the-browser.examplemap) | Walking skeleton | ready | 4 | 14 | 0 |

### Connect Bank B from application A

19 stories, 72 rules, 282 examples, 20 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Pick a bank from the registry](2-connect-bank-b-from-application-a/pick-a-bank-from-the-registry.examplemap) | Walking skeleton | analysing | 3 | 11 | 1 |
| [Configure the bank registry](2-connect-bank-b-from-application-a/configure-the-bank-registry.examplemap) | Walking skeleton | analysing | 4 | 17 | 1 |
| [Show the connection state per bank](2-connect-bank-b-from-application-a/show-the-connection-state-per-bank.examplemap) | MVP | analysing | 3 | 12 | 1 |
| [Create a bank-offered consent](2-connect-bank-b-from-application-a/create-a-bank-offered-consent.examplemap) | Walking skeleton | analysing | 4 | 15 | 2 |
| [Terminate the XS2A TLS with a client certificate](2-connect-bank-b-from-application-a/terminate-the-xs2a-tls-with-a-client-certificate.examplemap) | Walking skeleton | ready | 4 | 13 | 0 |
| [Validate the QWAC and its PSD2 roles](2-connect-bank-b-from-application-a/validate-the-qwac-and-its-psd2-roles.examplemap) | MVP | analysing | 4 | 18 | 2 |
| [Issue test QWACs from a sandbox CA](2-connect-bank-b-from-application-a/issue-test-qwacs-from-a-sandbox-ca.examplemap) | Walking skeleton | analysing | 5 | 16 | 1 |
| [POST /v1/consents creates consent and authorisation](2-connect-bank-b-from-application-a/post-v1-consents-creates-consent-and-authorisation.examplemap) | Walking skeleton | analysing | 4 | 25 | 2 |
| [Forward PSU context headers](2-connect-bank-b-from-application-a/forward-psu-context-headers.examplemap) | MVP | analysing | 4 | 12 | 1 |
| [Return a confirmation link](2-connect-bank-b-from-application-a/return-a-confirmation-link.examplemap) | MVP | ready | 4 | 10 | 0 |
| [Sign requests with the QSEAL](2-connect-bank-b-from-application-a/sign-requests-with-the-qseal.examplemap) | Hardening | analysing | 4 | 18 | 2 |
| [Expire the previous recurring consent](2-connect-bank-b-from-application-a/expire-the-previous-recurring-consent.examplemap) | MVP | analysing | 4 | 12 | 2 |
| [Read F's metadata from the scaOAuth link](2-connect-bank-b-from-application-a/read-fs-metadata-from-the-scaoauth-link.examplemap) | Walking skeleton | analysing | 4 | 17 | 1 |
| [Redirect with state and PKCE](2-connect-bank-b-from-application-a/redirect-with-state-and-pkce.examplemap) | Walking skeleton | ready | 4 | 13 | 0 |
| [Register the TPP client at F](2-connect-bank-b-from-application-a/register-the-tpp-client-at-f.examplemap) | Walking skeleton | analysing | 4 | 16 | 1 |
| [Validate the scope against the consent](2-connect-bank-b-from-application-a/validate-the-scope-against-the-consent.examplemap) | Walking skeleton | analysing | 3 | 16 | 1 |
| [Enforce redirect URIs in the QWAC domain](2-connect-bank-b-from-application-a/enforce-redirect-uris-in-the-qwac-domain.examplemap) | MVP | analysing | 4 | 14 | 1 |
| [Broker the PSU to Bank B CIAM](2-connect-bank-b-from-application-a/broker-the-psu-to-bank-b-ciam.examplemap) | Walking skeleton | analysing | 3 | 15 | 1 |
| [Pushed authorization requests](2-connect-bank-b-from-application-a/pushed-authorization-requests.examplemap) | Hardening | ready | 3 | 12 | 0 |

### Authenticate and approve at Bank B

23 stories, 77 rules, 288 examples, 17 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Log in with PSU-ID and password](3-authenticate-and-approve-at-bank-b/log-in-with-psu-id-and-password.examplemap) | Walking skeleton | analysing | 4 | 15 | 2 |
| [Move the authorisation to psuAuthenticated](3-authenticate-and-approve-at-bank-b/move-the-authorisation-to-psuauthenticated.examplemap) | Walking skeleton | ready | 4 | 13 | 0 |
| [Assess risk from PSU context and device signals](3-authenticate-and-approve-at-bank-b/assess-risk-from-psu-context-and-device-signals.examplemap) | Hardening | analysing | 3 | 11 | 2 |
| [Explain a refusal to the PSU](3-authenticate-and-approve-at-bank-b/explain-a-refusal-to-the-psu.examplemap) | MVP | analysing | 4 | 14 | 1 |
| [Choose the accounts to share](3-authenticate-and-approve-at-bank-b/choose-the-accounts-to-share.examplemap) | Walking skeleton | analysing | 4 | 15 | 2 |
| [Show the consent summary](3-authenticate-and-approve-at-bank-b/show-the-consent-summary.examplemap) | Walking skeleton | ready | 3 | 11 | 0 |
| [Show the TPP brand name](3-authenticate-and-approve-at-bank-b/show-the-tpp-brand-name.examplemap) | MVP | analysing | 3 | 10 | 2 |
| [Issue a challenge with dynamic linking](3-authenticate-and-approve-at-bank-b/issue-a-challenge-with-dynamic-linking.examplemap) | Walking skeleton | analysing | 4 | 15 | 1 |
| [Render the challenge as a QR code](3-authenticate-and-approve-at-bank-b/render-the-challenge-as-a-qr-code.examplemap) | Walking skeleton | ready | 3 | 12 | 0 |
| [Expire the challenge after three minutes](3-authenticate-and-approve-at-bank-b/expire-the-challenge-after-three-minutes.examplemap) | MVP | analysing | 4 | 13 | 1 |
| [Push the challenge to my active devices](3-authenticate-and-approve-at-bank-b/push-the-challenge-to-my-active-devices.examplemap) | Hardening | analysing | 3 | 11 | 1 |
| [Offer a new code when the old one expired](3-authenticate-and-approve-at-bank-b/offer-a-new-code-when-the-old-one-expired.examplemap) | MVP | ready | 3 | 11 | 0 |
| [App-to-app redirect on a mobile browser](3-authenticate-and-approve-at-bank-b/app-to-app-redirect-on-a-mobile-browser.examplemap) | Hardening | analysing | 3 | 9 | 2 |
| [Scan the QR and fetch the challenge](3-authenticate-and-approve-at-bank-b/scan-the-qr-and-fetch-the-challenge.examplemap) | Walking skeleton | ready | 4 | 17 | 0 |
| [See what I am approving](3-authenticate-and-approve-at-bank-b/see-what-i-am-approving.examplemap) | Walking skeleton | analysing | 3 | 9 | 1 |
| [Approve with biometric or PIN and sign](3-authenticate-and-approve-at-bank-b/approve-with-biometric-or-pin-and-sign.examplemap) | Walking skeleton | ready | 3 | 12 | 0 |
| [Verify the signature against the registered key](3-authenticate-and-approve-at-bank-b/verify-the-signature-against-the-registered-key.examplemap) | Walking skeleton | ready | 3 | 15 | 0 |
| [Deny a challenge from the app](3-authenticate-and-approve-at-bank-b/deny-a-challenge-from-the-app.examplemap) | MVP | ready | 3 | 12 | 0 |
| [Handle a PSU with no active device](3-authenticate-and-approve-at-bank-b/handle-a-psu-with-no-active-device.examplemap) | MVP | analysing | 3 | 10 | 1 |
| [Record the approved authorisation](3-authenticate-and-approve-at-bank-b/record-the-approved-authorisation.examplemap) | Walking skeleton | ready | 3 | 13 | 0 |
| [Complete the OIDC flow towards F](3-authenticate-and-approve-at-bank-b/complete-the-oidc-flow-towards-f.examplemap) | Walking skeleton | ready | 3 | 12 | 0 |
| [Issue the authorization code](3-authenticate-and-approve-at-bank-b/issue-the-authorization-code.examplemap) | Walking skeleton | ready | 3 | 10 | 0 |
| [Reject the consent when SCA fails](3-authenticate-and-approve-at-bank-b/reject-the-consent-when-sca-fails.examplemap) | MVP | analysing | 4 | 18 | 1 |

### Complete the connection

10 stories, 35 rules, 132 examples, 5 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Validate the callback state](4-complete-the-connection/validate-the-callback-state.examplemap) | Walking skeleton | ready | 4 | 14 | 0 |
| [Exchange the code with mTLS and PKCE](4-complete-the-connection/exchange-the-code-with-mtls-and-pkce.examplemap) | Walking skeleton | ready | 3 | 17 | 0 |
| [Issue a certificate-bound JWT scoped to the consent](4-complete-the-connection/issue-a-certificate-bound-jwt-scoped-to-the-consent.examplemap) | Walking skeleton | ready | 5 | 16 | 0 |
| [Issue a refresh token capped by validUntil](4-complete-the-connection/issue-a-refresh-token-capped-by-validuntil.examplemap) | MVP | analysing | 3 | 15 | 1 |
| [Store tokens encrypted](4-complete-the-connection/store-tokens-encrypted.examplemap) | MVP | analysing | 4 | 13 | 1 |
| [Use a pairwise subject](4-complete-the-connection/use-a-pairwise-subject.examplemap) | MVP | analysing | 3 | 11 | 1 |
| [Confirm with the bearer token](4-complete-the-connection/confirm-with-the-bearer-token.examplemap) | MVP | analysing | 4 | 13 | 1 |
| [Read the consent status](4-complete-the-connection/read-the-consent-status.examplemap) | Walking skeleton | analysing | 3 | 13 | 1 |
| [Read the consent object](4-complete-the-connection/read-the-consent-object.examplemap) | MVP | ready | 3 | 10 | 0 |
| [Tell the PSU the bank is connected](4-complete-the-connection/tell-the-psu-the-bank-is-connected.examplemap) | Walking skeleton | ready | 3 | 10 | 0 |

### View my accounts

10 stories, 37 rules, 139 examples, 5 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Serve GET /v1/accounts from the consent](5-view-my-accounts/serve-get-v1-accounts-from-the-consent.examplemap) | Walking skeleton | ready | 4 | 16 | 0 |
| [Validate token and consent on every call](5-view-my-accounts/validate-token-and-consent-on-every-call.examplemap) | Walking skeleton | ready | 4 | 23 | 0 |
| [Tokenise account identifiers](5-view-my-accounts/tokenise-account-identifiers.examplemap) | Walking skeleton | ready | 3 | 11 | 0 |
| [Include balances when consented](5-view-my-accounts/include-balances-when-consented.examplemap) | MVP | ready | 4 | 13 | 0 |
| [Return hyperlinks per account](5-view-my-accounts/return-hyperlinks-per-account.examplemap) | MVP | ready | 4 | 10 | 0 |
| [Render the account list](5-view-my-accounts/render-the-account-list.examplemap) | Walking skeleton | ready | 4 | 14 | 0 |
| [Serve GET /v1/accounts/{id}](5-view-my-accounts/serve-get-v1-accounts-id.examplemap) | MVP | analysing | 3 | 12 | 2 |
| [Refuse accounts outside the consent](5-view-my-accounts/refuse-accounts-outside-the-consent.examplemap) | MVP | analysing | 3 | 10 | 1 |
| [Render the account details](5-view-my-accounts/render-the-account-details.examplemap) | MVP | ready | 3 | 10 | 0 |
| [Read balances and transactions](5-view-my-accounts/read-balances-and-transactions.examplemap) | — | analysing | 5 | 20 | 2 |

### Come back later

10 stories, 32 rules, 122 examples, 10 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Refresh an expired access token](6-come-back-later/refresh-an-expired-access-token.examplemap) | MVP | ready | 4 | 11 | 0 |
| [Count accesses without PSU presence](6-come-back-later/count-accesses-without-psu-presence.examplemap) | MVP | analysing | 4 | 15 | 1 |
| [Handle TOKEN_EXPIRED and CONSENT_EXPIRED](6-come-back-later/handle-token-expired-and-consent-expired.examplemap) | MVP | ready | 3 | 16 | 0 |
| [Revoke a consent at Bank B](6-come-back-later/revoke-a-consent-at-bank-b.examplemap) | MVP | analysing | 3 | 13 | 2 |
| [Revoke the tokens of a revoked consent](6-come-back-later/revoke-the-tokens-of-a-revoked-consent.examplemap) | MVP | ready | 3 | 12 | 0 |
| [Delete a consent from A](6-come-back-later/delete-a-consent-from-a.examplemap) | MVP | analysing | 3 | 12 | 1 |
| [Ask the PSU to reconnect](6-come-back-later/ask-the-psu-to-reconnect.examplemap) | MVP | ready | 3 | 11 | 0 |
| [Notify A of consent status changes](6-come-back-later/notify-a-of-consent-status-changes.examplemap) | — | analysing | 3 | 10 | 1 |
| [Multilevel SCA for corporate accounts](6-come-back-later/multilevel-sca-for-corporate-accounts.examplemap) | — | analysing | 3 | 9 | 3 |
| [Initiate a payment with the same infrastructure](6-come-back-later/initiate-a-payment-with-the-same-infrastructure.examplemap) | Hardening | analysing | 3 | 13 | 2 |
