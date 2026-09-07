# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/sign-requests-with-the-qseal.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @bank-xs2a @spec-4.2 @spec-12 @hardening @analysing
Feature: Sign requests with the QSEAL
  As Bank security officer
  I want Digest, Signature and TPP-Signature-Certificate verified when mandated
  So that requests are non-repudiable at application level

  @spec-12.1
  Rule: When the Bank mandates signing, every request carries Digest, Signature and TPP-Signature-Certificate

    @nominal @hardening
    Scenario: A signed consent request is accepted
      Given the Bank runs with requestSigningRequired true and the TPP's registry entry has requiresSignature true
      And the TPP computes Digest SHA-256=… over the body and signs with its QSEAL
      When POST /v1/consents is called with Digest, Signature and TPP-Signature-Certificate
      Then the answer is 201

    @error @hardening
    Scenario: A missing Signature header is refused
      Given signing is mandated and the request has Digest but no Signature
      When POST /v1/consents is called
      Then the answer is 401 SIGNATURE_MISSING

    @error @hardening
    Scenario: A missing TPP-Signature-Certificate is refused
      Given signing is mandated and the request has Digest and Signature but no TPP-Signature-Certificate
      When the call is made
      Then the answer is 401 SIGNATURE_MISSING

    @edge @hardening
    Scenario: A GET signs the digest of an empty body
      Given signing is mandated
      When GET /v1/accounts is called
      Then Digest is SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=
      And the answer is 200

  @spec-12.2
  Rule: The signature covers digest, x-request-id, date and, when present, psu-id, psu-corporate-id and tpp-redirect-uri

    @nominal @hardening
    Scenario: A signature over the mandated headers is accepted
      Given Signature with headers='digest x-request-id date tpp-redirect-uri' and keyId='SN=1A2B,CA=CN=sandbox-ca'
      When POST /v1/consents is called
      Then the answer is 201

    @error @hardening
    Scenario: A signature that omits date is refused
      Given Signature with headers='digest x-request-id'
      When the call is made
      Then the answer is 401 SIGNATURE_INVALID with text 'date not covered'

    @error @hardening
    Scenario: An altered body no longer matches the digest
      Given a valid signed request whose body was changed in transit to validUntil 2027-12-05
      When the Bank recomputes the digest
      Then the answer is 401 SIGNATURE_INVALID

    @error @hardening
    Scenario: A Date header older than five minutes is refused
      Given Date is 2026-09-06T09:00:00Z and the Bank's clock says 09:06:00Z
      When the call is made
      Then the answer is 401 TIMESTAMP_INVALID

    @error @hardening
    Scenario: A replayed request with the same x-request-id is refused
      Given a signed request already processed with X-Request-ID 99391c7e-…
      When the identical request is sent again
      Then the answer is 400 FORMAT_ERROR with text 'X-Request-ID already used'

    @error @hardening
    Scenario: Changing a covered header invalidates the signature
      Given a valid signed request
      When TPP-Redirect-URI is changed to https://tpp.sandbox/other after signing
      Then the answer is 401 SIGNATURE_INVALID

  @spec-12
  Rule: The sealing certificate must be a QSEAL of the same TPP as the QWAC

    @nominal @hardening
    Scenario: The TPP's QSEAL with the TPP's QWAC is accepted
      Given TPP-Signature-Certificate is the TPP's QSEAL with organizationIdentifier PSDDE-BAFIN-123456 and the TLS certificate is the TPP's QWAC
      When the call is made
      Then the signature check proceeds

    @error @hardening
    Scenario: A QWAC used as sealing certificate is refused
      Given TPP-Signature-Certificate is the TPP's QWAC (QcType web)
      When the call is made
      Then the answer is 401 CERTIFICATE_INVALID with text 'not a sealing certificate'

    @error @hardening
    Scenario: C's QSEAL with the TPP's QWAC is refused
      Given TPP-Signature-Certificate is C's QSEAL (PSDDE-BAFIN-654321) over the TPP's TLS connection
      When the call is made
      Then the answer is 401 CERTIFICATE_INVALID with text 'sealing certificate does not match TLS certificate'

    @error @hardening
    Scenario: A revoked QSEAL is refused
      Given the TPP's QSEAL is on the CRL
      When the call is made
      Then the answer is 401 CERTIFICATE_REVOKED

    @error @hardening
    Scenario: A QSEAL from an untrusted CA is refused
      Given a sealing certificate from an unknown CA
      When the call is made
      Then the answer is 401 CERTIFICATE_INVALID

  Rule: The TPP decides per bank whether to sign, from the registry

    @nominal @hardening
    Scenario: The Bank with requiresSignature true gets signed requests
      Given bank.requiresSignature is true
      When the TPP calls the Bank
      Then every request carries the three headers

    @nominal @hardening
    Scenario: Bank C with requiresSignature false gets unsigned requests
      Given bank-c.requiresSignature is false
      When the TPP calls Bank C
      Then no Digest, Signature or TPP-Signature-Certificate header is sent

    @edge @hardening
    Scenario: The QSEAL private key is used through the KMS, never loaded into the TPP's process
      Given the TPP signs a request
      When the signing call is traced
      Then the signature is produced by the KMS sign API with key id qseal-a
