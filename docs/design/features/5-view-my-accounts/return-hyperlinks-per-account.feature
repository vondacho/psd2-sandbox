# Generated from docs/design/examplemap/5-view-my-accounts/return-hyperlinks-per-account.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-14.20 @mvp @ready
Feature: Return hyperlinks per account
  As TPP operator
  I want balances and transactions links only for the access types granted
  So that the TPP can navigate without guessing URLs

  @spec-14.20
  Rule: Each account carries a balances link if balances are granted and a transactions link if transactions are granted, and nothing else

    @nominal @mvp
    Scenario: accounts and balances
      Given consent with accounts and balances on Main Account (resourceId 3dc3d5b3-…)
      When the TPP calls GET /v1/accounts
      Then Main Account's _links is {balances: {href: /psd2/v1/accounts/3dc3d5b3-…/balances}}

    @edge @mvp
    Scenario: accounts, balances and transactions
      Given a consent with all three access types
      When the TPP calls GET /v1/accounts
      Then _links has balances and transactions

    @edge @mvp
    Scenario: accounts only
      Given a consent with accounts only
      When the TPP calls GET /v1/accounts
      Then the entry has no _links or an empty one

    @edge @mvp
    Scenario: Different rights on different accounts
      Given a dedicated consent with balances on Main and transactions on Savings
      When the TPP calls GET /v1/accounts
      Then Main has a balances link only and Savings a transactions link only

  @spec-4.11.2
  Rule: Links are relative to the API base and carry the resourceId, never an IBAN

    @nominal @mvp
    Scenario: The href form
      Given the balances link
      When it is inspected
      Then it is /psd2/v1/accounts/3dc3d5b3-7023-4848-9853-f5400a64e80f/balances

    @nominal @mvp
    Scenario: Resolving the link against the base works
      Given the base https://api.bank.sandbox
      When the TPP resolves the href
      Then the URL is https://api.bank.sandbox/psd2/v1/accounts/3dc3d5b3-…/balances and GET on it answers 200

  Rule: Following a link that was not returned is refused consistently

    @error @mvp
    Scenario: Transactions on an accounts+balances consent
      Given no transactions link was returned
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/transactions?bookingStatus=booked&dateFrom=2026-08-01
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Balances on an accounts-only consent
      Given no balances link was returned
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/balances
      Then the answer is 401 CONSENT_INVALID

  Rule: The TPP navigates from the links and never builds account URLs itself

    @nominal @mvp
    Scenario: The detail page uses the returned links
      Given the account list with links
      When the TPP loads balances for the detail page
      Then it GETs the href of _links.balances

    @nominal @mvp
    Scenario: A missing link hides the feature
      Given no transactions link
      When the detail page renders
      Then it shows no transactions section and makes no transactions call
