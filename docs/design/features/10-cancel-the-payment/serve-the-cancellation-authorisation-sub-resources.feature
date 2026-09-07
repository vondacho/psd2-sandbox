# Generated from docs/design/examplemap/10-cancel-the-payment/serve-the-cancellation-authorisation-sub-resources.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-5.8 @pis-cancellation @ready
Feature: Serve the cancellation authorisation sub-resources
  As TPP operator
  I want the cancellation authorisations listed and their SCA status readable
  So that the client can steer the cancellation like any other authorisation

  @spec-5.8
  Rule: The cancellation authorisations of a payment are listed and read under their own endpoint

    @nominal @pis-cancellation
    Scenario: The list after a cancellation was started
      Given pay002 has the cancellation authorisation pay002cancauth1
      When the TPP calls GET /v1/payments/sepa-credit-transfers/pay002/cancellation-authorisations
      Then the answer is 200 {cancellationIds: [pay002cancauth1]}

    @nominal @pis-cancellation
    Scenario: The SCA status of one cancellation authorisation
      Given the cancellation challenge was issued
      When GET on that cancellation authorisation is called
      Then the answer is 200 {scaStatus: started}

    @edge @pis-cancellation
    Scenario: An empty list before any cancellation was started
      Given pay001 with no cancellation
      When the list is read
      Then the answer is 200 {cancellationIds: []}

    @nominal @pis-cancellation
    Scenario: The payment authorisations and the cancellation authorisations are different lists
      Given pay002 with both kinds
      When both endpoints are read
      Then the authorisations list holds pay002auth1 and the cancellation list holds pay002cancauth1

    @error @pis-cancellation
    Scenario: A cancellation authorisation of another payment is not found
      Given pay002cancauth1 belongs to pay002
      When it is read under pay001
      Then the answer is 403 RESOURCE_UNKNOWN

  @spec-14.16
  Rule: The status ladder of a cancellation authorisation is the SCA ladder

    @nominal @pis-cancellation
    Scenario: From received to finalised
      Given the cancellation authorisation
      When the PSU authenticates and approves on the device
      Then the status went received, psuAuthenticated, started, finalised

    @nominal @pis-cancellation
    Scenario: A denied cancellation fails its authorisation
      Given the PSU rejects the cancellation challenge
      When the outcome is recorded
      Then the scaStatus is failed and the payment keeps its status

    @edge @pis-cancellation
    Scenario: Polling the status while the PSU approves
      Given the client polls every two seconds
      When the PSU approves
      Then the next poll answers finalised

  @security
  Rule: Only the creating TPP reads the cancellation authorisations

    @error @pis-cancellation
    Scenario: Another TPP is refused
      Given the other TPP's certificate
      When the cancellation list of pay002 is read
      Then the answer is 403 RESOURCE_UNKNOWN

    @nominal @pis-cancellation
    Scenario: The status carries no PSU data
      Given any cancellation authorisation answer
      When its fields are listed
      Then it holds the SCA status and links only
