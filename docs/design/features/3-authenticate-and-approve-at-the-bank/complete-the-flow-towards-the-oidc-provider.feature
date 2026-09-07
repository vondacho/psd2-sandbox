# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/complete-the-flow-towards-the-oidc-provider.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-ciam @oidc-provider @oidc-core @walking-skeleton @ready
Feature: Complete the flow towards the OIDC-provider
  As PSU
  I want the Bank to send me back to the OIDC-provider with an ID token that carries acr, amr and the consent id
  So that the OIDC-provider can issue the code for the TPP

  @oidc-core
  Rule: After the approval, the CIAM redirects the browser to the OIDC-provider's broker callback with a code, and the OIDC-provider redeems it over the back channel for an ID token

    @nominal @walking-skeleton
    Scenario: The redirect and the token
      Given session sess-1 approved for consent 123cons456, the OIDC-provider's broker request with state st1 and nonce nc1
      When the QR page polls approved
      Then the browser is redirected to https://oidc-provider.sandbox/broker/callback?code=c1&state=st1
      When the OIDC-provider posts code c1 to https://ciam.bank.sandbox/token with client oidc-broker
      Then the answer holds an ID token with iss https://ciam.bank.sandbox, aud oidc-broker, nonce nc1, exp in 5 minutes, sub the CIAM's pairwise subject for the OIDC-provider, acr urn:bank:psd2:sca, amr [pwd, hwk, face], consent_id 123cons456, consent_status authorised

    @edge @walking-skeleton
    Scenario: The amr reflects the methods used
      Given Anna used the PIN on the device
      When the ID token is issued
      Then amr is [pwd, hwk, pin]

    @error @mvp
    Scenario: The code is single-use
      Given the OIDC-provider redeemed c1
      When the OIDC-provider posts c1 again
      Then the CIAM answers 400 invalid_grant

    @error @mvp
    Scenario: The code expires after 60 seconds
      Given c1 issued at 09:13:30
      When the OIDC-provider redeems it at 09:14:35
      Then the CIAM answers 400 invalid_grant

    @error @mvp
    Scenario: A wrong client credential is refused
      Given a token request with a wrong secret for oidc-broker
      When the CIAM handles it
      Then the answer is 401 invalid_client

    @nominal @walking-skeleton
    Scenario: The browser never sees the ID token
      Given the whole flow
      When every browser request is inspected
      Then no ID token appears in a URL, a fragment or a cookie

  @security
  Rule: An ID token is produced only for a session whose challenge is approved

    @error @mvp
    Scenario: A refused session redirects with access_denied and no token
      Given session sess-1 refused
      When Anna clicks 'Back to TPP App'
      Then the browser is redirected to https://oidc-provider.sandbox/broker/callback?error=access_denied&state=st1
      And no code is issued by the CIAM

    @error @mvp
    Scenario: A session in step approved whose challenge is not approved yields no token
      Given an inconsistent session (step approved, challenge pending)
      When the OIDC-provider redeems its code
      Then the CIAM answers 400 invalid_grant and logs the inconsistency

    @error @mvp
    Scenario: A code cannot be minted for a session that never finished the first factor
      Given session sess-9 in step identified
      When the callback URL for sess-9 is forged with a code
      Then the CIAM answers invalid_grant for that code

  Rule: The session is completed once, and the consent id in the token is the session's subject

    @error @mvp
    Scenario: A second callback for the same session is refused
      Given sess-1 completed
      When the browser opens the CIAM's approved redirect again
      Then the CIAM shows 'This request was already completed'

    @nominal @walking-skeleton
    Scenario: The consent id cannot be swapped
      Given sess-1 for 123cons456
      When the ID token is issued
      Then consent_id is 123cons456 and nothing in the request could change it

    @nominal @walking-skeleton
    Scenario: The session records completion
      Given the token was issued at 09:13:40Z
      When sess-1 is read
      Then its step is completed and completedAt is 09:13:40Z
