# Generated from docs/design/examplemap/9-follow-the-payment/move-the-transaction-status-through-its-lifecycle.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-14.13 @pis-core @analysing
Feature: Move the transaction status through its lifecycle
  As Bank product owner
  I want RCVD, ACTC, ACSC and RJCT reached only through the allowed transitions
  So that a status never moves backwards or skips a step

  @spec-14.13
  Rule: A payment starts at RCVD and reaches a final status through the allowed steps only

    @nominal @pis-core
    Scenario: The nominal ladder
      Given pay001 created
      When the SCA is finalised and the core books the payment
      Then the status went RCVD, then ACTC, then ACSC

    @nominal @pis-core
    Scenario: A rejection before acceptance
      Given pay001 at RCVD
      When the PSU denies the challenge
      Then the status is RJCT

    @nominal @pis-core
    Scenario: A rejection by the core after acceptance
      Given pay001 at ACTC
      When the core refuses it for insufficient funds
      Then the status is RJCT

    @edge @pis-core
    Scenario: A cancellation after acceptance
      Given pay002 at ACTC and not yet settled
      When the cancellation is authorised
      Then the status is CANC

    @edge @pis-core
    Scenario: ACSC is final
      Given pay001 at ACSC
      When any later event arrives
      Then the status stays ACSC

    @edge @pis-core
    Scenario: RJCT is final
      Given pay001 at RJCT
      When an approval outcome arrives late
      Then the status stays RJCT

    @error @pis-core
    Scenario: A status never moves backwards
      Given pay001 at ACTC
      When an internal call tries to set RCVD
      Then the call is refused and the change is logged as rejected

    @error @pis-core
    Scenario: A skipped step is refused
      Given pay001 at RCVD
      When an internal call tries to set ACSC
      Then the call is refused

  Rule: Every status change is timestamped and readable through the interface

    @nominal @pis-core
    Scenario: The change is visible to the TPP at once
      Given the core booked pay001 at 09:20:00Z
      When the TPP reads the status at 09:20:01Z
      Then the answer is ACSC

    @nominal @pis-core
    Scenario: The history is kept for audit
      Given pay001 at ACSC
      When the audit trail is read
      Then it holds RCVD, ACTC and ACSC with their timestamps and their causes

    @edge @pis-core
    Scenario: A notification is sent when the payment reaches a final status
      Given the TPP registered a notification URI
      When pay001 reaches ACSC
      Then a notification is posted for that payment

  @spec-14.13
  Rule: The status vocabulary is the one of the specification, not a bank dialect

    @nominal @pis-core
    Scenario: Only defined codes are served
      Given every status the sandbox can return
      When they are listed
      Then each is one of RCVD, ACTC, ACSC, RJCT and CANC

    @edge @pis-core
    Scenario: An internal state does not leak
      Given the payment is queued inside the core
      When the status is read
      Then the answer is ACTC, not an internal queue state
