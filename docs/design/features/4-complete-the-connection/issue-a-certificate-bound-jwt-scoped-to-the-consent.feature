# Generated from docs/design/examplemap/4-complete-the-connection/issue-a-certificate-bound-jwt-scoped-to-the-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@oidc-provider @security @spec-13.4 @rfc-8705 @walking-skeleton @ready
Feature: Issue a certificate-bound JWT scoped to the consent
  As Bank security officer
  I want an access token with aud, scope AIS:<consentId>, cnf thumbprint and a short lifetime
  So that a leaked token cannot be used without the TPP's private key

  @spec-13.4
  Rule: The access token is an ES256 JWT with issuer, pairwise subject, the Bank's API as audience, the client id, the scope, the consent id, acr, amr, the certificate thumbprint, iat, exp and jti

    @nominal @walking-skeleton
    Scenario: The claims of the nominal token
      Given the exchange for grant g1 at 2026-09-06T09:13:20Z (1757150000) by the TPP with QWAC thumbprint bwcK0…
      When the OIDC-provider issues the access token
      Then the header has alg ES256 and kid oidc-2026
      And the claims are iss https://oidc-provider.sandbox, sub 8f6c2b1e-…, aud https://api.bank.sandbox/psd2, client_id PSDDE-BAFIN-123456, scope 'AIS:123cons456 offline_access', consent_id 123cons456, acr urn:bank:psd2:sca, amr [pwd, hwk], cnf {x5t#S256: bwcK0…}, iat 1757150000, exp 1757150600, jti unique

    @nominal @walking-skeleton
    Scenario: The token verifies against the OIDC-provider's JWKS
      Given the token
      When the Bank fetches https://oidc-provider.sandbox/jwks and verifies with kid oidc-2026
      Then the signature is valid

    @nominal @walking-skeleton
    Scenario: Two tokens never share a jti
      Given 1000 tokens
      When their jti values are compared
      Then all are distinct

    @nominal @walking-skeleton
    Scenario: The token carries no bank PSU-ID and no IBAN
      Given the token
      When its claims are listed
      Then there is no psu_id, iban or account claim, and sub is not anna.mueller

  @spec-13.4
  Rule: The token lives at most ten minutes

    @nominal @walking-skeleton
    Scenario: exp is iat plus 600
      Given iat 1757150000
      When the token is issued
      Then exp is 1757150600 and expires_in is 600

    @edge @mvp
    Scenario: A configured lifetime above ten minutes is capped
      Given the OIDC-provider configured with an access token lifetime of 3600
      When the OIDC-provider starts
      Then it refuses the configuration with 'access token lifetime must be at most 600'

    @edge @mvp
    Scenario: The Bank refuses the token one second after exp
      Given exp 1757150600
      When GET /v1/accounts is called at 1757150601
      Then the answer is 401 TOKEN_EXPIRED

  @rfc-8705
  Rule: The cnf thumbprint is the SHA-256 of the DER certificate presented at the token endpoint, base64url without padding

    @nominal @walking-skeleton
    Scenario: The thumbprint of the TPP's QWAC
      Given the TPP's QWAC DER bytes
      When the thumbprint is computed
      Then it equals base64url(SHA-256(DER)) without '=' padding and matches cnf.x5t#S256

    @edge @mvp
    Scenario: A renewed QWAC gives a different thumbprint
      Given the TPP exchanges a code with its new QWAC
      When the token is issued
      Then cnf.x5t#S256 is the thumbprint of the new certificate

    @nominal @walking-skeleton
    Scenario: Metadata advertises certificate-bound tokens
      Given the OIDC-provider's metadata
      When it is read
      Then tls_client_certificate_bound_access_tokens is true

  @spec-13.5
  Rule: The scope of the token is the scope that was authorised, and a refresh token is issued for recurring access

    @nominal @walking-skeleton
    Scenario: offline_access requested: refresh token issued
      Given scope 'AIS:123cons456 offline_access' authorised
      When the tokens are issued
      Then the response includes a refresh_token and scope 'AIS:123cons456 offline_access'

    @edge @mvp
    Scenario: Recurring consent without offline_access: refresh token still issued
      Given scope 'AIS:123cons456' authorised and the consent is recurring
      When the tokens are issued
      Then the response includes a refresh_token

    @edge @mvp
    Scenario: One-off consent without offline_access: no refresh token
      Given scope 'AIS:777cons888' for a one-off consent
      When the tokens are issued
      Then the response has no refresh_token

    @nominal @walking-skeleton
    Scenario: The token scope never widens
      Given scope 'AIS:123cons456' authorised
      When the token is issued
      Then scope contains no PIS entry and no second AIS entry

  Rule: The OIDC-provider's signing key rotates without breaking verification

    @edge @mvp
    Scenario: The old kid stays in the JWKS for 24 hours
      Given the OIDC-provider rotated from kid oidc-2026 to oidc-2026b at 10:00
      When the Bank verifies a token signed with oidc-2026 at 12:00
      Then the JWKS still holds oidc-2026 and the verification succeeds

    @nominal @mvp
    Scenario: New tokens use the new kid
      Given the rotation
      When a token is issued at 10:01
      Then its header kid is oidc-2026b
