# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/choose-the-accounts-to-share.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @spec-6.3.1.2 @walking-skeleton @analysing
Feature: Choose the accounts to share
  As PSU
  I want to tick which of my payment accounts the TPP may read
  So that the TPP only sees what I decided

  Rule: The page lists the payment accounts of the authenticated PSU, and nothing else

    @nominal @walking-skeleton
    Scenario: Anna sees her two payment accounts, not her loan
      Given anna.mueller holds Main Account DE23 1001 0010 0123 4567 89 EUR, Savings DE89 3704 0044 0532 0130 00 EUR and a loan account
      When the account selection renders
      Then two rows are shown: 'Main Account, DE23 …7 89, EUR' and 'Savings, DE89 …30 00, EUR'
      And the loan is absent

    @nominal @walking-skeleton
    Scenario: Ben's accounts are never listed for Anna
      Given ben.weber holds DE75 5121 0800 1245 1261 99
      When Anna's selection renders
      Then DE75 … is absent

    @edge @mvp
    Scenario: A PSU without payment accounts cannot continue
      Given a customer with only a loan account
      When the selection renders
      Then the page says 'You have no account that can be shared' and offers 'Back to TPP App'
      And the authorisation is failed and the consent rejected

    @edge @mvp
    Scenario: A blocked account is listed but cannot be ticked
      Given Anna's Savings is blocked in the ledger
      When the selection renders
      Then Savings is shown greyed with 'blocked'

    @edge @mvp
    Scenario: A multicurrency account shows its currencies
      Given Anna holds a multicurrency account with EUR and USD sub-accounts
      When the selection renders
      Then one row shows 'Multicurrency, DE11 …, EUR, USD'

  Rule: At least one account must be ticked to continue

    @error @walking-skeleton
    Scenario: Continue with nothing ticked is refused
      Given no account ticked
      When Anna clicks 'Continue'
      Then the page shows 'Select at least one account' and stays

    @nominal @walking-skeleton
    Scenario: One account ticked continues
      Given Main Account ticked
      When Anna clicks 'Continue'
      Then the summary page shows Main Account only

    @nominal @walking-skeleton
    Scenario: All accounts ticked continues
      Given both accounts ticked
      When Anna clicks 'Continue'
      Then the summary lists both

  @spec-6.3.1.2
  Rule: The selection becomes the consent's accessible accounts, with exactly the access types the TPP asked for

    @nominal @walking-skeleton
    Scenario: Main Account selected on a bank-offered accounts+balances consent
      Given consent 123cons456 asked access {accounts: [], balances: []}
      When Anna selects Main Account and completes the SCA
      Then the consent has one accessible account DE23 1001 0010 0123 4567 89 EUR with access types accounts, balances

    @nominal @walking-skeleton
    Scenario: Transactions are never granted when not requested
      Given the same consent
      When the accessible accounts are read
      Then none carries the access type transactions

    @nominal @walking-skeleton
    Scenario: Both accounts selected give two accessible accounts
      Given the same consent
      When Anna selects both accounts
      Then the consent has two accessible accounts, each with accounts, balances

    @edge @mvp
    Scenario: A multicurrency selection records one accessible account per currency
      Given the multicurrency account with EUR and USD
      When Anna selects it
      Then the consent has two accessible accounts with the same IBAN and currencies EUR and USD

    @nominal @walking-skeleton
    Scenario: The selection is recorded on the session before the challenge is issued
      Given Anna clicked Continue with Main Account
      When the session is read
      Then selectedAccounts is [DE23 1001 0010 0123 4567 89 EUR] and the step is accountsSelected

  @security
  Rule: The selection is only reachable after the first factor and the risk check

    @error @mvp
    Scenario: The selection URL without a verified first factor is refused
      Given a session in step identified
      When the browser opens the selection URL directly
      Then the login page is shown instead

    @error @mvp
    Scenario: Posting a selection with an IBAN that is not the PSU's is refused
      Given Anna's session
      When the form posts iban DE75 5121 0800 1245 1261 99 (Ben's)
      Then the CIAM answers 400 'account not yours' and the selection stays empty
      And the event is logged as a security event
