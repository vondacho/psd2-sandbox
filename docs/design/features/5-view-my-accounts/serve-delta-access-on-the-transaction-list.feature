# Generated from docs/design/examplemap/5-view-my-accounts/serve-delta-access-on-the-transaction-list.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.5.4 @ais-reads @analysing
Feature: Serve delta access on the transaction list
  As TPP operator
  I want entryReferenceFrom or deltaList to return only what changed since my last read
  So that a daily sync does not download the whole history

  @spec-6.5.4
  Rule: entryReferenceFrom returns the entries booked after the named entry

    @nominal @ais-reads
    Scenario: Everything after the last entry of the previous read
      Given the previous report ended with entryReference ent-2026-08-15-01
      And two bookings were added since: ent-2026-08-28-01 and ent-2026-09-02-01
      When the TPP calls with bookingStatus=booked&entryReferenceFrom=ent-2026-08-15-01
      Then the answer is 200 with exactly those two entries
      And the entry ent-2026-08-15-01 itself is not repeated

    @edge @ais-reads
    Scenario: Nothing new since the last read
      Given no booking after ent-2026-09-02-01
      When entryReferenceFrom=ent-2026-09-02-01 is called
      Then the answer is 200 with booked: []

    @error @ais-reads
    Scenario: An unknown entry reference is refused
      Given no entry ent-nope
      When entryReferenceFrom=ent-nope is called
      Then the answer is 400 FORMAT_ERROR naming entryReferenceFrom

    @error @ais-reads
    Scenario: An entry reference of another account is refused
      Given ent-2026-08-28-01 belongs to Main Account
      When it is used on the Savings resourceId
      Then the answer is 400 FORMAT_ERROR

    @edge @ais-reads
    Scenario: A pending entry has no entry reference to continue from
      Given a pending entry
      When the report is built
      Then the pending entry carries no entryReference and delta reads stay on booked entries

  @spec-6.5.4
  Rule: deltaList returns everything that changed since the last delta read of this consent

    @nominal @ais-reads
    Scenario: New bookings and status changes since the last delta read
      Given the last delta read for consent 123cons456 on Main Account was at 2026-09-06T09:00Z
      And one booking was added and one pending entry became booked since
      When the TPP calls with bookingStatus=both&deltaList=true
      Then the answer holds the new booking and the entry that changed status

    @edge @ais-reads
    Scenario: The first delta read has no starting point
      Given no earlier delta read for this consent and account
      When deltaList=true is called
      Then the answer is 400 FORMAT_ERROR with text 'no previous delta read'

    @edge @ais-reads
    Scenario: The delta cursor is kept per consent and account
      Given the TPP read a delta for Main Account and never for Savings
      When a delta read is made on Savings
      Then the answer is 400 FORMAT_ERROR, and the Main Account cursor is untouched

  @spec-6.5.4
  Rule: The delta parameters replace the period and are mutually exclusive

    @error @ais-reads
    Scenario: entryReferenceFrom together with dateFrom is refused
      Given entryReferenceFrom=ent-2026-08-15-01 and dateFrom=2026-08-01
      When the call is made
      Then the answer is 400 FORMAT_ERROR

    @error @ais-reads
    Scenario: entryReferenceFrom together with deltaList is refused
      Given both delta parameters
      When the call is made
      Then the answer is 400 FORMAT_ERROR

    @nominal @ais-reads
    Scenario: A delta read alone needs no period
      Given entryReferenceFrom only
      When the call is made
      Then the answer is 200

  @security
  Rule: Delta access does not widen what the consent allows

    @error @ais-reads
    Scenario: The ninety-day limit still applies without the PSU
      Given the named entry is older than ninety days and no PSU-IP-Address
      When the delta read is made
      Then the answer is 401 CONSENT_INVALID with text 'transactions older than 90 days require PSU presence'

    @nominal @ais-reads
    Scenario: A delta read counts against the frequency
      Given the counter for Main Account is 3 of 4 and no PSU-IP-Address
      When the delta read is made
      Then the answer is 200 and the counter is 4
