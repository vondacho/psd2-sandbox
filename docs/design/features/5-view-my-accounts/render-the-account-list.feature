# Generated from docs/design/examplemap/5-view-my-accounts/render-the-account-list.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @walking-skeleton @ready
Feature: Render the account list
  As PSU
  I want a list with name, IBAN, currency and balance
  So that I can pick an account

  Rule: Each account is a row with its name, its IBAN in groups of four, its currency and its closingBooked balance when present, linking to its details

    @nominal @walking-skeleton
    Scenario: Two accounts with balances
      Given GET /v1/accounts?withBalance=true returned Main Account DE23100100100123456789 EUR 1250.30 and Savings DE89370400440532013000 EUR 5000.00
      When the list renders
      Then row 1 is 'Main Account, DE23 1001 0010 0123 4567 89, EUR 1,250.30' linking to /banks/bank/accounts/3dc3d5b3-…
      And row 2 is 'Savings, DE89 3704 0044 0532 0130 00, EUR 5,000.00'

    @edge @mvp
    Scenario: No balance consented
      Given the answer has no balances
      When the list renders
      Then the balance column shows '—' and a note 'balances not shared'

    @edge @mvp
    Scenario: A negative balance
      Given closingBooked -12.50
      When the list renders
      Then the balance reads 'EUR -12.50' in the negative style

    @edge @mvp
    Scenario: displayName preferred over name
      Given an account with name 'Girokonto' and displayName 'Haushalt'
      When the list renders
      Then the row shows 'Haushalt'

    @edge @mvp
    Scenario: A closed account
      Given an account with status deleted
      When the list renders
      Then the row is shown greyed with 'closed' and does not link to details

  @spec-4.8
  Rule: The list is fetched with the PSU present, cached as account views with a timestamp, and refreshable

    @nominal @walking-skeleton
    Scenario: Opening the list calls the Bank with PSU-IP-Address
      Given Anna clicks 'View accounts'
      When the TPP calls GET /v1/accounts
      Then the call carries PSU-IP-Address
      And the page shows 'as of 09:15'

    @nominal @mvp
    Scenario: Refresh re-reads
      Given the list shown as of 09:15
      When Anna clicks 'Refresh' at 09:20
      Then the TPP calls the Bank again and the page shows 'as of 09:20'

    @edge @mvp
    Scenario: The cached views are shown while the Bank is slow
      Given views from 09:15 and the Bank taking 8 seconds
      When Anna opens the list
      Then the cached rows are shown at once with 'updating…', then replaced

  @spec-14.11
  Rule: Errors from the Bank become a message and the right next step

    @error @mvp
    Scenario: CONSENT_EXPIRED
      Given the Bank answers 401 CONSENT_EXPIRED
      When the list renders
      Then it shows 'Your connection to the Bank ended. Reconnect to see your accounts.' with 'Reconnect'

    @error @mvp
    Scenario: ACCESS_EXCEEDED
      Given the Bank answers 429 ACCESS_EXCEEDED
      When the list renders
      Then it shows the cached rows with 'the Bank limits how often we may ask today; try again later'

    @error @mvp
    Scenario: 503
      Given the Bank answers 503
      When the list renders
      Then it shows 'the Bank is temporarily unavailable' and the cached rows if any

    @edge @mvp
    Scenario: TOKEN_EXPIRED is invisible to the PSU
      Given the Bank answers 401 TOKEN_EXPIRED and the refresh succeeds
      When the list renders
      Then the rows are shown normally

  Rule: Only a connected connection shows accounts

    @error @walking-skeleton
    Scenario: A disconnected bank
      Given the connection to the Bank is disconnected
      When Anna opens /banks/bank/accounts
      Then the page shows 'the Bank is not connected' with 'Connect'

    @error @walking-skeleton
    Scenario: Another user's connection
      Given Ben opens /banks/bank/accounts while only Anna is connected
      When the page renders
      Then Ben sees 'the Bank is not connected', never Anna's accounts
