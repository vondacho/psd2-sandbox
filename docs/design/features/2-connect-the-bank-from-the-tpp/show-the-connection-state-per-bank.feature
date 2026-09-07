# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/show-the-connection-state-per-bank.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @mvp @analysing
Feature: Show the connection state per bank
  As PSU
  I want to see whether the Bank is connected, pending or needs re-consent
  So that I know what to do next

  Rule: Each connection state maps to one label and one call to action

    @nominal @mvp
    Scenario: connected shows the validity date and 'View accounts'
      Given Anna's connection to the Bank is connected with validUntil 2026-12-05
      When she opens 'My banks'
      Then the Bank shows 'Connected until 5 Dec 2026' and the button 'View accounts'

    @nominal @mvp
    Scenario: authorizing shows pending and 'Continue at the Bank'
      Given the connection is in state authorizing
      When she opens 'My banks'
      Then the Bank shows 'Pending, finish at the Bank' and the button 'Continue'

    @nominal @mvp
    Scenario: needsReconsent shows the reason and 'Reconnect'
      Given the connection is in state needsReconsent because the consent expired on 2026-09-01
      When she opens 'My banks'
      Then the Bank shows 'Access ended on 1 Sep 2026' and the button 'Reconnect'

    @nominal @mvp
    Scenario: disconnected shows 'Not connected' and 'Connect'
      Given the connection is in state disconnected
      When she opens 'My banks'
      Then the Bank shows 'Not connected' and the button 'Connect'

    @nominal @mvp
    Scenario: failed shows the failure and 'Try again'
      Given the connection is in state failed with reason 'access not granted'
      When she opens 'My banks'
      Then the Bank shows 'Connection failed: access not granted' and the button 'Try again'

    @edge @mvp
    Scenario: A bank never selected is not in 'My banks'
      Given Anna has no connection to bank-c
      When she opens 'My banks'
      Then Bank C is absent; it is only in the picker

  Rule: The label is derived from the consent status and the token set, never from a stale flag

    @nominal @mvp
    Scenario: A valid consent with tokens is connected
      Given consentStatus valid, a token set present
      When the state is computed
      Then the state is connected

    @edge @mvp
    Scenario: A valid consent whose validUntil is today shows 'expires today'
      Given consentStatus valid, validUntil 2026-09-06, today 2026-09-06
      When she opens 'My banks'
      Then the Bank shows 'Connected, expires today' and the button 'Renew'

    @edge @mvp
    Scenario: A valid consent without token set is treated as needing re-consent
      Given consentStatus valid but no token set (the vault entry was deleted)
      When the state is computed
      Then the state is needsReconsent with reason 'tokens missing'
      And an operational warning is logged

    @edge @mvp
    Scenario: A received consent older than 15 minutes is shown as failed
      Given the connection entered authorizing at 09:00 and it is 09:16
      When she opens 'My banks'
      Then the Bank shows 'Connection timed out' and 'Try again'

  Rule: A status change learned from the Bank updates the label on the next page load

    @nominal @mvp
    Scenario: A 401 CONSENT_INVALID on a background call flips the label to re-consent
      Given the connection is connected
      When the nightly refresh gets 401 CONSENT_INVALID from the Bank
      And Anna opens 'My banks'
      Then the Bank shows 'Access was revoked at the Bank' and 'Reconnect'

    @nominal @mvp
    Scenario: A status poll returning valid keeps connected
      Given the connection is connected
      When GET /v1/consents/123cons456/status returns valid
      Then the label stays 'Connected until 5 Dec 2026'
