# Generated from docs/design/examplemap/5-view-my-accounts/serve-one-transactions-details.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-6.5.5 @spec-14.26 @ais-reads @ready
Feature: Serve one transaction's details
  As PSU
  I want the details of a booking I picked, including the structured remittance
  So that I can tell what a line on my statement was

  @spec-6.5.5
  Rule: The endpoint returns one transaction with more detail than the list carries

    @nominal @ais-reads
    Scenario: The Rent booking in full
      Given consent 123cons456 grants transactions on Main Account and tx-3001 is the Rent booking
      When the TPP calls GET /v1/accounts/3dc3d5b3-…/transactions/tx-3001
      Then the answer is 200 with transactionId tx-3001, bookingDate 2026-08-28, valueDate 2026-08-28, amount '-950.00' EUR, creditorName 'Landlord GmbH', creditorAccount DE12500105170648489890 and the structured remittance

    @edge @ais-reads
    Scenario: The entry details of a collective booking
      Given tx-3002 is a collective booking of three salary payments
      When its details are read
      Then the answer carries entryDetails with the three underlying transactions

    @edge @ais-reads
    Scenario: A transaction with an exchange rate
      Given tx-3003 was booked in EUR from a USD amount
      When its details are read
      Then the answer carries the report exchange rate used

    @nominal @ais-reads
    Scenario: The detail view and the list agree
      Given tx-3001 in the August report
      When both are read
      Then amount, dates and counterpart are identical in the two answers

  @security
  Rule: A transaction is served only through the account and consent it belongs to

    @error @ais-reads
    Scenario: A transaction of another account is refused
      Given tx-4001 belongs to Savings
      When it is read under the Main Account resourceId
      Then the answer is 404 RESOURCE_UNKNOWN

    @error @ais-reads
    Scenario: An unknown transaction id is refused
      Given no transaction tx-9999
      When it is read
      Then the answer is 404 RESOURCE_UNKNOWN

    @error @ais-reads
    Scenario: A consent without transactions is refused
      Given consent 123cons456 grants accounts and balances only
      When a transaction detail is read
      Then the answer is 401 CONSENT_INVALID

    @nominal @ais-reads
    Scenario: The transaction id is opaque
      Given any transaction id
      When it is inspected
      Then it reveals no IBAN, no PAN and no core banking key

  @spec-6
  Rule: A detail read follows the same access rules as any other read

    @nominal @ais-reads
    Scenario: A background read counts once
      Given the counter for Main Account is 1 and no PSU-IP-Address
      When the detail is read
      Then the counter is 2

    @error @ais-reads
    Scenario: A booking older than ninety days needs the PSU
      Given tx-2001 was booked 100 days ago and no PSU-IP-Address
      When its details are read
      Then the answer is 401 CONSENT_INVALID
