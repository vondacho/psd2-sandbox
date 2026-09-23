# GENERATED from docs/stories/enforce-frequency.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 9a8f6fe3e6fdee8ab5ab037f5ab8775bf8b9a5cc77a421763adb4573cb868a8b
# generator: tools/sdlc/examplemap_to_feature.py
# 2 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-ENFORCE-FREQUENCY
Feature: Refuse reads beyond the agreed daily frequency
  As Account holder
  I want the bank to refuse a TPP that reads my data more often than I agreed
  So that the limit I confirmed means something

  # Rule R-FRQ-01: Unattended reads are counted per account and per PSU, against frequencyPerDay

  @MVP-01 @R-FRQ-01 @edge-case
  Scenario: The fifth unattended read of the day is refused on a consent of four
    Given a valid recurring consent with frequencyPerDay 4 on DE40100100103307118608
    And four reads already made today without the PSU present
    When the AISP reads the balances again without the PSU present
    Then the response is 429 with code ACCESS_EXCEEDED

  @MVP-01 @R-FRQ-01
  Scenario: A consent on two accounts counts each account separately
    Given a valid recurring consent with frequencyPerDay 2 on DE40100100103307118608 and DE02100100109307118603
    And two unattended reads already made today on DE40100100103307118608
    When the AISP reads the balances of DE02100100109307118603 without the PSU present
    Then the balances are returned

  # Rule R-FRQ-02: A read the PSU is present for does not consume the daily allowance

  @MVP-01 @R-FRQ-02 @edge-case
  Scenario: A PSU-initiated read on an exhausted allowance is served
    Given a valid consent with frequencyPerDay 4 whose allowance is used up today
    When the AISP reads the transactions with the PSU present
    Then the transactions are returned

  # Rule R-FRQ-03: The allowance resets, and a refusal never changes the consent

  @MVP-01 @R-FRQ-03
  Scenario: The allowance is available again the next day
    Given a valid consent with frequencyPerDay 4 refused with ACCESS_EXCEEDED yesterday
    When the AISP reads the balances today without the PSU present
    Then the balances are returned

  @MVP-01 @R-FRQ-03
  Scenario: A refused read leaves the consent valid
    Given a valid consent refused with ACCESS_EXCEEDED
    When the AISP reads the consent status
    Then consentStatus is valid
