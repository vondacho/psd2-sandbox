# Generated from docs/design/examplemap/6-come-back-later/initiate-a-payment-with-the-same-infrastructure.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @bank-xs2a @oidc-provider @pis @spec-5.1.5 @hardening @analysing
Feature: Initiate a payment with the same infrastructure
  As PSU
  I want to pay from a connected account with the same QR approval
  So that the Bank is PISP compliant with one SCA journey

  @spec-5.1.5
  Rule: POST /v1/payments/{product} with a PISP certificate creates a payment in status RCVD with an implicit authorisation and a scaOAuth link

    @nominal @hardening
    Scenario: A SEPA credit transfer
      Given the TPP's QWAC with PSP_PI and the body {instructedAmount: {currency: EUR, amount: '12.50'}, debtorAccount: {iban: DE23100100100123456789}, creditorName: 'Payee X', creditorAccount: {iban: DE89370400440532013000}, remittanceInformationUnstructured: 'Invoice 42'}
      When the TPP calls POST /v1/payments/sepa-credit-transfers
      Then the answer is 201 {transactionStatus: RCVD, paymentId: pay001, _links: {scaOAuth, scaStatus, self, status}} with ASPSP-SCA-Approach REDIRECT

    @error @hardening
    Scenario: An AISP-only certificate
      Given a QWAC with PSP_AI only
      When the payment is posted
      Then the answer is 401 ROLE_INVALID

    @error @hardening
    Scenario: An unknown product
      Given POST /v1/payments/space-credit-transfers
      When it is called
      Then the answer is 404 PRODUCT_UNKNOWN

    @error @hardening
    Scenario: A zero amount
      Given amount '0.00'
      When the payment is posted
      Then the answer is 400 FORMAT_ERROR with path instructedAmount.amount

    @error @hardening
    Scenario: A negative amount
      Given amount '-5.00'
      When the payment is posted
      Then the answer is 400 FORMAT_ERROR

    @error @hardening
    Scenario: An invalid debtor IBAN
      Given debtorAccount.iban DE00000000000000000000
      When the payment is posted
      Then the answer is 400 FORMAT_ERROR with path debtorAccount.iban

  @rts-art-5
  Rule: The same OAuth2 and SCA journey runs with scope PIS:<paymentId>; the CIAM and the app show the payment, and the dynamic link covers amount, payee and payment id

    @nominal @hardening
    Scenario: The payment journey
      Given payment pay001
      When the TPP redirects to the OIDC-provider with scope PIS:pay001 and Anna logs in at the Bank
      Then the CIAM shows 'TPP App wants to pay 12.50 EUR to Payee X from Main Account'
      And the challenge hash covers 'pay001|PSDDE-BAFIN-123456|12.50 EUR|DE89370400440532013000|Payee X'
      And the app shows 'Pay 12.50 EUR to Payee X from Main Account' and Anna approves with Face ID
      And the OIDC-provider issues a token with scope PIS:pay001 and the payment moves to ACCP

    @error @hardening
    Scenario: An AIS approval cannot be replayed for a payment
      Given a valid signature over an AIS challenge of Anna
      When it is posted for the payment challenge
      Then the SCA engine answers 400 'signature invalid'

    @error @hardening
    Scenario: The OIDC-provider validates the PIS scope against the payment
      Given scope PIS:pay999 for an unknown payment
      When the TPP requests it
      Then the OIDC-provider redirects with error=invalid_scope

    @nominal @hardening
    Scenario: The payment status
      Given the approved payment
      When the TPP calls GET /v1/payments/sepa-credit-transfers/pay001/status with the PIS token
      Then the answer is {transactionStatus: ACCP}

    @error @hardening
    Scenario: A denied payment
      Given Anna rejects in the app
      When the TPP reads the status
      Then the answer is {transactionStatus: RJCT}

  @spec-9
  Rule: A combined service session reuses the consent's first factor

    @edge @hardening
    Scenario: Payment right after the consent
      Given consent 123cons456 created with combinedServiceIndicator true and authorised two minutes ago
      When the TPP posts a payment with Consent-ID 123cons456 and starts the PIS authorization
      Then the CIAM skips the login and goes straight to the payment summary and the QR

    @nominal @hardening
    Scenario: Without the indicator the login is asked again
      Given a consent with combinedServiceIndicator false
      When the TPP starts a payment
      Then the CIAM asks for the password again
