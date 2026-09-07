# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/redirect-with-state-and-pkce.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @security @spec-13.1 @rfc-7636 @walking-skeleton @ready
Feature: Redirect with state and PKCE
  As PSU
  I want the TPP to send me to the OIDC-provider with a one-time state bound to my session and an S256 code challenge
  So that nobody can inject a code into my session

  @spec-7.6.1
  Rule: state is 32 random bytes, base64url, stored with the session, the consent and a 10-minute expiry

    @nominal @walking-skeleton
    Scenario: A fresh state is created for each authorization
      Given Anna's session sess-anna and consent 123cons456
      When the TPP starts the authorization
      Then an AuthorizationAttempt exists with a 43-character base64url state, userSessionId sess-anna, consentId 123cons456, startedAt now, outcome pending

    @edge @mvp
    Scenario: Two authorizations in the same session get two states
      Given Anna connects the Bank and Bank C in two tabs
      When both authorizations start
      Then two attempts exist with different states

    @nominal @walking-skeleton
    Scenario: The state is not derivable from the session id or the consent id
      Given 1000 generated states
      When they are compared
      Then no two are equal and none contains the session id or consent id

  @rfc-7636
  Rule: The PKCE verifier is 43 to 128 unreserved characters and the challenge is BASE64URL(SHA-256(verifier)) with method S256

    @nominal @walking-skeleton
    Scenario: The RFC 7636 test vector
      Given the verifier dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
      When the challenge is computed
      Then it is E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM

    @nominal @walking-skeleton
    Scenario: A generated verifier has 64 characters from the unreserved set
      Given the TPP generates a verifier
      When it is inspected
      Then it has 64 characters, all in [A-Za-z0-9-._~]

    @nominal @walking-skeleton
    Scenario: The verifier is stored server-side only
      Given the authorization started
      When the response to the browser is inspected
      Then neither the redirect URL nor any cookie contains the verifier

  @spec-13.1
  Rule: The authorization URL carries exactly the parameters of the code flow with PKCE

    @nominal @walking-skeleton
    Scenario: The redirect for consent 123cons456
      Given client PSDDE-BAFIN-123456, consent 123cons456, state S8NJ7…, challenge 5c3055…
      When the TPP answers the browser
      Then it is a 302 to https://oidc-provider.sandbox/authorize with response_type=code, client_id=PSDDE-BAFIN-123456, scope=AIS:123cons456 offline_access, state=S8NJ7…, redirect_uri=https://tpp.sandbox/xs2a/callback/bank, code_challenge=5c3055…, code_challenge_method=S256

    @edge @walking-skeleton
    Scenario: The scope is URL-encoded
      Given scope AIS:123cons456 offline_access
      When the URL is built
      Then the query contains scope=AIS%3A123cons456%20offline_access

    @nominal @walking-skeleton
    Scenario: No client secret is ever in the URL
      Given the redirect URL
      When it is inspected
      Then it has no client_secret, no code_verifier and no bearer token

    @nominal @walking-skeleton
    Scenario: The redirect_uri equals the TPP-Redirect-URI sent to the Bank
      Given TPP-Redirect-URI https://tpp.sandbox/xs2a/callback/bank was sent at consent creation
      When the URL is built
      Then redirect_uri is https://tpp.sandbox/xs2a/callback/bank

  Rule: The attempt is single-use and expires

    @edge @mvp
    Scenario: An attempt older than ten minutes is expired
      Given an attempt started at 09:00 with no callback
      When the clock reaches 09:10
      Then the attempt outcome is expired
      And a callback with its state is refused

    @error @walking-skeleton
    Scenario: A consumed attempt cannot be reused
      Given an attempt whose callback was processed
      When a second callback with the same state arrives
      Then it is refused

    @edge @mvp
    Scenario: Starting over creates a new attempt and expires the pending one
      Given an attempt is pending for 123cons456
      When Anna clicks 'Start over'
      Then a new attempt with a new state exists and the old one is expired
