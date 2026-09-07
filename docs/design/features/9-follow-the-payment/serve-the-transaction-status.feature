# Generated from docs/design/examplemap/9-follow-the-payment/serve-the-transaction-status.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-5.4 @spec-14.13 @pis-core @ready
Feature: Serve the transaction status
  As TPP operator
  I want GET .../status to return the current transaction status
  So that the PSU learns whether the payment went through

  @spec-5.4
  Rule: The status endpoint returns the transaction status of that payment and nothing more

    @nominal @pis-core
    Scenario: A payment waiting for its SCA
      Given pay001 was created and not yet authorised
      When the TPP calls GET /v1/payments/sepa-credit-transfers/pay001/status
      Then the answer is 200 {transactionStatus: RCVD}

    @nominal @pis-core
    Scenario: A payment accepted for execution
      Given pay001 is ACTC
      When the status is read
      Then the answer is {transactionStatus: ACTC}

    @nominal @pis-core
    Scenario: A settled payment
      Given pay001 is ACSC
      When the status is read
      Then the answer is {transactionStatus: ACSC}

    @nominal @pis-core
    Scenario: A rejected payment
      Given pay001 is RJCT
      When the status is read
      Then the answer is {transactionStatus: RJCT}

    @nominal @pis-core
    Scenario: A cancelled payment
      Given pay002 is CANC
      When the status is read
      Then the answer is {transactionStatus: CANC}

    @nominal @pis-core
    Scenario: The body carries no amount or payee
      Given any status answer
      When its fields are listed
      Then it holds the transaction status, and optionally a funds-available flag, and no payment detail

    @edge @pis-core
    Scenario: A rejected payment may carry the reason
      Given pay001 was rejected for insufficient funds
      When the status is read
      Then the answer may carry tppMessages explaining the rejection

  @security
  Rule: Only the TPP that created the payment reads its status, with a token scoped to it

    @nominal @pis-core
    Scenario: The creating TPP reads the status
      Given the TPP's certificate and a token with scope PIS:pay001
      When the status is read
      Then the answer is 200

    @error @pis-core
    Scenario: Another TPP is refused
      Given the other TPP's certificate
      When the status of pay001 is read
      Then the answer is 403 RESOURCE_UNKNOWN

    @error @pis-core
    Scenario: A token for another payment is refused
      Given a token with scope PIS:pay002
      When the status of pay001 is read
      Then the answer is 401 TOKEN_INVALID

    @error @pis-core
    Scenario: An unknown payment id
      Given no payment pay999
      When its status is read
      Then the answer is 403 RESOURCE_UNKNOWN

    @nominal @pis-core
    Scenario: Unknown and foreign look the same
      Given the two refusals
      When the bodies are compared
      Then they are identical apart from the request id

  @spec-5.4
  Rule: Reading a status is cheap and always allowed

    @edge @pis-core
    Scenario: Polling every two seconds is served
      Given the payment is waiting for its SCA
      When the status is polled thirty times in a minute
      Then every call answers 200

    @nominal @pis-core
    Scenario: A status read is not counted against any frequency
      Given no PSU-IP-Address
      When the status is read
      Then no usage counter changes, because a payment has no consent frequency

    @error @pis-core
    Scenario: A missing X-Request-ID is refused
      Given a status call without X-Request-ID
      When it is made
      Then the answer is 400 FORMAT_ERROR
