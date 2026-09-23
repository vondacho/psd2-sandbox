# GENERATED from docs/stories/consent-dedicated.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 9aa330e8eeab24158a13dbf8b0cf62dbeff8be23fe8b50c442ab12ea8618d4b4
# generator: tools/sdlc/examplemap_to_feature.py
# 7 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-CONSENT-DEDICATED
Feature: Request a consent on dedicated accounts
  As AISP
  I want to ask for access to named accounts, with the access types, validity and daily frequency I need
  So that my PSU is asked to confirm exactly the access my service uses

  # Rule R-CNS-01: Every access list used names at least one account

  @WS-01 @R-CNS-01
  Scenario: Balances and transactions on one IBAN are accepted
    Given access.balances = [DE40100100103307118608]
    And access.transactions = [DE40100100103307118608]
    And recurringIndicator true, validUntil 2026-11-01, frequencyPerDay 4
    When the AISP posts the consent
    Then the response is 201 Created with consentStatus received
    And the response carries a consentId and a Location header

  @MVP-01 @R-CNS-01 @edge-case
  Scenario: A named balances list next to an empty transactions list is refused
    Given access.balances = [DE40100100103307118608]
    And access.transactions = []
    When the AISP posts the consent
    Then no consent resource is created

  # Rule R-CNS-03: frequencyPerDay is at least 1, and at most 4 unless bilaterally agreed

  @WS-01 @R-CNS-03
  Scenario: Four reads a day are accepted
    Given a recurring consent request with frequencyPerDay 4
    When the AISP posts the consent
    Then the response is 201 Created

  @MVP-01 @R-CNS-03 @edge-case
  Scenario: Five reads a day are refused without a bilateral agreement
    Given a recurring consent request with frequencyPerDay 5
    And no bilateral agreement with the TPP
    When the AISP posts the consent
    Then no consent resource is created

  @MVP-01 @R-CNS-03 @edge-case
  Scenario: Zero reads a day are refused
    Given a consent request with frequencyPerDay 0
    When the AISP posts the consent
    Then no consent resource is created

  # Rule R-CNS-04: A one-off consent reads once

  @MVP-01 @R-CNS-04
  Scenario: A one-off consent with frequencyPerDay 1 is accepted
    Given recurringIndicator false and frequencyPerDay 1
    When the AISP posts the consent
    Then the response is 201 Created

  # Rule R-CNS-05: validUntil is what the bank grants; 9999-12-31 asks for the maximum

  @MVP-01 @R-CNS-05
  Scenario: A request for the maximum validity shows the bank's own end date
    Given a recurring consent request with validUntil 9999-12-31
    When the consent is authorised and the AISP reads GET /v1/consents/123cons456
    Then validUntil is the bank's maximum end date, not 9999-12-31

  @MVP-01 @R-CNS-05 @edge-case
  Scenario: The confirmation panel shows the granted date, not the requested one
    Given a consent requesting validUntil 9999-12-31 which the bank shortens to 2027-03-31
    When the consent confirmation panel is presented on the enrolled device
    Then the panel shows 2027-03-31

  # Rule R-CNS-07: A combined AIS and PIS session is refused while sessions are not offered

  @MVP-01 @R-CNS-07 @edge-case
  Scenario: combinedServiceIndicator true is refused
    Given a consent request with combinedServiceIndicator true
    When the AISP posts the consent
    Then the response is 400 with code SESSIONS_NOT_SUPPORTED
