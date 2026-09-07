# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/serve-an-explicit-start-of-the-authorisation-process.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-7.1 @authorisation-resources @analysing
Feature: Serve an explicit start of the authorisation process
  As TPP operator
  I want POST on the authorisations endpoint to create an authorisation when I ask for it explicitly
  So that I control when the PSU is sent to authenticate

  @spec-7.1
  Rule: With the explicit preference, the resource is created without an authorisation and offers a start link

    @nominal @authorisation-resources
    Scenario: A consent created for an explicit start
      Given TPP-Explicit-Authorisation-Preferred: true on POST /v1/consents
      When the consent is created
      Then the answer is 201 with a startAuthorisation link and no scaStatus link
      And GET on the authorisations endpoint returns an empty list

    @nominal @authorisation-resources
    Scenario: A payment created for an explicit start
      Given the same header on a payment initiation
      When the payment is created
      Then the answer carries startAuthorisation and no scaStatus

    @nominal @authorisation-resources
    Scenario: Without the header the authorisation is implicit
      Given no such header
      When the consent is created
      Then the answer carries scaStatus and the authorisation exists

  @spec-7.1
  Rule: POST on the authorisations endpoint creates one authorisation in status received and returns its links

    @nominal @authorisation-resources
    Scenario: The explicit start of a consent authorisation
      Given consent 123cons456 created with an explicit preference
      When the TPP calls POST /v1/consents/123cons456/authorisations with an empty body
      Then the answer is 201 with authorisationId 123auth567, scaStatus received and the scaStatus and scaOAuth links

    @nominal @authorisation-resources
    Scenario: The explicit start of a payment authorisation
      Given pay001 created with an explicit preference
      When POST on its authorisations endpoint is called
      Then the answer is 201 with a new authorisation in status received

    @error @authorisation-resources
    Scenario: A second explicit start is refused for a single-signature resource
      Given one authorisation already exists on 123cons456
      When POST is called again
      Then the answer is 409 STATUS_INVALID

    @error @authorisation-resources
    Scenario: An explicit start on a resource that is already valid is refused
      Given consent 123cons456 is valid
      When POST on its authorisations is called
      Then the answer is 409 STATUS_INVALID

    @error @authorisation-resources
    Scenario: An explicit start by another TPP is refused
      Given the other TPP's certificate
      When POST on the authorisations of 123cons456 is called
      Then the answer is 403 CONSENT_UNKNOWN

    @edge @authorisation-resources
    Scenario: The body may carry the PSU identification
      Given a body with psuData {password: …} in an embedded approach
      When the authorisation is started
      Then the answer is 201 and the status is psuAuthenticated

  @spec-7
  Rule: Whichever way it was created, the authorisation behaves the same afterwards

    @nominal @authorisation-resources
    Scenario: An explicitly started authorisation runs the same SCA
      Given an authorisation created by POST
      When the PSU authenticates and approves
      Then the status ladder and the challenge are the same as for an implicit one

    @nominal @authorisation-resources
    Scenario: The steering links after an explicit start point at the same places
      Given an explicit and an implicit authorisation of two consents
      When their links are compared
      Then both carry scaStatus and scaOAuth with the same shape
