# GENERATED from docs/stories/sca-redirect-app.examplemap — do not edit; change the example map and regenerate.
# source-sha256: f6949c2aa1c0c0dbde45940db12347a21f7e30ea1eb58b7d7a62fa890fbc70da
# generator: tools/sdlc/examplemap_to_feature.py
# 6 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-SCA-REDIRECT-APP
Feature: Approve a TPP's request in my bank app after a redirect
  As Account holder
  I want to be taken from the TPP to my bank app, authenticate there and approve the request
  So that I never give my bank credentials to the TPP

  # Rule R-SCA-01: A received consent comes back with a redirect link and an implicitly created authorisation

  @WS-01 @R-SCA-01
  Scenario: The consent response carries scaRedirect and scaStatus links
    Given the AISP posts a valid dedicated-account consent with TPP-Redirect-URI https://www.example-TPP.com/xs2a-client/v1/cb
    When the bank answers
    Then the header ASPSP-SCA-Approach is REDIRECT
    And _links contains scaRedirect, status and scaStatus
    And the authorisation behind scaStatus has scaStatus received

  @MVP-01 @R-SCA-01 @edge-case
  Scenario: An explicit-start preference returns a startAuthorisation link instead
    Given the AISP sends TPP-Explicit-Authorisation-Preferred true
    When the bank answers
    Then _links contains startAuthorisation and no scaRedirect

  # Rule R-SCA-02: The PSU approves exactly what the TPP asked for

  @MVP-01 @R-SCA-02
  Scenario: The approval screen shows the consent details
    Given consent 123cons456 from Sandbox AISP Ltd for balances and transactions on DE40100100103307118608, valid until 2017-11-01, 4 reads a day
    When the PSU opens the approval screen
    Then the screen shows Sandbox AISP Ltd, DE40100100103307118608, balances and transactions, 2017-11-01 and 4 reads a day

  # Rule R-SCA-03: A finalised authorisation makes the consent valid; a failed one rejects it

  @WS-01 @R-SCA-03
  Scenario: The PSU approves
    Given consent 123cons456 in status received with authorisation 123auth567 in status received
    When the PSU authenticates in the bank app and approves
    Then authorisation 123auth567 has scaStatus finalised
    And consent 123cons456 has consentStatus valid
    And the PSU is sent to https://www.example-TPP.com/xs2a-client/v1/cb

  @MVP-01 @R-SCA-03 @edge-case
  Scenario: The PSU declines
    Given consent 123cons456 in status received with authorisation 123auth567 in status received
    When the PSU declines in the bank app
    Then authorisation 123auth567 has scaStatus failed
    And consent 123cons456 has consentStatus rejected

  @MVP-01 @R-SCA-03 @edge-case
  Scenario: The PSU fails authentication
    Given consent 123cons456 in status received
    When the PSU fails authentication in the bank app
    Then authorisation 123auth567 has scaStatus failed
    And consent 123cons456 has consentStatus rejected

  # Rule R-SCA-04: A failed PSU is sent to TPP-Nok-Redirect-URI when the TPP gave one

  @MVP-01 @R-SCA-04 @edge-case
  Scenario: Decline goes to the nok URI
    Given TPP-Nok-Redirect-URI https://www.example-TPP.com/xs2a-client/v1/nok on the consent request
    When the PSU declines in the bank app
    Then the PSU is sent to https://www.example-TPP.com/xs2a-client/v1/nok

  @MVP-01 @R-SCA-04 @edge-case
  Scenario: A redirect URI outside the certificate's domain is still accepted in v1.3.16
    Given a QWAC for example-TPP.com
    And TPP-Redirect-URI https://other-domain.com/cb
    When the AISP posts the consent
    Then the response is 201 Created

  # Rule R-SCA-05: A final authorisation accepts no further updates

  @MVP-01 @R-SCA-05 @edge-case
  Scenario: An update after a failed SCA is refused
    Given authorisation 123auth567 with scaStatus failed
    When the AISP sends PUT /v1/consents/123cons456/authorisations/123auth567
    Then the response is 400 with code SCA_INVALID
