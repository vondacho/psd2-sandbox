# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/accept-a-consent-on-dedicated-accounts.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.3.1.1 @consent-models @analysing
Feature: Accept a consent on dedicated accounts
  As TPP operator
  I want a consent naming the IBANs I already know to be accepted without a bank-side account choice
  So that a PSU who has told me their accounts is not asked twice

  @spec-6.3.1.1
  Rule: A request naming accounts is accepted and the named accounts become the accessible ones

    @nominal @consent-models
    Scenario: Two accounts named for accounts and balances
      Given access {accounts: [DE23100100100123456789, DE89370400440532013000], balances: [DE23100100100123456789]}
      When the TPP calls POST /v1/consents
      Then the answer is 201 with consentStatus received
      When Anna authenticates and approves
      Then the consent has two accessible accounts, and only DE23… carries the access type balances

    @nominal @consent-models
    Scenario: The PSU is not asked to choose accounts
      Given a dedicated consent naming Main Account
      When Anna reaches the Bank's consent screen
      Then the screen shows the named account and no selection list

    @edge @consent-models
    Scenario: An account reference with a currency addresses one sub-account
      Given access.accounts [{iban: DE11…, currency: USD}]
      When the consent is authorised
      Then only the USD sub-account is accessible

    @error @consent-models
    Scenario: An IBAN the PSU does not hold is refused
      Given access.accounts [DE75512108001245126199], which belongs to Ben
      When Anna authenticates for that consent
      Then the consent is rejected with CONSENT_INVALID and no account becomes accessible

    @error @consent-models
    Scenario: A malformed IBAN is refused at creation
      Given access.accounts [DE00]
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR naming access.accounts

    @error @consent-models
    Scenario: An empty accounts array with a non-empty balances array is refused
      Given access {accounts: [], balances: [DE23100100100123456789]}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

  @spec-14.17
  Rule: An access type may only name accounts that the accounts array also names

    @error @consent-models
    Scenario: Transactions on an account that is not in accounts is refused
      Given access {accounts: [DE23…], transactions: [DE89…]}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

    @nominal @consent-models
    Scenario: Balances on a subset is accepted
      Given access {accounts: [DE23…, DE89…], balances: [DE23…]}
      When the consent is authorised
      Then balances are served for DE23… and refused for DE89…

  @spec-14.15
  Rule: A dedicated consent still needs one SCA and follows the same lifecycle

    @nominal @consent-models
    Scenario: The consent becomes valid only after SCA
      Given a dedicated consent in status received
      When the account list is read before the SCA
      Then the answer is 401 CONSENT_INVALID

    @nominal @consent-models
    Scenario: The account list holds exactly the named accounts
      Given a dedicated consent on Main Account only, now valid
      When GET /v1/accounts is called
      Then the list holds Main Account and not Savings

    @edge @consent-models
    Scenario: A dedicated recurring consent replaces the previous recurring consent
      Given the TPP holds a valid bank-offered consent for Anna
      When a dedicated recurring consent of the same TPP becomes valid
      Then the older consent is terminated
