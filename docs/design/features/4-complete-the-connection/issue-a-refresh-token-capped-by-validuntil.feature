# Generated from docs/design/examplemap/4-complete-the-connection/issue-a-refresh-token-capped-by-validuntil.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@oidc-provider @spec-13.5 @mvp @analysing
Feature: Issue a refresh token capped by validUntil
  As PSU
  I want the TPP to keep access for the life of my consent without asking me again
  So that I authenticate once per consent, not per visit

  @spec-13.5
  Rule: The refresh token expires at the end of the consent's validUntil day in the Bank's time zone, or after 180 days, whichever is first

    @nominal @mvp
    Scenario: validUntil 2026-12-05
      Given consent 123cons456 with validUntil 2026-12-05
      When the refresh token is issued on 2026-09-06
      Then it expires at 2026-12-05T23:59:59+01:00

    @edge @mvp
    Scenario: validUntil today
      Given a consent with validUntil 2026-09-06
      When the refresh token is issued at 2026-09-06T09:13:20Z
      Then it expires at 2026-09-06T23:59:59+02:00

    @edge @mvp
    Scenario: validUntil shortened by the bank
      Given the TPP asked 2027-09-06 and the bank stored 2027-03-05
      When the refresh token is issued
      Then it expires at 2027-03-05T23:59:59+01:00

    @edge @mvp
    Scenario: The 180-day cap
      Given a bank configured with 365 days and validUntil 2027-09-06
      When the refresh token is issued on 2026-09-06
      Then it expires at 2027-03-05T23:59:59+01:00

    @nominal @mvp
    Scenario: The refresh token is opaque
      Given the refresh token tGzv3JokF0XG5Qx2TlKWIA
      When it is inspected
      Then it is not a JWT and reveals nothing about the consent

  @spec-13.5 @rfc-8705
  Rule: A refresh over mTLS with the same certificate, while the consent is valid, yields a new access token with the same scope and binding and a rotated refresh token

    @nominal @mvp
    Scenario: The nominal refresh
      Given grant g1 with refresh token R1 and consent 123cons456 valid
      When the TPP posts grant_type=refresh_token, refresh_token=R1, client_id=PSDDE-BAFIN-123456 with its QWAC
      Then the OIDC-provider asks consent management and gets status valid
      And the answer has a new access token with the same scope, sub and cnf, and a new refresh token R2
      And R1 is invalid from now on

    @error @mvp
    Scenario: A revoked consent
      Given consent 123cons456 revokedByPsu
      When the TPP refreshes with R1
      Then the OIDC-provider answers 400 invalid_grant with error_description 'consent no longer valid'
      And the TPP marks the connection needsReconsent

    @error @mvp
    Scenario: An expired consent
      Given consent 123cons456 expired
      When the TPP refreshes
      Then the OIDC-provider answers 400 invalid_grant

    @error @mvp
    Scenario: A refresh after the refresh token's own expiry
      Given R1 expired at 2026-12-05T23:59:59+01:00
      When the TPP refreshes on 2026-12-06
      Then the OIDC-provider answers 400 invalid_grant

    @edge @mvp
    Scenario: A refresh with another certificate of the same client
      Given the TPP's new QWAC bound as second certificate
      When the TPP refreshes R1 with the new QWAC
      Then the OIDC-provider issues an access token bound to the new certificate's thumbprint

    @error @mvp
    Scenario: A refresh with C's certificate
      Given R1 of the TPP
      When C posts it with its QWAC
      Then the OIDC-provider answers 401 invalid_client

    @error @mvp
    Scenario: A refresh without mTLS
      Given R1
      When it is posted without client certificate
      Then the OIDC-provider answers 401 invalid_client

    @error @mvp
    Scenario: A rotated refresh token used again revokes the grant
      Given R1 was rotated to R2
      When R1 is posted again
      Then the OIDC-provider answers 400 invalid_grant and revokes R2 and every access token of g1
      And the event is logged as a refresh-token replay

  @spec-13.5
  Rule: A one-off consent gets no refresh token

    @nominal @mvp
    Scenario: recurringIndicator false
      Given consent 777cons888 with recurringIndicator false
      When the tokens are issued
      Then the response has no refresh_token

    @error @mvp
    Scenario: A refresh attempt for a one-off consent
      Given no refresh token exists for 777cons888
      When the TPP posts grant_type=refresh_token with any value
      Then the OIDC-provider answers 400 invalid_grant
