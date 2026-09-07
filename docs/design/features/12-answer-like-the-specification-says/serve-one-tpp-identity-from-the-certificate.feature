# Generated from docs/design/examplemap/12-answer-like-the-specification-says/serve-one-tpp-identity-from-the-certificate.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @security @spec-4.9 @conformance @analysing
Feature: Serve one TPP identity from the certificate
  As Bank security officer
  I want one service that turns a presented certificate into a TPP identity with roles, or a refusal
  So that the gateway, the payment endpoints and the authorization server give the same answer

  @spec-4.9
  Rule: One service answers who is calling, from the certificate alone

    @nominal @conformance
    Scenario: A valid QWAC becomes a TPP identity
      Given the TPP's QWAC issued by the sandbox CA
      When the identification service is asked
      Then the answer holds organizationIdentifier PSDDE-BAFIN-123456, the legal name TPP Fintech GmbH, the roles AISP and PISP and the certificate validity

    @nominal @conformance
    Scenario: The same certificate gives the same identity everywhere
      Given the XS2A gateway, the payment endpoints and the authorization server
      When each identifies the same certificate
      Then all three receive the same organization identifier and roles

    @error @conformance
    Scenario: A certificate without the PSD2 statement is refused
      Given a certificate from the sandbox CA without the PSD2 qualified statement
      When the identification service is asked
      Then the answer is a refusal with CERTIFICATE_INVALID

    @error @conformance
    Scenario: A revoked certificate is refused
      Given a certificate on the revocation list
      When the identification service is asked
      Then the answer is a refusal with CERTIFICATE_REVOKED

    @error @conformance
    Scenario: An expired certificate is refused
      Given a certificate past its validity
      When the identification service is asked
      Then the answer is a refusal with CERTIFICATE_EXPIRED

    @nominal @conformance
    Scenario: The identity carries no more than the certificate says
      Given an identified TPP
      When the fields are listed
      Then each comes from the certificate, and nothing is inferred or remembered from earlier calls

  @spec-3
  Rule: The roles of the identity decide which endpoints the caller may use

    @nominal @conformance
    Scenario: An AISP may read accounts and not initiate payments
      Given an identity with the AISP role only
      When the account list and a payment initiation are attempted
      Then the first is served and the second answers 401 ROLE_INVALID

    @nominal @conformance
    Scenario: A PISP may initiate payments and not read accounts
      Given an identity with the PISP role only
      When both are attempted
      Then the payment is served and the account list answers 401 ROLE_INVALID

    @nominal @conformance
    Scenario: A role check happens before any token or consent check
      Given a PISP-only identity with a valid account token
      When the account list is called
      Then the answer is 401 ROLE_INVALID

  @security
  Rule: A revocation takes effect quickly and is visible in the audit trail

    @edge @conformance
    Scenario: A certificate revoked between two calls
      Given a call served at 10:00 and the certificate revoked at 10:05
      When the next call is made at 10:11
      Then it answers 401 CERTIFICATE_REVOKED

    @nominal @conformance
    Scenario: Every identification is logged with the request id
      Given any call
      When the audit trail is read
      Then it holds the organization identifier, the roles used and the request id
