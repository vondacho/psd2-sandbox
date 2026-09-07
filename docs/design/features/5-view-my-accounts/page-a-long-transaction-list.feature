# Generated from docs/design/examplemap/5-view-my-accounts/page-a-long-transaction-list.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-4.15 @ais-reads @analysing
Feature: Page a long transaction list
  As TPP operator
  I want a next link when the report does not fit one response
  So that a long history is read without guessing offsets

  @spec-4.15
  Rule: A report longer than the page size is split, and every page but the last carries a next link

    @nominal @ais-reads
    Scenario: Three hundred bookings over two pages
      Given the page size is 200 and the period holds 300 booked entries
      When the TPP calls the transactions endpoint
      Then the answer holds 200 entries and _links.next
      When the TPP follows _links.next
      Then the answer holds the remaining 100 entries and no next link

    @nominal @ais-reads
    Scenario: A report that fits one page has no next link
      Given the period holds 3 entries
      When the report is read
      Then the answer has no _links.next

    @edge @ais-reads
    Scenario: An empty report has no next link
      Given the period holds no entry
      When the report is read
      Then booked is empty and there is no next link

    @nominal @ais-reads
    Scenario: The pages together are the whole report, with nothing repeated
      Given the 300 entries
      When both pages are concatenated
      Then every entry appears exactly once and the order is preserved

  @security
  Rule: The next link is opaque, bound to the request that produced it, and expires

    @nominal @ais-reads
    Scenario: The link carries a cursor, not an offset the TPP can craft
      Given a next link
      When it is inspected
      Then its query holds an opaque cursor and no page number or IBAN

    @error @ais-reads
    Scenario: A cursor of another consent is refused
      Given a cursor issued under consent 111cons222
      When it is followed with Consent-ID 123cons456
      Then the answer is 401 CONSENT_INVALID

    @error @ais-reads
    Scenario: A cursor older than an hour is refused
      Given a cursor issued 61 minutes ago
      When it is followed
      Then the answer is 400 FORMAT_ERROR with text 'cursor expired'
      And the TPP restarts the report from its period

    @error @ais-reads
    Scenario: A tampered cursor is refused
      Given a cursor with one character changed
      When it is followed
      Then the answer is 400 FORMAT_ERROR

  @spec-6
  Rule: Following a page counts as one access, and the report is stable while it is paged

    @nominal @ais-reads
    Scenario: Two pages count one access, not two
      Given the counter for Main Account is 0 and no PSU-IP-Address
      When the first page and its next page are read
      Then the counter is 1

    @edge @ais-reads
    Scenario: A booking added between pages does not shift the pages
      Given the first page was served
      When a new booking arrives and the next page is read
      Then the second page holds the entries that followed the cursor, and the new booking is not inserted in the middle
