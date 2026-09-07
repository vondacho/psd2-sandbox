# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/broker-the-psu-to-the-bank-ciam.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@oidc-provider @oidc-core @walking-skeleton @analysing
Feature: Broker the PSU to the Bank CIAM
  As PSU
  I want the OIDC-provider to hand me to the Bank's own login page with the consent context
  So that I authenticate with my bank, not with a stranger

  @oidc-core
  Rule: After the scope is validated, the OIDC-provider redirects the browser to the CIAM with its own state and nonce, the required acr and the consent context

    @nominal @walking-skeleton
    Scenario: The brokered authorization request
      Given the request for AIS:123cons456 by client PSDDE-BAFIN-123456 passed scope validation
      When the OIDC-provider answers the browser
      Then it is a 302 to https://ciam.bank.sandbox/authorize with client_id oidc-broker, response_type code, scope openid, acr_values urn:bank:psd2:sca, a fresh state and nonce, redirect_uri https://oidc-provider.sandbox/broker/callback, consent_id 123cons456 and tpp_client_id PSDDE-BAFIN-123456

    @nominal @walking-skeleton
    Scenario: The TPP's state is not forwarded to the CIAM
      Given the TPP's state S8NJ7…
      When the brokered URL is inspected
      Then its state differs from S8NJ7…

    @nominal @walking-skeleton
    Scenario: The PSU is never asked for credentials at the OIDC-provider
      Given the OIDC-provider has no PSU accounts
      When the browser hits /authorize
      Then the OIDC-provider renders no login form and redirects to the CIAM

    @error @mvp
    Scenario: The CIAM unreachable yields temporarily_unavailable to the TPP
      Given the CIAM answers 503 on /authorize
      When the browser follows the redirect
      Then the CIAM's error is shown and the OIDC-provider, on its next contact, redirects the TPP with error=temporarily_unavailable

  @oidc-core
  Rule: The OIDC-provider accepts the CIAM's ID token only if it is signed by the CIAM, meant for the OIDC-provider, fresh, and carries the required acr and the requested consent id with status authorised

    @nominal @walking-skeleton
    Scenario: A correct ID token yields a code for the TPP
      Given an ID token with iss https://ciam.bank.sandbox, aud oidc-broker, the sent nonce, exp in 5 minutes, acr urn:bank:psd2:sca, amr [pwd, hwk], consent_id 123cons456, consent_status authorised
      When the OIDC-provider validates it
      Then the OIDC-provider issues an authorization code to the TPP

    @error @walking-skeleton
    Scenario: An ID token with a lower acr is refused
      Given an ID token with acr urn:bank:password-only
      When the OIDC-provider validates it
      Then the OIDC-provider redirects the TPP with error=access_denied and error_description 'SCA not performed'

    @error @walking-skeleton
    Scenario: An ID token for another consent is refused
      Given an ID token with consent_id 111cons222 while AIS:123cons456 was requested
      When the OIDC-provider validates it
      Then the OIDC-provider issues no code and redirects the TPP with error=server_error
      And the mismatch is logged as a security event

    @error @mvp
    Scenario: A refused consent yields access_denied
      Given an ID token with consent_status refused
      When the OIDC-provider validates it
      Then the OIDC-provider redirects the TPP's nok URI with error=access_denied and the state

    @error @mvp
    Scenario: A wrong nonce is refused
      Given an ID token whose nonce is not the one the OIDC-provider sent
      When the OIDC-provider validates it
      Then the OIDC-provider issues no code

    @error @mvp
    Scenario: An expired ID token is refused
      Given an ID token with exp one minute in the past
      When the OIDC-provider validates it
      Then the OIDC-provider issues no code and redirects the TPP with error=server_error

    @error @mvp
    Scenario: An ID token signed with an unknown key is refused
      Given an ID token whose kid is not in the CIAM's JWKS
      When the OIDC-provider validates it
      Then the OIDC-provider issues no code

    @error @mvp
    Scenario: An ID token with aud of another relying party is refused
      Given an ID token with aud other-rp
      When the OIDC-provider validates it
      Then the OIDC-provider issues no code

  Rule: The CIAM's callback to the OIDC-provider is single-use and bound to the brokered request

    @error @mvp
    Scenario: A replayed broker callback is refused
      Given the CIAM redirected to https://oidc-provider.sandbox/broker/callback?code=c1&state=st1 and the OIDC-provider processed it
      When the same URL is opened again
      Then the OIDC-provider answers 400 'request already completed'

    @error @mvp
    Scenario: A broker callback with an unknown state is refused
      Given a callback with state st-unknown
      When the OIDC-provider handles it
      Then the OIDC-provider answers 400 and issues no code

    @nominal @walking-skeleton
    Scenario: The OIDC-provider redeems the CIAM code over the back channel with its own client credentials
      Given the broker callback with code c1
      When the OIDC-provider calls POST https://ciam.bank.sandbox/token
      Then the call authenticates client oidc-broker and returns the ID token
      And the browser never sees the ID token
