# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/serve-the-list-of-authorisation-sub-resources.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-7.4 @authorisation-resources @ready
Feature: Serve the list of authorisation sub-resources
  As TPP operator
  I want GET on the authorisations endpoint to list the authorisation ids of a resource
  So that I can find the authorisation I did not create myself

  @spec-7.4
  Rule: The endpoint lists the authorisation ids of that resource, and nothing else

    @nominal @authorisation-resources
    Scenario: One authorisation on a consent
      Given consent 123cons456 with the implicit authorisation 123auth567
      When GET /v1/consents/123cons456/authorisations is called
      Then the answer is 200 {authorisationIds: [123auth567]}

    @nominal @authorisation-resources
    Scenario: One authorisation on a payment
      Given pay001 with pay001auth1
      When GET on its authorisations endpoint is called
      Then the answer is 200 {authorisationIds: [pay001auth1]}

    @edge @authorisation-resources
    Scenario: An empty list before an explicit start
      Given a consent created with an explicit preference and no start yet
      When the list is read
      Then the answer is 200 {authorisationIds: []}

    @nominal @authorisation-resources
    Scenario: The list carries no status and no PSU data
      Given any answer of this endpoint
      When its fields are listed
      Then it holds authorisation ids only

    @edge @authorisation-resources
    Scenario: A finalised authorisation is still listed
      Given 123auth567 is finalised
      When the list is read
      Then it still holds 123auth567

  @security
  Rule: Only the TPP that owns the resource may list its authorisations

    @error @authorisation-resources
    Scenario: Another TPP is refused
      Given the other TPP's certificate
      When the authorisations of 123cons456 are listed
      Then the answer is 403 CONSENT_UNKNOWN

    @error @authorisation-resources
    Scenario: An unknown resource is refused the same way
      Given no consent 999cons000
      When its authorisations are listed
      Then the answer is 403 CONSENT_UNKNOWN

    @error @authorisation-resources
    Scenario: A payment of another TPP is refused
      Given pay003 belongs to the other TPP
      When its authorisations are listed by this client
      Then the answer is 403 RESOURCE_UNKNOWN

  Rule: The listing is the way to find an authorisation the client did not create

    @nominal @authorisation-resources
    Scenario: A client that lost its authorisation id finds it again
      Given the client stored the consent id but not the authorisation id
      When it lists the authorisations
      Then it gets the id and can read the SCA status with it

    @nominal @authorisation-resources
    Scenario: The ids are stable
      Given two listings a minute apart
      When they are compared
      Then the ids are the same
