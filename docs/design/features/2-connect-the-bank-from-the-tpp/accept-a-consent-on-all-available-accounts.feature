# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/accept-a-consent-on-all-available-accounts.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.3.1.2 @spec-14.17 @consent-models @analysing
Feature: Accept a consent on all available accounts
  As TPP operator
  I want availableAccounts and availableAccountsWithBalance to grant the account list only
  So that an app that just lists accounts does not ask for transaction rights

  @spec-14.17
  Rule: availableAccounts grants the account list and nothing else

    @nominal @consent-models
    Scenario: The list of every payment account, without balances
      Given access {availableAccounts: allAccounts} and Anna holds Main Account and Savings
      When the consent is valid and GET /v1/accounts is called
      Then both accounts are listed
      And no entry carries balances and no balances link

    @error @consent-models
    Scenario: Balances are refused
      Given the same consent
      When GET /v1/accounts?withBalance=true is called
      Then the answer is 401 CONSENT_INVALID

    @error @consent-models
    Scenario: Transactions are refused
      Given the same consent
      When the transactions endpoint is called
      Then the answer is 401 CONSENT_INVALID

    @edge @consent-models
    Scenario: Account details are served
      Given the same consent
      When GET /v1/accounts/3dc3d5b3-… is called
      Then the answer is 200 without balances

  @spec-14.17
  Rule: availableAccountsWithBalance grants the list and its balances

    @nominal @consent-models
    Scenario: The list with balances
      Given access {availableAccountsWithBalance: allAccounts}
      When GET /v1/accounts?withBalance=true is called
      Then the answer is 200 and every account carries its balances

    @error @consent-models
    Scenario: Transactions are still refused
      Given the same consent
      When the transactions endpoint is called
      Then the answer is 401 CONSENT_INVALID

    @nominal @consent-models
    Scenario: The balances endpoint is served
      Given the same consent
      When the balances endpoint of Main Account is called
      Then the answer is 200

  @spec-14.17
  Rule: The code must be allAccounts, and no other access field may be combined with it

    @error @consent-models
    Scenario: An unknown code is refused
      Given access {availableAccounts: everything}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR naming access.availableAccounts

    @error @consent-models
    Scenario: Combining with a named accounts array is refused
      Given access {availableAccounts: allAccounts, accounts: [DE23…]}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

    @error @consent-models
    Scenario: Combining both available-accounts codes is refused
      Given access holding availableAccounts and availableAccountsWithBalance
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

  Rule: The accessible accounts follow the PSU's accounts at the moment of authorisation

    @edge @consent-models
    Scenario: An account opened after the consent is not added
      Given the consent was authorised when Anna held two accounts
      When she opens a third account and the list is read
      Then the list holds the two accounts that were accessible at authorisation

    @edge @consent-models
    Scenario: An account closed after the consent is shown as deleted
      Given Savings is closed in the ledger
      When the list is read
      Then Savings is present with status deleted
