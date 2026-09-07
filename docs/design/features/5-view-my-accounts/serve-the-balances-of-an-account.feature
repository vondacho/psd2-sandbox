# Generated from docs/design/examplemap/5-view-my-accounts/serve-the-balances-of-an-account.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.5.3 @spec-14.23 @ais-reads @analysing
Feature: Serve the balances of an account
  As PSU
  I want the balances endpoint to return every balance type the Bank holds for my account
  So that an app can show what I can actually spend

  @spec-6.5.3
  Rule: The endpoint returns the account reference and every balance the Bank holds for that account

    @nominal @ais-reads
    Scenario: Main Account has a booked and an available balance
      Given consent 123cons456 valid with balances on Main Account, resourceId 3dc3d5b3-…
      And the ledger holds closingBooked 1250.30 EUR of 2026-09-05 and interimAvailable 1180.30 EUR
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/balances
      Then the answer is 200 {account: {iban: DE23100100100123456789, currency: EUR}, balances: [closingBooked 1250.30, interimAvailable 1180.30]}

    @nominal @ais-reads
    Scenario: Each balance carries its type, amount, currency and reference date
      Given the closingBooked balance of 2026-09-05
      When the entry is inspected
      Then it has balanceType closingBooked, balanceAmount {currency: EUR, amount: '1250.30'} and referenceDate 2026-09-05

    @edge @ais-reads
    Scenario: An account with a single balance returns one entry
      Given Savings has only a closingBooked balance
      When its balances are read
      Then the array holds one entry

    @edge @ais-reads
    Scenario: A zero balance is served, not omitted
      Given a balance of 0.00 EUR
      When the balances are read
      Then the entry is present with amount '0.00'

    @edge @ais-reads
    Scenario: An overdrawn account returns a negative amount
      Given closingBooked -12.50 EUR
      When the balances are read
      Then the amount is '-12.50'

    @edge @ais-reads
    Scenario: A currency sub-account returns its own balance only
      Given the multicurrency account with a EUR and a USD sub-account
      When the balances of the USD resourceId are read
      Then every balanceAmount has currency USD

  @security
  Rule: The consent must grant balances for that account

    @error @ais-reads
    Scenario: An accounts-only consent is refused
      Given consent 555cons666 grants the access type accounts only
      When the balances endpoint is called
      Then the answer is 401 CONSENT_INVALID

    @error @ais-reads
    Scenario: An account outside the consent is refused
      Given Savings is not an accessible account of consent 123cons456
      When its balances are read with that consent
      Then the answer is 401 CONSENT_INVALID

    @edge @ais-reads
    Scenario: A dedicated consent that grants balances on one account only
      Given a consent with accounts [Main, Savings] and balances [Main]
      When the balances of Savings are read
      Then the answer is 401 CONSENT_INVALID
      When the balances of Main Account are read
      Then the answer is 200

    @error @ais-reads
    Scenario: The full validation chain runs first
      Given an expired access token and a consent that grants balances
      When the balances endpoint is called
      Then the answer is 401 TOKEN_EXPIRED, not CONSENT_INVALID

  @spec-6
  Rule: A read without the PSU present counts against the consented frequency

    @nominal @ais-reads
    Scenario: A background read is counted for that account
      Given the counter for Main Account is 2 of 4 today
      When the balances are read without PSU-IP-Address
      Then the answer is 200 and the counter is 3

    @nominal @ais-reads
    Scenario: A read with the PSU present is not counted
      Given the counter is 4 of 4
      When the balances are read with PSU-IP-Address
      Then the answer is 200 and the counter stays 4

    @error @ais-reads
    Scenario: The fifth background read is refused
      Given the counter is 4 of 4
      When the balances are read without PSU-IP-Address
      Then the answer is 429 ACCESS_EXCEEDED
