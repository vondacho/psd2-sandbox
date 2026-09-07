# Generated from docs/design/examplemap/10-cancel-the-payment/require-an-authorisation-for-a-cancellation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-5.7 @pis-cancellation @analysing
Feature: Require an authorisation for a cancellation
  As Bank security officer
  I want the cancellation to answer ACTC with a cancellation authorisation link when SCA is needed
  So that a payment is never withdrawn without the PSU

  @spec-5.7
  Rule: When the Bank requires an SCA, the cancellation is started rather than done

    @nominal @pis-cancellation
    Scenario: The cancellation is accepted for authorisation
      Given pay002 is ACTC and the sandbox runs with cancellationScaRequired true
      When the TPP calls DELETE /v1/payments/sepa-credit-transfers/pay002
      Then the answer is 202 with transactionStatus ACTC and a startAuthorisationWithPsuAuthentication link
      And the payment is not yet cancelled

    @nominal @pis-cancellation
    Scenario: The payment keeps its status until the cancellation is authorised
      Given the cancellation was accepted for authorisation
      When the status is read
      Then the answer is ACTC

    @edge @pis-cancellation
    Scenario: The execution is held while the cancellation is pending
      Given a pending cancellation authorisation on pay002
      When the execution job runs
      Then the payment is not handed to the core until the cancellation is resolved

    @edge @pis-cancellation
    Scenario: A cancellation that is never authorised leaves the payment alone
      Given the cancellation authorisation expired without an approval
      When the expiry is processed
      Then the cancellation is failed and the payment continues to execution

  @spec-5.8
  Rule: The cancellation authorisation is a resource of its own, separate from the payment's

    @nominal @pis-cancellation
    Scenario: It has its own id and its own SCA status
      Given the cancellation of pay002 was accepted for authorisation
      When the cancellation authorisation is created
      Then it has the id pay002cancauth1 and scaStatus received
      And the payment's own authorisation pay002auth1 is untouched and still finalised

    @nominal @pis-cancellation
    Scenario: The two authorisations do not share a challenge
      Given a challenge for the payment and a challenge for its cancellation
      When their subjects are compared
      Then they differ, and a signature over one is refused for the other

    @nominal @pis-cancellation
    Scenario: The dynamic link of a cancellation names the cancellation
      Given the cancellation challenge
      When the approval screen renders
      Then it says 'Cancel the payment of EUR 12.50 to Payee X', not 'Pay'

  Rule: Whether an SCA is required is the Bank's decision, announced in the answer

    @nominal @pis-cancellation
    Scenario: Without the requirement the payment is cancelled at once
      Given cancellationScaRequired false
      When the cancellation is called
      Then the answer is 204 and the status is CANC

    @nominal @pis-cancellation
    Scenario: With the requirement the answer carries the link
      Given cancellationScaRequired true
      When the cancellation is called
      Then the answer is 202 with a link to start the cancellation authorisation

    @nominal @pis-cancellation
    Scenario: The TPP does not have to guess which case it is in
      Given either answer
      When the client reads it
      Then 204 means done and 202 with a link means one more step
