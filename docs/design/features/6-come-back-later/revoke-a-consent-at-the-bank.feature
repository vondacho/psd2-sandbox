# Generated from docs/design/examplemap/6-come-back-later/revoke-a-consent-at-the-bank.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @spec-14.15 @mvp @analysing
Feature: Revoke a consent at the Bank
  As PSU
  I want a page at the Bank listing my consents with a revoke button
  So that I can cut off an app without contacting the app

  Rule: The dashboard lists every consent of the logged-in PSU with the TPP, the accounts, the validity, the status, the last access and today's usage

    @nominal @mvp
    Scenario: Anna's consents
      Given Anna has consent 123cons456 by TPP App (valid until 2026-12-05, Main Account, last access today 09:15, 3 of 4 without her) and 333cons444 by C Pay (valid until 2026-10-01, Savings)
      When she opens 'Connected apps' in online banking
      Then two rows are shown with those values and a 'Revoke' button each

    @edge @mvp
    Scenario: An expired consent is listed without a button
      Given consent 111cons222 expired on 2026-09-01
      When the dashboard renders
      Then its row says 'expired 1 Sep 2026' and has no 'Revoke'

    @edge @mvp
    Scenario: A revoked consent stays visible for 90 days
      Given a consent revoked 10 days ago
      When the dashboard renders
      Then its row says 'revoked by you on …'

    @edge @mvp
    Scenario: No consents
      Given Ben has no consent
      When he opens 'Connected apps'
      Then the page says 'No app has access to your accounts'

    @nominal @mvp
    Scenario: Ben never sees Anna's consents
      Given Ben is logged in
      When the dashboard renders
      Then 123cons456 is absent

  @spec-14.15
  Rule: Revoking sets the consent to revokedByPsu immediately, revokes its tokens at the OIDC-provider, and the next TPP call is refused

    @nominal @mvp
    Scenario: Revoke TPP App
      Given consent 123cons456 valid and the TPP holding valid tokens
      When Anna clicks 'Revoke' on TPP App and confirms
      Then the consent status is revokedByPsu
      And consent management calls POST /internal/tokens/revoke?consent_id=123cons456 at the OIDC-provider
      And the TPP's next GET /v1/accounts answers 401 CONSENT_INVALID
      And the row says 'revoked by you just now'

    @nominal @mvp
    Scenario: C's consent is untouched
      Given the revocation of 123cons456
      When C calls GET /v1/accounts with 333cons444
      Then the answer is 200

    @edge @mvp
    Scenario: Revoking twice
      Given 123cons456 already revokedByPsu
      When the revoke request is sent again
      Then the answer is 204 and nothing changes

    @error @mvp
    Scenario: Ben cannot revoke Anna's consent
      Given Ben is logged in
      When he posts the revoke request for 123cons456
      Then the answer is 404 and the consent stays valid

    @edge @mvp
    Scenario: The OIDC-provider is unreachable during revocation
      Given the OIDC-provider answers 503 to the token revocation
      When Anna revokes
      Then the consent is revokedByPsu at once, the token revocation is queued and retried, and the TPP's calls are already refused

  Rule: Revocation is the PSU's act; the TPP learns it on its next call or through a notification

    @nominal @mvp
    Scenario: The TPP learns from the failed call
      Given the revocation
      When the TPP's nightly call answers 401 CONSENT_INVALID
      Then the TPP marks the connection needsReconsent with reason revoked

    @nominal @mvp
    Scenario: GET status says revokedByPsu
      Given the revocation
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is revokedByPsu

    @edge @mvp
    Scenario: A revoked consent cannot be un-revoked
      Given 123cons456 revokedByPsu
      When Anna wants TPP App back
      Then she connects again from TPP App, which creates a new consent
