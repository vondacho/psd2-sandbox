# Generated from docs/design/examplemap/9-follow-the-payment/execute-the-payment-at-the-core-banking.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-core @pis-core @analysing
Feature: Execute the payment at the core banking
  As Bank product owner
  I want funds and limits checked, then the payment booked or rejected
  So that the transaction status reflects what the ledger did

  Rule: A payment is handed to the core only after it is accepted for execution

    @nominal @pis-core
    Scenario: Execution starts at ACTC
      Given pay001 moved to ACTC
      When the execution job runs
      Then the core receives the instruction once

    @nominal @pis-core
    Scenario: A payment at RCVD is never executed
      Given pay001 at RCVD
      When the execution job runs
      Then the core receives nothing

    @nominal @pis-core
    Scenario: A cancelled payment is not executed
      Given pay002 moved to CANC before the job ran
      When the job runs
      Then the core receives nothing

    @edge @pis-core
    Scenario: The instruction is handed over once, even after a retry
      Given the job crashed after handing pay001 over
      When it runs again
      Then the core recognises the payment id and does not book twice

  Rule: The core checks funds and limits, and its answer drives the status

    @nominal @pis-core
    Scenario: Enough funds: the payment is booked
      Given Main Account holds 1250.30 EUR and the payment is 12.50 EUR
      When the core executes it
      Then the account is debited by 12.50 and the status becomes ACSC

    @error @pis-core
    Scenario: Not enough funds: the payment is rejected
      Given Main Account holds 5.00 EUR
      When the core executes the payment
      Then nothing is debited and the status becomes RJCT with a reason

    @error @pis-core
    Scenario: Above the daily limit: the payment is rejected
      Given the daily payment limit of the account is reached
      When the core executes the payment
      Then the status becomes RJCT

    @error @pis-core
    Scenario: A blocked account is rejected
      Given Main Account is blocked in the ledger
      When the core executes the payment
      Then the status becomes RJCT

    @nominal @pis-core
    Scenario: The debit appears in the account's transactions
      Given pay001 was booked
      When the transactions of Main Account are read with a consent that grants them
      Then a booking of -12.50 EUR to Payee X is in the list

  Rule: The core is reached through an adapter, so its vocabulary never reaches the TPP

    @nominal @pis-core
    Scenario: A core error code becomes a specification code
      Given the core answers with its own error 'E-4711 insufficient cover'
      When the adapter translates it
      Then the interface answers RJCT with the code PAYMENT_FAILED

    @error @pis-core
    Scenario: The core being unavailable leaves the payment accepted
      Given the core does not answer
      When the job runs
      Then the status stays ACTC and the job retries later
      And an operational alert is raised
