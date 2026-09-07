# Generated from docs/design/examplemap/10-cancel-the-payment/refuse-to-cancel-a-payment-that-is-already-settled.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-14.11 @pis-cancellation @ready
Feature: Refuse to cancel a payment that is already settled
  As Bank security officer
  I want a cancellation of an executed payment refused with CANCELLATION_INVALID
  So that the ledger and the interface never disagree

  @spec-14.13
  Rule: A payment in a final status cannot be cancelled

    @error @pis-cancellation
    Scenario: A settled payment
      Given pay003 is ACSC
      When the cancellation is called
      Then the answer is 405 CANCELLATION_INVALID and the status stays ACSC

    @error @pis-cancellation
    Scenario: A rejected payment
      Given pay001 is RJCT
      When the cancellation is called
      Then the answer is 405 CANCELLATION_INVALID

    @edge @pis-cancellation
    Scenario: An already cancelled payment answers as cancelled, not as an error
      Given pay002 is CANC
      When the cancellation is called
      Then the answer is 204

    @nominal @pis-cancellation
    Scenario: The ledger is untouched by a refused cancellation
      Given pay003 was booked with a debit of 12.50 EUR
      When a cancellation is refused
      Then no reversal booking exists

  Rule: The race between execution and cancellation resolves once, and the answer says which won

    @edge @pis-cancellation
    Scenario: The cancellation arrives while the core is booking
      Given pay002 is ACTC and the execution job has taken it
      When the cancellation arrives
      Then either the answer is 204 and the payment is CANC and never booked, or the answer is 405 and the payment is ACSC
      And the payment is never both cancelled and booked

    @edge @pis-cancellation
    Scenario: Two cancellations at the same moment
      Given pay002 is ACTC
      When two cancellations arrive within 50 ms
      Then the payment is cancelled once and both callers see a consistent answer

  @spec-4.13
  Rule: A refused cancellation explains itself and can be understood by the PSU

    @nominal @pis-cancellation
    Scenario: The error body
      Given the refusal for a settled payment
      When the body is inspected
      Then it is {tppMessages: [{category: ERROR, code: CANCELLATION_INVALID, text: 'the payment was already executed'}]}

    @nominal @pis-cancellation
    Scenario: The TPP can tell the PSU what to do next
      Given the refusal
      When the client renders it
      Then it says the payment already went through and offers to contact the payee or the Bank
