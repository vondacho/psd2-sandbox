# GENERATED from docs/stories/pis-status.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 7ad9d54346d00ef62f433a5bf2d8886e43335c8e937a0476206920d40102e1b1
# generator: tools/sdlc/examplemap_to_feature.py
# 2 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-PIS-STATUS
Feature: Read the payment status
  As PISP
  I want to read the ISO 20022 transaction status of the payment
  So that I can tell the merchant and the PSU what happened

  # Rule R-PST-01: The status is one of the ISO 20022 codes the specification lists

  @WS-01 @R-PST-01
  Scenario: A freshly created payment reports RCVD
    Given a payment initiation created one second ago
    When the PISP reads the payment status
    Then transactionStatus is RCVD

  @MVP-01 @R-PST-01
  Scenario: A payment accepted after technical validation reports ACTC
    Given a payment whose authorisation is finalised and which passed the bank's checks
    When the PISP reads the payment status
    Then transactionStatus is ACTC

  # Rule R-PST-02: Only the TPP that created the payment may read its status

  @MVP-01 @R-PST-02 @edge-case
  Scenario: Another TPP reading the status learns nothing about the payment
    Given payment 1234-wertiq-983 created by PSDES-BDE-3DFD21
    And a second TPP PSDFR-ACPR-12345 with the PISP role
    When the second TPP reads the status of 1234-wertiq-983
    Then the transaction status is not disclosed

  # Rule R-PST-03: A payment whose SCA window closes without confirmation is rejected

  @MVP-01 @R-PST-03 @edge-case
  Scenario: An unconfirmed payment reports RJCT after the window
    Given a payment whose PSU never confirmed on the enrolled device
    And an SCA window that has closed
    When the PISP reads the payment status
    Then transactionStatus is RJCT

  # Rule R-PST-04: A final status does not change again

  @MVP-01 @R-PST-04
  Scenario: A rejected payment stays rejected
    Given a payment at RJCT
    When the PISP reads the status an hour later
    Then transactionStatus is RJCT

  @MVP-01 @R-PST-04 @edge-case
  Scenario: A rejected payment cannot be authorised afterwards
    Given a payment at RJCT
    When an SCA result arrives for its authorisation
    Then the payment stays at RJCT
