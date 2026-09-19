# GENERATED from docs/stories/pis-initiate-sct.examplemap — do not edit; change the example map and regenerate.
# source-sha256: c8f135f7c997566eb61d5394b725951855365d3ca4fcb57f34e4e8da5b4080d3
# generator: tools/sdlc/examplemap_to_feature.py
# 6 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-PIS-INITIATE-SCT
Feature: Initiate a SEPA credit transfer
  As PISP
  I want to submit a SEPA credit transfer for my PSU and get a payment resource back
  So that my PSU can pay a merchant straight from the bank account

  # Rule R-PIS-01: A valid SEPA credit transfer creates a payment resource in status RCVD with steering links

  @WS-01 @R-PIS-01
  Scenario: The spec's example payment is accepted
    Given instructedAmount 123.50 EUR from debtorAccount DE40100100103307118608
    And creditorName Merchant123 and creditorAccount DE02100100109307118603
    And remittanceInformationUnstructured Ref Number Merchant and PSU-IP-Address 192.168.8.78
    When the PISP posts POST /v1/payments/sepa-credit-transfers
    Then the response is 201 Created with transactionStatus RCVD and a paymentId
    And the header ASPSP-SCA-Approach is REDIRECT
    And _links contains scaRedirect, self, status and scaStatus

  # Rule R-PIS-02: PSU-IP-Address is mandatory on a payment initiation

  @MVP-01 @R-PIS-02 @edge-case
  Scenario: A payment without PSU-IP-Address is refused
    Given the example payment of 123.50 EUR without a PSU-IP-Address header
    When the PISP posts it
    Then the response is 400 with code FORMAT_ERROR
    And no payment resource is created

  # Rule R-PIS-03: Only payment products the bank offers are accepted

  @MVP-01 @R-PIS-03 @edge-case
  Scenario: An unsupported product is unknown
    Given the bank offers sepa-credit-transfers only
    When the PISP posts the example payment to /v1/payments/target-2-payments
    Then the response is 404 with code PRODUCT_UNKNOWN

  # Rule R-PIS-04: Later calls must name the product the payment was created under

  @MVP-01 @R-PIS-04 @edge-case
  Scenario: The status under a different product is not served
    Given payment 1234-wertiq-983 created under sepa-credit-transfers
    When the PISP reads GET /v1/payments/instant-sepa-credit-transfers/1234-wertiq-983/status
    Then no status is returned

  # Rule R-PIS-05: The PSU approves exactly the amount and payee that were submitted

  @WS-01 @R-PIS-05
  Scenario: The SCA screen shows amount and payee
    Given payment 1234-wertiq-983 of 123.50 EUR to Merchant123, DE02100100109307118603
    When the PSU opens the SCA screen in the bank app
    Then the screen shows 123.50 EUR, Merchant123 and DE02100100109307118603
