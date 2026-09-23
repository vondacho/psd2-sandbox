# GENERATED from docs/stories/sca-device.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 3655084f5084511f5853a4079d238509ccda190f92c86b27a87ecb7381cba7e4
# generator: tools/sdlc/examplemap_to_feature.py
# 6 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-SCA-DEVICE
Feature: Log in at the bank and confirm the consent on my enrolled device
  As Account holder
  I want to log in on the bank's login screen and then confirm the request on my enrolled device
  So that I never give my bank credentials to the TPP, and only my own device can complete the approval

  # Rule R-SCA-01: The bank starts the authorisation itself and hands the TPP a redirect link

  @WS-01 @R-SCA-01
  Scenario: A consent request comes back with a redirect link and no further TPP data
    Given an AISP that sent TPP-Redirect-Preferred true and a TPP-Redirect-URI
    When the AISP posts a consent on dedicated accounts
    Then the response is 201 with header ASPSP-SCA-Approach REDIRECT
    And the response carries a scaRedirect link and an authorisation sub-resource

  # Rule R-SCA-02: The panel shows the consent the PSU is confirming, and the SCA binds to what it showed

  @WS-01 @R-SCA-02
  Scenario: The panel names the TPP, the accounts and the access types
    Given a consent from Sandbox AISP Ltd for balances and transactions on DE40100100103307118608
    And a PSU authenticated on the bank login screen with one enrolled device
    When the consent confirmation panel is presented on that device
    Then the panel names Sandbox AISP Ltd
    And the panel lists DE40100100103307118608 with balances and transactions

  @MVP-01 @R-SCA-02 @edge-case
  Scenario: A consent changed after the panel was shown cannot be confirmed
    Given a consent confirmation panel showing two accounts
    And the underlying consent record is replaced before the PSU confirms
    When the PSU confirms on the device
    Then the confirmation is refused because it does not match what was shown
    And the authorisation does not reach finalised

  # Rule R-SCA-03: The consent becomes valid only when the authorisation is finalised

  @WS-01 @R-SCA-03
  Scenario: The TPP sees received until the PSU has confirmed on the device
    Given a consent whose authorisation is at scaStatus psuAuthenticated
    When the AISP reads the consent status
    Then consentStatus is received

  @WS-01 @R-SCA-03
  Scenario: The consent becomes valid after the items are confirmed
    Given a consent whose PSU confirmed identity and then the items on the panel
    When the AISP reads the consent status
    Then consentStatus is valid
    And the scaStatus of the authorisation is finalised

  # Rule R-SCA-04: A decline ends the authorisation and the consent, and says so to both sides

  @MVP-01 @R-SCA-04
  Scenario: Declining the items rejects the consent
    Given a consent whose PSU confirmed identity on the device
    When the PSU declines the items on the consent confirmation panel
    Then the scaStatus of the authorisation is failed
    And consentStatus is rejected
    And the browser offers a way back to the TPP

  @MVP-01 @R-SCA-04 @edge-case
  Scenario: Rejecting the identity step never reaches the panel
    Given a PSU authenticated on the login screen
    When the PSU rejects the request on the OTP screen
    Then the consent confirmation panel is not presented
    And consentStatus is rejected

  # Rule R-SCA-05: A redirect link works once, and only inside its window

  @MVP-01 @R-SCA-05 @edge-case
  Scenario: Following the same redirect link twice shows the unavailable page
    Given a scaRedirect link already followed to completion
    When the PSU opens the same link again
    Then the request-no-longer-available page is shown
    And no second authorisation is started

  @MVP-01 @R-SCA-05 @edge-case
  Scenario: A redirect link followed after the SCA window shows the unavailable page
    Given a scaRedirect link whose SCA window has closed
    When the PSU opens it
    Then the request-no-longer-available page is shown
