# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/show-the-consent-summary.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-ciam @walking-skeleton @ready
Feature: Show the consent summary
  As PSU
  I want to see the TPP name, the access types, the accounts, the validity and the frequency before I approve
  So that I know exactly what I am granting

  Rule: The summary states who, what, which accounts, until when and how often, in words

    @nominal @walking-skeleton
    Scenario: The summary for the TPP's bank-offered consent on Main Account
      Given consent 123cons456 by the TPP (brand TPP App, legal TPP Fintech GmbH), access accounts and balances, validUntil 2026-12-05, frequencyPerDay 4, recurring, Main Account selected
      When the summary renders
      Then it says 'TPP App (TPP Fintech GmbH) wants to read the list of your accounts and their balances'
      And it lists 'Main Account, DE23 1001 0010 0123 4567 89, EUR'
      And it says 'until 5 December 2026, up to 4 times a day without you being present'

    @edge @mvp
    Scenario: A one-off consent says once
      Given recurringIndicator false, frequencyPerDay 1
      When the summary renders
      Then it says 'one time only, today'

    @edge @mvp
    Scenario: A validity shortened by the bank shows the shortened date
      Given the TPP asked for 2027-09-06 and the Bank stored 2027-03-05
      When the summary renders
      Then it says 'until 5 March 2027'

    @edge @mvp
    Scenario: A consent with transactions says so
      Given access accounts, balances and transactions
      When the summary renders
      Then it says 'the list of your accounts, their balances and their transactions'

    @nominal @walking-skeleton
    Scenario: Two selected accounts are both listed
      Given Main Account and Savings selected
      When the summary renders
      Then both rows appear, in the order of the selection page

  Rule: The PSU can change the selection or decline before approving

    @nominal @walking-skeleton
    Scenario: Back returns to the selection with the ticks kept
      Given the summary for Main Account
      When Anna clicks 'Change accounts'
      Then the selection page shows Main Account ticked

    @nominal @walking-skeleton
    Scenario: Changing the selection changes the summary
      Given Anna goes back and also ticks Savings
      When the summary renders again
      Then both accounts are listed

    @nominal @walking-skeleton
    Scenario: Decline rejects the consent and goes back to the TPP
      Given the summary
      When Anna clicks 'Decline'
      Then the session step is refused, the authorisation failed, the consent rejected
      And the browser ends at the TPP's nok URI with error=access_denied

    @edge @mvp
    Scenario: Decline cannot be undone
      Given Anna declined
      When she presses the browser back button and clicks 'Approve'
      Then the page shows 'This request was declined' and nothing is issued

  @rts-art-5
  Rule: Approving the summary issues the challenge; nothing is granted by the summary itself

    @nominal @walking-skeleton
    Scenario: Approve leads to the QR page
      Given the summary
      When Anna clicks 'Approve on my device'
      Then a challenge is created and the QR page renders
      And the consent is still received

    @nominal @walking-skeleton
    Scenario: The summary text and the challenge cover the same facts
      Given the summary for Main Account until 2026-12-05
      When the challenge is created
      Then its dynamic link summary is 'TPP App: accounts and balances of DE23 …7 89 until 2026-12-05'
