# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/issue-test-qwacs-from-a-sandbox-ca.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@sandbox @security @walking-skeleton @analysing
Feature: Issue test QWACs from a sandbox CA
  As TPP operator
  I want a private CA that issues certificates with a PSD2 QcStatement
  So that the sandbox exercises the real validation path

  @etsi-ts-119-495
  Rule: An issued QWAC carries the PSD2 QcStatement with the requested roles and the organizationIdentifier in the subject

    @nominal @walking-skeleton
    Scenario: A QWAC for the TPP with AISP and PISP
      Given the request 'tpp, roles AISP PISP, NCA BaFin, id PSDDE-BAFIN-123456, domains tpp.sandbox'
      When the CA issues the certificate
      Then the subject has organizationIdentifier PSDDE-BAFIN-123456 and O 'TPP Fintech GmbH'
      And the qcStatements extension has id-etsi-psd2-qcStatement with roles PSP_AI and PSP_PI, NCA name 'BaFin' and NCA id 'DE-BAFIN'
      And the SAN contains dNSName tpp.sandbox
      And extended key usage contains clientAuth

    @nominal @walking-skeleton
    Scenario: A PISP-only QWAC for C
      Given the request 'tpp-c, roles PISP, id PSDDE-BAFIN-654321'
      When the CA issues the certificate
      Then the QcStatement lists PSP_PI only

    @error @walking-skeleton
    Scenario: A request without any role is refused
      Given the request 'tpp-x, roles none'
      When the CA is asked to issue
      Then it exits with 'at least one PSD2 role is required'

    @error @walking-skeleton
    Scenario: A request with an unknown role is refused
      Given the request 'tpp-x, roles AISP BANK'
      When the CA is asked to issue
      Then it exits with 'unknown role BANK'

    @nominal @walking-skeleton
    Scenario: openssl shows the QcStatement
      Given the issued certificate tpp.pem
      When openssl x509 -text is run on it
      Then the output contains 'qcStatements' and '0.4.0.19495.2'

  Rule: The CA also issues QSEALs for request signing, distinguishable from QWACs

    @nominal @hardening
    Scenario: A QSEAL for the TPP
      Given the request 'tpp, seal, id PSDDE-BAFIN-123456'
      When the CA issues the certificate
      Then the QcStatement carries QcType id-etsi-qct-eseal
      And key usage is nonRepudiation and the certificate has no clientAuth

    @nominal @hardening
    Scenario: A QWAC presented as a sealing certificate is distinguishable
      Given the TPP's QWAC with QcType id-etsi-qct-web
      When the Bank inspects the QcType
      Then it is not accepted as a QSEAL

  Rule: The CA publishes a CRL and can revoke a certificate

    @nominal @mvp
    Scenario: Revoking the TPP's certificate puts its serial on the CRL
      Given the TPP's QWAC has serial 0x1A2B
      When the operator runs the revoke command for tpp
      Then the CRL at https://pki.sandbox/crl.pem lists 0x1A2B
      And the Bank's next call from the TPP answers 401 CERTIFICATE_REVOKED

    @nominal @mvp
    Scenario: The CRL is signed by the CA and has a nextUpdate
      Given the published CRL
      When it is verified against the CA certificate
      Then the signature is valid and nextUpdate is at most 24 hours ahead

    @error @mvp
    Scenario: Revoking an unknown certificate fails
      Given no certificate was issued for tpp-z
      When the operator runs the revoke command for tpp-z
      Then it exits with 'no certificate for tpp-z'

  Rule: Validity is configurable so expiry can be tested

    @nominal @walking-skeleton
    Scenario: The default validity is 365 days
      Given the request for tpp without validity
      When the certificate is issued on 2026-09-06
      Then notAfter is 2027-09-06

    @edge @mvp
    Scenario: A one-minute certificate expires for the test
      Given the request 'tpp, validity 1m'
      When the certificate is issued and used two minutes later
      Then the Bank answers 401 CERTIFICATE_EXPIRED

    @edge @mvp
    Scenario: A certificate with notBefore in the future can be issued
      Given the request 'tpp, not-before +1d'
      When the certificate is used today
      Then the Bank answers 401 CERTIFICATE_INVALID

  Rule: The Bank's gateway and the OIDC-provider trust the sandbox CA and nothing else

    @nominal @walking-skeleton
    Scenario: The CA certificate is in the trust stores of the gateway and of the OIDC-provider
      Given the docker compose stack
      When the gateway and the OIDC-provider start
      Then both load pki/ca.pem as the only client CA

    @error @walking-skeleton
    Scenario: A certificate from a second, unrelated CA is not trusted
      Given a certificate issued by another test CA
      When it is presented to the gateway
      Then the handshake fails

    @edge @mvp
    Scenario: The CA's private key is not in the image
      Given the built images
      When the file system of the gateway image is inspected
      Then no CA private key is present; it lives only in the pki volume
