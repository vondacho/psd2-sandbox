# Generated from docs/design/examplemap/5-view-my-accounts/read-balances-and-transactions.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @tpp @spec-6.5.3 @spec-6.5.4 @analysing
Feature: Read balances and transactions
  As PSU
  I want the TPP to show balances and recent transactions of an account
  So that I can follow my spending in one place

  @spec-6.5.3
  Rule: GET /v1/accounts/{id}/balances returns the balances of an account whose consent grants balances

    @nominal
    Scenario: Balances of Main Account
      Given consent with balances on Main Account, ledger closingBooked 1250.30 and interimAvailable 1180.30
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/balances
      Then the answer is 200 {account: {iban: DE23…, currency: EUR}, balances: [closingBooked 1250.30, interimAvailable 1180.30]}

    @error
    Scenario: Balances not granted
      Given an accounts-only consent
      When the TPP calls the balances endpoint
      Then the answer is 401 CONSENT_INVALID

    @error
    Scenario: Balances of an unselected account
      Given Savings not in the consent
      When the TPP calls its balances endpoint
      Then the answer is 401 CONSENT_INVALID

  @spec-6.5.4
  Rule: GET /v1/accounts/{id}/transactions needs bookingStatus and a period, and returns the booked and/or pending entries of that period

    @nominal
    Scenario: Booked transactions of August
      Given consent with transactions on Main Account and three bookings in August 2026
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/transactions?bookingStatus=booked&dateFrom=2026-08-01&dateTo=2026-08-31
      Then the answer is 200 {account: {…}, transactions: {booked: [three entries with transactionId, bookingDate, valueDate, transactionAmount, creditorName or debtorName, remittanceInformationUnstructured]}}

    @edge
    Scenario: Pending only
      Given one card reservation pending
      When the TPP calls with bookingStatus=pending&dateFrom=2026-09-01
      Then transactions.pending holds one entry and there is no booked array

    @edge
    Scenario: Both
      Given the same data
      When the TPP calls with bookingStatus=both&dateFrom=2026-08-01
      Then booked and pending are both present

    @edge
    Scenario: An empty period
      Given no bookings in 2020
      When the TPP calls with dateFrom=2020-01-01&dateTo=2020-01-31
      Then the answer is 200 with booked: []

    @error
    Scenario: Missing bookingStatus
      Given a call without bookingStatus
      When it is made
      Then the answer is 400 FORMAT_ERROR with path bookingStatus

    @error
    Scenario: Missing dateFrom
      Given bookingStatus=booked and no dateFrom, no entryReferenceFrom, no deltaList
      When the call is made
      Then the answer is 400 FORMAT_ERROR with path dateFrom

    @error
    Scenario: dateFrom after dateTo
      Given dateFrom=2026-09-01&dateTo=2026-08-01
      When the call is made
      Then the answer is 400 PERIOD_INVALID

    @edge
    Scenario: dateTo defaults to today
      Given dateFrom=2026-08-01 and no dateTo
      When the call is made
      Then entries up to 2026-09-06 are returned

    @error
    Scenario: Transactions not granted
      Given an accounts+balances consent
      When the transactions endpoint is called
      Then the answer is 401 CONSENT_INVALID

  @rts-art-10
  Rule: History older than 90 days is served only with the PSU present

    @nominal
    Scenario: Old history with PSU present
      Given dateFrom=2026-01-01 and PSU-IP-Address present
      When the call is made
      Then the answer is 200

    @error
    Scenario: Old history without PSU present
      Given dateFrom=2026-01-01 and no PSU-IP-Address
      When the call is made
      Then the answer is 401 CONSENT_INVALID with text 'transactions older than 90 days require PSU presence'

    @edge
    Scenario: Exactly 90 days without presence
      Given dateFrom=2026-06-08 (90 days ago) and no PSU-IP-Address
      When the call is made
      Then the answer is 200

  @spec-14.11
  Rule: Only JSON is served; other formats are refused

    @error
    Scenario: Accept text/csv
      Given Accept: text/csv
      When the transactions endpoint is called
      Then the answer is 406 REQUESTED_FORMATS_INVALID

    @nominal
    Scenario: Accept application/json
      Given Accept: application/json
      When the call is made
      Then the answer is 200 with Content-Type application/json

  Rule: The TPP renders transactions per account with date, counterpart, amount and remittance, most recent first

    @nominal
    Scenario: The transaction list
      Given three booked entries: 2026-08-03 REWE -45.20, 2026-08-15 Salary +3200.00, 2026-08-28 Rent -950.00
      When the page renders
      Then rows read '28 Aug 2026, Rent, EUR -950.00', '15 Aug 2026, Salary, EUR +3,200.00', '3 Aug 2026, REWE, EUR -45.20'

    @edge
    Scenario: Pending entries are marked
      Given one pending card reservation
      When the page renders
      Then its row is marked 'pending'

    @nominal
    Scenario: No transactions link: no section
      Given the consent did not grant transactions
      When the page renders
      Then there is no transactions section and no call
