# Generated from docs/design/examplemap/6-come-back-later/count-balance-and-transaction-reads-against-the-frequency.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6 @access-rules @analysing
Feature: Count balance and transaction reads against the frequency
  As Bank product owner
  I want every account-data read without the PSU counted, not only the account list
  So that the consented frequency means the same on all endpoints

  @spec-6 @rts-art-36
  Rule: Every read of account data without the PSU present increments the counter of each account it touches

    @nominal @access-rules
    Scenario: The balances endpoint counts one for its account
      Given the counter for Main Account is 0 of 4 and no PSU-IP-Address
      When the balances of Main Account are read
      Then the counter for Main Account is 1 and the counter for Savings is 0

    @nominal @access-rules
    Scenario: The transaction list counts one for its account
      Given the counter for Main Account is 1
      When its transactions are read without the PSU
      Then the counter is 2

    @nominal @access-rules
    Scenario: A transaction detail counts one
      Given the counter is 2
      When one transaction's details are read without the PSU
      Then the counter is 3

    @nominal @access-rules
    Scenario: The account list counts one on every account it returns
      Given counters Main 0 and Savings 0
      When GET /v1/accounts is read without the PSU
      Then both counters are 1

    @edge @access-rules
    Scenario: A paged report counts once, not once per page
      Given the counter is 0 and a report of three pages
      When all three pages are read without the PSU
      Then the counter is 1

    @nominal @access-rules
    Scenario: A status or consent read is never counted
      Given the counter is 4 of 4
      When the consent status and the consent object are read
      Then both answer 200 and the counter stays 4

  @spec-14.11
  Rule: The counter refuses the read that would exceed the consented frequency, and refuses it whole

    @error @access-rules
    Scenario: The fifth read of an account is refused
      Given the counter for Main Account is 4 of 4
      When its balances are read without the PSU
      Then the answer is 429 ACCESS_EXCEEDED and the counter stays 4

    @edge @access-rules
    Scenario: A list touching one exhausted account is refused whole
      Given counters Main 4 and Savings 1
      When GET /v1/accounts is read without the PSU
      Then the answer is 429 ACCESS_EXCEEDED and no counter moves

    @error @access-rules
    Scenario: The other endpoints of an exhausted account are refused too
      Given the counter for Main Account is 4
      When its transactions, its details and one transaction detail are read without the PSU
      Then each answers 429 ACCESS_EXCEEDED

    @nominal @access-rules
    Scenario: A read with the PSU present is served past the limit
      Given the counter is 4 of 4
      When the transactions are read with PSU-IP-Address
      Then the answer is 200 and the counter stays 4

  Rule: Counters are per consent, per account and per calendar day of the Bank

    @edge @access-rules
    Scenario: Midnight resets every counter of the consent
      Given counters Main 4 and Savings 4 on 2026-09-06
      When a read is made at 2026-09-07 00:00:01 Europe/Berlin without the PSU
      Then the answer is 200 and the counter for that account is 1 for the new day

    @edge @access-rules
    Scenario: Two consents on the same account count apart
      Given Main Account is accessible under 123cons456 at 4 and under 333cons444 at 0
      When the other TPP reads it without the PSU
      Then the answer is 200

    @nominal @access-rules
    Scenario: The counters are visible to the PSU
      Given the counter for Main Account is 3 of 4 today
      When Anna opens her consent dashboard
      Then the consent shows that the app read that account three of four times today without her
