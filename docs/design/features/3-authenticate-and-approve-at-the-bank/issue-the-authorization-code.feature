# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/issue-the-authorization-code.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@oidc-provider @spec-13.2 @rfc-6749 @walking-skeleton @ready
Feature: Issue the authorization code
  As PSU
  I want the OIDC-provider to redirect me to the TPP with a code and my original state
  So that the TPP can finish without asking me anything else

  @spec-13.2
  Rule: After a valid ID token, the OIDC-provider issues a random single-use code bound to the client, the redirect URI, the PKCE challenge and the consent, and redirects with the client's state

    @nominal @walking-skeleton
    Scenario: The redirect to the TPP
      Given request req-1 by PSDDE-BAFIN-123456 with state S8NJ7…, redirect_uri https://tpp.sandbox/xs2a/callback/bank, code_challenge 5c3055…, scope AIS:123cons456 offline_access, and a valid ID token
      When the OIDC-provider issues the code
      Then the browser is redirected to https://tpp.sandbox/xs2a/callback/bank?code=SplxlOBeZQQYbYS6WxSbIA&state=S8NJ7…
      And the code is 128 bits of randomness, base64url
      And the request status is codeIssued

    @edge @walking-skeleton
    Scenario: The state is returned verbatim
      Given state 'a b+c/d=' URL-encoded on the way in
      When the OIDC-provider redirects
      Then the state parameter decodes to exactly 'a b+c/d='

    @edge @mvp
    Scenario: A redirect URI that already has a query gets the code appended with &
      Given redirect_uri https://tpp.sandbox/xs2a/callback/bank?outcome=nok registered and used
      When the OIDC-provider redirects
      Then the URL is https://tpp.sandbox/xs2a/callback/bank?outcome=nok&code=…&state=…

    @nominal @walking-skeleton
    Scenario: The OIDC-provider redirects only to the registered redirect_uri of the request
      Given the request's redirect_uri
      When the OIDC-provider redirects
      Then the location is that URI, never one derived from the ID token or the CIAM

    @error @walking-skeleton
    Scenario: No code without a valid ID token
      Given the CIAM answered access_denied
      When the OIDC-provider handles the broker callback
      Then no code is issued

  @rfc-6749
  Rule: The code lives 60 seconds and is redeemable once

    @edge @mvp
    Scenario: A code exchanged at 59 seconds works
      Given the code issued at 09:13:40
      When the TPP exchanges it at 09:14:39
      Then tokens are issued

    @error @mvp
    Scenario: A code exchanged at 61 seconds fails
      Given the code issued at 09:13:40
      When the TPP exchanges it at 09:14:41
      Then the OIDC-provider answers 400 invalid_grant

    @error @walking-skeleton
    Scenario: A code exchanged twice
      Given the code was exchanged once
      When it is exchanged again
      Then the OIDC-provider answers 400 invalid_grant and revokes the tokens of the first exchange

  Rule: One request yields at most one code

    @edge @mvp
    Scenario: A second ID token for the same request issues nothing
      Given req-1 is codeIssued
      When a second broker callback for req-1 arrives
      Then the OIDC-provider answers 400 and issues no second code

    @error @mvp
    Scenario: A request that expired before the PSU finished issues nothing
      Given req-1 received at 09:00 and the PSU finished at 09:31 with a 30-minute request lifetime
      When the broker callback arrives
      Then the OIDC-provider redirects the TPP with error=access_denied and error_description 'authorization request expired'
