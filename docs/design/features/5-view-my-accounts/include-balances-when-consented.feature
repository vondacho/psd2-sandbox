# Generated from docs/design/examplemap/5-view-my-accounts/include-balances-when-consented.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-6.5.1 @spec-14.22 @mvp @ready
Feature: Include balances when consented
  As PSU
  I want withBalance=true to return my booked balances
  So that I see how much is on each account

  @spec-6.5.1
  Rule: withBalance=true adds a balances array to each account for which balances were granted; without it, no balances

    @nominal @mvp
    Scenario: withBalance=true on an accounts+balances consent
      Given consent 123cons456 with accounts and balances on Main Account, ledger closingBooked 1250.30 EUR on 2026-09-05
      When the TPP calls GET /v1/accounts?withBalance=true
      Then Main Account has balances [{balanceType: closingBooked, balanceAmount: {currency: EUR, amount: '1250.30'}, referenceDate: 2026-09-05}]

    @nominal @mvp
    Scenario: withBalance absent
      Given the same consent
      When the TPP calls GET /v1/accounts
      Then no entry has balances

    @edge @mvp
    Scenario: withBalance=false
      Given the same consent
      When the TPP calls GET /v1/accounts?withBalance=false
      Then no entry has balances

    @error @mvp
    Scenario: withBalance=maybe
      Given the same consent
      When the TPP calls GET /v1/accounts?withBalance=maybe
      Then the answer is 400 FORMAT_ERROR with path withBalance

    @edge @mvp
    Scenario: Several balance types are all returned
      Given the ledger has closingBooked 1250.30 and interimAvailable 1180.30 (a 70.00 card reservation)
      When the TPP calls with withBalance=true
      Then balances holds both entries

  @spec-14.11
  Rule: withBalance on a consent without the balances access type is refused, not silently ignored

    @error @mvp
    Scenario: Accounts-only consent
      Given consent 555cons666 with access type accounts only
      When the TPP calls GET /v1/accounts?withBalance=true
      Then the answer is 401 CONSENT_INVALID with text 'balances not covered by consent'

    @nominal @mvp
    Scenario: Accounts-only consent without withBalance
      Given the same consent
      When the TPP calls GET /v1/accounts
      Then the answer is 200 without balances

    @edge @mvp
    Scenario: Balances granted on one account only (dedicated consent)
      Given a dedicated consent with accounts [Main, Savings] and balances [Main]
      When the TPP calls with withBalance=true
      Then Main has balances and Savings has none, and the answer is 200

  @spec-14.22
  Rule: Amounts are decimal strings with a dot, negative when overdrawn, in the account's currency

    @edge @mvp
    Scenario: An overdrawn account
      Given closingBooked -12.50 EUR
      When the balance is returned
      Then balanceAmount is {currency: EUR, amount: '-12.50'}

    @edge @mvp
    Scenario: A large amount without grouping
      Given closingBooked 1234567.89 EUR
      When the balance is returned
      Then amount is '1234567.89'

    @edge @mvp
    Scenario: A USD sub-account in USD
      Given the USD sub-account with 300.00 USD
      When the balance is returned
      Then balanceAmount.currency is USD

    @edge @mvp
    Scenario: A zero balance
      Given closingBooked 0.00
      When the balance is returned
      Then amount is '0.00'

  @spec-6
  Rule: Reading balances on the list is one access per account, not two

    @nominal @mvp
    Scenario: Counting
      Given usage counters at 0 and no PSU-IP-Address
      When the TPP calls GET /v1/accounts?withBalance=true for two accounts
      Then each account's counter is 1
