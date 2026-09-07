# Generated from docs/design/examplemap/7-create-the-payment/create-the-payment-authorisation-implicitly.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-4.6 @spec-7 @pis-core @ready
Feature: Create the payment authorisation implicitly
  As TPP operator
  I want the payment resource to carry an authorisation sub-resource from the start
  So that the same authorisation model serves consents and payments

  @spec-4.6
  Rule: A payment created without an explicit authorisation request carries one authorisation in status received

    @nominal @pis-core
    Scenario: The authorisation exists with the payment
      Given pay001 was just created
      When the TPP follows the scaStatus link
      Then the answer is 200 {scaStatus: received}
      And the authorisation id is pay001auth1

    @nominal @pis-core
    Scenario: The authorisation list holds exactly one entry
      Given pay001
      When GET /v1/payments/sepa-credit-transfers/pay001/authorisations is called
      Then the answer is {authorisationIds: [pay001auth1]}

    @error @pis-core
    Scenario: The authorisation belongs to that payment only
      Given pay001auth1 belongs to pay001
      When it is read under pay002
      Then the answer is 403 RESOURCE_UNKNOWN

    @edge @pis-core
    Scenario: No second authorisation is created implicitly
      Given pay001 with its implicit authorisation
      When the payment is read again
      Then the authorisation list still holds one entry

  @spec-7
  Rule: The payment authorisation is the same kind of resource as a consent authorisation

    @nominal @pis-core
    Scenario: The SCA status vocabulary is the same
      Given the payment authorisation
      When it moves through the journey
      Then it takes the values received, psuIdentified, psuAuthenticated, started, unconfirmed, finalised and failed

    @edge @pis-core
    Scenario: The status moves forward only
      Given the authorisation is finalised
      When a late update arrives
      Then it stays finalised

    @nominal @pis-core
    Scenario: The challenge is issued by the same SCA engine
      Given the payment authorisation reaches the challenge step
      When the challenge is created
      Then it is an ScaChallenge with subject kind PIS_PAYMENT and the payment id as its subject

  @spec-7.1
  Rule: When the TPP prefers an explicit start, no implicit authorisation is created

    @edge @pis-core
    Scenario: The header suppresses the implicit authorisation
      Given TPP-Explicit-Authorisation-Preferred: true on the initiation
      When the payment is created
      Then the answer carries a startAuthorisation link and no scaStatus link
      And the authorisation list is empty

    @nominal @pis-core
    Scenario: Without the header the implicit authorisation is created
      Given no TPP-Explicit-Authorisation-Preferred header
      When the payment is created
      Then the scaStatus link is present
