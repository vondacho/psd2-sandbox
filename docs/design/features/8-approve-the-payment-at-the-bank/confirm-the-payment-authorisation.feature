# Generated from docs/design/examplemap/8-approve-the-payment-at-the-bank/confirm-the-payment-authorisation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-7.6.4 @pis-core @ready
Feature: Confirm the payment authorisation
  As Bank security officer
  I want the confirmation call checked against the token's payment id and client
  So that the payment becomes valid only for the TPP that created it

  @spec-7.6.4
  Rule: A confirmation with a token scoped to that payment finalises the authorisation and accepts the payment

    @nominal @pis-core
    Scenario: The nominal confirmation
      Given pay001auth1 is unconfirmed and the TPP holds a token with scope PIS:pay001
      When PUT /v1/payments/sepa-credit-transfers/pay001/authorisations/pay001auth1 is called with that token
      Then the answer is 200 {scaStatus: finalised}
      And the transaction status of pay001 is ACTC

    @edge @pis-core
    Scenario: The confirmation is idempotent
      Given the authorisation is finalised
      When the confirmation is repeated
      Then the answer is 200 {scaStatus: finalised} and nothing changes

    @nominal @pis-core
    Scenario: The status link shows the payment moved
      Given the confirmation succeeded
      When the status link is followed
      Then the answer is {transactionStatus: ACTC}

  @security
  Rule: A token for another payment, another client or no token at all does not confirm

    @error @pis-core
    Scenario: A token for another payment
      Given a token with scope PIS:pay002
      When the confirmation of pay001 is called
      Then the answer is 401 TOKEN_INVALID and the authorisation stays unconfirmed

    @error @pis-core
    Scenario: A consent token cannot confirm a payment
      Given a token with scope AIS:123cons456
      When the confirmation of pay001 is called
      Then the answer is 401 TOKEN_INVALID

    @error @pis-core
    Scenario: A token presented over another certificate
      Given the right token over the other TPP's certificate
      When the confirmation is called
      Then the answer is 401 TOKEN_INVALID

    @error @pis-core
    Scenario: No token
      Given the confirmation without an Authorization header
      When it is called
      Then the answer is 401 TOKEN_INVALID

    @error @pis-core
    Scenario: An expired token
      Given a token past its expiry
      When the confirmation is called
      Then the answer is 401 TOKEN_EXPIRED

  @spec-14.16
  Rule: Confirmation is possible only from the unconfirmed state

    @error @pis-core
    Scenario: Confirming a started authorisation
      Given the authorisation is started, with no device approval yet
      When the confirmation is called
      Then the answer is 409 STATUS_INVALID

    @error @pis-core
    Scenario: Confirming a failed authorisation
      Given the authorisation is failed
      When the confirmation is called
      Then the answer is 409 STATUS_INVALID

    @error @pis-core
    Scenario: Confirming a payment that was rejected
      Given pay001 is RJCT
      When the confirmation is called
      Then the answer is 409 STATUS_INVALID

  Rule: Until the payment is accepted, nothing is executed

    @nominal @pis-core
    Scenario: No booking before ACTC
      Given the authorisation is unconfirmed
      When the core banking is inspected
      Then no booking exists for pay001

    @nominal @pis-core
    Scenario: The execution starts after acceptance
      Given the confirmation moved pay001 to ACTC
      When the execution job runs
      Then the payment is handed to the core banking
