# Generated from docs/design/examplemap/6-come-back-later/limit-the-transaction-history-without-a-fresh-sca.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @security @rts-art-10 @access-rules @analysing
Feature: Limit the transaction history without a fresh SCA
  As Bank security officer
  I want transactions older than ninety days served only when the PSU is authenticated
  So that the exemption for account information stays within its limits

  @rts-art-10
  Rule: Without the PSU present, a transaction report reaches back ninety days and no further

    @nominal @access-rules
    Scenario: A period inside the window is served
      Given today is 2026-09-07 and no PSU-IP-Address
      When transactions are read with dateFrom=2026-08-01
      Then the answer is 200

    @error @access-rules
    Scenario: A period reaching further back is refused
      Given the same call without the PSU
      When dateFrom=2026-01-01 is used
      Then the answer is 401 CONSENT_INVALID with text 'transactions older than 90 days require PSU presence'

    @edge @access-rules
    Scenario: Exactly ninety days back is served
      Given today is 2026-09-07 and no PSU-IP-Address
      When dateFrom=2026-06-09 is used
      Then the answer is 200

    @edge @access-rules
    Scenario: One day beyond is refused
      Given the same call
      When dateFrom=2026-06-08 is used
      Then the answer is 401 CONSENT_INVALID

    @edge @access-rules
    Scenario: The window moves with the day
      Given a period accepted yesterday at its oldest edge
      When the same period is read a day later without the PSU
      Then the answer is 401 CONSENT_INVALID

  @rts-art-10
  Rule: With the PSU present, the whole history the Bank holds is served

    @nominal @access-rules
    Scenario: A long period with the PSU present
      Given PSU-IP-Address is sent
      When dateFrom=2026-01-01 is used
      Then the answer is 200 with the bookings of that period

    @nominal @access-rules
    Scenario: A transaction detail older than ninety days with the PSU
      Given tx-2001 booked 100 days ago and PSU-IP-Address sent
      When its details are read
      Then the answer is 200

    @error @access-rules
    Scenario: The same detail without the PSU
      Given no PSU-IP-Address
      When tx-2001 is read
      Then the answer is 401 CONSENT_INVALID

  Rule: The limit applies to delta reads and to what the Bank actually returns

    @error @access-rules
    Scenario: A delta read that would cross the window is refused
      Given entryReferenceFrom names an entry booked 100 days ago and no PSU-IP-Address
      When the delta read is made
      Then the answer is 401 CONSENT_INVALID

    @edge @access-rules
    Scenario: A period that starts inside the window returns nothing older
      Given dateFrom inside the window and bookings older than it in the ledger
      When the report is built
      Then no entry older than dateFrom is returned

    @nominal @access-rules
    Scenario: Balances are not limited by the window
      Given no PSU-IP-Address
      When the balances are read
      Then the answer is 200, because a balance has no history
