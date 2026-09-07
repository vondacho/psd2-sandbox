# Generated from docs/design/examplemap/1-enrol-a-device-at-the-bank/device-simulator-in-the-browser.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@sandbox @bank-app @walking-skeleton @ready
Feature: Device simulator in the browser
  As PSU
  I want a web page that holds a WebCrypto key and scans or pastes a QR
  So that the sandbox journey runs without a native app

  Rule: The simulator holds one non-extractable WebCrypto P-256 key pair that survives a reload

    @nominal @walking-skeleton
    Scenario: First visit generates a key and shows its public JWK
      Given a fresh browser profile opens https://app.bank.sandbox/simulator
      When the page loads
      Then a P-256 key pair is generated with extractable = false
      And the key is stored in IndexedDB
      And the page shows the public JWK and the state 'not enrolled'

    @nominal @walking-skeleton
    Scenario: A reload keeps the same key
      Given the simulator generated key K1
      When the page is reloaded
      Then the public JWK shown is still K1

    @edge @mvp
    Scenario: Clearing site data loses the key and the enrolment
      Given the simulator is enrolled as dev-anna-sim with key K1
      When the browser's site data is cleared and the page reopened
      Then a new key K2 is generated
      And the page shows 'not enrolled' and hints that dev-anna-sim must be removed at the Bank

    @error @walking-skeleton
    Scenario: The private key cannot be exported through the console
      Given the simulator key in IndexedDB
      When crypto.subtle.exportKey('jwk', privateKey) is called
      Then the call rejects with InvalidAccessError

  Rule: The simulator enrols through the same device API as the native app

    @nominal @walking-skeleton
    Scenario: Enrolling the simulator creates a device at the Bank
      Given Anna is logged in to the Bank online banking in the same browser
      When she clicks 'Enrol this browser' in the simulator
      Then POST /devices is sent with the public JWK, platform 'browser', name 'Browser simulator' and no pushToken
      And the Bank lists 'Browser simulator' under Anna's devices

    @nominal @walking-skeleton
    Scenario: The simulator is activated with the sandbox activation code
      Given the simulator is enrolled and pending
      And the sandbox shows the activation code 0000-0000 on the mock letter page
      When Anna enters 0000-0000 in the simulator
      Then the device is active
      And the simulator shows 'enrolled as dev-anna-sim, active'

  Rule: A challenge can be entered by camera scan or by pasting the payload

    @nominal @walking-skeleton
    Scenario: Pasting a QR payload loads the challenge
      Given the QR page shows the payload text for challenge chl-01
      When Anna pastes the payload into the simulator
      Then the simulator fetches GET /sca/challenges/chl-01 with a device-signed request
      And the approval screen shows 'TPP App wants to read Main Account until 2026-12-05'

    @nominal @mvp
    Scenario: Scanning the QR with the camera loads the same challenge
      Given the QR page is displayed on a second screen
      When Anna clicks 'Scan' and points the camera at it
      Then the payload is decoded and the challenge is fetched

    @error @walking-skeleton
    Scenario: A malformed payload is rejected before any network call
      Given the pasted text is 'hello world'
      When Anna clicks 'Load'
      Then the simulator shows 'Not a Bank code'
      And no request is sent

    @error @mvp
    Scenario: A payload whose endpoint is not the Bank is refused
      Given a well-formed payload with endpoint https://evil.example/sca
      When Anna pastes it
      Then the simulator shows 'This code does not come from the Bank'
      And no request is sent to evil.example

    @error @mvp
    Scenario: A payload with an invalid server signature is refused
      Given a payload whose server signature was altered
      When Anna pastes it
      Then the simulator shows 'Not a Bank code'

  @sca
  Rule: The simulator signs only after a simulated local verification

    @nominal @walking-skeleton
    Scenario: The correct PIN signs and posts the response
      Given challenge chl-01 is loaded and the simulator PIN is 1234
      When Anna clicks 'Approve' and enters 1234
      Then the simulator signs 'chl-01|nonce|dynamic-link-hash' with the WebCrypto key
      And POST /sca/challenges/chl-01/response is sent
      And the simulator shows 'Approved'

    @error @walking-skeleton
    Scenario: A wrong PIN sends nothing
      Given challenge chl-01 is loaded
      When Anna clicks 'Approve' and enters 0000
      Then the simulator shows 'Wrong PIN'
      And no request is sent

    @nominal @mvp
    Scenario: Reject sends a denial without signing
      Given challenge chl-01 is loaded
      When Anna clicks 'Reject'
      Then POST /sca/challenges/chl-01/response is sent with decision deny
      And the simulator shows 'Rejected'
