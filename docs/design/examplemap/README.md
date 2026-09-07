# Example maps of the two PSU journeys

One `.examplemap` file per story of the three story maps in
[`../storymap/`](../storymap/), grouped in one directory per story-map activity.
The directory numbers run in journey order, so the folder listing is itself the
backbone:

| Directories | Covers | Stories |
|---|---|---|
| `1-` to `6-` | **The account-list journey.** A PSU enrols a device at the Bank, picks the Bank in the TPP and consents to the access, authenticates with a password and approves a QR challenge on that device, the TPP exchanges its tokens and reads the account list and the details, and comes back later under the consent's frequency and validity limits. | 90 |
| `7-` to `10-` | **The payment journey.** The same PSU pays from one of those accounts: the TPP posts the payment, the PSU reviews payee and amount and approves a challenge whose dynamic link covers them, the payment is executed and followed through its transaction status, and cancelled while that is still allowed. | 20 |
| `11-` to `12-` | **Neither journey and both.** What the Bank's interface owes every TPP whatever the service: the authorisation sub-resource as a resource of its own, and conformance in errors, status, hyperlinks and notifications. | 16 |

The two journeys share their machinery on purpose — one device, one SCA engine,
one authorisation model, one token issuer — so a rule proved in the account
journey is not re-proved in the payment journey; only what the payment adds
(the amount and payee in the dynamic link, the transaction status, the
cancellation) gets its own maps.

The grammar is the example-mapping DSL documented at
[doc-em.obya.ch/dsl](https://doc-em.obya.ch/dsl); the practice is described at
[dev-portal.obya.ch/doc/practices/example-mapping](https://dev-portal.obya.ch/doc/practices/example-mapping/).

Each map holds the story (yellow card), its business rules (blue cards), the
concrete examples that illustrate each rule (green cards) and the questions
nobody could answer from the design alone (red cards). The examples are written
with Given/When/Then steps and real values so that they export to Gherkin
mechanically: story to `Feature:`, rule to `Rule:`, example to `Scenario:`;
questions are not exported.

That export is not hypothetical. [`../features/`](../features/) holds one
generated `.feature` per map — 426 rules and 1594 scenarios — produced by
`python3 tools/emgherkin.py`. The maps here are the source of truth; the
feature files are regenerated, never edited.

## Conventions

- **One story per file, named after the story.** The `examplemap` title, the
  `story` title and the file name (kebab-case) are the story title of the story
  map. The `as`/`want`/`so` clauses and the `+tags` of the story are copied from
  the story map, including the `+"spec x.y"` references to the NextGenPSD2 XS2A
  Implementation Guidelines v1.3.16.
- **Deliveries.** A map declares the delivery bands it uses and the story
  ships (`@`) in the band its story map gives it. The account-list journey was
  sliced into `Walking skeleton`, `MVP` and `Hardening`: there, examples of a
  Walking-skeleton story ship their nominal cases in the skeleton and their
  edge and error cases in the MVP, because the skeleton is the thinnest
  end-to-end path. The compliance work is sliced into one band per increment
  (`AIS reads`, `Consent models`, `Authorisation resources`, `PIS core`,
  `PIS cancellation`, `Access rules`, `Conformance`): there, a story and all
  its examples ship together in its increment. Stories the story maps have not
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
  `+"ask bank"`, `+"ask oidc-provider"`, `+"ask product"`, `+"ask tpp"`,
  `+"ask sandbox"` or `+"ask fraud"`. Where a map had to assume an answer to
  write its examples (a lifetime, a cap, an error code), the assumption is
  stated in the question so the examples can be corrected in one place.
- **Reading a map.** Following the practice: many red cards means the story is
  not ready to estimate; many blue cards means the story is too large and
  should split along its rules; a rule with many green cards probably hides
  two rules.

## Shared fixtures

The examples use one consistent set of names and values so that scenarios from
different maps can share step definitions. The set spans both journeys: Anna,
the TPP and her Main Account are the same throughout, and that account is both
what is read under consent `123cons456` and the debtor account of payment
`pay001`. The consent is deliberately *not* shared — the payment maps name
`123cons456` only as a negative, an AIS token, scope or signature offered for a
payment and refused, because a payment is authorised under its own
`PIS:<paymentId>` scope.

| Fixture | Value |
|---|---|
| Today | 2026-09-06 (Saturday), the Bank's time zone Europe/Berlin |
| PSU Anna | PSU-ID `anna.mueller`, identity active, display name Anna Müller |
| PSU Ben | PSU-ID `ben.weber`, another customer of the Bank |
| Anna's accounts | Main Account `DE23 1001 0010 0123 4567 89` EUR (product Girokonto, resourceId `3dc3d5b3-7023-4848-9853-f5400a64e80f` under consent 123cons456, closingBooked 1250.30); Savings `DE89 3704 0044 0532 0130 00` EUR (resourceId `7a1f…`); optionally a multicurrency account `DE11 …` with EUR and USD sub-accounts, and a loan account that is not a payment account |
| Ben's account | `DE75 5121 0800 1245 1261 99` |
| Anna's devices | `dev-anna-1` "Anna's iPhone" active (key K1); `dev-anna-0` "Old phone" blocked; `dev-anna-2`, `dev-anna-3` used as newly registered or pending devices; `dev-anna-sim` the browser device simulator |
| Ben's device | `dev-ben-1` active (key K2) |
| The TPP | Legal name TPP Fintech GmbH, brand "TPP App", `client_id` and QWAC organizationIdentifier `PSDDE-BAFIN-123456`, roles AISP and PISP, QWAC domain `tpp.sandbox`, redirect URI `https://tpp.sandbox/xs2a/callback/bank`, nok URI `…/callback/bank?outcome=nok` |
| TPP C | Brand "C Pay", `PSDDE-BAFIN-654321`, PISP only unless stated otherwise, domain `tpp-c.sandbox` |
| The Bank | XS2A API `https://api.bank.sandbox/psd2`, CIAM `https://ciam.bank.sandbox`, app and simulator `https://app.bank.sandbox`, PKI `https://pki.sandbox` |
| The OIDC-provider | `https://oidc-provider.sandbox`, metadata at `/.well-known/oauth-authorization-server`, signing key id `oidc-2026`, broker client at the CIAM `oidc-broker` |
| Consents | `123cons456` the consent of the account-list journey (authorisation `123auth567`, validUntil 2026-12-05, frequencyPerDay 4, recurring); `111cons222` an older recurring consent of the TPP for Anna; `333cons444` a consent of C for Anna; `555cons666` a consent of the TPP for Ben or an accounts-only consent; `777cons888` a one-off consent; `900cons001` a corporate consent; `999cons000` never exists |
| OAuth2 values | state `S8NJ7…`, PKCE verifier `dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk` and challenge `E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM` (RFC 7636 test vector), code `SplxlOBeZQQYbYS6WxSbIA`, refresh tokens `R1`, `R2`, access token `T1`, grant `g1`, pairwise subject `8f6c2b1e-…`, certificate thumbprint `bwcK0…` |
| SCA | challenge `chl-01J8` (also `chl-01`, `chl-02`, `chl-03` for retries), nonce `m3A9…`, dynamic-link hash `H1` (another consent: `H2`), lifetime 180 s, at most 3 challenges per session and 3 invalid signatures per challenge |
| Payments | `pay001` the payment of the payment journey (sepa-credit-transfers, EUR 12.50 from Main Account to Payee X `DE12 5001 0517 0648 4898 90`, remittance "Invoice 42", authorisation `pay001auth1`, dynamic-link hash `P1`); `pay002` accepted and still cancellable (cancellation authorisation `pay002cancauth1`); `pay003` already settled or belonging to TPP C; `pay999` never exists |
| Transactions | On Main Account: `tx-3001` Rent EUR -950.00 to Landlord GmbH on 2026-08-28 (entry reference `ent-2026-08-28-01`), Salary EUR +3200.00 from Employer AG on 2026-08-15, REWE EUR -45.20 on 2026-08-03, a pending card reservation of EUR -70.00; `tx-3002` a collective booking with entry details; `tx-3003` booked through an exchange rate; `tx-2001` booked more than ninety days ago; `tx-4001` belongs to Savings |
| Sandbox parameters | validity cap 180 days, frequency cap 4 per day, access-token lifetime 600 s, authorization code lifetime 60 s, login session inactivity 10 min, abandoned consent rejected after 30 min, `confirmationRequired` and `requestSigningRequired` switchable, transaction page size 200 with a one-hour paging cursor, `cancellationScaRequired` switchable, per-payment limit EUR 10000.00, notifications switchable, offered payment services and products configurable |

## Index

Across the three story maps: 126 stories, 426 rules, 1594 examples, 100 open questions.

## PSU account list journey

[`obi_psu-account-list-journey.storymap`](../storymap/obi_psu-account-list-journey.storymap). 90 stories, 316 rules, 1188 examples, 79 open questions.

### Enrol a device at the Bank

6 stories, 25 rules, 85 examples, 9 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Generate a device-bound key pair](1-enrol-a-device-at-the-bank/generate-a-device-bound-key-pair.examplemap) | Walking skeleton | analysing | 4 | 13 | 1 |
| [Register the device with the CIAM](1-enrol-a-device-at-the-bank/register-the-device-with-the-ciam.examplemap) | Walking skeleton | analysing | 5 | 17 | 2 |
| [Protect enrolment with an existing SCA](1-enrol-a-device-at-the-bank/protect-enrolment-with-an-existing-sca.examplemap) | MVP | analysing | 4 | 14 | 2 |
| [Verify platform attestation at enrolment](1-enrol-a-device-at-the-bank/verify-platform-attestation-at-enrolment.examplemap) | Hardening | analysing | 4 | 14 | 2 |
| [List and remove my devices](1-enrol-a-device-at-the-bank/list-and-remove-my-devices.examplemap) | MVP | analysing | 4 | 13 | 2 |
| [Device simulator in the browser](1-enrol-a-device-at-the-bank/device-simulator-in-the-browser.examplemap) | Walking skeleton | ready | 4 | 14 | 0 |

### Connect the Bank from the TPP

23 stories, 85 rules, 324 examples, 24 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Pick a bank from the registry](2-connect-the-bank-from-the-tpp/pick-a-bank-from-the-registry.examplemap) | Walking skeleton | analysing | 3 | 11 | 1 |
| [Configure the bank registry](2-connect-the-bank-from-the-tpp/configure-the-bank-registry.examplemap) | Walking skeleton | analysing | 4 | 17 | 1 |
| [Show the connection state per bank](2-connect-the-bank-from-the-tpp/show-the-connection-state-per-bank.examplemap) | MVP | analysing | 3 | 12 | 1 |
| [Create a bank-offered consent](2-connect-the-bank-from-the-tpp/create-a-bank-offered-consent.examplemap) | Walking skeleton | analysing | 4 | 15 | 2 |
| [Terminate the XS2A TLS with a client certificate](2-connect-the-bank-from-the-tpp/terminate-the-xs2a-tls-with-a-client-certificate.examplemap) | Walking skeleton | ready | 4 | 13 | 0 |
| [Validate the QWAC and its PSD2 roles](2-connect-the-bank-from-the-tpp/validate-the-qwac-and-its-psd2-roles.examplemap) | MVP | analysing | 4 | 18 | 2 |
| [Issue test QWACs from a sandbox CA](2-connect-the-bank-from-the-tpp/issue-test-qwacs-from-a-sandbox-ca.examplemap) | Walking skeleton | analysing | 5 | 16 | 1 |
| [POST /v1/consents creates consent and authorisation](2-connect-the-bank-from-the-tpp/post-v1-consents-creates-consent-and-authorisation.examplemap) | Walking skeleton | analysing | 4 | 25 | 2 |
| [Forward PSU context headers](2-connect-the-bank-from-the-tpp/forward-psu-context-headers.examplemap) | MVP | analysing | 4 | 12 | 1 |
| [Return a confirmation link](2-connect-the-bank-from-the-tpp/return-a-confirmation-link.examplemap) | MVP | ready | 4 | 10 | 0 |
| [Sign requests with the QSEAL](2-connect-the-bank-from-the-tpp/sign-requests-with-the-qseal.examplemap) | Hardening | analysing | 4 | 18 | 2 |
| [Expire the previous recurring consent](2-connect-the-bank-from-the-tpp/expire-the-previous-recurring-consent.examplemap) | MVP | analysing | 4 | 12 | 2 |
| [Accept a consent on dedicated accounts](2-connect-the-bank-from-the-tpp/accept-a-consent-on-dedicated-accounts.examplemap) | Consent models | analysing | 3 | 11 | 1 |
| [Accept a consent on all available accounts](2-connect-the-bank-from-the-tpp/accept-a-consent-on-all-available-accounts.examplemap) | Consent models | analysing | 4 | 12 | 1 |
| [Accept a global consent](2-connect-the-bank-from-the-tpp/accept-a-global-consent.examplemap) | Consent models | analysing | 3 | 10 | 1 |
| [Serve the owner name and additional information](2-connect-the-bank-from-the-tpp/serve-the-owner-name-and-additional-information.examplemap) | Consent models | analysing | 3 | 9 | 1 |
| [Read the OIDC-provider's metadata from the scaOAuth link](2-connect-the-bank-from-the-tpp/read-the-oidc-providers-metadata-from-the-scaoauth-link.examplemap) | Walking skeleton | analysing | 4 | 17 | 1 |
| [Redirect with state and PKCE](2-connect-the-bank-from-the-tpp/redirect-with-state-and-pkce.examplemap) | Walking skeleton | ready | 4 | 13 | 0 |
| [Register the TPP client at the OIDC-provider](2-connect-the-bank-from-the-tpp/register-the-tpp-client-at-the-oidc-provider.examplemap) | Walking skeleton | analysing | 4 | 16 | 1 |
| [Validate the scope against the consent](2-connect-the-bank-from-the-tpp/validate-the-scope-against-the-consent.examplemap) | Walking skeleton | analysing | 3 | 16 | 1 |
| [Enforce redirect URIs in the QWAC domain](2-connect-the-bank-from-the-tpp/enforce-redirect-uris-in-the-qwac-domain.examplemap) | MVP | analysing | 4 | 14 | 1 |
| [Broker the PSU to the Bank CIAM](2-connect-the-bank-from-the-tpp/broker-the-psu-to-the-bank-ciam.examplemap) | Walking skeleton | analysing | 3 | 15 | 1 |
| [Pushed authorization requests](2-connect-the-bank-from-the-tpp/pushed-authorization-requests.examplemap) | Hardening | ready | 3 | 12 | 0 |

### Authenticate and approve at the Bank

23 stories, 77 rules, 288 examples, 17 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Log in with PSU-ID and password](3-authenticate-and-approve-at-the-bank/log-in-with-psu-id-and-password.examplemap) | Walking skeleton | analysing | 4 | 15 | 2 |
| [Move the authorisation to psuAuthenticated](3-authenticate-and-approve-at-the-bank/move-the-authorisation-to-psuauthenticated.examplemap) | Walking skeleton | ready | 4 | 13 | 0 |
| [Assess risk from PSU context and device signals](3-authenticate-and-approve-at-the-bank/assess-risk-from-psu-context-and-device-signals.examplemap) | Hardening | analysing | 3 | 11 | 2 |
| [Explain a refusal to the PSU](3-authenticate-and-approve-at-the-bank/explain-a-refusal-to-the-psu.examplemap) | MVP | analysing | 4 | 14 | 1 |
| [Choose the accounts to share](3-authenticate-and-approve-at-the-bank/choose-the-accounts-to-share.examplemap) | Walking skeleton | analysing | 4 | 15 | 2 |
| [Show the consent summary](3-authenticate-and-approve-at-the-bank/show-the-consent-summary.examplemap) | Walking skeleton | ready | 3 | 11 | 0 |
| [Show the TPP brand name](3-authenticate-and-approve-at-the-bank/show-the-tpp-brand-name.examplemap) | MVP | analysing | 3 | 10 | 2 |
| [Issue a challenge with dynamic linking](3-authenticate-and-approve-at-the-bank/issue-a-challenge-with-dynamic-linking.examplemap) | Walking skeleton | analysing | 4 | 15 | 1 |
| [Render the challenge as a QR code](3-authenticate-and-approve-at-the-bank/render-the-challenge-as-a-qr-code.examplemap) | Walking skeleton | ready | 3 | 12 | 0 |
| [Expire the challenge after three minutes](3-authenticate-and-approve-at-the-bank/expire-the-challenge-after-three-minutes.examplemap) | MVP | analysing | 4 | 13 | 1 |
| [Push the challenge to my active devices](3-authenticate-and-approve-at-the-bank/push-the-challenge-to-my-active-devices.examplemap) | Hardening | analysing | 3 | 11 | 1 |
| [Offer a new code when the old one expired](3-authenticate-and-approve-at-the-bank/offer-a-new-code-when-the-old-one-expired.examplemap) | MVP | ready | 3 | 11 | 0 |
| [App-to-app redirect on a mobile browser](3-authenticate-and-approve-at-the-bank/app-to-app-redirect-on-a-mobile-browser.examplemap) | Hardening | analysing | 3 | 9 | 2 |
| [Scan the QR and fetch the challenge](3-authenticate-and-approve-at-the-bank/scan-the-qr-and-fetch-the-challenge.examplemap) | Walking skeleton | ready | 4 | 17 | 0 |
| [See what I am approving](3-authenticate-and-approve-at-the-bank/see-what-i-am-approving.examplemap) | Walking skeleton | analysing | 3 | 9 | 1 |
| [Approve with biometric or PIN and sign](3-authenticate-and-approve-at-the-bank/approve-with-biometric-or-pin-and-sign.examplemap) | Walking skeleton | ready | 3 | 12 | 0 |
| [Verify the signature against the registered key](3-authenticate-and-approve-at-the-bank/verify-the-signature-against-the-registered-key.examplemap) | Walking skeleton | ready | 3 | 15 | 0 |
| [Deny a challenge from the app](3-authenticate-and-approve-at-the-bank/deny-a-challenge-from-the-app.examplemap) | MVP | ready | 3 | 12 | 0 |
| [Handle a PSU with no active device](3-authenticate-and-approve-at-the-bank/handle-a-psu-with-no-active-device.examplemap) | MVP | analysing | 3 | 10 | 1 |
| [Record the approved authorisation](3-authenticate-and-approve-at-the-bank/record-the-approved-authorisation.examplemap) | Walking skeleton | ready | 3 | 13 | 0 |
| [Complete the flow towards the OIDC-provider](3-authenticate-and-approve-at-the-bank/complete-the-flow-towards-the-oidc-provider.examplemap) | Walking skeleton | ready | 3 | 12 | 0 |
| [Issue the authorization code](3-authenticate-and-approve-at-the-bank/issue-the-authorization-code.examplemap) | Walking skeleton | ready | 3 | 10 | 0 |
| [Reject the consent when SCA fails](3-authenticate-and-approve-at-the-bank/reject-the-consent-when-sca-fails.examplemap) | MVP | analysing | 4 | 18 | 1 |

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

15 stories, 53 rules, 202 examples, 11 open questions.

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
| [Serve the balances of an account](5-view-my-accounts/serve-the-balances-of-an-account.examplemap) | AIS reads | analysing | 3 | 13 | 1 |
| [Serve the transaction list for a period](5-view-my-accounts/serve-the-transaction-list-for-a-period.examplemap) | AIS reads | analysing | 3 | 17 | 2 |
| [Serve delta access on the transaction list](5-view-my-accounts/serve-delta-access-on-the-transaction-list.examplemap) | AIS reads | analysing | 4 | 13 | 2 |
| [Serve one transaction's details](5-view-my-accounts/serve-one-transactions-details.examplemap) | AIS reads | ready | 3 | 10 | 0 |
| [Page a long transaction list](5-view-my-accounts/page-a-long-transaction-list.examplemap) | AIS reads | analysing | 3 | 10 | 1 |

### Come back later

13 stories, 41 rules, 157 examples, 13 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Refresh an expired access token](6-come-back-later/refresh-an-expired-access-token.examplemap) | MVP | ready | 4 | 11 | 0 |
| [Count accesses without PSU presence](6-come-back-later/count-accesses-without-psu-presence.examplemap) | MVP | analysing | 4 | 15 | 1 |
| [Handle TOKEN_EXPIRED and CONSENT_EXPIRED](6-come-back-later/handle-token-expired-and-consent-expired.examplemap) | MVP | ready | 3 | 16 | 0 |
| [Count balance and transaction reads against the frequency](6-come-back-later/count-balance-and-transaction-reads-against-the-frequency.examplemap) | Access rules | analysing | 3 | 13 | 1 |
| [Limit the transaction history without a fresh SCA](6-come-back-later/limit-the-transaction-history-without-a-fresh-sca.examplemap) | Access rules | analysing | 3 | 11 | 1 |
| [Renew the consent when its access period ends](6-come-back-later/renew-the-consent-when-its-access-period-ends.examplemap) | Access rules | analysing | 3 | 11 | 1 |
| [Revoke a consent at the Bank](6-come-back-later/revoke-a-consent-at-the-bank.examplemap) | MVP | analysing | 3 | 13 | 2 |
| [Revoke the tokens of a revoked consent](6-come-back-later/revoke-the-tokens-of-a-revoked-consent.examplemap) | MVP | ready | 3 | 12 | 0 |
| [Delete a consent from the TPP](6-come-back-later/delete-a-consent-from-the-tpp.examplemap) | MVP | analysing | 3 | 12 | 1 |
| [Ask the PSU to reconnect](6-come-back-later/ask-the-psu-to-reconnect.examplemap) | MVP | ready | 3 | 11 | 0 |
| [Notify the TPP of consent status changes](6-come-back-later/notify-the-tpp-of-consent-status-changes.examplemap) | — | analysing | 3 | 10 | 1 |
| [Multilevel SCA for corporate accounts](6-come-back-later/multilevel-sca-for-corporate-accounts.examplemap) | — | analysing | 3 | 9 | 3 |
| [Initiate a payment with the same infrastructure](6-come-back-later/initiate-a-payment-with-the-same-infrastructure.examplemap) | Hardening | analysing | 3 | 13 | 2 |

## PSU payment journey

[`obi-psu-payment-journey.storymap`](../storymap/obi-psu-payment-journey.storymap). 20 stories, 62 rules, 227 examples, 9 open questions.

### Create the payment

5 stories, 15 rules, 59 examples, 2 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Serve POST /v1/payments/{payment-product}](7-create-the-payment/serve-post-v1-payments-payment-product.examplemap) | PIS core | analysing | 3 | 13 | 1 |
| [Validate the payment instruction](7-create-the-payment/validate-the-payment-instruction.examplemap) | PIS core | analysing | 3 | 16 | 1 |
| [Create the payment authorisation implicitly](7-create-the-payment/create-the-payment-authorisation-implicitly.examplemap) | PIS core | ready | 3 | 9 | 0 |
| [Return the payment steering links](7-create-the-payment/return-the-payment-steering-links.examplemap) | PIS core | ready | 3 | 11 | 0 |
| [Refuse a payment product the Bank does not offer](7-create-the-payment/refuse-a-payment-product-the-bank-does-not-offer.examplemap) | PIS core | ready | 3 | 10 | 0 |

### Approve the payment at the Bank

5 stories, 17 rules, 60 examples, 2 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Show the payment on the Bank's review screen](8-approve-the-payment-at-the-bank/show-the-payment-on-the-banks-review-screen.examplemap) | PIS core | analysing | 3 | 11 | 1 |
| [Validate the PIS scope against the payment](8-approve-the-payment-at-the-bank/validate-the-pis-scope-against-the-payment.examplemap) | PIS core | ready | 4 | 14 | 0 |
| [Cover amount and payee in the dynamic link](8-approve-the-payment-at-the-bank/cover-amount-and-payee-in-the-dynamic-link.examplemap) | PIS core | ready | 3 | 11 | 0 |
| [Record the approved payment authorisation](8-approve-the-payment-at-the-bank/record-the-approved-payment-authorisation.examplemap) | PIS core | analysing | 3 | 11 | 1 |
| [Confirm the payment authorisation](8-approve-the-payment-at-the-bank/confirm-the-payment-authorisation.examplemap) | PIS core | ready | 4 | 13 | 0 |

### Follow the payment

4 stories, 12 rules, 49 examples, 3 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Serve the transaction status](9-follow-the-payment/serve-the-transaction-status.examplemap) | PIS core | ready | 3 | 15 | 0 |
| [Serve the payment resource](9-follow-the-payment/serve-the-payment-resource.examplemap) | PIS core | analysing | 3 | 10 | 1 |
| [Move the transaction status through its lifecycle](9-follow-the-payment/move-the-transaction-status-through-its-lifecycle.examplemap) | PIS core | analysing | 3 | 13 | 1 |
| [Execute the payment at the core banking](9-follow-the-payment/execute-the-payment-at-the-core-banking.examplemap) | PIS core | analysing | 3 | 11 | 1 |

### Cancel the payment

6 stories, 18 rules, 59 examples, 2 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Cancel a payment that needs no authorisation](10-cancel-the-payment/cancel-a-payment-that-needs-no-authorisation.examplemap) | PIS cancellation | analysing | 3 | 11 | 1 |
| [Refuse to cancel a payment that is already settled](10-cancel-the-payment/refuse-to-cancel-a-payment-that-is-already-settled.examplemap) | PIS cancellation | ready | 3 | 8 | 0 |
| [Require an authorisation for a cancellation](10-cancel-the-payment/require-an-authorisation-for-a-cancellation.examplemap) | PIS cancellation | analysing | 3 | 10 | 1 |
| [Serve the cancellation authorisation sub-resources](10-cancel-the-payment/serve-the-cancellation-authorisation-sub-resources.examplemap) | PIS cancellation | ready | 3 | 10 | 0 |
| [Issue a Cancel-PIS scoped token](10-cancel-the-payment/issue-a-cancel-pis-scoped-token.examplemap) | PIS cancellation | ready | 3 | 11 | 0 |
| [Finish the cancellation with CANC](10-cancel-the-payment/finish-the-cancellation-with-canc.examplemap) | PIS cancellation | ready | 3 | 9 | 0 |

## ASPSP interface conformance (increments 3 and 7)

[`obi_aspsp-interface-conformance.storymap`](../storymap/obi_aspsp-interface-conformance.storymap). 16 stories, 48 rules, 179 examples, 12 open questions.

### Drive the authorisation explicitly

8 stories, 24 rules, 87 examples, 6 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Serve an explicit start of the authorisation process](11-drive-the-authorisation-explicitly/serve-an-explicit-start-of-the-authorisation-process.examplemap) | Authorisation resources | analysing | 3 | 11 | 1 |
| [Serve the list of authorisation sub-resources](11-drive-the-authorisation-explicitly/serve-the-list-of-authorisation-sub-resources.examplemap) | Authorisation resources | ready | 3 | 10 | 0 |
| [Serve the SCA status of an authorisation](11-drive-the-authorisation-explicitly/serve-the-sca-status-of-an-authorisation.examplemap) | Authorisation resources | ready | 3 | 13 | 0 |
| [Announce the SCA approach on every resource](11-drive-the-authorisation-explicitly/announce-the-sca-approach-on-every-resource.examplemap) | Authorisation resources | analysing | 3 | 11 | 1 |
| [Update PSU data for identification](11-drive-the-authorisation-explicitly/update-psu-data-for-identification.examplemap) | Authorisation resources | analysing | 3 | 11 | 1 |
| [Update PSU data for authentication](11-drive-the-authorisation-explicitly/update-psu-data-for-authentication.examplemap) | Authorisation resources | analysing | 3 | 11 | 1 |
| [Offer the SCA methods and record the selection](11-drive-the-authorisation-explicitly/offer-the-sca-methods-and-record-the-selection.examplemap) | Authorisation resources | analysing | 3 | 11 | 1 |
| [Serve challenge data for the selected method](11-drive-the-authorisation-explicitly/serve-challenge-data-for-the-selected-method.examplemap) | Authorisation resources | analysing | 3 | 9 | 1 |

### Answer like the specification says

8 stories, 24 rules, 92 examples, 6 open questions.

| Story | Delivery | Status | Rules | Examples | Questions |
|---|---|---|---|---|---|
| [Serve the message codes of each service](12-answer-like-the-specification-says/serve-the-message-codes-of-each-service.examplemap) | Conformance | analysing | 3 | 12 | 1 |
| [Map failures to the right HTTP response codes](12-answer-like-the-specification-says/map-failures-to-the-right-http-response-codes.examplemap) | Conformance | ready | 3 | 15 | 0 |
| [Report status information consistently](12-answer-like-the-specification-says/report-status-information-consistently.examplemap) | Conformance | ready | 3 | 10 | 0 |
| [Steer every state with hyperlinks](12-answer-like-the-specification-says/steer-every-state-with-hyperlinks.examplemap) | Conformance | analysing | 3 | 12 | 1 |
| [Accept data extensions without breaking](12-answer-like-the-specification-says/accept-data-extensions-without-breaking.examplemap) | Conformance | analysing | 3 | 10 | 1 |
| [Announce notification support and accept a notification URI](12-answer-like-the-specification-says/announce-notification-support-and-accept-a-notification-uri.examplemap) | Conformance | analysing | 3 | 11 | 1 |
| [Notify the TPP of payment status changes](12-answer-like-the-specification-says/notify-the-tpp-of-payment-status-changes.examplemap) | Conformance | analysing | 3 | 11 | 1 |
| [Serve one TPP identity from the certificate](12-answer-like-the-specification-says/serve-one-tpp-identity-from-the-certificate.examplemap) | Conformance | analysing | 3 | 11 | 1 |
