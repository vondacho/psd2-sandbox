# Generated from docs/design/examplemap/6-come-back-later/ask-the-psu-to-reconnect.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @mvp @ready
Feature: Ask the PSU to reconnect
  As PSU
  I want the TPP to tell me when my consent has ended and offer to reconnect
  So that I can renew before I need my data

  Rule: A connection in needsReconsent shows a banner with the reason and a Reconnect action that starts a new consent on the same connection

    @nominal @mvp
    Scenario: Expired
      Given the connection to the Bank is needsReconsent with reason expired on 2026-12-05
      When Anna opens the TPP
      Then a banner says 'Your connection to the Bank ended on 5 Dec 2026' with 'Reconnect'

    @nominal @mvp
    Scenario: Revoked
      Given reason revoked
      When Anna opens the TPP
      Then the banner says 'Access to the Bank was withdrawn at the bank' with 'Reconnect'

    @nominal @mvp
    Scenario: Reconnect starts a new consent on the same connection
      Given the banner
      When Anna clicks 'Reconnect' and completes the journey
      Then the same BankConnection now holds the new consentId, a new token set and state connected
      And the banner is gone

    @edge @mvp
    Scenario: Dismissing the banner brings it back next visit
      Given Anna dismisses the banner
      When she opens the TPP tomorrow
      Then the banner is shown again

    @edge @mvp
    Scenario: Two banks: two banners
      Given the Bank and Bank C both need re-consent
      When Anna opens the TPP
      Then two banners are shown, one per bank

  Rule: The TPP warns seven days before validUntil and lets the PSU renew early

    @nominal @mvp
    Scenario: Seven days before
      Given validUntil 2026-12-05 and today 2026-11-28
      When Anna opens the TPP
      Then a banner says 'Your connection to the Bank expires on 5 Dec 2026' with 'Renew now'

    @edge @mvp
    Scenario: Eight days before: no banner
      Given today 2026-11-27
      When Anna opens the TPP
      Then no banner is shown

    @nominal @mvp
    Scenario: Renew now replaces the consent
      Given the renewal banner
      When Anna renews and the new consent becomes valid
      Then the Bank terminates the old consent and the connection holds the new one with validUntil 2027-02-26

    @edge @mvp
    Scenario: Renewal declined at the Bank keeps the old connection
      Given Anna declines during the renewal
      When she returns to the TPP
      Then the old consent is still valid and the connection connected, and the banner remains

  Rule: While re-consent is needed, no account data is shown

    @nominal @mvp
    Scenario: Account views are hidden
      Given needsReconsent
      When Anna opens the accounts of the Bank
      Then the page shows the banner and no account rows

    @nominal @mvp
    Scenario: The scheduler skips the connection
      Given needsReconsent
      When the nightly refresh runs
      Then no call is made for the Bank
