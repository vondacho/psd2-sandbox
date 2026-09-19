# GENERATED from docs/stories/pis-status.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 34f863f5064ea6fe26b631751f8f649d725ccb4ebef44e29db65cdbf2458878f
# generator: tools/sdlc/examplemap_to_feature.py
# 4 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-PIS-STATUS
Feature: Read the payment status
  As PISP
  I want to read the transaction status of the payment I initiated
  So that I can tell the merchant and my PSU whether the payment went through

  # Rule R-PST-01: A status read answers 200 even when the payment failed

  @MVP-01 @R-PST-01
  Scenario: A rejected payment's status is read successfully
    Given payment 1234-wertiq-983 in transactionStatus RJCT
    When the PISP reads GET /v1/payments/sepa-credit-transfers/1234-wertiq-983/status
    Then the response is 200 with transactionStatus RJCT

  # Rule R-PST-02: A finalised authorisation takes the payment to at least ACTC

  @WS-01 @R-PST-02
  Scenario: The approved example payment is technically accepted
    Given payment 1234-wertiq-983 of 123.50 EUR whose authorisation 123auth456 has scaStatus finalised
    When the PISP reads the status
    Then transactionStatus is ACTC

  # Rule R-PST-03: A payment whose SCA is not completed in time is rejected

  @MVP-01 @R-PST-03 @edge-case
  Scenario: An abandoned payment becomes RJCT
    Given payment 1234-wertiq-983 in transactionStatus RCVD with authorisation 123auth456 in scaStatus received
    And the SCA window has passed
    When the PISP reads the status
    Then transactionStatus is RJCT

  # Rule R-PST-04: A payment rejected for missing funds after acceptance says so

  @MVP-01 @R-PST-04 @edge-case
  Scenario: Missing funds found during processing
    Given payment 1234-wertiq-983 accepted with ACTC
    And core banking rejects it for insufficient funds
    When the PISP reads the status
    Then the response is 200 with transactionStatus RJCT
    And tppMessages contains code FUNDS_NOT_AVAILABLE
