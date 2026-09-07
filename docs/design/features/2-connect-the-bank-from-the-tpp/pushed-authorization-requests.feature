# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/pushed-authorization-requests.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@oidc-provider @tpp @security @rfc-9126 @hardening @ready
Feature: Pushed authorization requests
  As Bank security officer
  I want the authorization parameters sent over the mTLS back channel
  So that they cannot be tampered with in the browser

  @rfc-9126
  Rule: The TPP posts the authorization parameters to the PAR endpoint over mTLS and redirects the browser with client_id and request_uri only

    @nominal @hardening
    Scenario: The pushed request and the short redirect
      Given the OIDC-provider's metadata has pushed_authorization_request_endpoint https://oidc-provider.sandbox/par
      When the TPP posts response_type, client_id, scope, state, redirect_uri, code_challenge and code_challenge_method to /par with its QWAC
      Then the OIDC-provider answers 201 {request_uri: urn:ietf:params:oauth:request_uri:6esc_11ACC5bwc014ltc14eY22c, expires_in: 60}
      And the browser is redirected to https://oidc-provider.sandbox/authorize?client_id=PSDDE-BAFIN-123456&request_uri=urn:ietf:params:oauth:request_uri:6esc_11ACC5bwc014ltc14eY22c

    @nominal @hardening
    Scenario: The redirect carries no scope, state or code_challenge
      Given the redirect URL
      When it is inspected
      Then it has exactly the parameters client_id and request_uri

    @error @hardening
    Scenario: A PAR without client certificate is refused
      Given a POST /par without mTLS
      When the OIDC-provider handles it
      Then the answer is 401 invalid_client

    @error @hardening
    Scenario: A PAR with an invalid redirect_uri is refused at the back channel
      Given redirect_uri https://evil.example/cb
      When the TPP posts to /par
      Then the answer is 400 invalid_request
      And the browser is never redirected

    @error @hardening
    Scenario: A PAR with an invalid scope is refused at the back channel
      Given scope AIS:999cons000 for an unknown consent
      When the TPP posts to /par
      Then the answer is 400 invalid_scope

  @rfc-9126
  Rule: A request_uri is single-use, short-lived and bound to the client that pushed it

    @error @hardening
    Scenario: A request_uri used twice is refused
      Given request_uri urn:…:6esc was already used at /authorize
      When the browser opens /authorize with it again
      Then the OIDC-provider shows an error page 'request_uri already used'

    @error @hardening
    Scenario: A request_uri older than 60 seconds is refused
      Given the PAR answered at 09:00:00 with expires_in 60
      When /authorize is opened at 09:01:05
      Then the OIDC-provider shows an error page 'request_uri expired'

    @error @hardening
    Scenario: A request_uri of the TPP opened with client_id C is refused
      Given request_uri urn:…:6esc pushed by PSDDE-BAFIN-123456
      When /authorize is opened with client_id PSDDE-BAFIN-654321 and that request_uri
      Then the OIDC-provider shows an error page

    @error @hardening
    Scenario: An unknown request_uri is refused
      Given request_uri urn:ietf:params:oauth:request_uri:nope
      When /authorize is opened with it
      Then the OIDC-provider shows an error page

  Rule: When the OIDC-provider requires PAR, a plain /authorize with inline parameters is refused

    @nominal @hardening
    Scenario: Metadata advertises the requirement
      Given the OIDC-provider runs with require_pushed_authorization_requests true
      When the TPP reads the metadata
      Then require_pushed_authorization_requests is true and the TPP uses PAR

    @error @hardening
    Scenario: A plain /authorize is refused
      Given the OIDC-provider requires PAR
      When the browser opens /authorize with scope, state and code_challenge inline
      Then the OIDC-provider shows an error page 'pushed authorization request required'

    @edge @hardening
    Scenario: When the OIDC-provider does not require PAR, both forms work
      Given the OIDC-provider runs with require_pushed_authorization_requests false
      When the TPP uses PAR for the Bank and inline parameters for Bank C
      Then both authorizations proceed
