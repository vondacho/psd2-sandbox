# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/accept-a-global-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-14.17 @consent-models @analysing
Feature: Accept a global consent
  As TPP operator
  I want allPsd2 to grant every payment account the PSU can see online
  So that an aggregator does not re-consent when the PSU opens a new account

  @spec-14.17
  Rule: allPsd2 grants every access type on every payment account the PSU holds online

    @nominal @consent-models
    Scenario: Every account with balances and transactions
      Given access {allPsd2: allAccounts} authorised by Anna
      When GET /v1/accounts?withBalance=true is called
      Then both of Anna's payment accounts are listed with balances
      When the transactions of either account are read
      Then the answer is 200

    @edge @consent-models
    Scenario: Accounts that are not payment accounts stay out
      Given Anna also holds a loan account
      When the list is read
      Then the loan account is absent

    @nominal @consent-models
    Scenario: The consent screen says what allPsd2 means
      Given the consent screen for an allPsd2 consent
      When it renders
      Then it says that the app may read all payment accounts, their balances and their transactions until the validity date

    @error @consent-models
    Scenario: The code must be allAccounts
      Given access {allPsd2: everything}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

    @error @consent-models
    Scenario: allPsd2 may not be combined with other access fields
      Given access {allPsd2: allAccounts, balances: [DE23…]}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

  @spec-6
  Rule: A global consent is still bound by validity, frequency and ownership

    @nominal @consent-models
    Scenario: The frequency applies per account
      Given an allPsd2 consent with frequencyPerDay 4 and two accounts
      When each account is read four times without the PSU
      Then every read is served
      When a fifth read of one account is made
      Then the answer is 429 ACCESS_EXCEEDED for that account only

    @error @consent-models
    Scenario: Another TPP's global consent grants nothing here
      Given an allPsd2 consent of C for Anna
      When the TPP calls with its own certificate and that consent id
      Then the answer is 401 TOKEN_INVALID

    @edge @consent-models
    Scenario: Expiry ends every access at once
      Given an allPsd2 consent whose validUntil has passed
      When any account endpoint is called
      Then the answer is 401 CONSENT_EXPIRED

  Rule: The Bank may cap what a global consent grants, and says so on the consent object

    @error @consent-models
    Scenario: A bank that does not offer allPsd2 refuses it
      Given the sandbox runs with allPsd2 disabled
      When POST /v1/consents is called with allPsd2
      Then the answer is 400 SERVICE_INVALID with text 'consent model not supported'

    @nominal @consent-models
    Scenario: The granted access is readable afterwards
      Given an authorised allPsd2 consent
      When GET /v1/consents/123cons456 is called
      Then the access object shows what was finally granted, account by account
