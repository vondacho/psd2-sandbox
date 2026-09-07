# Generated from docs/design/examplemap/5-view-my-accounts/serve-get-v1-accounts-id.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.5.2 @mvp @analysing
Feature: Serve GET /v1/accounts/{id}
  As PSU
  I want the TPP to show the details of the account I clicked
  So that I can check product, owner name and balances

  @spec-6.5.2
  Rule: The account object holds the identifiers, product data, status, owner name per policy, balances when asked and granted, and the links

    @nominal @mvp
    Scenario: Main Account with balances
      Given consent 123cons456 valid, resourceId 3dc3d5b3-… for Main Account
      When the TPP calls GET /v1/accounts/3dc3d5b3-…?withBalance=true
      Then the answer is 200 {account: {resourceId: 3dc3d5b3-…, iban: DE23100100100123456789, currency: EUR, ownerName: Anna Müller, name: Main Account, product: Girokonto, cashAccountType: CACC, status: enabled, bic: BANKDEBBXXX, balances: [closingBooked 1250.30 EUR], _links: {balances: …}}}

    @nominal @mvp
    Scenario: Without withBalance
      Given the same
      When the TPP calls GET /v1/accounts/3dc3d5b3-…
      Then the object has no balances

    @error @mvp
    Scenario: withBalance on an accounts-only consent
      Given consent 555cons666 with accounts only
      When the TPP calls with withBalance=true
      Then the answer is 401 CONSENT_INVALID

    @edge @mvp
    Scenario: A USD sub-account
      Given the USD sub-account resourceId
      When the TPP reads it
      Then currency is USD and the IBAN is the shared one

    @edge @mvp
    Scenario: A closed account
      Given Savings closed in the ledger
      When the TPP reads it
      Then status is deleted and there are no balances

  @spec-6.5.2
  Rule: The same validation chain as the list applies, then the account must be in the consent

    @error @mvp
    Scenario: A resourceId that exists nowhere
      Given resourceId 00000000-0000-4000-8000-000000000000
      When the TPP reads it
      Then the answer is 404 RESOURCE_UNKNOWN

    @error @mvp
    Scenario: A resourceId of another consent
      Given resourceId 9e9e… of consent 111cons222
      When the TPP reads it with Consent-ID 123cons456
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: A malformed id
      Given resourceId 'main'
      When the TPP reads it
      Then the answer is 404 RESOURCE_UNKNOWN

    @error @mvp
    Scenario: An expired token
      Given an expired access token
      When the TPP reads the account
      Then the answer is 401 TOKEN_EXPIRED

  @spec-6
  Rule: A detail read without PSU presence counts one access for that account only

    @nominal @mvp
    Scenario: Counting
      Given counters Main 2, Savings 2 and no PSU-IP-Address
      When the TPP reads Main Account
      Then Main is 3 and Savings still 2

    @nominal @mvp
    Scenario: With PSU presence nothing is counted
      Given the same counters and PSU-IP-Address present
      When the TPP reads Main Account
      Then the counters are unchanged

    @error @mvp
    Scenario: The fifth detail read of the day without presence is refused
      Given Main at 4 of 4
      When the TPP reads Main Account without PSU-IP-Address
      Then the answer is 429 ACCESS_EXCEEDED
