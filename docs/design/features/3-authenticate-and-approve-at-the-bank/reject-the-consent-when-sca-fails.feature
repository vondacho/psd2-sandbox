# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/reject-the-consent-when-sca-fails.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @oidc-provider @spec-14.15 @mvp @analysing
Feature: Reject the consent when SCA fails
  As Bank product owner
  I want a denied, expired or failed challenge to set the consent to rejected and send the PSU to the nok redirect URI
  So that the TPP learns the outcome without polling forever

  @spec-14.15 @spec-14.16
  Rule: Every failure of the authorisation rejects the consent and fails the authorisation, whatever the cause

    @nominal @mvp
    Scenario: Denied on the device
      Given Anna rejected chl-01J8 in the app
      When the outcome is recorded
      Then authorisation 123auth567 is failed and consent 123cons456 is rejected

    @nominal @mvp
    Scenario: Third challenge expired
      Given chl-01, chl-02 and chl-03 expired
      When the third expiry is processed
      Then the authorisation is failed and the consent rejected

    @nominal @mvp
    Scenario: Too many bad signatures on the last challenge
      Given three invalid signatures on chl-03, the last allowed challenge
      When the third is refused
      Then the authorisation is failed and the consent rejected

    @nominal @mvp
    Scenario: Declined on the summary
      Given Anna clicked 'Decline'
      When the refusal is recorded
      Then the authorisation is failed and the consent rejected

    @nominal @hardening
    Scenario: Refused by the risk engine
      Given the risk decision was refuse
      When the refusal is recorded
      Then the authorisation is failed and the consent rejected

    @nominal @mvp
    Scenario: Locked after the fifth password
      Given anna.mueller was locked in this session
      When the lock is recorded
      Then the authorisation is failed and the consent rejected

    @edge @mvp
    Scenario: Abandoned for 30 minutes
      Given the consent received at 09:00 and no activity since
      When the clock reaches 09:31
      Then the authorisation is failed and the consent rejected

  @spec-14.15
  Rule: rejected is terminal

    @edge @mvp
    Scenario: A late approval outcome is ignored
      Given consent 123cons456 rejected
      When an approved outcome for chl-01J8 arrives
      Then consent management answers 409 and the consent stays rejected

    @error @mvp
    Scenario: A new authorization request for a rejected consent is refused at the OIDC-provider
      Given consent 123cons456 rejected
      When the TPP requests AIS:123cons456 again
      Then the OIDC-provider redirects with error=invalid_scope

    @nominal @mvp
    Scenario: GET status answers rejected
      Given the rejected consent
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is rejected

    @nominal @mvp
    Scenario: No token is ever issued for a rejected consent
      Given the rejected consent
      When the OIDC-provider is asked for the grant of 123cons456
      Then there is none

  @spec-7.6
  Rule: The PSU is sent to the TPP's nok redirect URI with error=access_denied and the TPP's state; without a nok URI, to the ok URI with the error

    @nominal @mvp
    Scenario: With a nok URI
      Given TPP-Nok-Redirect-URI https://tpp.sandbox/xs2a/callback/bank?outcome=nok and state S8NJ7…
      When the PSU returns after a denial
      Then the browser ends at https://tpp.sandbox/xs2a/callback/bank?outcome=nok&error=access_denied&state=S8NJ7…

    @edge @mvp
    Scenario: Without a nok URI
      Given no TPP-Nok-Redirect-URI
      When the PSU returns after a denial
      Then the browser ends at https://tpp.sandbox/xs2a/callback/bank?error=access_denied&state=S8NJ7…

    @edge @mvp
    Scenario: The error carries a reason the TPP can show
      Given a denial in the app
      When the redirect is built
      Then it includes error_description 'denied by PSU'

    @nominal @mvp
    Scenario: The PSU never returns with a code after a failure
      Given any failure
      When the redirect to the TPP is inspected
      Then it has no code parameter

  Rule: The TPP treats access_denied with a valid state as a failed connection, without calling the token endpoint

    @nominal @mvp
    Scenario: The TPP's callback handling
      Given the callback error=access_denied&state=S8NJ7… for a pending attempt
      When the TPP handles it
      Then the attempt outcome is denied, the connection state is failed with 'access not granted'
      And no request goes to the OIDC-provider's token endpoint
      And the page shows 'the Bank did not grant access' and 'Try again'

    @nominal @mvp
    Scenario: A retry creates a new consent
      Given the failed connection
      When Anna clicks 'Try again'
      Then a new POST /v1/consents is sent and a new attempt starts

    @error @mvp
    Scenario: An access_denied with an unknown state is ignored
      Given the callback error=access_denied&state=unknown
      When the TPP handles it
      Then no connection changes and the page shows 'Unknown request'
