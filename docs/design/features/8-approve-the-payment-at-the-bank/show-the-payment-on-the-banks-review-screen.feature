# Generated from docs/design/examplemap/8-approve-the-payment-at-the-bank/show-the-payment-on-the-banks-review-screen.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @pis-core @analysing
Feature: Show the payment on the Bank's review screen
  As PSU
  I want the payee, the amount, my debtor account and the execution date before I approve
  So that I know exactly what I am paying

  @rts-art-5
  Rule: The review screen shows the payment as the Bank stored it, in the PSU's words

    @nominal @pis-core
    Scenario: The review of a SEPA credit transfer
      Given pay001 of 12.50 EUR from Main Account to Payee X with the remittance 'Invoice 42', initiated by TPP App
      When Anna reaches the review screen after her password
      Then it shows 'TPP App asks you to pay', 'EUR 12.50', 'to Payee X, DE12 5001 0517 0648 4898 90', 'from Main Account, DE23 1001 0010 0123 4567 89' and 'Invoice 42'
      And it shows 'today' as the execution date

    @nominal @pis-core
    Scenario: The values come from the payment, never from the browser
      Given the review screen
      When the rendered values are traced
      Then each is read from pay001 in payment initiation

    @nominal @pis-core
    Scenario: The TPP is named by its brand and its legal name
      Given the payment was initiated with the brand TPP App by TPP Fintech GmbH
      When the screen renders
      Then it shows 'TPP App (TPP Fintech GmbH)'

    @edge @pis-core
    Scenario: A payment without a debtor account asks which account to pay from
      Given pay002 was initiated without debtorAccount
      When Anna reaches the review screen
      Then it lists her payment accounts and asks her to choose one
      And the chosen account is stored on the payment before the challenge is issued

    @edge @pis-core
    Scenario: An account with too little money is shown but warned about
      Given Main Account holds 5.00 EUR and the payment is 12.50 EUR
      When the screen renders
      Then it warns that the balance may not cover the payment, and still lets Anna approve

  @spec-14.13
  Rule: The PSU can decline, and declining rejects the payment

    @nominal @pis-core
    Scenario: Decline on the review screen
      Given the review screen for pay001
      When Anna clicks 'Decline'
      Then the authorisation is failed and the payment status is RJCT
      And the browser ends at the TPP's nok redirect URI with error=access_denied

    @edge @pis-core
    Scenario: Declining is final
      Given Anna declined pay001
      When she presses back and approves
      Then the page says the payment was declined and nothing is issued

    @nominal @pis-core
    Scenario: The TPP reads the rejection
      Given the declined payment
      When the TPP reads the transaction status
      Then the answer is RJCT

  @security
  Rule: The screen is reachable only inside an authenticated session for that payment

    @error @pis-core
    Scenario: Without the first factor the review screen is not shown
      Given a session in step identified
      When the review URL is opened directly
      Then the login page is shown instead

    @error @pis-core
    Scenario: A session for another payment cannot review this one
      Given a session opened for pay002
      When the review screen of pay001 is requested
      Then the CIAM answers 404

    @edge @pis-core
    Scenario: The session times out like any other
      Given the review screen was opened eleven minutes ago with no action
      When Anna clicks 'Approve'
      Then the page says the session expired and sends her back to the TPP
