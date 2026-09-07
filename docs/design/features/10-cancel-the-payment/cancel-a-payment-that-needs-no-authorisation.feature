# Generated from docs/design/examplemap/10-cancel-the-payment/cancel-a-payment-that-needs-no-authorisation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-5.7 @spec-4.7 @pis-cancellation @analysing
Feature: Cancel a payment that needs no authorisation
  As PSU
  I want a payment that has not been executed cancelled straight away
  So that I can stop a payment I no longer want

  @spec-5.7
  Rule: A payment that the Bank can still stop, and whose cancellation needs no SCA, is cancelled at once

    @nominal @pis-cancellation
    Scenario: A payment still waiting for its SCA
      Given pay001 is RCVD
      When the TPP calls DELETE /v1/payments/sepa-credit-transfers/pay001
      Then the answer is 204
      And the transaction status is CANC

    @nominal @pis-cancellation
    Scenario: A payment accepted but not yet executed, when the Bank requires no SCA
      Given pay002 is ACTC, the sandbox runs with cancellationScaRequired false
      When the cancellation is called
      Then the answer is 204 and the status is CANC

    @nominal @pis-cancellation
    Scenario: The cancelled payment is never handed to the core
      Given pay002 was cancelled before the execution job ran
      When the job runs
      Then the core receives nothing

    @edge @pis-cancellation
    Scenario: Cancelling twice is harmless
      Given pay002 is CANC
      When the cancellation is repeated
      Then the answer is 204 and the status stays CANC

    @nominal @pis-cancellation
    Scenario: The status endpoint shows the cancellation
      Given the cancelled payment
      When the status is read
      Then the answer is {transactionStatus: CANC}

  @security
  Rule: Only the TPP that created the payment may cancel it

    @error @pis-cancellation
    Scenario: Another TPP is refused
      Given the other TPP's certificate
      When DELETE on pay001 is called
      Then the answer is 403 RESOURCE_UNKNOWN and the payment is untouched

    @error @pis-cancellation
    Scenario: A token scoped to another payment is refused
      Given a token with scope PIS:pay002
      When pay001 is cancelled
      Then the answer is 401 TOKEN_INVALID

    @error @pis-cancellation
    Scenario: An unknown payment id
      Given no payment pay999
      When it is cancelled
      Then the answer is 403 RESOURCE_UNKNOWN

    @edge @pis-cancellation
    Scenario: The PSU can also cancel through the Bank's own channel
      Given pay002 is ACTC
      When Anna cancels it in online banking
      Then the status is CANC and the TPP reads CANC on its next status call

  @spec-14.11
  Rule: A cancellation is refused when the payment product does not allow it

    @error @pis-cancellation
    Scenario: An instant payment cannot be cancelled
      Given pay003 is an instant-sepa-credit-transfers payment at ACTC
      When it is cancelled
      Then the answer is 405 CANCELLATION_INVALID with text 'this payment product cannot be cancelled'

    @edge @pis-cancellation
    Scenario: The product's rule is configuration, not code
      Given the sandbox marks sepa-credit-transfers cancellable and instant payments not
      When each product is cancelled
      Then the first answers 204 and the second 405
