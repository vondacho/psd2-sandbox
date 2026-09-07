# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/deny-a-challenge-from-the-app.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-app @mvp @ready
Feature: Deny a challenge from the app
  As PSU
  I want a reject button that fails the authorisation
  So that I can stop a request I did not start

  Rule: Reject from an active device of the PSU denies the pending challenge, fails the authorisation and rejects the consent

    @nominal @mvp
    Scenario: Anna rejects
      Given chl-01J8 pending for anna.mueller loaded on dev-anna-1
      When Anna taps 'Reject'
      Then POST /sca/challenges/chl-01J8/response is sent with {deviceId: dev-anna-1, decision: deny} over the device-authenticated channel
      And the challenge is denied, the session refused, the authorisation failed, the consent rejected
      And the app shows 'Rejected. Nothing was granted.'

    @nominal @mvp
    Scenario: The browser learns the denial
      Given the QR page is polling
      When the denial is recorded
      Then the page shows 'You rejected the request on your device' and 'Back to TPP App'

    @nominal @mvp
    Scenario: The TPP learns the denial through the nok redirect
      Given Anna clicks 'Back to TPP App'
      When the browser arrives at the TPP
      Then the TPP's connection is failed with 'access not granted' and offers 'Try again'

    @nominal @mvp
    Scenario: A denial needs no signature over the hash but does need the device channel
      Given the deny request
      When it is inspected
      Then it carries X-Device-Id, X-Timestamp, X-Nonce and X-Signature, and no challenge signature

  @security
  Rule: Only the PSU's own active device may deny

    @error @mvp
    Scenario: Ben's device cannot deny Anna's challenge
      Given chl-01J8 for anna.mueller
      When dev-ben-1 posts decision deny
      Then the answer is 403 and the challenge stays pending

    @error @mvp
    Scenario: A blocked device cannot deny
      Given dev-anna-0 blocked
      When it posts decision deny
      Then the answer is 403

    @error @mvp
    Scenario: An unauthenticated deny is refused
      Given a POST without device signature headers
      When it arrives
      Then the answer is 401

  Rule: A denial is final for that challenge and harmless for the PSU

    @error @mvp
    Scenario: Approve after deny is refused
      Given chl-01J8 denied
      When a valid approval signature is posted
      Then the answer is 409 and the status stays denied

    @edge @mvp
    Scenario: Deny after expiry
      Given chl-01J8 expired
      When Anna taps 'Reject'
      Then the answer is 410 and the app shows 'This code had already expired'

    @edge @mvp
    Scenario: Deny after approval
      Given chl-01J8 approved on dev-anna-2
      When dev-anna-1 posts deny
      Then the answer is 409 and the status stays approved

    @nominal @mvp
    Scenario: A denial locks nothing
      Given Anna denied chl-01J8
      When she starts a new connection from TPP App
      Then a new consent is created and the journey runs normally

    @edge @mvp
    Scenario: Denials are counted for fraud monitoring
      Given Anna denied three challenges from TPP App this week
      When the security dashboard is read
      Then it shows 3 denials for TPP App with the timestamps
