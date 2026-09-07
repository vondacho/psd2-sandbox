# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/register-the-tpp-client-at-the-oidc-provider.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@oidc-provider @spec-13.1 @rfc-8705 @walking-skeleton @analysing
Feature: Register the TPP client at the OIDC-provider
  As TPP operator
  I want a client whose id is the QWAC organizationIdentifier, bound to the certificate and redirect URIs
  So that the OIDC-provider can authenticate the TPP by mTLS

  @spec-13.1 @rfc-8705
  Rule: The client id is the organizationIdentifier of the QWAC and the client authenticates with tls_client_auth

    @nominal @walking-skeleton
    Scenario: The TPP is registered and authenticates with its QWAC
      Given client PSDDE-BAFIN-123456 registered with tls_client_auth_subject_dn 'organizationIdentifier=PSDDE-BAFIN-123456,O=TPP Fintech GmbH,C=DE'
      When the TPP calls POST /token over mTLS with its QWAC
      Then the OIDC-provider authenticates the client as PSDDE-BAFIN-123456

    @error @walking-skeleton
    Scenario: C's certificate cannot act as the TPP client
      Given C presents its QWAC (PSDDE-BAFIN-654321) with client_id PSDDE-BAFIN-123456
      When C calls POST /token
      Then the OIDC-provider answers 401 invalid_client

    @error @walking-skeleton
    Scenario: An unregistered client id is refused at /authorize
      Given client_id PSDDE-BAFIN-000000 is not registered
      When the browser hits /authorize
      Then the OIDC-provider shows an error page 'unknown client' and does not redirect

    @error @mvp
    Scenario: A client id that differs from the certificate's organizationIdentifier is refused
      Given a certificate with organizationIdentifier PSDDE-BAFIN-123456 and a registration attempt with client_id 'app-a'
      When the registration is submitted
      Then the OIDC-provider refuses with 'client_id must equal the organizationIdentifier'

    @error @walking-skeleton
    Scenario: The TPP token request without client certificate is refused
      Given a POST /token without TLS client certificate
      When the OIDC-provider handles it
      Then the answer is 401 invalid_client

  @spec-4.10
  Rule: Redirect URIs are registered and matched exactly

    @nominal @walking-skeleton
    Scenario: The registered callback matches
      Given registered https://tpp.sandbox/xs2a/callback/bank and https://tpp.sandbox/xs2a/callback/bank?outcome=nok
      When /authorize is called with redirect_uri https://tpp.sandbox/xs2a/callback/bank
      Then the request is accepted

    @error @walking-skeleton
    Scenario: A different path is refused without redirect
      Given the same registration
      When /authorize is called with redirect_uri https://tpp.sandbox/xs2a/callback/other
      Then the OIDC-provider shows an error page and does not redirect anywhere

    @error @mvp
    Scenario: An added query parameter is refused
      Given the same registration
      When /authorize is called with redirect_uri https://tpp.sandbox/xs2a/callback/bank?x=1
      Then the OIDC-provider shows an error page

    @error @mvp
    Scenario: A different scheme is refused
      Given the same registration
      When /authorize is called with redirect_uri http://tpp.sandbox/xs2a/callback/bank
      Then the OIDC-provider shows an error page

    @edge @mvp
    Scenario: Case differs in the host only: accepted
      Given the same registration
      When /authorize is called with redirect_uri https://the TPP.TPP.SANDBOX/xs2a/callback/bank
      Then the request is accepted, hosts compare case-insensitively

  @spec-13.1
  Rule: The client's PSD2 roles come from the QWAC and gate the scope kinds

    @nominal @walking-skeleton
    Scenario: A with AISP may request AIS scopes
      Given the TPP client registered with roles AISP, PISP
      When /authorize is called with scope AIS:123cons456
      Then the scope kind is allowed

    @error @mvp
    Scenario: C with PISP only may not request AIS scopes
      Given client C registered with role PISP
      When /authorize is called with scope AIS:123cons456
      Then the OIDC-provider redirects with error=invalid_scope

    @edge @mvp
    Scenario: Roles are re-read when the certificate is rotated
      Given the TPP's new QWAC carries AISP only
      When the binding is updated
      Then the client's roles are AISP
      And a PIS scope request is refused

  Rule: A client may hold more than one certificate binding so certificates can rotate

    @edge @mvp
    Scenario: A second QWAC with the same organizationIdentifier is added
      Given the TPP client bound to certificate thumbprint T1
      When the operator adds the new QWAC with thumbprint T2
      Then both T1 and T2 authenticate the TPP client

    @error @mvp
    Scenario: A certificate with another organizationIdentifier cannot be bound
      Given the TPP client
      When the operator tries to bind C's QWAC
      Then the OIDC-provider refuses with 'organizationIdentifier mismatch'

    @nominal @mvp
    Scenario: Removing the old binding stops the old certificate
      Given the TPP client bound to T1 and T2
      When T1 is removed
      Then a token request with the T1 certificate answers invalid_client
