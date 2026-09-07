# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/expire-the-previous-recurring-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.3.1.1 @mvp @analysing
Feature: Expire the previous recurring consent
  As PSU
  I want an older recurring consent from the same TPP to expire when the new one is authorised
  So that I never have two live consents for the same app

  @spec-6.3.1.1
  Rule: When a new recurring consent of the same TPP for the same PSU becomes valid, the former valid recurring consent is terminated

    @nominal @mvp
    Scenario: The old consent is terminated the moment the new one turns valid
      Given consent 111cons222 of the TPP for Anna is valid until 2026-10-01
      And consent 123cons456 of the TPP for Anna is received and Anna completes SCA
      When 123cons456 becomes valid
      Then 111cons222 has status terminatedByTpp
      And GET /v1/accounts with Consent-ID 111cons222 answers 401 CONSENT_INVALID
      And the tokens of 111cons222 are revoked at the OIDC-provider

    @edge @mvp
    Scenario: A new consent that is rejected leaves the old one untouched
      Given 111cons222 is valid and 123cons456 is received
      When Anna denies the challenge for 123cons456
      Then 123cons456 is rejected and 111cons222 is still valid

    @edge @mvp
    Scenario: While the new consent is only received, both exist
      Given 111cons222 is valid
      When 123cons456 is created and not yet authorised
      Then 111cons222 is still valid and 123cons456 is received

    @edge @mvp
    Scenario: The PSU is only known after login, so replacement is decided at that moment
      Given 111cons222 belongs to Anna and 123cons456 was created without PSU-ID
      When Ben logs in and authorises 123cons456
      Then 123cons456 belongs to Ben and 111cons222 of Anna is untouched

  Rule: Only consents of the same TPP and the same PSU are affected

    @nominal @mvp
    Scenario: C's consent for Anna survives the TPP's new consent
      Given consent 333cons444 of C for Anna is valid
      When the TPP's 123cons456 for Anna becomes valid
      Then 333cons444 is still valid

    @nominal @mvp
    Scenario: The TPP's consent for Ben survives the TPP's new consent for Anna
      Given consent 555cons666 of the TPP for Ben is valid
      When the TPP's 123cons456 for Anna becomes valid
      Then 555cons666 is still valid

    @nominal @mvp
    Scenario: Two valid recurring consents of the TPP for Anna never coexist
      Given the TPP's 123cons456 for Anna became valid
      When consent management lists the TPP's valid consents for Anna
      Then exactly one is returned

  Rule: One-off consents neither replace nor are replaced

    @edge @mvp
    Scenario: A new one-off consent leaves the recurring one valid
      Given 111cons222 recurring is valid
      When a one-off consent 777cons888 of the TPP for Anna becomes valid
      Then 111cons222 is still valid

    @edge @mvp
    Scenario: A new recurring consent leaves an unused one-off consent valid
      Given one-off consent 777cons888 of the TPP for Anna is valid and unused
      When recurring 123cons456 becomes valid
      Then 777cons888 is still valid

  Rule: The TPP learns the replacement from the status of the old consent, and swaps the connection's consent

    @nominal @mvp
    Scenario: The TPP stores the new consent on the same connection
      Given Anna's connection to the Bank held 111cons222
      When the reconnect with 123cons456 completes
      Then the connection holds 123cons456, the token set of 123cons456, and state connected

    @edge @mvp
    Scenario: The TPP revokes its old refresh token at the OIDC-provider when swapping
      Given the connection swapped from 111cons222 to 123cons456
      When the TPP finishes the swap
      Then the TPP calls POST /revoke at the OIDC-provider for the refresh token of 111cons222

    @nominal @mvp
    Scenario: GET status on the old consent answers terminatedByTpp
      Given 111cons222 was replaced
      When the TPP calls GET /v1/consents/111cons222/status
      Then the answer is terminatedByTpp
