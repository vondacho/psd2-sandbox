# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/read-the-oidc-providers-metadata-from-the-scaoauth-link.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @spec-13 @walking-skeleton @analysing
Feature: Read the OIDC-provider's metadata from the scaOAuth link
  As TPP operator
  I want the TPP to discover the authorization and token endpoints from the metadata document
  So that no endpoint is hard-coded per bank

  @spec-13 @rfc-8414
  Rule: The TPP fetches the RFC 8414 document at the scaOAuth href and uses its endpoints

    @nominal @walking-skeleton
    Scenario: The endpoints of the OIDC-provider are taken from the document
      Given the 201 answer carries scaOAuth https://oidc-provider.sandbox/.well-known/oauth-authorization-server
      And that document has issuer https://oidc-provider.sandbox, authorization_endpoint https://oidc-provider.sandbox/authorize, token_endpoint https://oidc-provider.sandbox/token, jwks_uri https://oidc-provider.sandbox/jwks
      When the TPP prepares the authorization
      Then the browser is redirected to https://oidc-provider.sandbox/authorize
      And the code will be exchanged at https://oidc-provider.sandbox/token

    @nominal @walking-skeleton
    Scenario: No endpoint of the OIDC-provider is present in the TPP's configuration
      Given the TPP's registry entry for the Bank
      When the configuration is inspected
      Then it holds the metadata URL only, no authorize or token URL

    @error @mvp
    Scenario: A 404 on the metadata URL fails the connection with an operational alert
      Given https://oidc-provider.sandbox/.well-known/oauth-authorization-server answers 404
      When the TPP fetches it
      Then the connection state is failed with reason 'authorization server metadata unavailable'
      And an alert names the Bank and the URL

    @error @mvp
    Scenario: A document without token_endpoint aborts
      Given a metadata document without token_endpoint
      When the TPP validates it
      Then the connection fails with 'metadata incomplete: token_endpoint'

    @error @mvp
    Scenario: A document whose issuer does not match its location aborts
      Given the document at https://oidc-provider.sandbox/.well-known/oauth-authorization-server says issuer https://other.example
      When the TPP validates it
      Then the connection fails with 'issuer mismatch'

    @error @mvp
    Scenario: A document that is not JSON aborts
      Given the metadata URL answers an HTML page
      When the TPP parses it
      Then the connection fails with 'metadata not parseable'

  @spec-13.1 @spec-13.3
  Rule: The TPP requires the capabilities the design depends on: tls_client_auth, S256 and the code grant

    @nominal @walking-skeleton
    Scenario: The OIDC-provider advertises everything needed
      Given token_endpoint_auth_methods_supported [tls_client_auth], code_challenge_methods_supported [S256], grant_types_supported [authorization_code, refresh_token], tls_client_certificate_bound_access_tokens true
      When the TPP validates the document
      Then the authorization proceeds

    @error @mvp
    Scenario: Without tls_client_auth the TPP aborts
      Given token_endpoint_auth_methods_supported [client_secret_basic]
      When the TPP validates the document
      Then the connection fails with 'the OIDC-provider does not support tls_client_auth'

    @error @mvp
    Scenario: Without S256 the TPP aborts
      Given code_challenge_methods_supported [plain]
      When the TPP validates the document
      Then the connection fails with 'the OIDC-provider does not support PKCE S256'

    @edge @mvp
    Scenario: Without refresh_token grant the TPP still connects but warns
      Given grant_types_supported [authorization_code]
      When the TPP validates the document
      Then the authorization proceeds
      And a warning 'no refresh token grant at the Bank' is logged

  @security
  Rule: The scaOAuth link must be https and on the host the registry knows for this bank

    @nominal @walking-skeleton
    Scenario: A link on the registered host is followed
      Given bank.oauthMetadataUrl is https://oidc-provider.sandbox/.well-known/oauth-authorization-server
      When the 201 carries scaOAuth on host oidc-provider.sandbox
      Then the TPP fetches it

    @error @mvp
    Scenario: A link on another host is refused
      Given the 201 carries scaOAuth https://evil.example/.well-known/oauth-authorization-server
      When the TPP validates the link
      Then the connection fails with 'scaOAuth host not expected for the Bank'
      And nothing is fetched from evil.example

    @error @mvp
    Scenario: An http link is refused
      Given the 201 carries scaOAuth http://oidc-provider.sandbox/.well-known/oauth-authorization-server
      When the TPP validates the link
      Then the connection fails with 'scaOAuth must use https'

    @edge @mvp
    Scenario: A link with a different path on the same host is followed
      Given the 201 carries scaOAuth https://oidc-provider.sandbox/.well-known/openid-configuration
      When the TPP validates the link
      Then the TPP fetches it and uses it

  Rule: Metadata is cached per bank for one hour and refreshed on failure

    @nominal @mvp
    Scenario: Two connects within an hour fetch the document once
      Given Anna and Ben connect the Bank within ten minutes
      When the requests to oidc-provider.sandbox are counted
      Then the metadata document was fetched once

    @edge @mvp
    Scenario: A changed link invalidates the cache
      Given the cached document came from https://oidc-provider.sandbox/.well-known/oauth-authorization-server
      When a new 201 carries scaOAuth https://oidc-provider.sandbox/.well-known/openid-configuration
      Then the TPP fetches the new document

    @edge @mvp
    Scenario: A token endpoint that answers 404 triggers a refetch before failing
      Given the cached token_endpoint answers 404
      When the TPP exchanges a code
      Then the TPP refetches the metadata once and retries the exchange
