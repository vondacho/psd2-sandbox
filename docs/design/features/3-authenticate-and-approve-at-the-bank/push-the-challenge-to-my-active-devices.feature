# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/push-the-challenge-to-my-active-devices.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @bank-app @sca @hardening @analysing
Feature: Push the challenge to my active devices
  As PSU
  I want a notification on my phone so I do not have to scan
  So that approval is one tap away

  Rule: On creation, a push carrying only the challenge id goes to every active device with a push token

    @nominal @hardening
    Scenario: Two active devices get two pushes
      Given Anna has dev-anna-1 (token apns-abc) and dev-anna-2 (token fcm-xyz), both active
      When chl-01 is created
      Then one push is sent to apns-abc and one to fcm-xyz
      And each payload is {challengeId: chl-01} with the title 'Approve a request from TPP App'

    @nominal @hardening
    Scenario: The push carries no details
      Given the push payload
      When it is inspected
      Then it has no accounts, amount, IBAN or hash

    @edge @hardening
    Scenario: A device without token is skipped and the QR still shows
      Given Anna's only active device is the browser simulator without token
      When chl-01 is created
      Then no push is sent and the QR page renders normally

    @nominal @hardening
    Scenario: A blocked device gets no push
      Given dev-anna-0 is blocked with token apns-old
      When chl-01 is created
      Then no push goes to apns-old

    @nominal @hardening
    Scenario: A pending device gets no push
      Given dev-anna-3 is pending with a token
      When chl-01 is created
      Then no push goes to it

  Rule: Tapping the push loads the challenge like a scan would

    @nominal @hardening
    Scenario: The tap opens the approval screen
      Given the push for chl-01 arrived on dev-anna-1
      When Anna taps it
      Then the app calls GET /sca/challenges/chl-01 over the device-authenticated channel and shows the approval screen

    @edge @hardening
    Scenario: A tap after expiry shows the expiry
      Given the push for chl-01 arrived and chl-01 expired
      When Anna taps it
      Then the app shows 'Code expired, request a new one on the Bank page'

    @edge @hardening
    Scenario: A tap after approval on the other device shows it is done
      Given chl-01 was approved on dev-anna-2
      When Anna taps the push on dev-anna-1
      Then the app shows 'Already approved'

  Rule: Push delivery never changes the challenge, and push failures never block the journey

    @error @hardening
    Scenario: A failed push clears the token and the QR path continues
      Given the push provider answers 'Unregistered' for apns-abc
      When chl-01 is created
      Then dev-anna-1's pushToken is cleared and marked 'push disabled'
      And chl-01 is pending and the QR page renders

    @error @hardening
    Scenario: A push provider outage is logged and ignored
      Given the push provider times out
      When chl-01 is created
      Then the challenge is created and the outage is logged

    @nominal @hardening
    Scenario: Delivery receipts do not change the status
      Given the provider reports the push delivered
      When the challenge is read
      Then the status is still pending
