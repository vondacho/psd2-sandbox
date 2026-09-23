# GENERATED from docs/stories/consent-end.examplemap — do not edit; change the example map and regenerate.
# source-sha256: cd62772c91566b332371a8698e88d68fe9dcbe90636a81402ff20e9aa37b7edb
# generator: tools/sdlc/examplemap_to_feature.py
# 4 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-CONSENT-DELETE
Feature: Delete the consent
  As AISP
  I want to delete a consent my PSU no longer wants
  So that the access stops and my PSU sees that it stopped

  # Rule R-REV-01: A TPP deletion ends the consent and stops the access

  @WS-01 @R-REV-01
  Scenario: Deleting a valid consent returns 204 and ends it
    Given a valid consent 123cons456 created by PSDES-BDE-3DFD21
    When the AISP deletes /v1/consents/123cons456
    Then the response is 204 No Content
    And consentStatus is terminatedByTpp

  @MVP-01 @R-REV-01 @edge-case
  Scenario: Deleting a consent that is already terminated changes nothing
    Given a consent 123cons456 already at terminatedByTpp
    When the AISP deletes it again
    Then consentStatus is still terminatedByTpp

  # Rule R-REV-02: No read succeeds once the consent has ended, whichever way it ended

  @WS-01 @R-REV-02 @edge-case
  Scenario: A read after a TPP deletion is refused
    Given a consent at terminatedByTpp
    When the AISP reads GET /v1/accounts with that Consent-ID
    Then no account data is returned

  @MVP-01 @R-REV-02 @edge-case
  Scenario: A read on the next call after an ending at the gateway is refused
    Given a valid consent whose record was ended at Finologee one second ago
    When the AISP reads GET /v1/accounts with that Consent-ID
    Then no account data is returned

  # Rule R-REV-03: A consent ends by itself when its validity runs out

  @MVP-01 @R-REV-03
  Scenario: A consent is still usable on its validUntil date
    Given a valid consent with validUntil 2026-11-01
    When the AISP reads the balances on 2026-11-01
    Then the balances are returned

  @MVP-01 @R-REV-03 @edge-case
  Scenario: The same consent is refused the following day
    Given a consent with validUntil 2026-11-01
    When the AISP reads the balances on 2026-11-02
    Then the response is 401 with code CONSENT_EXPIRED
    And consentStatus is expired

  # Rule R-CNS-06: Authorising a new recurring consent ends the former one of the same TPP and PSU

  @MVP-01 @R-CNS-06
  Scenario: The second recurring consent replaces the first
    Given consent A, recurring and valid, for PSU-1234 and TPP PSDES-BDE-3DFD21
    And consent B, recurring, for the same PSU and the same TPP
    When the PSU confirms consent B on the enrolled device
    Then consent B is valid
    And account reads with consent A are refused

  @MVP-01 @R-CNS-06 @edge-case
  Scenario: A one-off consent leaves the recurring consent alone
    Given consent A, recurring and valid, for PSU-1234 and TPP PSDES-BDE-3DFD21
    And consent C, one-off, for the same PSU and the same TPP
    When the PSU confirms consent C on the enrolled device
    Then consent A is still valid
