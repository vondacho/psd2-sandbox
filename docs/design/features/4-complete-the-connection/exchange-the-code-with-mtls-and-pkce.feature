# Generated from docs/design/examplemap/4-complete-the-connection/exchange-the-code-with-mtls-and-pkce.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @oidc-provider @spec-13.3 @rfc-7636 @rfc-8705 @walking-skeleton @ready
Feature: Exchange the code with mTLS and PKCE
  As TPP operator
  I want the TPP to call the token endpoint with its QWAC and the code verifier
  So that the OIDC-provider can bind the token to the TPP's certificate

  @spec-13.3
  Rule: The TPP posts the code, the same redirect URI, the code verifier and its client id to the token endpoint over mTLS with its QWAC

    @nominal @walking-skeleton
    Scenario: The token request
      Given attempt att-1 with verifier dBjft… for consent 123cons456 and the code Splx…
      When the TPP calls POST https://oidc-provider.sandbox/token with its QWAC
      Then the form body is grant_type=authorization_code, client_id=PSDDE-BAFIN-123456, code=Splx…, redirect_uri=https://tpp.sandbox/xs2a/callback/bank, code_verifier=dBjft…
      And no client_secret is sent

    @nominal @walking-skeleton
    Scenario: The OIDC-provider answers tokens
      Given the token request
      When the OIDC-provider answers 200
      Then the body has access_token (a JWT), token_type Bearer, expires_in 600, refresh_token, scope 'AIS:123cons456 offline_access'
      And the attempt outcome is succeeded

    @error @mvp
    Scenario: The OIDC-provider answers invalid_grant
      Given the code expired
      When the OIDC-provider answers 400 invalid_grant
      Then the connection state is failed with 'the Bank did not accept the login, try again'
      And no retry of the exchange is made

    @error @mvp
    Scenario: The OIDC-provider answers invalid_client
      Given the TPP's certificate is not bound to its client at the OIDC-provider
      When the OIDC-provider answers 401 invalid_client
      Then the connection state is failed and an operational alert 'client authentication at oidc-provider.sandbox failed' is raised

    @error @mvp
    Scenario: The token endpoint times out
      Given the OIDC-provider does not answer within 10 seconds
      When the request times out
      Then the TPP retries once, then fails the connection with 'the Bank did not answer'

    @nominal @walking-skeleton
    Scenario: The verifier is sent to the token endpoint only
      Given the whole flow
      When every outgoing request of the TPP is inspected
      Then the verifier appears exactly once, in the POST to https://oidc-provider.sandbox/token

  @rfc-7636 @rfc-8705
  Rule: The OIDC-provider redeems a code only for the client that obtained it, presenting its bound certificate, the same redirect URI and the matching verifier, once

    @nominal @walking-skeleton
    Scenario: Nominal exchange at the OIDC-provider
      Given code Splx… issued to PSDDE-BAFIN-123456 for redirect_uri …/callback/bank with challenge E9Mel…
      When the TPP exchanges it with its QWAC, that redirect_uri and the verifier dBjft…
      Then the OIDC-provider issues tokens

    @error @walking-skeleton
    Scenario: A wrong verifier
      Given the same code
      When the TPP sends code_verifier 'wrong'
      Then the OIDC-provider answers 400 invalid_grant

    @error @mvp
    Scenario: A missing verifier
      Given the same code
      When the TPP sends no code_verifier
      Then the OIDC-provider answers 400 invalid_request

    @error @mvp
    Scenario: A different redirect_uri
      Given the same code
      When the TPP sends redirect_uri https://tpp.sandbox/xs2a/callback/bank-c
      Then the OIDC-provider answers 400 invalid_grant

    @error @walking-skeleton
    Scenario: C redeems the TPP's code with C's certificate
      Given code Splx… issued to the TPP
      When C posts it with client_id PSDDE-BAFIN-654321 and its QWAC
      Then the OIDC-provider answers 400 invalid_grant

    @error @mvp
    Scenario: C redeems the TPP's code claiming client_id the TPP
      Given code Splx… issued to the TPP
      When C posts it with client_id PSDDE-BAFIN-123456 and C's QWAC
      Then the OIDC-provider answers 401 invalid_client

    @error @walking-skeleton
    Scenario: No client certificate
      Given the same code
      When the token request is sent without mTLS
      Then the OIDC-provider answers 401 invalid_client

    @error @mvp
    Scenario: The code used twice revokes the first grant
      Given code Splx… already redeemed into grant g1
      When it is redeemed again
      Then the OIDC-provider answers 400 invalid_grant and revokes every token of g1

    @nominal @mvp
    Scenario: A code of another client's request cannot be redeemed with a valid verifier guessed
      Given the challenge is SHA-256 of a 64-character random verifier
      When an attacker without the verifier tries
      Then the exchange fails with invalid_grant

  Rule: The TPP never exchanges a code before validating the state, and stores the result only in the vault

    @nominal @walking-skeleton
    Scenario: The order of operations
      Given the callback
      When the TPP processes it
      Then the state is validated before any request to the OIDC-provider

    @nominal @walking-skeleton
    Scenario: Tokens go to the vault, not to the session or a cookie
      Given the token response
      When the TPP stores it
      Then the vault holds the tokens under (anna, bank, 123cons456) and no cookie or session field contains them
