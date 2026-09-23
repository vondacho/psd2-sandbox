# GENERATED from docs/stories/pis-initiate-sct.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 134d2b20ba9102004dd1c05e8aa45cf3f55ea000ce905de8354b194d1b6a9213
# generator: tools/sdlc/examplemap_to_feature.py
# 4 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-PIS-INITIATE-SCT
Feature: Initiate a SEPA credit transfer
  As PISP
  I want to submit a single SEPA credit transfer for my PSU
  So that my PSU can pay from their bank account without entering card details

  # Rule R-PIS-01: An accepted initiation becomes a resource with transactionStatus RCVD

  @WS-01 @R-PIS-01
  Scenario: A single credit transfer of 123 EUR is accepted
    Given instructedAmount 123.50 EUR
    And debtorAccount DE40100100103307118608 and creditorAccount DE02100100109307118603
    And creditorName Merchant Inc
    When the PISP posts the payment to /v1/payments/sepa-credit-transfers
    Then the response is 201 Created with transactionStatus RCVD
    And the response carries a paymentId, a Location header and a scaRedirect link

  # Rule R-PIS-02: The payment product in the path must match the payment in the body

  @MVP-01 @R-PIS-02 @edge-case
  Scenario: An instant transfer posted to the sepa-credit-transfers endpoint is refused
    Given a payment body describing an instant credit transfer
    When the PISP posts it to /v1/payments/sepa-credit-transfers
    Then no payment initiation resource is created

  # Rule R-PIS-03: A payment names a debtor account the PSU may pay from

  @MVP-01 @R-PIS-03 @edge-case
  Scenario: A payment from an account the authenticated PSU does not hold fails
    Given a payment with debtorAccount DE02100100109307118603
    And a PSU who holds only DE40100100103307118608
    When the PSU has authenticated and the authorisation is evaluated
    Then the payment does not reach an authorised state
    And transactionStatus becomes RJCT

  # Rule R-PIS-04: A payment initiation never changes after it is created

  @MVP-01 @R-PIS-04
  Scenario: Reading the payment back returns the amount that was submitted
    Given a payment initiation 1234-wertiq-983 of 123.50 EUR
    When the PISP reads GET /v1/payments/sepa-credit-transfers/1234-wertiq-983
    Then instructedAmount is 123.50 EUR

  # Rule R-PIS-05: The PSU sees the amount and the payee on the surface where the payment is confirmed
  # Example named but not written out: The amount and payee are shown before the PSU confirms
  # Example named but not written out: A payment whose amount changed after it was shown cannot be confirmed
