# PSU account list journey

**Product:** OBI

## The timeline

- **Walking skeleton** — release
  Thinnest end-to-end path: test QWAC, bank-offered
  consent, password + QR on the device simulator,
  account list. One PSU, one bank, no refresh.
- **MVP** — release
  Complete journey with details, later access,
  errors, revocation and the consent dashboard.
- **Hardening** — release
  Production-grade controls: request signing,
  risk engine, push, PAR, app-to-app, PIS.
- **AIS reads** — release
  Increment 1: balances, transaction lists with
  booking status and
  period, delta access, transaction details and
  paging.
  Section 6.5.3 to 6.5.5.
- **Consent models** — release
  Increment 2: the consent models beyond
  bank-offered, and the
  additional information a consent may grant.
  Section 6.3.1,
  14.17, 14.18.
- **Access rules** — release
  Increment 6: the frequency counter on every read,
  the history
  limit without a fresh SCA, and the renewal of the
  access period.
  Section 6, RTS art. 10 and 36(5).

## Enrol a device at the Bank

`+precondition` `+ES column 1`

*For PSU, Bank security officer.*

### Activate the Bank app on a device

`+bank-app` `+bank-ciam` `+ES column 1`

- **Walking skeleton** — Generate a device-bound key pair
  `+bank-app`
  As PSU, I want the app to create a key in my phone's secure hardware when I activate it, so that only this device can approve my consents.
- **Walking skeleton** — Register the device with the CIAM
  `+bank-ciam`
  As PSU, I want my activated device listed under my identity at the Bank, so that the Bank knows where to send my challenges.
- **Walking skeleton** — Device simulator in the browser
  `+sandbox` `+bank-app`
  As PSU, I want a web page that holds a WebCrypto key and scans or pastes a QR, so that the sandbox journey runs without a native app.
- **MVP** — Protect enrolment with an existing SCA
  `+bank-ciam` `+security`
  As Bank security officer, I want a new device confirmed with an activation code or an already active device, so that an attacker with a password alone cannot enrol a device.
- **MVP** — List and remove my devices
  `+bank-ciam`
  As PSU, I want to see my active devices and block one, so that a lost phone cannot approve anything.
- **Hardening** — Verify platform attestation at enrolment
  `+bank-ciam` `+security`
  As Bank security officer, I want the key attested by the platform before the device is activated, so that software-only keys are refused.

## Connect the Bank from the TPP

`+ES columns 2-4`

*For PSU, TPP operator, Bank security officer.*

### Select the Bank

`+tpp` `+ES column 2`

- **Walking skeleton** — Pick a bank from the registry
  `+tpp`
  As PSU, I want to choose the Bank from a list of registered banks, so that the TPP knows which XS2A API and authorization server to talk to.
- **Walking skeleton** — Configure the bank registry
  `+tpp`
  As TPP operator, I want each bank's XS2A base URL, metadata URL and consent model in a config file, so that adding a bank does not need a code change.
- **MVP** — Show the connection state per bank
  `+tpp`
  As PSU, I want to see whether the Bank is connected, pending or needs re-consent, so that I know what to do next.

### Request the consent

`+tpp` `+bank-xs2a` `+ES column 3`

- **Walking skeleton** — Create a bank-offered consent
  `+tpp` `+spec 6.3.1.2`
  As PSU, I want the TPP to ask the Bank for access to the accounts I will choose at the bank, so that I decide at the Bank which accounts the TPP may see.
- **Walking skeleton** — Terminate the XS2A TLS with a client certificate
  `+bank-xs2a` `+security` `+spec 3`
  As Bank security officer, I want every XS2A call to present a client certificate and be refused otherwise, so that only identified TPPs reach the API.
- **Walking skeleton** — Issue test QWACs from a sandbox CA
  `+sandbox` `+security`
  As TPP operator, I want a private CA that issues certificates with a PSD2 QcStatement, so that the sandbox exercises the real validation path.
- **Walking skeleton** — POST /v1/consents creates consent and authorisation
  `+bank-xs2a` `+spec 6.3.1.1` `+spec 4.6`
  As TPP operator, I want a 201 with consentId, ASPSP-SCA-Approach REDIRECT and the scaOAuth, scaStatus, self and status links, so that the TPP can steer the next step from the hyperlinks.
- **MVP** — Validate the QWAC and its PSD2 roles
  `+bank-xs2a` `+security` `+spec 3`
  As Bank security officer, I want the certificate chain, revocation and the AISP role checked on every call, so that a revoked or non-AISP certificate gets CERTIFICATE\_\* or ROLE\_INVALID.
- **MVP** — Forward PSU context headers
  `+tpp` `+spec 4.8`
  As Bank security officer, I want the TPP to send PSU-IP-Address, PSU-User-Agent, PSU-Device-ID and geo location, so that the risk engine can assess the session.
- **MVP** — Return a confirmation link
  `+bank-xs2a` `+spec 7.6`
  As Bank security officer, I want the consent response to carry a confirmation link when configured, so that the token holder must prove it is the consent creator.
- **MVP** — Expire the previous recurring consent
  `+bank-xs2a` `+spec 6.3.1.1`
  As PSU, I want an older recurring consent from the same TPP to expire when the new one is authorised, so that I never have two live consents for the same app.
- **Hardening** — Sign requests with the QSEAL
  `+tpp` `+bank-xs2a` `+spec 4.2` `+spec 12`
  As Bank security officer, I want Digest, Signature and TPP-Signature-Certificate verified when mandated, so that requests are non-repudiable at application level.
- **Consent models** — Accept a consent on dedicated accounts
  `+bank-xs2a` `+spec 6.3.1.1`
  As TPP operator, I want a consent naming the IBANs I already know to be accepted without a bank-side account choice, so that a PSU who has told me their accounts is not asked twice.
- **Consent models** — Accept a consent on all available accounts
  `+bank-xs2a` `+spec 6.3.1.2` `+spec 14.17`
  As TPP operator, I want availableAccounts and availableAccountsWithBalance to grant the account list only, so that an app that just lists accounts does not ask for transaction rights.
- **Consent models** — Accept a global consent
  `+bank-xs2a` `+spec 14.17`
  As TPP operator, I want allPsd2 to grant every payment account the PSU can see online, so that an aggregator does not re-consent when the PSU opens a new account.
- **Consent models** — Serve the owner name and additional information
  `+bank-xs2a` `+spec 14.18`
  As PSU, I want my name released only when the consent asked for it, so that an app learns no more about me than I agreed.

### Start the authorization at the OIDC-provider

`+tpp` `+oidc-provider` `+ES column 4`

- **Walking skeleton** — Read the OIDC-provider's metadata from the scaOAuth link
  `+tpp` `+spec 13`
  As TPP operator, I want the TPP to discover the authorization and token endpoints from the metadata document, so that no endpoint is hard-coded per bank.
- **Walking skeleton** — Redirect with state and PKCE
  `+tpp` `+security` `+spec 13.1`
  As PSU, I want the TPP to send me to the OIDC-provider with a one-time state bound to my session and an S256 code challenge, so that nobody can inject a code into my session.
- **Walking skeleton** — Register the TPP client at the OIDC-provider
  `+oidc-provider` `+spec 13.1`
  As TPP operator, I want a client whose id is the QWAC organizationIdentifier, bound to the certificate and redirect URIs, so that the OIDC-provider can authenticate the TPP by mTLS.
- **Walking skeleton** — Validate the scope against the consent
  `+oidc-provider` `+bank-xs2a`
  As Bank security officer, I want the OIDC-provider to accept AIS:\<consentId\> only if the consent exists, is received and belongs to this client, so that a TPP cannot authorise somebody else's consent.
- **Walking skeleton** — Broker the PSU to the Bank CIAM
  `+oidc-provider`
  As PSU, I want the OIDC-provider to hand me to the Bank's own login page with the consent context, so that I authenticate with my bank, not with a stranger.
- **MVP** — Enforce redirect URIs in the QWAC domain
  `+oidc-provider` `+security` `+spec 4.10`
  As Bank security officer, I want redirect URIs outside the certificate's domain refused, so that codes are never sent to a third party.
- **Hardening** — Pushed authorization requests
  `+oidc-provider` `+tpp` `+security`
  As Bank security officer, I want the authorization parameters sent over the mTLS back channel, so that they cannot be tampered with in the browser.

## Authenticate and approve at the Bank

`+ES columns 5-9`

*For PSU, Bank security officer, Bank product owner.*

### Identify and enter my password

`+bank-ciam` `+ES column 5`

- **Walking skeleton** — Log in with PSU-ID and password
  `+bank-ciam`
  As PSU, I want to enter my bank customer id and password on the Bank's page, so that the Bank knows who is consenting.
- **Walking skeleton** — Move the authorisation to psuAuthenticated
  `+bank-xs2a` `+spec 14.16`
  As Bank product owner, I want the authorisation sub-resource updated as the PSU progresses, so that the TPP can read a truthful scaStatus.
- **MVP** — Explain a refusal to the PSU
  `+bank-ciam`
  As PSU, I want a clear message and a way back to the TPP when the Bank refuses, so that I am not left on a dead page.
- **Hardening** — Assess risk from PSU context and device signals
  `+bank-ciam` `+security`
  As Bank security officer, I want the session scored before the second factor is offered, so that suspicious sessions are refused or stepped up.

### Select accounts and review the consent

`+bank-ciam` `+ES column 6`

- **Walking skeleton** — Choose the accounts to share
  `+bank-ciam` `+spec 6.3.1.2`
  As PSU, I want to tick which of my payment accounts the TPP may read, so that the TPP only sees what I decided.
- **Walking skeleton** — Show the consent summary
  `+bank-ciam`
  As PSU, I want to see the TPP name, the access types, the accounts, the validity and the frequency before I approve, so that I know exactly what I am granting.
- **MVP** — Show the TPP brand name
  `+bank-ciam` `+spec 4.9`
  As PSU, I want the name I know the app by, not only its legal name, so that I recognise who is asking.

### Receive the SCA challenge

`+bank-ciam` `+ES column 7`

- **Walking skeleton** — Issue a challenge with dynamic linking
  `+bank-ciam` `+sca` `+RTS art. 5`
  As Bank security officer, I want the challenge hash to cover consentId, TPP, accounts and validity, so that an approval cannot be replayed for a different consent.
- **Walking skeleton** — Render the challenge as a QR code
  `+bank-ciam` `+sca`
  As PSU, I want a QR code on the Bank's page that my app can scan, so that I can approve from my registered device.
- **MVP** — Expire the challenge after three minutes
  `+bank-ciam` `+sca` `+security`
  As Bank security officer, I want a challenge unusable after its lifetime and after a retry limit, so that a stale QR cannot be approved later.
- **MVP** — Offer a new code when the old one expired
  `+bank-ciam`
  As PSU, I want to request a fresh QR without starting over, so that a slow scan does not cost me the whole journey.
- **Hardening** — Push the challenge to my active devices
  `+bank-ciam` `+bank-app` `+sca`
  As PSU, I want a notification on my phone so I do not have to scan, so that approval is one tap away.
- **Hardening** — App-to-app redirect on a mobile browser
  `+bank-ciam` `+bank-app` `+spec 4.8`
  As PSU, I want the Bank to open its app directly when I am already on my phone, so that I do not scan a QR on the same screen.

### Approve on my registered device

`+bank-app` `+bank-ciam` `+ES column 8`

- **Walking skeleton** — Scan the QR and fetch the challenge
  `+bank-app` `+sca`
  As PSU, I want the app to read the QR and load the challenge from the Bank over an authenticated channel, so that what I approve is what the bank recorded, not what the QR says.
- **Walking skeleton** — See what I am approving
  `+bank-app`
  As PSU, I want the TPP, the accounts and the validity shown on my phone before I approve, so that I cannot be tricked into approving something else.
- **Walking skeleton** — Approve with biometric or PIN and sign
  `+bank-app` `+sca`
  As PSU, I want the app to sign the challenge with my device key after my biometric or PIN, so that possession and a local check are both needed.
- **Walking skeleton** — Verify the signature against the registered key
  `+bank-ciam` `+sca` `+security`
  As Bank security officer, I want the response accepted only from an active device of the identified PSU with a valid signature, so that a stolen challenge id is worthless.
- **MVP** — Deny a challenge from the app
  `+bank-app`
  As PSU, I want a reject button that fails the authorisation, so that I can stop a request I did not start.
- **MVP** — Handle a PSU with no active device
  `+bank-ciam`
  As Bank product owner, I want the journey to explain how to enrol a device or to abort cleanly, so that the PSU is never stuck at the QR page.

### Return to the TPP

`+bank-ciam` `+oidc-provider` `+ES column 9`

- **Walking skeleton** — Record the approved authorisation
  `+bank-xs2a` `+spec 14.16`
  As Bank product owner, I want the accessible accounts stored and the authorisation set to unconfirmed or finalised, so that the XS2A API can serve exactly the approved accounts.
- **Walking skeleton** — Complete the flow towards the OIDC-provider
  `+bank-ciam` `+oidc-provider`
  As PSU, I want the Bank to send me back to the OIDC-provider with an ID token that carries acr, amr and the consent id, so that the OIDC-provider can issue the code for the TPP.
- **Walking skeleton** — Issue the authorization code
  `+oidc-provider` `+spec 13.2`
  As PSU, I want the OIDC-provider to redirect me to the TPP with a code and my original state, so that the TPP can finish without asking me anything else.
- **MVP** — Reject the consent when SCA fails
  `+bank-xs2a` `+oidc-provider` `+spec 14.15`
  As Bank product owner, I want a denied, expired or failed challenge to set the consent to rejected and send the PSU to the nok redirect URI, so that the TPP learns the outcome without polling forever.

## Complete the connection

`+ES columns 10-11`

*For PSU, TPP operator, Bank security officer.*

### Exchange the code for tokens

`+tpp` `+oidc-provider` `+ES column 10`

- **Walking skeleton** — Validate the callback state
  `+tpp` `+security` `+spec 7.6.3`
  As TPP operator, I want the TPP to abort when the returned state does not match the session, so that a fixated session never receives a token.
- **Walking skeleton** — Exchange the code with mTLS and PKCE
  `+tpp` `+oidc-provider` `+spec 13.3`
  As TPP operator, I want the TPP to call the token endpoint with its QWAC and the code verifier, so that the OIDC-provider can bind the token to the TPP's certificate.
- **Walking skeleton** — Issue a certificate-bound JWT scoped to the consent
  `+oidc-provider` `+security` `+spec 13.4`
  As Bank security officer, I want an access token with aud, scope AIS:\<consentId\>, cnf thumbprint and a short lifetime, so that a leaked token cannot be used without the TPP's private key.
- **MVP** — Issue a refresh token capped by validUntil
  `+oidc-provider` `+spec 13.5`
  As PSU, I want the TPP to keep access for the life of my consent without asking me again, so that I authenticate once per consent, not per visit.
- **MVP** — Store tokens encrypted
  `+tpp` `+security`
  As TPP operator, I want tokens encrypted at rest and keyed by PSU, bank and consent, so that a database leak does not expose bank access.
- **MVP** — Use a pairwise subject
  `+oidc-provider` `+security`
  As PSU, I want the OIDC-provider to give the TPP a pseudonymous identifier instead of my bank customer id, so that the TPP cannot correlate me across banks.

### Confirm the authorisation

`+tpp` `+bank-xs2a` `+ES column 11`

- **Walking skeleton** — Read the consent status
  `+tpp` `+bank-xs2a` `+spec 6.3.2`
  As TPP operator, I want GET /v1/consents/{id}/status to return valid once SCA is done, so that the TPP can show the PSU that the bank is connected.
- **Walking skeleton** — Tell the PSU the bank is connected
  `+tpp`
  As PSU, I want a confirmation screen after I come back from the Bank, so that I know the connection worked.
- **MVP** — Confirm with the bearer token
  `+tpp` `+bank-xs2a` `+spec 7.6.4`
  As Bank security officer, I want the TPP to PUT the authorisation with its token and the Bank to check consent id and client before finalising, so that the consent becomes valid only for the TPP that created it.
- **MVP** — Read the consent object
  `+tpp` `+bank-xs2a` `+spec 6.3.3`
  As TPP operator, I want GET /v1/consents/{id} to return the access finally granted, so that the TPP knows which accounts and access types were approved at the bank.

## View my accounts

`+ES columns 12-13`

*For PSU, TPP operator, Bank security officer.*

### See the account list

`+tpp` `+bank-xs2a` `+ES column 12`

- **Walking skeleton** — Serve GET /v1/accounts from the consent
  `+bank-xs2a` `+spec 6.5.1`
  As PSU, I want the TPP to show the accounts I selected at the Bank, so that I see my accounts inside the TPP.
- **Walking skeleton** — Validate token and consent on every call
  `+bank-xs2a` `+security`
  As Bank security officer, I want the JWT signature, audience, expiry, certificate binding and the Consent-ID match checked before any data leaves, so that a token is necessary but never sufficient.
- **Walking skeleton** — Tokenise account identifiers
  `+bank-xs2a` `+spec 4.11.2`
  As Bank security officer, I want opaque resourceIds in paths instead of IBANs, so that account numbers never appear in URLs or logs.
- **Walking skeleton** — Render the account list
  `+tpp`
  As PSU, I want a list with name, IBAN, currency and balance, so that I can pick an account.
- **MVP** — Include balances when consented
  `+bank-xs2a` `+spec 6.5.1`
  As PSU, I want withBalance=true to return my booked balances, so that I see how much is on each account.
- **MVP** — Return hyperlinks per account
  `+bank-xs2a` `+spec 14.20`
  As TPP operator, I want balances and transactions links only for the access types granted, so that the TPP can navigate without guessing URLs.

### See an account's details

`+tpp` `+bank-xs2a` `+ES column 13`

- **MVP** — Serve GET /v1/accounts/{id}
  `+bank-xs2a` `+spec 6.5.2`
  As PSU, I want the TPP to show the details of the account I clicked, so that I can check product, owner name and balances.
- **MVP** — Refuse accounts outside the consent
  `+bank-xs2a` `+security`
  As Bank security officer, I want a resourceId not covered by the consent to return CONSENT\_INVALID, so that the TPP cannot enumerate other accounts.
- **MVP** — Render the account details
  `+tpp`
  As PSU, I want a detail page with balances and links back to the list, so that I can move between my accounts.
- **Not scheduled** — Read balances and transactions
  `+bank-xs2a` `+spec 6.5.3` `+spec 6.5.4`
  As PSU, I want the TPP to show balances and recent transactions of an account, so that I can follow my spending in one place.

### See balances and transactions

`+bank-xs2a` `+ES column 13`

- **AIS reads** — Serve the balances of an account
  `+bank-xs2a` `+spec 6.5.3` `+spec 14.23`
  As PSU, I want the balances endpoint to return every balance type the Bank holds for my account, so that an app can show what I can actually spend.
- **AIS reads** — Serve the transaction list for a period
  `+bank-xs2a` `+spec 6.5.4` `+spec 14.25`
  As PSU, I want booked, pending or both over the dates I ask for, so that I see the bookings I am looking for and no others.
- **AIS reads** — Serve delta access on the transaction list
  `+bank-xs2a` `+spec 6.5.4`
  As TPP operator, I want entryReferenceFrom or deltaList to return only what changed since my last read, so that a daily sync does not download the whole history.
- **AIS reads** — Serve one transaction's details
  `+bank-xs2a` `+spec 6.5.5` `+spec 14.26`
  As PSU, I want the details of a booking I picked, including the structured remittance, so that I can tell what a line on my statement was.
- **AIS reads** — Page a long transaction list
  `+bank-xs2a` `+spec 4.15`
  As TPP operator, I want a next link when the report does not fit one response, so that a long history is read without guessing offsets.

## Come back later

`+ES column 14`

*For PSU, TPP operator, Bank product owner, Bank security officer.*

### Reuse the connection

`+tpp` `+oidc-provider` `+bank-xs2a` `+ES column 14`

- **MVP** — Refresh an expired access token
  `+tpp` `+oidc-provider` `+spec 13.5`
  As PSU, I want the TPP to renew its token silently while my consent is valid, so that I am not asked to authenticate on every visit.
- **MVP** — Count accesses without PSU presence
  `+bank-xs2a` `+spec 6`
  As Bank product owner, I want calls without PSU-IP-Address counted per account per day against frequencyPerDay and refused with ACCESS\_EXCEEDED, so that background polling stays within the consented frequency.
- **MVP** — Handle TOKEN\_EXPIRED and CONSENT\_EXPIRED
  `+tpp` `+spec 14.11`
  As TPP operator, I want the TPP to map the XS2A error codes to refresh, re-consent or alert, so that the PSU sees the right next step.
- **Access rules** — Count balance and transaction reads against the frequency
  `+bank-xs2a` `+spec 6`
  As Bank product owner, I want every account-data read without the PSU counted, not only the account list, so that the consented frequency means the same on all endpoints.
- **Access rules** — Limit the transaction history without a fresh SCA
  `+bank-xs2a` `+RTS art. 10`
  As Bank security officer, I want transactions older than ninety days served only when the PSU is authenticated, so that the exemption for account information stays within its limits.
- **Access rules** — Renew the consent when its access period ends
  `+bank-xs2a` `+RTS art. 10` `+spec 14.15`
  As PSU, I want my consent to expire at the end of the access period and to need a new SCA, so that no app keeps access indefinitely on one authentication.

### Revoke or renew the consent

`+bank-ciam` `+bank-xs2a` `+oidc-provider` `+tpp` `+ES column 14`

- **MVP** — Revoke a consent at the Bank
  `+bank-ciam` `+spec 14.15`
  As PSU, I want a page at the Bank listing my consents with a revoke button, so that I can cut off an app without contacting the app.
- **MVP** — Revoke the tokens of a revoked consent
  `+bank-xs2a` `+oidc-provider`
  As Bank product owner, I want the OIDC-provider to revoke the refresh and access tokens when a consent is revoked, expires or is deleted, so that no token outlives its consent.
- **MVP** — Delete a consent from the TPP
  `+tpp` `+bank-xs2a` `+spec 6.4`
  As PSU, I want to disconnect the Bank inside the TPP, so that the consent is terminated by the TPP at the bank.
- **MVP** — Ask the PSU to reconnect
  `+tpp`
  As PSU, I want the TPP to tell me when my consent has ended and offer to reconnect, so that I can renew before I need my data.
- **Hardening** — Initiate a payment with the same infrastructure
  `+tpp` `+bank-xs2a` `+oidc-provider` `+pis` `+spec 5.1.5`
  As PSU, I want to pay from a connected account with the same QR approval, so that the Bank is PISP compliant with one SCA journey.
- **Not scheduled** — Notify the TPP of consent status changes
  `+bank-xs2a` `+tpp`
  As TPP operator, I want the Bank to push consent status changes to a notification URI, so that the TPP does not learn about a revocation from a failed call.
- **Not scheduled** — Multilevel SCA for corporate accounts
  `+bank-xs2a` `+bank-ciam` `+spec 6.3.4`
  As PSU, I want a consent on a corporate account authorised by every required signer, so that company accounts can be connected too.

## The slice

What each delivery leaves untouched. An empty activity is a finding, not a fault — a first slice does not have to reach everything — but it is the question worth asking before the plan is agreed.

- **Walking skeleton** — nothing in Come back later.
- **MVP** — touches every activity.
- **Hardening** — nothing in Complete the connection, View my accounts.
- **AIS reads** — nothing in Enrol a device at the Bank, Connect the Bank from the TPP, Authenticate and approve at the Bank, Complete the connection, Come back later.
- **Consent models** — nothing in Enrol a device at the Bank, Authenticate and approve at the Bank, Complete the connection, View my accounts, Come back later.
- **Access rules** — nothing in Enrol a device at the Bank, Connect the Bank from the TPP, Authenticate and approve at the Bank, Complete the connection, View my accounts.

3 stories are below the line. That is the map saying what the plan currently leaves out, and it is worth reading before anybody adds another delivery.
