# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/verify-the-signature-against-the-registered-key.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-ciam @sca @security @walking-skeleton @ready
Feature: Verify the signature against the registered key
  As Bank security officer
  I want the response accepted only from an active device of the identified PSU with a valid signature
  So that a stolen challenge id is worthless

  @rts-art-5
  Rule: A response is accepted only if the challenge is pending and unexpired, the device is active and belongs to the challenge's PSU, and the signature verifies over the expected message with the stored key

    @nominal @walking-skeleton
    Scenario: The nominal approval
      Given chl-01J8 pending for anna.mueller, dev-anna-1 active with key K1
      When a signature over 'chl-01J8|m3A9…|H1' made with K1 is posted with deviceId dev-anna-1
      Then the answer is 200 {status: approved}
      And the challenge is approved with deviceId dev-anna-1, the signature stored and answeredAt set

    @error @walking-skeleton
    Scenario: A signature from Ben's active device
      Given chl-01J8 for anna.mueller and dev-ben-1 active with key K2
      When a valid K2 signature is posted with deviceId dev-ben-1
      Then the answer is 403 'challenge not for this device'
      And chl-01J8 stays pending

    @error @walking-skeleton
    Scenario: A signature from Anna's blocked device
      Given dev-anna-0 blocked with key K0
      When a valid K0 signature is posted
      Then the answer is 403 'device blocked' and chl-01J8 stays pending

    @error @mvp
    Scenario: A signature from Anna's pending device
      Given dev-anna-3 pending
      When a valid signature is posted
      Then the answer is 403 'device not active'

    @error @walking-skeleton
    Scenario: A valid signature over another challenge's message
      Given a K1 signature over 'chl-99|nonce99|H1'
      When it is posted for chl-01J8
      Then the answer is 400 'signature invalid' and the attempt counter is 1

    @error @walking-skeleton
    Scenario: A valid signature over another consent's hash
      Given a K1 signature over 'chl-01J8|m3A9…|H2'
      When it is posted
      Then the answer is 400 'signature invalid'

    @error @walking-skeleton
    Scenario: Random bytes as signature
      Given 64 random bytes
      When they are posted as the signature
      Then the answer is 400 'signature invalid' and the attempt counter is 1

    @error @mvp
    Scenario: A correct signature for an expired challenge
      Given chl-01J8 expired
      When a valid signature is posted
      Then the answer is 410 and the status stays expired

    @edge @mvp
    Scenario: A second correct signature
      Given chl-01J8 approved
      When the same signature is posted again
      Then the answer is 409 'already answered' and nothing changes

    @error @walking-skeleton
    Scenario: An unknown device id
      Given deviceId dev-nope
      When a signature is posted
      Then the answer is 403

    @error @mvp
    Scenario: A device id of Anna's with a signature from another of Anna's keys
      Given dev-anna-1 (K1) and dev-anna-2 (K3) both active
      When a K3 signature is posted with deviceId dev-anna-1
      Then the answer is 400 'signature invalid'

  @security
  Rule: Verification uses the key stored at enrolment; nothing in the response can supply a key

    @error @walking-skeleton
    Scenario: A public key sent in the response is ignored
      Given a response body with an extra field publicKey holding an attacker's key, and a signature made with that key
      When it is posted for dev-anna-1
      Then the answer is 400 'signature invalid'

    @nominal @mvp
    Scenario: A rotated key is a new device, not a new key for the old device
      Given dev-anna-1 stored with K1
      When the registry is asked to replace K1 by K5
      Then it refuses; only a new device record can carry K5

  Rule: A successful verification updates the challenge, the device and the session

    @nominal @walking-skeleton
    Scenario: The side effects
      Given the nominal approval at 2026-09-06T09:13:20Z
      When it is processed
      Then dev-anna-1.lastUsedAt is 09:13:20Z
      And the session step is approved and its methods are [pwd, hwk, face]
      And the outcome is sent to consent management

    @nominal @mvp
    Scenario: The stored evidence allows a later audit
      Given the approved challenge
      When an auditor reads it
      Then they find the hash, the nonce, the device id, the signature and the timestamps, enough to re-verify
