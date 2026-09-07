# Generated from docs/design/examplemap/8-approve-the-payment-at-the-bank/record-the-approved-payment-authorisation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-14.16 @spec-14.13 @pis-core @analysing
Feature: Record the approved payment authorisation
  As Bank product owner
  I want the authorisation finalised and the payment moved to ACTC
  So that the payment is accepted for execution only after SCA

  @spec-14.16
  Rule: A verified challenge finalises the authorisation and accepts the payment

    @nominal @pis-core
    Scenario: Without a confirmation step
      Given the sandbox runs with confirmationRequired false and Anna's device approved the challenge for pay001
      When the outcome is recorded
      Then the authorisation pay001auth1 is finalised with finalisedAt set
      And the transaction status of pay001 is ACTC

    @nominal @pis-core
    Scenario: With a confirmation step the payment waits
      Given confirmationRequired true and the challenge approved
      When the outcome is recorded
      Then the authorisation is unconfirmed and the status stays RCVD

    @nominal @pis-core
    Scenario: The PSU is recorded on the payment
      Given Anna approved pay001
      When the payment is read internally
      Then its psuId is anna.mueller

    @edge @pis-core
    Scenario: The chosen debtor account is recorded when it was missing
      Given pay002 was initiated without a debtor account and Anna chose Main Account
      When the outcome is recorded
      Then the payment carries debtorAccount DE23100100100123456789

  @spec-14.13
  Rule: A denied, expired or failed challenge rejects the payment

    @nominal @pis-core
    Scenario: Denied on the device
      Given Anna rejected the challenge for pay001
      When the outcome is recorded
      Then the authorisation is failed and the payment status is RJCT

    @nominal @pis-core
    Scenario: The last challenge expired
      Given the third challenge for pay001 expired
      When the expiry is processed
      Then the authorisation is failed and the payment is RJCT

    @edge @pis-core
    Scenario: The risk engine refused the session
      Given the risk decision was refuse
      When the refusal is recorded
      Then the authorisation is failed and the payment is RJCT

    @edge @pis-core
    Scenario: RJCT is terminal for the payment
      Given pay001 is RJCT
      When a late approval outcome arrives
      Then it is refused with 409 and the status stays RJCT

  @security
  Rule: The outcome is accepted once, for the right challenge, and cannot be replayed

    @edge @pis-core
    Scenario: A duplicate outcome changes nothing
      Given the outcome for the challenge of pay001 was recorded
      When the same outcome is posted again
      Then the answer is 200 and the payment is unchanged

    @error @pis-core
    Scenario: An outcome for a pending challenge is refused
      Given the challenge is still pending
      When an outcome is posted
      Then the answer is 409 'challenge not approved'

    @error @pis-core
    Scenario: An outcome naming another payment's challenge is refused
      Given a challenge that belongs to pay002
      When an outcome for it is posted to pay001
      Then the answer is 409
