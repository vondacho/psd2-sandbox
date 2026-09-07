# Generated from docs/design/examplemap/6-come-back-later/renew-the-consent-when-its-access-period-ends.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @rts-art-10 @spec-14.15 @access-rules @analysing
Feature: Renew the consent when its access period ends
  As PSU
  I want my consent to expire at the end of the access period and to need a new SCA
  So that no app keeps access indefinitely on one authentication

  @rts-art-10
  Rule: The access period is capped at the configured maximum, counted from the authorisation

    @nominal @access-rules
    Scenario: A consent authorised today expires at the cap
      Given the cap is 180 days and the consent is authorised on 2026-09-07
      When the consent becomes valid
      Then validUntil is 2027-03-06 at the latest

    @nominal @access-rules
    Scenario: A shorter validUntil asked by the TPP is kept
      Given the TPP asked validUntil 2026-12-05
      When the consent becomes valid
      Then validUntil is 2026-12-05

    @edge @access-rules
    Scenario: A longer validUntil is shortened, not refused
      Given the TPP asked validUntil 2027-09-06 and the cap is 180 days
      When the consent is created
      Then the answer is 201 and the stored validUntil is the capped date

    @edge @access-rules
    Scenario: The cap is a sandbox parameter
      Given the sandbox runs with a cap of 90 days
      When a consent is authorised on 2026-09-07
      Then validUntil is 2026-12-06 at the latest

  @spec-14.15
  Rule: When the period ends the consent expires by itself and serves nothing

    @nominal @access-rules
    Scenario: The consent expires at the end of its last day
      Given validUntil 2026-12-05
      When the clock passes 2026-12-06 00:00 Europe/Berlin
      Then the consent status is expired

    @error @access-rules
    Scenario: Reads after expiry are refused
      Given the expired consent
      When any account endpoint is called
      Then the answer is 401 CONSENT_EXPIRED

    @edge @access-rules
    Scenario: The last day still serves
      Given validUntil 2026-12-05 and the call at 2026-12-05 23:59 Europe/Berlin
      When the account list is read
      Then the answer is 200

    @nominal @access-rules
    Scenario: Expiry revokes the tokens of the consent
      Given the consent expired
      When the TPP refreshes its token
      Then the OIDC-provider answers invalid_grant

  Rule: Renewal is a new consent with a new SCA, never an extension of the old one

    @nominal @access-rules
    Scenario: A new consent is created and authorised
      Given the expired consent 123cons456
      When Anna reconnects and completes SCA on a new consent
      Then the new consent is valid with a fresh access period
      And 123cons456 stays expired

    @error @access-rules
    Scenario: The old consent cannot be extended
      Given the expired consent
      When a request tries to authorise it again
      Then the OIDC-provider refuses the scope, because the consent is not in status received

    @edge @access-rules
    Scenario: The PSU sees the renewal at the Bank
      Given the renewal completed
      When Anna opens her consent dashboard
      Then the old consent is listed as expired and the new one as valid
