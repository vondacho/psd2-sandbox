# Generated from docs/design/examplemap/9-follow-the-payment/serve-the-payment-resource.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-5.6 @pis-core @analysing
Feature: Serve the payment resource
  As TPP operator
  I want GET on the payment to return the instruction as the Bank stored it
  So that the client can show what was actually initiated

  @spec-5.6
  Rule: The payment resource returns the instruction the Bank holds, with its status

    @nominal @pis-core
    Scenario: The stored instruction of pay001
      Given pay001 accepted for execution
      When the TPP calls GET /v1/payments/sepa-credit-transfers/pay001
      Then the answer is 200 with instructedAmount {currency: EUR, amount: '12.50'}, debtorAccount DE23100100100123456789, creditorName 'Payee X', creditorAccount DE12500105170648489890, remittanceInformationUnstructured 'Invoice 42' and transactionStatus ACTC

    @edge @pis-core
    Scenario: A debtor account chosen at the Bank is echoed
      Given pay002 was initiated without a debtor account and Anna chose Main Account
      When the payment is read
      Then debtorAccount is DE23100100100123456789

    @nominal @pis-core
    Scenario: The answer never carries the PSU's identity
      Given any payment answer
      When its fields are listed
      Then there is no psuId, no customer number and no device data

    @edge @pis-core
    Scenario: A rejected payment is still readable
      Given pay001 is RJCT
      When it is read
      Then the answer is 200 with the instruction and transactionStatus RJCT

  @spec-4.11.1
  Rule: The resource is served under the service and product it was created with

    @nominal @pis-core
    Scenario: The right path serves the payment
      Given pay001 created as a sepa-credit-transfers payment
      When it is read under /v1/payments/sepa-credit-transfers/pay001
      Then the answer is 200

    @error @pis-core
    Scenario: Another product in the path does not find it
      Given the same payment
      When it is read under /v1/payments/instant-sepa-credit-transfers/pay001
      Then the answer is 403 RESOURCE_UNKNOWN

    @error @pis-core
    Scenario: Another service in the path does not find it
      Given the same payment
      When it is read under /v1/bulk-payments/sepa-credit-transfers/pay001
      Then the answer is 404 SERVICE_INVALID

  @security
  Rule: The same access rules as the status endpoint apply

    @error @pis-core
    Scenario: Another TPP is refused
      Given the other TPP's certificate
      When pay001 is read
      Then the answer is 403 RESOURCE_UNKNOWN

    @error @pis-core
    Scenario: A token scoped to another payment is refused
      Given a token with scope PIS:pay002
      When pay001 is read
      Then the answer is 401 TOKEN_INVALID

    @edge @pis-core
    Scenario: Reading before the SCA is allowed for the creator
      Given pay001 is RCVD and the TPP holds no token yet
      When it is read with the TPP's certificate
      Then the answer is 200, because the creator may read what it created
