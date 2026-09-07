# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/return-a-confirmation-link.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-7.6 @mvp @ready
Feature: Return a confirmation link
  As Bank security officer
  I want the consent response to carry a confirmation link when configured
  So that the token holder must prove it is the consent creator

  @spec-7.6
  Rule: The confirmation link is returned if and only if the Bank is configured to require confirmation

    @nominal @mvp
    Scenario: With confirmationRequired true the link points at the authorisation
      Given the Bank runs with confirmationRequired true
      When POST /v1/consents answers 201
      Then _links.confirmation.href is /psd2/v1/consents/123cons456/authorisations/123auth567
      And the authorisation has confirmationRequired true

    @nominal @mvp
    Scenario: With confirmationRequired false there is no link
      Given the Bank runs with confirmationRequired false
      When POST /v1/consents answers 201
      Then _links has no confirmation entry
      And the authorisation has confirmationRequired false

    @edge @mvp
    Scenario: The setting is read per consent at creation, not at SCA time
      Given consent 123cons456 was created while confirmationRequired was true
      When the operator switches the setting to false and the SCA completes
      Then the authorisation still waits for confirmation

  @spec-14.16
  Rule: When a confirmation link was returned, a verified SCA leaves the consent received and the authorisation unconfirmed

    @nominal @mvp
    Scenario: After the device signature the status is unconfirmed
      Given the link was returned and Anna's device approved the challenge
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is received
      When the TPP calls the scaStatus link
      Then the answer is unconfirmed

    @error @mvp
    Scenario: Account data is refused before confirmation
      Given the authorisation is unconfirmed and the TPP holds a valid access token
      When the TPP calls GET /v1/accounts
      Then the answer is 401 CONSENT_INVALID

    @nominal @mvp
    Scenario: After confirmation the consent is valid
      Given the authorisation is unconfirmed
      When the TPP calls PUT on the confirmation link with its bearer token
      Then the scaStatus is finalised and the consent status is valid

  Rule: Without a confirmation link, a verified SCA finalises the authorisation and validates the consent directly

    @nominal @mvp
    Scenario: Direct finalisation
      Given no link was returned and Anna's device approved the challenge
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is valid
      When the TPP calls the scaStatus link
      Then the answer is finalised

    @nominal @mvp
    Scenario: Account data is served right after the token exchange
      Given no link was returned and the TPP holds the access token
      When the TPP calls GET /v1/accounts
      Then the answer is 200

  Rule: The confirmation link is the same resource as the scaStatus link

    @nominal @mvp
    Scenario: Both hrefs are equal
      Given the 201 answer with both links
      When the hrefs are compared
      Then _links.confirmation.href equals _links.scaStatus.href

    @nominal @mvp
    Scenario: GET on the confirmation link reads the status, PUT confirms
      Given the confirmation link
      When the TPP calls GET on it
      Then the answer is {scaStatus: …}
      When the TPP calls PUT on it with the bearer token
      Then the authorisation is confirmed
