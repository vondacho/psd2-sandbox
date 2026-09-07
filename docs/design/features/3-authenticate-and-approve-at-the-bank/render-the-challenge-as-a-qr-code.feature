# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/render-the-challenge-as-a-qr-code.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-ciam @sca @walking-skeleton @ready
Feature: Render the challenge as a QR code
  As PSU
  I want a QR code on the Bank's page that my app can scan
  So that I can approve from my registered device

  Rule: The QR encodes a signed payload with version, challenge id, nonce, endpoint, expiry and the dynamic-link hash, and nothing else

    @nominal @walking-skeleton
    Scenario: The decoded payload
      Given challenge chl-01J8 with nonce m3A9…, hash H1, expiresAt 1757150180
      When the QR page renders
      Then the QR decodes to base64url JSON {v: 1, challengeId: chl-01J8, nonce: m3A9…, endpoint: https://ciam.bank.sandbox/sca, exp: 1757150180, dl: H1} followed by a server signature

    @nominal @walking-skeleton
    Scenario: The payload carries no personal data
      Given the decoded payload
      When its fields are listed
      Then there is no PSU-ID, IBAN, TPP name or amount

    @nominal @walking-skeleton
    Scenario: The server signature verifies with the SCA engine's public key
      Given the payload and its signature
      When the app verifies with the key published at https://ciam.bank.sandbox/sca/keys
      Then the verification succeeds

    @edge @mvp
    Scenario: The encoded payload stays under 400 characters so the QR is readable on a phone
      Given the longest possible challenge id and endpoint
      When the payload is encoded
      Then it has at most 400 characters and the QR is version 10 or lower

  Rule: The page shows the QR, the same summary as the app will show, a countdown and a copyable text form of the payload

    @nominal @walking-skeleton
    Scenario: The QR page
      Given the challenge for Main Account until 2026-12-05
      When the page renders
      Then it shows the QR, 'TPP App: accounts and balances of DE23 …7 89 until 5 Dec 2026', 'expires in 3:00' and a 'Copy code' button

    @edge @mvp
    Scenario: The countdown reaches zero
      Given the page opened at 09:12:00
      When the clock reaches 09:15:00
      Then the QR is hidden and the page shows 'Code expired'

    @nominal @walking-skeleton
    Scenario: Copy code yields the exact payload text
      Given the page
      When Anna clicks 'Copy code'
      Then the clipboard holds the base64url payload with its signature

  Rule: The page polls the challenge status and moves on when it changes

    @nominal @walking-skeleton
    Scenario: Approval redirects to the OIDC-provider
      Given the page polls GET /challenge/chl-01J8/status every 2 seconds
      When the status becomes approved
      Then the next poll answers approved and the browser is redirected to the OIDC-provider's broker callback

    @nominal @mvp
    Scenario: Denial shows the refusal
      Given the page polls
      When the status becomes denied
      Then the page shows 'You rejected the request on your device' and 'Back to TPP App'

    @edge @mvp
    Scenario: A hidden tab catches up when shown again
      Given the tab was in the background for five minutes
      When it becomes visible
      Then the next poll answers expired and the page shows 'Code expired' with 'New code'

    @error @mvp
    Scenario: The status endpoint is bound to the session
      Given chl-01J8 belongs to session sess-1
      When a browser without sess-1's cookie polls /challenge/chl-01J8/status
      Then the answer is 404

    @edge @mvp
    Scenario: Polling stops after the terminal status
      Given the status became approved
      When the page has redirected
      Then no further poll is sent
