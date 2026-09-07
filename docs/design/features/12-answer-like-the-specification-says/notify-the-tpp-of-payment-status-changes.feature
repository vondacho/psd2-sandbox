# Generated from docs/design/examplemap/12-answer-like-the-specification-says/notify-the-tpp-of-payment-status-changes.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @conformance @analysing
Feature: Notify the TPP of payment status changes
  As TPP operator
  I want a signed notification when a payment reaches a final status
  So that I do not learn about an execution from a polling loop

  Rule: A payment that reaches a final status notifies the URI the initiation carried

    @nominal @conformance
    Scenario: A settled payment notifies
      Given pay001 was initiated with a notification URI and reaches ACSC
      When the status change is recorded
      Then within five seconds the Bank posts {paymentId: pay001, transactionStatus: ACSC, timestamp: …} to that URI

    @nominal @conformance
    Scenario: A rejected payment notifies
      Given pay001 reaches RJCT
      When the change is recorded
      Then a notification with RJCT is posted

    @nominal @conformance
    Scenario: A cancelled payment notifies
      Given pay002 reaches CANC
      When the change is recorded
      Then a notification with CANC is posted

    @edge @conformance
    Scenario: An intermediate status does not notify
      Given pay001 moves from RCVD to ACTC
      When the change is recorded
      Then no notification is posted, because ACTC is not final

    @edge @conformance
    Scenario: A payment initiated without a notification URI notifies nobody
      Given pay003 was initiated without the header
      When it reaches ACSC
      Then nothing is posted

  @security
  Rule: The notification is signed and carries no more than the status

    @nominal @conformance
    Scenario: The notification is signed with the Bank's sealing certificate
      Given a notification
      When its headers are read
      Then it carries Digest, Signature and the Bank's signing certificate
      And the TPP can verify it before acting

    @nominal @conformance
    Scenario: The body carries no payment detail
      Given a notification body
      When its fields are listed
      Then it holds the payment id, the status and a timestamp, and no amount, payee or PSU

    @edge @conformance
    Scenario: An unsigned notification is one a TPP should ignore
      Given a client receiving an unsigned post on its notification URI
      When it verifies the signature
      Then the verification fails and the client ignores the message

  Rule: Delivery is retried, then given up, and the interface remains the source of truth

    @error @conformance
    Scenario: A failing endpoint is retried with a backoff
      Given the TPP's notification URI answers 503
      When the Bank delivers
      Then it retries after 1, 5, 30, 120 and 600 minutes, then stops

    @nominal @conformance
    Scenario: The status endpoint still tells the truth after a failed delivery
      Given every delivery failed
      When the TPP reads the payment status
      Then the answer is the current status

    @edge @conformance
    Scenario: A duplicate notification is harmless
      Given the same notification is delivered twice
      When the client handles it
      Then the payment id and the status let it recognise the duplicate
