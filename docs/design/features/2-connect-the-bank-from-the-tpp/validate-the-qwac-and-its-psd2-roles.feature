# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/validate-the-qwac-and-its-psd2-roles.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @security @spec-3 @mvp @analysing
Feature: Validate the QWAC and its PSD2 roles
  As Bank security officer
  I want the certificate chain, revocation and the AISP role checked on every call
  So that a revoked or non-AISP certificate gets CERTIFICATE_* or ROLE_INVALID

  @spec-3 @etsi-ts-119-495
  Rule: The chain must end at a trusted qualified trust service provider; in the sandbox, at the sandbox CA

    @nominal @mvp
    Scenario: The TPP's QWAC chained to the sandbox CA is accepted
      Given the TPP's QWAC issued by the sandbox CA
      When POST /v1/consents is called
      Then the call proceeds to request validation

    @error @mvp
    Scenario: A certificate whose intermediate is missing is refused
      Given a client sends a leaf certificate without its intermediate and the gateway has no path to the root
      When the call is made
      Then the answer is 401 CERTIFICATE_INVALID

    @error @mvp
    Scenario: A certificate without a PSD2 QcStatement is refused
      Given a certificate from the sandbox CA issued without the qcStatements extension
      When POST /v1/consents is called
      Then the answer is 401 CERTIFICATE_INVALID with text 'PSD2 QcStatement missing'

    @error @mvp
    Scenario: A certificate whose organizationIdentifier is malformed is refused
      Given a certificate with organizationIdentifier 'ACME-123' (no PSD prefix, no NCA)
      When the call is made
      Then the answer is 401 CERTIFICATE_INVALID with text 'organizationIdentifier invalid'

  @spec-14.11
  Rule: Validity period and revocation are checked on every call

    @error @mvp
    Scenario: An expired certificate gets CERTIFICATE_EXPIRED
      Given a QWAC with notAfter 2026-09-05T23:59:59Z and today 2026-09-06
      When GET /v1/accounts is called
      Then the answer is 401 CERTIFICATE_EXPIRED

    @error @mvp
    Scenario: A revoked certificate gets CERTIFICATE_REVOKED
      Given the TPP's QWAC serial 0x1A2B is on the sandbox CA's CRL
      When GET /v1/accounts is called
      Then the answer is 401 CERTIFICATE_REVOKED

    @error @mvp
    Scenario: A certificate blocked by the Bank gets CERTIFICATE_BLOCKED
      Given the Bank's operator put serial 0x1A2B on the local block list
      When GET /v1/accounts is called
      Then the answer is 401 CERTIFICATE_BLOCKED

    @error @mvp
    Scenario: A certificate not yet valid gets CERTIFICATE_INVALID
      Given a QWAC with notBefore 2026-09-07T00:00:00Z and now 2026-09-06T12:00:00Z
      When the call is made
      Then the answer is 401 CERTIFICATE_INVALID

    @edge @mvp
    Scenario: A revocation published a minute ago is honoured on the next call
      Given the TPP's QWAC was validated and cached at 10:00 and revoked at 10:05
      When the TPP calls at 10:11
      Then the answer is 401 CERTIFICATE_REVOKED

    @edge @mvp
    Scenario: A certificate expiring in the middle of a session still works until notAfter
      Given a QWAC with notAfter 2026-09-06T12:00:00Z
      When the TPP calls at 11:59:59Z
      Then the call is served

  @spec-3
  Rule: The endpoint's role must be in the certificate's PSD2 roles

    @nominal @mvp
    Scenario: A certificate with AISP and PISP may create consents
      Given the TPP's QWAC with roles PSP_AI and PSP_PI
      When POST /v1/consents is called
      Then the call is served

    @error @mvp
    Scenario: A PISP-only certificate may not create consents
      Given C's QWAC with role PSP_PI only
      When POST /v1/consents is called
      Then the answer is 401 ROLE_INVALID

    @error @mvp
    Scenario: A PISP-only certificate may not read accounts
      Given C's QWAC with role PSP_PI only and a stolen valid token of the TPP
      When GET /v1/accounts is called
      Then the answer is 401 ROLE_INVALID before any token check

    @error @mvp
    Scenario: An AISP-only certificate may not initiate payments
      Given a QWAC with role PSP_AI only
      When POST /v1/payments/sepa-credit-transfers is called
      Then the answer is 401 ROLE_INVALID

    @error @mvp
    Scenario: A PIISP-only certificate may not read accounts
      Given a QWAC with role PSP_IC only
      When GET /v1/accounts is called
      Then the answer is 401 ROLE_INVALID

  Rule: The organizationIdentifier of the certificate is the TPP identity for everything that follows

    @nominal @mvp
    Scenario: The consent is created for PSDDE-BAFIN-123456
      Given the TPP's QWAC with organizationIdentifier PSDDE-BAFIN-123456
      When POST /v1/consents succeeds
      Then the consent's tppId is PSDDE-BAFIN-123456

    @edge @mvp
    Scenario: A renewed certificate with the same organizationIdentifier keeps the identity
      Given the TPP replaces its QWAC with a new one carrying PSDDE-BAFIN-123456
      When GET /v1/consents/123cons456/status is called with the new certificate
      Then the consent is found and served

    @nominal @mvp
    Scenario: The error body follows the tppMessages format
      Given a revoked certificate
      When the call is refused
      Then the body is {tppMessages: [{category: ERROR, code: CERTIFICATE_REVOKED, text: …}]}
      And the response carries the request's X-Request-ID
