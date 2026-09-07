# Generated from docs/design/examplemap/6-come-back-later/revoke-the-tokens-of-a-revoked-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @oidc-provider @mvp @ready
Feature: Revoke the tokens of a revoked consent
  As Bank product owner
  I want the OIDC-provider to revoke the refresh and access tokens when a consent is revoked, expires or is deleted
  So that no token outlives its consent

  Rule: Whenever a consent leaves the valid status, consent management tells the OIDC-provider, and the OIDC-provider revokes every token of the consent's grant

    @nominal @mvp
    Scenario: Revoked by the PSU
      Given grant g1 for 123cons456 with refresh token R1 and access token T1
      When the consent becomes revokedByPsu
      Then consent management posts /internal/tokens/revoke?consent_id=123cons456
      And the OIDC-provider marks g1 revoked; a refresh with R1 answers invalid_grant and introspection of T1 says active false

    @nominal @mvp
    Scenario: Expired at midnight
      Given validUntil 2026-12-05
      When the expiry job runs at 2026-12-06 00:00 Europe/Berlin
      Then the consent is expired and the revocation is posted to the OIDC-provider

    @nominal @mvp
    Scenario: Deleted by the TPP
      Given the TPP calls DELETE /v1/consents/123cons456
      When the consent becomes terminatedByTpp
      Then the revocation is posted to the OIDC-provider

    @nominal @mvp
    Scenario: Replaced by a new recurring consent
      Given 111cons222 replaced by 123cons456
      When 111cons222 becomes terminatedByTpp
      Then the revocation for 111cons222 is posted, and g2 of 123cons456 is untouched

    @edge @mvp
    Scenario: Rejected before any token
      Given consent 123cons456 rejected and no grant
      When the revocation is posted
      Then the OIDC-provider answers 204 and nothing changes

  Rule: Revocation is idempotent and resilient

    @edge @mvp
    Scenario: Posted twice
      Given g1 already revoked
      When the revocation is posted again
      Then the OIDC-provider answers 204

    @error @mvp
    Scenario: The OIDC-provider is down
      Given the OIDC-provider answers 503
      When the revocation is posted
      Then consent management queues it and retries with backoff 1, 2, 4, 8 minutes until 200 or 204
      And meanwhile the XS2A API already refuses the consent, so no data leaks

    @error @mvp
    Scenario: The internal endpoint needs the Bank's client credentials
      Given a revocation posted without credentials
      When the OIDC-provider handles it
      Then the answer is 401 and nothing is revoked

  @security
  Rule: A revoked grant is dead in every way

    @error @mvp
    Scenario: Refresh after revocation
      Given g1 revoked
      When the TPP refreshes with R1
      Then the OIDC-provider answers 400 invalid_grant

    @error @mvp
    Scenario: Access token still within exp after revocation
      Given T1 with 8 minutes left and the consent revoked
      When the TPP calls GET /v1/accounts with T1
      Then the answer is 401 CONSENT_INVALID within one second of the revocation

    @nominal @mvp
    Scenario: Introspection
      Given T1 after revocation
      When the Bank calls POST https://oidc-provider.sandbox/introspect with T1
      Then the answer is {active: false}

    @edge @mvp
    Scenario: A code not yet redeemed for the revoked consent
      Given an authorization code issued for 123cons456 seconds before the revocation
      When the TPP redeems it
      Then the OIDC-provider answers invalid_grant
