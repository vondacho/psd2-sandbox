# Generated from docs/design/examplemap/5-view-my-accounts/render-the-account-details.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @mvp @ready
Feature: Render the account details
  As PSU
  I want a detail page with balances and links back to the list
  So that I can move between my accounts

  Rule: The detail page shows the account's name, IBAN, BIC, currency, product, owner and every balance with its type and date, plus navigation

    @nominal @mvp
    Scenario: Main Account
      Given GET /v1/accounts/3dc3d5b3-…?withBalance=true returned Main Account, DE23…, BANKDEBBXXX, EUR, Girokonto, Anna Müller, closingBooked 1250.30 on 2026-09-05 and interimAvailable 1180.30
      When the page renders
      Then it shows 'Main Account', 'DE23 1001 0010 0123 4567 89', 'BANKDEBBXXX', 'Girokonto', 'Anna Müller'
      And it lists 'Booked balance EUR 1,250.30 (5 Sep 2026)' and 'Available EUR 1,180.30'
      And it has 'Back to accounts' and 'Next: Savings'

    @edge @mvp
    Scenario: No balances consented
      Given the object has no balances
      When the page renders
      Then the balances section is hidden and a note says 'balances not shared'

    @edge @mvp
    Scenario: Only one account: no next/previous
      Given the connection has one account view
      When the page renders
      Then only 'Back to accounts' is shown

    @edge @mvp
    Scenario: Owner name absent
      Given the object has no ownerName
      When the page renders
      Then the owner row is omitted

  Rule: The page reads only accounts known from the list, with the PSU present

    @nominal @mvp
    Scenario: The call carries PSU-IP-Address
      Given Anna clicks Main Account
      When the TPP calls GET /v1/accounts/3dc3d5b3-…?withBalance=true
      Then the call carries PSU-IP-Address and Consent-ID 123cons456

    @error @mvp
    Scenario: A resourceId not in the stored views
      Given Anna types /banks/bank/accounts/00000000-0000-4000-8000-000000000000
      When the page renders
      Then the TPP answers 404 and makes no call to the Bank

    @error @mvp
    Scenario: Another user's resourceId
      Given Ben types the URL of Anna's Main Account
      When the page renders
      Then the TPP answers 404

  @spec-14.11
  Rule: Errors are shown with the right next step

    @error @mvp
    Scenario: CONSENT_INVALID on a detail
      Given the Bank answers 401 CONSENT_INVALID
      When the page renders
      Then it says 'This account is no longer shared with TPP App' and links back to the list
      And the connection is marked needsReconsent

    @error @mvp
    Scenario: ACCESS_EXCEEDED
      Given the Bank answers 429
      When the page renders
      Then it shows the cached view with 'try again later'

    @error @mvp
    Scenario: RESOURCE_UNKNOWN
      Given the Bank answers 404 RESOURCE_UNKNOWN for a stored view
      When the page renders
      Then it says 'This account is no longer available' and the view is removed on the next list refresh
