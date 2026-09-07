# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/terminate-the-xs2a-tls-with-a-client-certificate.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @security @spec-3 @walking-skeleton @ready
Feature: Terminate the XS2A TLS with a client certificate
  As Bank security officer
  I want every XS2A call to present a client certificate and be refused otherwise
  So that only identified TPPs reach the API

  @spec-3
  Rule: The TLS handshake on the XS2A endpoint requires a client certificate chained to a trusted CA

    @nominal @walking-skeleton
    Scenario: The TPP's QWAC from the sandbox CA completes the handshake
      Given the TPP presents the QWAC issued by the sandbox CA for PSDDE-BAFIN-123456
      When the TPP opens a TLS connection to api.bank.sandbox
      Then the handshake completes
      And the request reaches the XS2A service

    @error @walking-skeleton
    Scenario: A connection without client certificate is closed during the handshake
      Given a client that presents no certificate
      When it opens a TLS connection to api.bank.sandbox
      Then the gateway closes the connection with a TLS alert
      And no HTTP response is produced

    @error @walking-skeleton
    Scenario: A certificate from an unknown CA is refused during the handshake
      Given a client certificate issued by a self-signed CA the gateway does not trust
      When it opens a TLS connection
      Then the handshake fails with unknown_ca

    @error @walking-skeleton
    Scenario: A public web-server certificate is refused
      Given a certificate from a public CA without client-authentication usage
      When it is presented as client certificate
      Then the handshake fails

    @nominal @walking-skeleton
    Scenario: The requirement holds for every path under /psd2
      Given no client certificate
      When GET /psd2/v1/accounts and POST /psd2/v1/consents are attempted
      Then both fail at the handshake

  @security
  Rule: Only TLS 1.2 and 1.3 are accepted

    @nominal @walking-skeleton
    Scenario: TLS 1.3 is accepted
      Given a client offering TLS 1.3 only
      When it connects with the TPP's QWAC
      Then the handshake completes with TLS 1.3

    @nominal @walking-skeleton
    Scenario: TLS 1.2 is accepted
      Given a client offering TLS 1.2 only
      When it connects with the TPP's QWAC
      Then the handshake completes with TLS 1.2

    @error @walking-skeleton
    Scenario: TLS 1.1 is refused
      Given a client offering TLS 1.1 at most
      When it connects
      Then the handshake fails with protocol_version

  @security
  Rule: The gateway forwards the verified certificate to the service and strips any client-supplied copy

    @nominal @walking-skeleton
    Scenario: The service sees the PEM of the presented certificate
      Given the TPP connects with its QWAC
      When the request is forwarded to the XS2A service
      Then the header X-Client-Cert holds the URL-encoded PEM of the TPP's QWAC

    @error @walking-skeleton
    Scenario: A forged X-Client-Cert header from the client is replaced
      Given the TPP connects with its QWAC and adds a header X-Client-Cert containing C's certificate
      When the request is forwarded
      Then the service sees the TPP's certificate, not C's

    @error @mvp
    Scenario: The service refuses a request that reaches it without the forwarded certificate
      Given a request that bypasses the gateway and hits the service port directly
      When the service receives it without X-Client-Cert
      Then the service answers 401 CERTIFICATE_MISSING

  Rule: Server-side TLS is strong and the service identity is verifiable

    @nominal @walking-skeleton
    Scenario: The server certificate names api.bank.sandbox
      Given the TPP validates the server certificate
      When it connects to api.bank.sandbox
      Then the certificate's SAN contains api.bank.sandbox

    @edge @mvp
    Scenario: Only AEAD cipher suites are offered
      Given a client offering only TLS_RSA_WITH_AES_128_CBC_SHA
      When it connects
      Then the handshake fails with handshake_failure
