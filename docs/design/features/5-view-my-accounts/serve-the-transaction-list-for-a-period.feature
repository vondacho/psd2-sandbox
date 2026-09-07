# Generated from docs/design/examplemap/5-view-my-accounts/serve-the-transaction-list-for-a-period.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.5.4 @spec-14.25 @ais-reads @analysing
Feature: Serve the transaction list for a period
  As PSU
  I want booked, pending or both over the dates I ask for
  So that I see the bookings I am looking for and no others

  @spec-6.5.4
  Rule: bookingStatus and a period are mandatory, and each status returns its own array

    @nominal @ais-reads
    Scenario: Booked transactions of August
      Given consent 123cons456 grants transactions on Main Account
      And the ledger holds bookings on 2026-08-03 REWE -45.20, 2026-08-15 Salary +3200.00 and 2026-08-28 Rent -950.00
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/transactions?bookingStatus=booked&dateFrom=2026-08-01&dateTo=2026-08-31
      Then the answer is 200 with transactions.booked holding those three entries and no pending array

    @nominal @ais-reads
    Scenario: Pending only
      Given one card reservation of -70.00 EUR is pending
      When bookingStatus=pending&dateFrom=2026-09-01 is called
      Then transactions.pending holds one entry and there is no booked array

    @edge @ais-reads
    Scenario: Both statuses in one report
      Given the same data
      When bookingStatus=both&dateFrom=2026-08-01 is called
      Then both arrays are present

    @edge @ais-reads
    Scenario: A period with no bookings returns an empty array
      Given no bookings in January 2020
      When dateFrom=2020-01-01&dateTo=2020-01-31 is called
      Then the answer is 200 with booked: []

    @error @ais-reads
    Scenario: A missing bookingStatus is refused
      Given a call without bookingStatus
      When it is made
      Then the answer is 400 FORMAT_ERROR naming bookingStatus

    @error @ais-reads
    Scenario: An unknown bookingStatus is refused
      Given bookingStatus=maybe
      When the call is made
      Then the answer is 400 FORMAT_ERROR naming bookingStatus

    @error @ais-reads
    Scenario: A missing dateFrom without a delta parameter is refused
      Given bookingStatus=booked and no dateFrom, entryReferenceFrom or deltaList
      When the call is made
      Then the answer is 400 FORMAT_ERROR naming dateFrom

    @error @ais-reads
    Scenario: dateFrom after dateTo is refused
      Given dateFrom=2026-09-01 and dateTo=2026-08-01
      When the call is made
      Then the answer is 400 PERIOD_INVALID

    @edge @ais-reads
    Scenario: dateTo defaults to today
      Given dateFrom=2026-08-01 and no dateTo, today 2026-09-07
      When the call is made
      Then bookings up to 2026-09-07 are returned

    @edge @ais-reads
    Scenario: The period boundaries are inclusive
      Given a booking on 2026-08-31
      When dateFrom=2026-08-01&dateTo=2026-08-31 is called
      Then that booking is in the report

  @spec-14.25
  Rule: Every entry carries what the specification requires of a transaction

    @nominal @ais-reads
    Scenario: A debit entry
      Given the Rent booking of 2026-08-28
      When the entry is inspected
      Then it has transactionId tx-3001, entryReference ent-2026-08-28-01, bookingDate 2026-08-28, valueDate 2026-08-28, transactionAmount {currency: EUR, amount: '-950.00'}, creditorName 'Landlord GmbH' and remittanceInformationUnstructured 'Rent September'

    @nominal @ais-reads
    Scenario: A credit entry names the debtor instead of the creditor
      Given the Salary booking of 2026-08-15
      When the entry is inspected
      Then it has debtorName 'Employer AG' and amount '3200.00'

    @edge @ais-reads
    Scenario: The report carries the account reference and a balance when asked
      Given withBalance=true on a consent that grants balances
      When the report is built
      Then it carries the account reference and the balances of the account

    @nominal @ais-reads
    Scenario: Entries are ordered most recent first
      Given the three August bookings
      When the report is read
      Then the order is 2026-08-28, 2026-08-15, 2026-08-03

  @security
  Rule: Transactions are served only for an account whose consent grants them

    @error @ais-reads
    Scenario: An accounts and balances consent is refused
      Given consent 123cons456 grants accounts and balances only
      When the transactions endpoint is called
      Then the answer is 401 CONSENT_INVALID

    @error @ais-reads
    Scenario: An account outside the consent is refused
      Given Savings is not accessible under this consent
      When its transactions are read
      Then the answer is 401 CONSENT_INVALID

    @nominal @ais-reads
    Scenario: A background read counts once for the account
      Given the counter for Main Account is 0 and no PSU-IP-Address
      When the transactions are read
      Then the counter is 1
