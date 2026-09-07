# Generated from docs/design/examplemap/7-create-the-payment/serve-post-v1-payments-payment-product.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-5.3.1 @spec-4.11.1 @pis-core @analysing
Feature: Serve POST /v1/payments/{payment-product}
  As TPP operator
  I want a 201 with paymentId, transactionStatus RCVD and the steering links
  So that the payment can be authorised in the next step

  @spec-5.3.1
  Rule: A valid single payment creates a payment resource in status RCVD

    @nominal @pis-core
    Scenario: A SEPA credit transfer of 12.50 EUR
      Given the TPP's QWAC carries the PISP role and X-Request-ID is a fresh UUID
      And the body is {instructedAmount: {currency: EUR, amount: '12.50'}, debtorAccount: {iban: DE23100100100123456789}, creditorName: 'Payee X', creditorAccount: {iban: DE12500105170648489890}, remittanceInformationUnstructured: 'Invoice 42'}
      When POST /v1/payments/sepa-credit-transfers is called
      Then the answer is 201 with transactionStatus RCVD, paymentId pay001 and Location /psd2/v1/payments/sepa-credit-transfers/pay001
      And the ASPSP-SCA-Approach header is REDIRECT

    @nominal @pis-core
    Scenario: The payment is stored as the Bank read it
      Given the created payment pay001
      When the resource is read in payment initiation
      Then it holds the amount, both accounts, the creditor name, the remittance, the TPP id and createdAt

    @edge @pis-core
    Scenario: Two initiations create two payments
      Given the same body sent twice with different X-Request-ID values
      When both answers arrive
      Then two payment ids exist, both RCVD

    @nominal @pis-core
    Scenario: X-Request-ID is echoed
      Given X-Request-ID 6b2d1f4a-…
      When the payment is created
      Then the response carries the same X-Request-ID

    @edge @pis-core
    Scenario: A debtor account the PSU does not hold is refused at authorisation
      Given debtorAccount DE75512108001245126199, which belongs to Ben
      When Anna authenticates for pay001
      Then the payment is rejected with RJCT and text 'debtor account not held by the PSU'

    @edge @pis-core
    Scenario: A payment without debtorAccount is accepted and the account is chosen at the Bank
      Given a body without debtorAccount
      When the payment is created and Anna authenticates
      Then the Bank's review screen asks her which account to pay from

  @security @spec-3
  Rule: Only a certificate carrying the PISP role may initiate a payment

    @error @pis-core
    Scenario: An AISP-only certificate is refused
      Given a QWAC with the role PSP_AI only
      When POST /v1/payments/sepa-credit-transfers is called
      Then the answer is 401 ROLE_INVALID and no payment is created

    @error @pis-core
    Scenario: A revoked certificate is refused
      Given the TPP's QWAC is on the revocation list
      When the payment is initiated
      Then the answer is 401 CERTIFICATE_REVOKED

    @error @pis-core
    Scenario: No client certificate at all
      Given a connection without a client certificate
      When the payment is initiated
      Then the connection is refused at the TLS handshake

    @nominal @pis-core
    Scenario: The payment belongs to the initiating TPP
      Given pay001 created by PSDDE-BAFIN-123456
      When another TPP reads it with its own certificate
      Then the answer is 403 RESOURCE_UNKNOWN

  @spec-4.8 @spec-4.10
  Rule: The redirect URIs and PSU context of the initiation are stored with the payment

    @nominal @pis-core
    Scenario: The redirect URIs are kept for the authorisation
      Given TPP-Redirect-URI https://tpp.sandbox/xs2a/callback/bank and its nok variant
      When the payment is created
      Then both are stored on the payment and used when the PSU returns

    @error @pis-core
    Scenario: A redirect URI outside the certificate domain is refused
      Given TPP-Redirect-URI https://evil.example/cb
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming TPP-Redirect-URI

    @nominal @pis-core
    Scenario: The PSU context is passed to the risk engine
      Given PSU-IP-Address, PSU-User-Agent and PSU-Device-ID are sent
      When the payment is created
      Then the risk engine receives them with the payment
