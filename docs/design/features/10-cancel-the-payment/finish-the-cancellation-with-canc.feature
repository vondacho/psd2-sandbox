# Generated from docs/design/examplemap/10-cancel-the-payment/finish-the-cancellation-with-canc.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-14.13 @pis-cancellation @ready
Feature: Finish the cancellation with CANC
  As PSU
  I want the payment set to CANC once the cancellation is authorised
  So that everyone sees that the payment will not be executed

  @spec-14.13
  Rule: An authorised cancellation cancels the payment and stops its execution

    @nominal @pis-cancellation
    Scenario: The payment reaches CANC
      Given pay002 is ACTC and its cancellation authorisation is finalised
      When the outcome is recorded
      Then the transaction status is CANC
      And the execution job never hands the payment to the core

    @nominal @pis-cancellation
    Scenario: The TPP reads the new status
      Given the cancelled payment
      When the status endpoint is called
      Then the answer is {transactionStatus: CANC}

    @edge @pis-cancellation
    Scenario: CANC is final
      Given pay002 is CANC
      When a late execution message arrives from the core
      Then the status stays CANC and the message is logged as ignored

    @edge @pis-cancellation
    Scenario: The PSU sees the cancellation at the Bank
      Given the cancelled payment
      When Anna opens her payments in online banking
      Then the payment is shown as cancelled with its date

  Rule: A refused or abandoned cancellation leaves the payment on its way

    @nominal @pis-cancellation
    Scenario: The PSU denies the cancellation challenge
      Given the cancellation challenge for pay002
      When Anna rejects it on her device
      Then the cancellation authorisation is failed and the payment stays ACTC
      And the execution continues

    @edge @pis-cancellation
    Scenario: The cancellation challenge expires
      Given the last cancellation challenge expired
      When the expiry is processed
      Then the cancellation is failed and the payment stays ACTC

    @edge @pis-cancellation
    Scenario: A new cancellation can be started after a failed one
      Given a failed cancellation authorisation and a payment still at ACTC
      When the TPP calls DELETE again
      Then a new cancellation authorisation is created

  Rule: The cancellation is recorded so both sides can prove what happened

    @nominal @pis-cancellation
    Scenario: The audit trail holds the cancellation
      Given the cancelled payment
      When the audit trail is read
      Then it holds who requested the cancellation, the challenge that authorised it and the time of each step

    @edge @pis-cancellation
    Scenario: A notification tells the TPP
      Given the TPP registered a notification URI
      When the payment reaches CANC
      Then a notification is posted for that payment
