# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/scan-the-qr-and-fetch-the-challenge.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-app @sca @walking-skeleton @ready
Feature: Scan the QR and fetch the challenge
  As PSU
  I want the app to read the QR and load the challenge from the Bank over an authenticated channel
  So that what I approve is what the bank recorded, not what the QR says

  @security
  Rule: The app verifies the payload's server signature and endpoint before any network call

    @nominal @walking-skeleton
    Scenario: A genuine QR is fetched
      Given the QR of chl-01J8 signed by the SCA engine with endpoint https://ciam.bank.sandbox/sca
      When Anna scans it with the app on dev-anna-1
      Then the app calls GET https://ciam.bank.sandbox/sca/challenges/chl-01J8

    @error @walking-skeleton
    Scenario: An altered payload is refused offline
      Given a QR whose payload was modified after signing
      When Anna scans it
      Then the app shows 'Not a Bank code'
      And no request is sent

    @error @mvp
    Scenario: A payload pointing to another host is refused offline
      Given a QR with endpoint https://evil.example/sca and a signature from an unknown key
      When Anna scans it
      Then the app shows 'Not a Bank code' and sends nothing

    @edge @mvp
    Scenario: A payload with an unsupported version asks for an update
      Given a QR with v: 2
      When Anna scans it with an app that supports v 1 only
      Then the app shows 'Update the Bank app to continue'

    @error @walking-skeleton
    Scenario: A QR that is not a Bank payload at all is ignored
      Given a QR encoding https://example.com
      When Anna scans it
      Then the app shows 'Not a Bank code'

  @security
  Rule: The fetch is authenticated with the device key: a signed request with the device id, a timestamp and a fresh nonce

    @nominal @walking-skeleton
    Scenario: A correctly signed fetch returns the details
      Given dev-anna-1 active
      When the app sends GET /sca/challenges/chl-01J8 with headers X-Device-Id dev-anna-1, X-Timestamp, X-Nonce and X-Signature over method, path, timestamp and nonce
      Then the answer is 200 with the challenge details

    @error @walking-skeleton
    Scenario: A fetch with a bad signature is refused
      Given X-Signature made with another key
      When the fetch is sent
      Then the answer is 401

    @error @mvp
    Scenario: A replayed fetch is refused
      Given a fetch with nonce n1 already accepted
      When the same request is sent again
      Then the answer is 401 'nonce reused'

    @error @mvp
    Scenario: A fetch with a timestamp older than five minutes is refused
      Given X-Timestamp ten minutes in the past
      When the fetch is sent
      Then the answer is 401 'stale request'

    @error @mvp
    Scenario: A fetch from a blocked device is refused
      Given dev-anna-0 blocked
      When it fetches chl-01J8
      Then the answer is 403 'device blocked'

    @error @mvp
    Scenario: A fetch from a pending device is refused
      Given dev-anna-3 pending
      When it fetches chl-01J8
      Then the answer is 403 'device not active'

  @security
  Rule: A challenge is only returned to an active device of the PSU it was issued for

    @nominal @walking-skeleton
    Scenario: Anna's device gets Anna's challenge
      Given chl-01J8 for anna.mueller and dev-anna-1 of anna.mueller
      When dev-anna-1 fetches it
      Then the answer is 200

    @error @walking-skeleton
    Scenario: Ben's device does not get Anna's challenge
      Given chl-01J8 for anna.mueller and dev-ben-1 of ben.weber
      When dev-ben-1 fetches it
      Then the answer is 403 'challenge not for this device'
      And the app shows 'This code is not for this device'

    @error @walking-skeleton
    Scenario: An unknown challenge id
      Given no challenge chl-nope
      When dev-anna-1 fetches it
      Then the answer is 404 and the app shows 'Code invalid'

    @error @mvp
    Scenario: An expired challenge
      Given chl-01J8 expired
      When dev-anna-1 fetches it
      Then the answer is 410 and the app shows 'Code expired, request a new one on the Bank page'

  @rts-art-5
  Rule: The app shows the server's details and refuses a QR whose hash disagrees with the server

    @nominal @walking-skeleton
    Scenario: The details shown come from the server
      Given the server's challenge says TPP App, Main Account, until 2026-12-05
      When the approval screen renders
      Then it shows exactly those values

    @error @mvp
    Scenario: A QR hash that differs from the server's hash is refused
      Given a QR with dl H9 while the server's challenge chl-01J8 has hash H1
      When the app compares them
      Then it shows 'This code was tampered with' and offers no approve button
      And the mismatch is reported to the SCA engine
