# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/approve-with-biometric-or-pin-and-sign.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-app @sca @rts-art-4 @walking-skeleton @ready
Feature: Approve with biometric or PIN and sign
  As PSU
  I want the app to sign the challenge with my device key after my biometric or PIN
  So that possession and a local check are both needed

  @rts-art-4
  Rule: Approve triggers the phone's user verification, and only after success the device key signs

    @nominal @walking-skeleton
    Scenario: Face ID then signature
      Given chl-01J8 loaded on dev-anna-1
      When Anna taps 'Approve' and Face ID succeeds
      Then the app signs the message 'chl-01J8|m3A9…|H1' with the device key (ES256)
      And POST /sca/challenges/chl-01J8/response is sent with {deviceId: dev-anna-1, signature, amr: [hwk, face]}
      And the app shows 'Approved. Return to your browser.'

    @nominal @walking-skeleton
    Scenario: PIN fallback after a failed biometric
      Given Face ID fails and the phone offers the passcode
      When Anna enters the passcode
      Then the signature is made and posted with amr [hwk, pin]

    @error @walking-skeleton
    Scenario: Cancelling the verification sends nothing
      Given chl-01J8 loaded
      When Anna cancels the Face ID prompt
      Then no request is sent and the challenge stays pending
      And the screen returns to the details with the approve button

    @error @mvp
    Scenario: Too many failed verifications send nothing
      Given biometric fails and the passcode is wrong three times
      When the phone locks the verification
      Then no request is sent and the app shows 'Try again later'

    @nominal @walking-skeleton
    Scenario: The key cannot sign without the verification
      Given an instrumented app that skips the prompt
      When it asks the keystore to sign
      Then the keystore refuses

  @rts-art-5
  Rule: The signed message binds the challenge id, the nonce and the dynamic-link hash

    @nominal @walking-skeleton
    Scenario: The message format
      Given chl-01J8, nonce m3A9…, hash H1
      When the message is built
      Then it is the UTF-8 string 'chl-01J8|m3A9…|H1'

    @nominal @walking-skeleton
    Scenario: A signature cannot be precomputed before the challenge exists
      Given the nonce is generated at challenge creation
      When an attacker has the hash H1 in advance
      Then the signature still needs the nonce, which is only in the challenge

    @nominal @walking-skeleton
    Scenario: The signature is ES256 in raw r||s form, 64 bytes
      Given a signature from dev-anna-1
      When it is inspected
      Then it is 64 bytes, base64url in the request

  Rule: The response is posted over the device-authenticated channel, once, and survives a flaky network

    @nominal @walking-skeleton
    Scenario: The response is a signed request from the device
      Given the response
      When it is sent
      Then it carries X-Device-Id, X-Timestamp, X-Nonce and X-Signature like the fetch

    @edge @mvp
    Scenario: A network error retries the identical request once
      Given the first POST times out
      When the app retries with the same signature
      Then the server, which had received the first, answers 409 'already answered' and the app treats it as success

    @edge @mvp
    Scenario: Expiry during the prompt
      Given chl-01J8 expires while the Face ID prompt is open
      When the signature is posted
      Then the answer is 410 and the app shows 'Code expired, request a new one on the Bank page'

    @nominal @mvp
    Scenario: The app never stores the signature or the challenge after posting
      Given the response was posted
      When the app's local storage is inspected
      Then no challenge or signature is kept
