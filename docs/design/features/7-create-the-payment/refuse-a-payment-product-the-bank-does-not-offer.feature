# Generated from docs/design/examplemap/7-create-the-payment/refuse-a-payment-product-the-bank-does-not-offer.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-14.11 @pis-core @ready
Feature: Refuse a payment product the Bank does not offer
  As Bank security officer
  I want an unknown payment service or product refused with PRODUCT_UNKNOWN
  So that only the products the Bank sells can be initiated

  @spec-4.11.1
  Rule: The payment product in the path must be one the Bank offers

    @nominal @pis-core
    Scenario: The offered product is accepted
      Given the sandbox offers sepa-credit-transfers
      When POST /v1/payments/sepa-credit-transfers is called
      Then the answer is 201

    @error @pis-core
    Scenario: An unknown product is refused
      Given the same sandbox
      When POST /v1/payments/space-credit-transfers is called
      Then the answer is 404 PRODUCT_UNKNOWN

    @error @pis-core
    Scenario: A product the specification defines but the Bank does not offer is refused
      Given the sandbox does not offer cross-border-credit-transfers
      When it is used in the path
      Then the answer is 404 PRODUCT_UNKNOWN and the message names the products on offer

    @edge @pis-core
    Scenario: The product is case-sensitive
      Given the path segment SEPA-Credit-Transfers
      When the payment is initiated
      Then the answer is 404 PRODUCT_UNKNOWN

  @spec-4.11.1
  Rule: The payment service in the path must be one the Bank offers

    @nominal @pis-core
    Scenario: Single payments are offered
      Given the path segment payments
      When a payment is initiated
      Then the answer is 201

    @error @pis-core
    Scenario: Bulk payments are refused while they are not implemented
      Given the sandbox does not implement bulk-payments
      When POST /v1/bulk-payments/sepa-credit-transfers is called
      Then the answer is 404 SERVICE_INVALID

    @error @pis-core
    Scenario: Periodic payments are refused while they are not implemented
      Given the same sandbox
      When POST /v1/periodic-payments/sepa-credit-transfers is called
      Then the answer is 404 SERVICE_INVALID

    @error @pis-core
    Scenario: An unknown service is refused
      Given the path segment donations
      When it is called
      Then the answer is 404 SERVICE_INVALID

  Rule: What the Bank offers is discoverable rather than guessed

    @nominal @pis-core
    Scenario: The refusal names what is available
      Given a refusal for an unknown product
      When the body is read
      Then the text lists the payment services and products the sandbox offers

    @edge @pis-core
    Scenario: The offered products are a configuration parameter
      Given the sandbox is configured with sepa-credit-transfers and instant-sepa-credit-transfers
      When both are used
      Then both answer 201
