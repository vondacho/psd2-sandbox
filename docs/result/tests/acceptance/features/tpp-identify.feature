# GENERATED from docs/stories/tpp-identify.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 5fe9edc2d0d550e0cfed7ffee9c050c5387c64f186d277198c11ff2af733309b
# generator: tools/sdlc/examplemap_to_feature.py
# 3 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-TPP-IDENTIFY
Feature: Identify the TPP from its certificate
  As AISP
  I want the bank to recognise me and my PSD2 roles from my QWAC on the TLS connection
  So that I can act for my PSUs under my own licence without a separate bank-specific login

  # Rule R-TPP-01: No request reaches the resource model without a valid QWAC

  @WS-01 @R-TPP-01
  Scenario: A consent request over mTLS with a valid QWAC is accepted
    Given a TPP with organizationIdentifier PSDES-BDE-3DFD21 and role PSP_AI
    And a valid, unexpired QWAC presented on the TLS connection
    When the TPP posts a consent on dedicated accounts
    Then the request reaches the XS2A resource model
    And the consent records PSDES-BDE-3DFD21 as its owner

  @MVP-01 @R-TPP-01 @edge-case
  Scenario: An expired certificate is refused before any resource is created
    Given a TPP whose QWAC expired yesterday
    When the TPP posts a consent on dedicated accounts
    Then the response is 401 with code CERTIFICATE_EXPIRED
    And no consent resource is created

  # Rule R-TPP-02: The PSD2 roles in the certificate decide which services the TPP may call

  @MVP-01 @R-TPP-02 @edge-case
  Scenario: A certificate with only the AISP role may not initiate a payment
    Given a TPP with role PSP_AI only
    When the TPP posts a SEPA credit transfer
    Then the response is 401 with code ROLE_INVALID
    And no payment initiation resource is created

  @MVP-01 @R-TPP-02
  Scenario: A certificate with the PISP role may initiate a payment
    Given a TPP with role PSP_PI
    When the TPP posts a SEPA credit transfer
    Then a payment initiation resource is created

  # Rule R-TPP-03: A TPP may only address the resources it created

  @MVP-01 @R-TPP-03 @edge-case
  Scenario: Another TPP cannot read a consent it did not create
    Given consent 123cons456 created by PSDES-BDE-3DFD21
    And a second TPP PSDFR-ACPR-12345 with a valid QWAC and the AISP role
    When the second TPP reads GET /v1/consents/123cons456
    Then the consent content is not disclosed

  # Rule R-TPP-04: The owner of a resource is the legal holder of the certificate, not the brand

  @MVP-01 @R-TPP-04
  Scenario: Two brands of one licensed TPP share their resources
    Given consent 123cons456 created with organizationIdentifier PSDES-BDE-3DFD21 and brand Budget Buddy
    When the same organizationIdentifier reads the consent while logging brand Money Mate
    Then the consent is readable
