# GENERATED from docs/stories/consent-dedicated.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 810c71eadee542ae6b5fa0a8122b80ad8377f0889b9cf68572fb0de0a12b8e24
# generator: tools/sdlc/examplemap_to_feature.py
# 7 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-CONSENT-DEDICATED
Feature: Request a consent on dedicated accounts
  As AISP
  I want to ask for access to named accounts, with the access types, validity and daily frequency I need
  So that my PSU is asked to approve exactly the access my service uses

  # Rule R-CNS-01: Every access list used names at least one account

  @WS-01 @R-CNS-01
  Scenario: Balances and transactions on one IBAN are accepted
    Given access.balances = [DE40100100103307118608]
    And access.transactions = [DE40100100103307118608]
    And recurringIndicator true, validUntil 2017-11-01, frequencyPerDay 4
    When the AISP posts the consent
    Then the response is 201 Created with consentStatus received
    And the response carries a consentId and a Location header

  @MVP-01 @R-CNS-01 @edge-case
  Scenario: A named balances list next to an empty transactions list is refused
    Given access.balances = [DE40100100103307118608]
    And access.transactions = []
    When the AISP posts the consent
    Then no consent resource is created

  # Rule R-CNS-02: A balances or transactions access also grants the account list

  @MVP-01 @R-CNS-02
  Scenario: Transactions access alone shows the account in the list
    Given a valid consent with access.transactions = [DE40100100103307118608] and no access.accounts
    When the AISP reads GET /v1/accounts
    Then the list contains the account DE40100100103307118608

  # Rule R-CNS-03: frequencyPerDay is at least 1 and at most 4 unless bilaterally agreed

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

  # Rule R-CNS-05: validUntil may be shortened by the bank; 9999-12-31 asks for the maximum

  @MVP-01 @R-CNS-05
  Scenario: A request for the maximum validity shows the bank's own end date
    Given a recurring consent request with validUntil 9999-12-31
    When the consent is authorised and the AISP reads GET /v1/consents/{consentId}
    Then validUntil is the bank's maximum end date, not 9999-12-31

  # Rule R-CNS-06: Authorising a new recurring consent ends the former recurring consent of the same TPP and PSU

  @MVP-01 @R-CNS-06
  Scenario: The second recurring consent replaces the first
    Given consent A, recurring and valid, for PSU PSU-1234 and TPP PSDES-BDE-3DFD21
    And consent B, recurring, for the same PSU and TPP
    When the PSU authorises consent B
    Then consent B is valid
    And account reads with consent A are refused

  @MVP-01 @R-CNS-06 @edge-case
  Scenario: A one-off consent leaves the recurring consent alone
    Given consent A, recurring and valid, for PSU PSU-1234 and TPP PSDES-BDE-3DFD21
    And consent C, one-off, for the same PSU and TPP
    When the PSU authorises consent C
    Then consent A is still valid

  # Rule R-CNS-07: A combined AIS/PIS session is refused while sessions are not offered

  @MVP-01 @R-CNS-07 @edge-case
  Scenario: combinedServiceIndicator true is refused
    Given a consent request with combinedServiceIndicator true
    When the AISP posts the consent
    Then the response is 400 with code SESSIONS_NOT_SUPPORTED
