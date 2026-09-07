# Generated from docs/design/examplemap/5-view-my-accounts/validate-token-and-consent-on-every-call.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @security @spec-13.6 @rfc-8705 @walking-skeleton @ready
Feature: Validate token and consent on every call
  As Bank security officer
  I want the JWT signature, audience, expiry, certificate binding and the Consent-ID match checked before any data leaves
  So that a token is necessary but never sufficient

  @spec-13.6
  Rule: The JWT must be signed by the OIDC-provider, issued by the OIDC-provider, addressed to the Bank's API, and within its validity

    @nominal @walking-skeleton
    Scenario: A valid token passes
      Given a token signed with the OIDC-provider's kid oidc-2026, iss https://oidc-provider.sandbox, aud https://api.bank.sandbox/psd2, exp in 5 minutes
      When GET /v1/accounts is called
      Then the token checks pass

    @error @walking-skeleton
    Scenario: A bad signature
      Given a token whose payload was altered
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: alg none
      Given a token with header alg none
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: An unknown kid
      Given a token with kid unknown
      When the call is made
      Then the Bank refetches the JWKS once, then answers 401 TOKEN_INVALID

    @error @walking-skeleton
    Scenario: Expired
      Given a token with exp one second ago
      When the call is made
      Then the answer is 401 TOKEN_EXPIRED

    @error @mvp
    Scenario: Not yet valid
      Given a token with nbf one minute ahead
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: Wrong audience
      Given a token with aud https://api.bank-c.sandbox/psd2
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: Wrong issuer
      Given a token with iss https://evil.example signed with a key of evil.example
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @walking-skeleton
    Scenario: No Authorization header
      Given no Authorization header
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: Token in the query string
      Given GET /v1/accounts?access_token=eyJ…
      When the call is made
      Then the answer is 401 TOKEN_INVALID and the token is not accepted from the URL

  @rfc-8705
  Rule: The token's certificate thumbprint and client id must match the presented certificate

    @nominal @walking-skeleton
    Scenario: The TPP's token over the TPP's certificate
      Given cnf.x5t#S256 equals the thumbprint of the TPP's QWAC and client_id equals its organizationIdentifier
      When the call is made
      Then the binding checks pass

    @error @walking-skeleton
    Scenario: The TPP's token over C's certificate
      Given the TPP's token presented over a TLS connection with C's QWAC
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @edge @mvp
    Scenario: The TPP's old token after a certificate rotation
      Given the TPP's token bound to the old QWAC and the TPP now presents the new QWAC
      When the call is made
      Then the answer is 401 TOKEN_INVALID and the TPP must refresh with the new certificate

    @error @mvp
    Scenario: A token without cnf
      Given a token with no cnf claim
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: A token whose client_id is not the certificate's organizationIdentifier
      Given a token with client_id PSDDE-BAFIN-654321 bound (impossibly) to the TPP's thumbprint
      When the call is made
      Then the answer is 401 TOKEN_INVALID

  @spec-13.4
  Rule: The AIS scope of the token must name the Consent-ID of the call

    @nominal @walking-skeleton
    Scenario: Matching scope and header
      Given scope AIS:123cons456 and Consent-ID 123cons456
      When the call is made
      Then the scope check passes

    @error @walking-skeleton
    Scenario: Mismatch
      Given scope AIS:123cons456 and Consent-ID 111cons222
      When the call is made
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: A PIS token on an AIS endpoint
      Given scope PIS:pay001 and Consent-ID 123cons456
      When GET /v1/accounts is called
      Then the answer is 401 TOKEN_INVALID

  @spec-6
  Rule: The consent must exist for this TPP, be valid and within validUntil; the checks run in a fixed order and only the first failure is reported

    @nominal @mvp
    Scenario: The order: certificate, signature, token, binding, scope, consent
      Given a call with a bad token for an unknown consent
      When it is refused
      Then the answer is 401 TOKEN_INVALID, not CONSENT_UNKNOWN

    @error @walking-skeleton
    Scenario: A revoked consent with a perfectly valid token
      Given consent 123cons456 revoked one second ago and a valid token
      When the call is made
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Past validUntil with a valid token
      Given validUntil 2026-12-05 and the call on 2026-12-06 00:00:01 Europe/Berlin
      When the call is made
      Then the answer is 401 CONSENT_EXPIRED

    @edge @mvp
    Scenario: On validUntil itself the consent serves
      Given validUntil 2026-12-05 and the call on 2026-12-05 23:59:00 Europe/Berlin
      When the call is made
      Then the answer is 200

    @nominal @walking-skeleton
    Scenario: Every endpoint runs the same chain
      Given GET /v1/accounts, GET /v1/accounts/{id}, GET /v1/accounts/{id}/balances, GET /v1/accounts/{id}/transactions
      When each is called with the TPP's token over C's certificate
      Then each answers 401 TOKEN_INVALID
