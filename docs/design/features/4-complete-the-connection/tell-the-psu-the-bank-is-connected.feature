# Generated from docs/design/examplemap/4-complete-the-connection/tell-the-psu-the-bank-is-connected.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @walking-skeleton @ready
Feature: Tell the PSU the bank is connected
  As PSU
  I want a confirmation screen after I come back from the Bank
  So that I know the connection worked

  Rule: After the token exchange, the confirmation (if any) and a status of valid, the callback page says the bank is connected and offers the accounts

    @nominal @walking-skeleton
    Scenario: The nominal confirmation screen
      Given the exchange succeeded, the PUT answered finalised and the status is valid with validUntil 2026-12-05
      When the callback page renders
      Then it says 'the Bank is connected until 5 December 2026' with the button 'View accounts'
      And the connection state is connected and connectedAt is now

    @edge @mvp
    Scenario: With the consent object, the number of accounts is shown
      Given the consent object lists two accounts
      When the page renders
      Then it says '2 accounts shared'

    @edge @mvp
    Scenario: The status is still received right after confirmation
      Given the PUT answered finalised but GET status answers received
      When the TPP retries the status three times, two seconds apart
      Then if it becomes valid the page says connected
      And if not, the page says 'Almost done, the Bank is finishing up' and the state is authorizing

  Rule: A failure shows what happened and what to do, never a blank page

    @error @walking-skeleton
    Scenario: Access not granted
      Given the callback carried error=access_denied
      When the page renders
      Then it says 'the Bank did not grant access' with 'Try again'

    @error @mvp
    Scenario: Token exchange failed
      Given the OIDC-provider answered invalid_grant
      When the page renders
      Then it says 'Something went wrong while connecting to the Bank (ref A-8F3A). Try again.'

    @error @mvp
    Scenario: The Bank unreachable during confirmation
      Given the PUT timed out
      When the page renders
      Then it says 'the Bank did not answer. Your connection may still complete; check My banks in a minute.'

    @error @mvp
    Scenario: No registered device
      Given error_description 'no registered device'
      When the page renders
      Then it explains that the Bank app must be activated first

  Rule: Reloading or revisiting the callback repeats nothing

    @edge @walking-skeleton
    Scenario: Reload after success
      Given the callback was processed and the state consumed
      When Anna reloads the page
      Then it shows 'the Bank is connected' again and sends nothing to the OIDC-provider or the Bank

    @edge @mvp
    Scenario: Reload after failure
      Given the callback failed
      When Anna reloads
      Then it shows the same failure and 'Try again'

    @edge @mvp
    Scenario: Back button to the Bank's page
      Given Anna presses back to the CIAM page
      When the page renders
      Then the CIAM shows 'This request was already completed' and a link to TPP App
