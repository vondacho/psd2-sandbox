# Generated from docs/design/examplemap/6-come-back-later/refresh-an-expired-access-token.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @oidc-provider @spec-13.5 @mvp @ready
Feature: Refresh an expired access token
  As PSU
  I want the TPP to renew its token silently while my consent is valid
  So that I am not asked to authenticate on every visit

  @spec-13.5
  Rule: The TPP refreshes before a call when the access token expires within 60 seconds, or after a 401 TOKEN_EXPIRED, and retries the call once

    @nominal @mvp
    Scenario: Reactive refresh
      Given the stored access token expired and the refresh token R1 is valid
      When the TPP calls GET /v1/accounts and gets 401 TOKEN_EXPIRED
      Then the TPP posts grant_type=refresh_token with R1 over mTLS, stores the new tokens, and repeats GET /v1/accounts once
      And the second call answers 200 and Anna sees her accounts without any prompt

    @nominal @mvp
    Scenario: Proactive refresh
      Given the access token expires in 30 seconds
      When the TPP prepares GET /v1/accounts
      Then the TPP refreshes first and the call is made with the new token

    @edge @mvp
    Scenario: A token that expires in 90 seconds is used as is
      Given the access token expires in 90 seconds
      When the TPP prepares the call
      Then no refresh happens

    @edge @mvp
    Scenario: At most one refresh per call
      Given the refreshed token is also refused with TOKEN_EXPIRED (clock skew at the Bank)
      When the TPP handles the second 401
      Then the TPP does not refresh again, marks the connection failed and raises an alert 'token refused after refresh'

  Rule: A refresh that fails because the consent ended puts the connection in re-consent; a transient failure is retried

    @error @mvp
    Scenario: invalid_grant
      Given the OIDC-provider answers 400 invalid_grant
      When the TPP handles it
      Then the token set is deleted and the connection is needsReconsent
      And Anna sees 'Your connection to the Bank ended. Reconnect.'

    @error @mvp
    Scenario: The OIDC-provider is unavailable
      Given the OIDC-provider answers 503
      When the TPP handles it
      Then the TPP retries after 2 and 4 seconds, then shows 'the Bank is temporarily unavailable' and keeps the token set

    @error @mvp
    Scenario: invalid_client
      Given the OIDC-provider answers 401 invalid_client
      When the TPP handles it
      Then an operational alert is raised and the connection is failed

  Rule: Concurrent calls share one refresh

    @edge @mvp
    Scenario: Two requests at once
      Given Anna opens the list and a detail at the same moment with an expired token
      When both calls hit 401 TOKEN_EXPIRED
      Then exactly one refresh request goes to the OIDC-provider and both calls retry with the new token

    @edge @mvp
    Scenario: The nightly scheduler and a PSU click
      Given the scheduler is refreshing when Anna clicks
      When Anna's call needs a token
      Then it waits for the running refresh and uses its result

  Rule: The refresh is invisible to the PSU and never uses the browser

    @nominal @mvp
    Scenario: No redirect during a refresh
      Given a reactive refresh
      When the browser traffic is inspected
      Then no redirect to the OIDC-provider or the Bank happened

    @nominal @mvp
    Scenario: The old refresh token is gone after rotation
      Given R1 rotated to R2
      When the vault is read
      Then only R2 is stored
