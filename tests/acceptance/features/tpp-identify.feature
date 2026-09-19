# GENERATED from docs/stories/tpp-identify.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 4a37b13ff62586e1f9652a570b156b1777f5f9ede45bdcea911c1ee4fce212af
# generator: tools/sdlc/examplemap_to_feature.py
# 5 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-TPP-IDENTIFY
Feature: Identify the TPP from its certificate
  As AISP
  I want the bank to recognise me and my PSD2 roles from my QWAC on the TLS connection
  So that I can act for my PSUs under my own licence without a separate bank-specific login

  # Rule R-TPP-01: A request is served only over mutual TLS with a qualified website certificate

  @WS-01 @R-TPP-01
  Scenario: A TPP with a valid QWAC carrying PSP_AI is identified
    Given a QWAC for organizationIdentifier PSDES-BDE-3DFD21 with the role PSP_AI
    When the TPP posts a consent over mutual TLS with that certificate
    Then the request is processed for TPP PSDES-BDE-3DFD21

  @WS-01 @R-TPP-01 @edge-case
  Scenario: A connection without a client certificate is refused
    Given a TLS client that presents no certificate
    When it calls POST /v1/consents
    Then no consent resource is created

  # Rule R-TPP-02: A TPP may use only the services its certificate roles cover

  @MVP-01 @R-TPP-02 @edge-case
  Scenario: An AISP-only certificate cannot initiate a payment
    Given a QWAC for PSDES-BDE-3DFD21 carrying only the role PSP_AI
    When the TPP posts a payment to /v1/payments/sepa-credit-transfers
    Then the response is 401 with code ROLE_INVALID
    And no payment resource is created

  @WS-01 @R-TPP-02
  Scenario: A PISP certificate can initiate a payment
    Given a QWAC for PSDES-BDE-3DFD21 carrying the role PSP_PI
    When the TPP posts a payment to /v1/payments/sepa-credit-transfers
    Then the response is 201 Created

  # Rule R-TPP-03: The legal owner of the certificate, not the brand in OU, owns consents and payments

  @MVP-01 @R-TPP-03
  Scenario: Two brand certificates of one legal TPP address the same consent
    Given consent 123cons456 created with a QWAC for PSDES-BDE-3DFD21 whose OU is BrandA
    When the TPP reads consent 123cons456 with another QWAC for PSDES-BDE-3DFD21 whose OU is BrandB
    Then the consent is returned

  # Rule R-TPP-04: A TPP can only address resources it created

  @MVP-01 @R-TPP-04 @edge-case
  Scenario: Another TPP cannot read a consent it did not create
    Given consent 123cons456 created by PSDES-BDE-3DFD21
    When TPP PSDFR-ACPR-12345 reads GET /v1/consents/123cons456
    Then the consent is not returned
