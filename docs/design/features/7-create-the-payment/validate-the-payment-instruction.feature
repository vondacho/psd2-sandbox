# Generated from docs/design/examplemap/7-create-the-payment/validate-the-payment-instruction.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-5.3.1 @pis-core @analysing
Feature: Validate the payment instruction
  As Bank security officer
  I want amount, currency, debtor and creditor accounts and the remittance checked before a resource exists
  So that a malformed instruction never reaches the core banking

  @spec-5.3.1
  Rule: The mandatory fields of a single payment must be present and well formed

    @error @pis-core
    Scenario: A missing instructedAmount is refused
      Given a body without instructedAmount
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming instructedAmount

    @error @pis-core
    Scenario: A missing creditorAccount is refused
      Given a body without creditorAccount
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming creditorAccount

    @error @pis-core
    Scenario: A missing creditorName is refused
      Given a body without creditorName
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming creditorName

    @error @pis-core
    Scenario: A malformed IBAN is refused
      Given creditorAccount {iban: DE00000000000000000000}
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming creditorAccount.iban

    @error @pis-core
    Scenario: A body that is not JSON is refused
      Given the body 'pay please'
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR

    @error @pis-core
    Scenario: A creditor name longer than seventy characters is refused
      Given a creditorName of 71 characters
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming creditorName

    @error @pis-core
    Scenario: An unstructured remittance longer than 140 characters is refused
      Given remittanceInformationUnstructured of 141 characters
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR

  @spec-14.3
  Rule: The amount must be positive, in the currency the product allows, with two decimals

    @error @pis-core
    Scenario: A zero amount is refused
      Given amount '0.00'
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming instructedAmount.amount

    @error @pis-core
    Scenario: A negative amount is refused
      Given amount '-5.00'
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR

    @error @pis-core
    Scenario: Three decimals are refused for EUR
      Given amount '12.505'
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR

    @edge @pis-core
    Scenario: An amount without decimals is accepted
      Given amount '12'
      When the payment is initiated
      Then the answer is 201 and the stored amount is 12.00

    @error @pis-core
    Scenario: A currency the product does not carry is refused
      Given currency USD on sepa-credit-transfers
      When the payment is initiated
      Then the answer is 400 FORMAT_ERROR naming instructedAmount.currency

    @edge @pis-core
    Scenario: An amount above the Bank's per-payment limit is refused
      Given the sandbox limit is 10000.00 EUR and the amount is 10000.01
      When the payment is initiated
      Then the answer is 400 PAYMENT_FAILED with text 'amount above the limit'

  @spec-4.13
  Rule: Validation happens before any resource exists, and reports every field it can at once

    @nominal @pis-core
    Scenario: No payment resource is created on a refusal
      Given an invalid body
      When the payment is refused
      Then no paymentId is returned and nothing is stored

    @edge @pis-core
    Scenario: Several bad fields are reported together
      Given a body with a zero amount and no creditorName
      When the payment is refused
      Then tppMessages holds one entry per faulty field, each with its path

    @nominal @pis-core
    Scenario: The error body follows the standard shape
      Given any refusal
      When the body is inspected
      Then it is {tppMessages: [{category: ERROR, code: FORMAT_ERROR, path: …, text: …}]}
