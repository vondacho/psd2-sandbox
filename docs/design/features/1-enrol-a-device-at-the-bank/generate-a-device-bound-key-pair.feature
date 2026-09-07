# Generated from docs/design/examplemap/1-enrol-a-device-at-the-bank/generate-a-device-bound-key-pair.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-app @walking-skeleton @analysing
Feature: Generate a device-bound key pair
  As PSU
  I want the app to create a key in my phone's secure hardware when I activate it
  So that only this device can approve my consents

  @rts-art-7
  Rule: The key pair is created inside the device's secure hardware and the private key never leaves it

    @nominal @walking-skeleton
    Scenario: Activation on an iPhone with Secure Enclave creates a non-exportable P-256 key
      Given Anna installs the Bank app on an iPhone with a Secure Enclave
      When she taps 'Activate this device'
      Then a P-256 key pair is generated in the Secure Enclave
      And the private key is marked non-exportable
      And the app records hardwareBacked = true

    @nominal @walking-skeleton
    Scenario: Activation on an Android phone with StrongBox uses the StrongBox keystore
      Given Anna installs the Bank app on an Android phone that reports StrongBox
      When she taps 'Activate this device'
      Then the key pair is generated with setIsStrongBoxBacked(true)
      And the app records hardwareBacked = true

    @edge @walking-skeleton
    Scenario: Android phone with a TEE keystore but no StrongBox is accepted as hardware-backed
      Given an Android phone whose keystore reports security level TRUSTED_ENVIRONMENT
      When the app activates the device
      Then the key pair is generated in the TEE keystore
      And the app records hardwareBacked = true

    @edge @mvp
    Scenario: A phone without any hardware keystore generates a software key flagged as such
      Given an old Android phone whose keystore reports security level SOFTWARE
      When the app activates the device
      Then the key pair is generated as non-exportable in the software keystore
      And the app records hardwareBacked = false
      And the registration request carries hardwareBacked = false so the Bank can decide

    @error @walking-skeleton
    Scenario: The private key cannot be read back by the app
      Given an activated device with its key pair
      When the app asks the keystore to export the private key
      Then the keystore refuses
      And only the public key is available for export

  Rule: The key uses ECDSA with curve P-256 and the public key is exported as a JWK

    @nominal @walking-skeleton
    Scenario: The exported public key is a P-256 JWK with x and y only
      Given an activated device
      When the app exports the public key for registration
      Then the JWK has kty = EC, crv = P-256, alg = ES256
      And the JWK carries x and y and no d parameter

    @nominal @walking-skeleton
    Scenario: A signature made with the key verifies with the exported public key
      Given the exported JWK of Anna's iPhone
      And the message 'chl_01J8|m3A9|H1' signed with the device key
      When the signature is verified with the JWK
      Then the verification succeeds

  @sca
  Rule: Key generation requires a local user verification method on the phone

    @error @mvp
    Scenario: A phone without screen lock cannot be activated
      Given an iPhone with no passcode and no Face ID configured
      When Anna taps 'Activate this device'
      Then the app shows 'Set up a passcode or Face ID first'
      And no key pair is generated

    @edge @walking-skeleton
    Scenario: A phone with only a PIN is accepted
      Given an Android phone with a 6-digit PIN and no biometrics
      When Anna activates the device
      Then the key pair is generated with userAuthenticationRequired = true
      And later approvals will ask for the PIN

    @nominal @walking-skeleton
    Scenario: Using the key requires the user verification each time
      Given an activated device
      When the app signs a challenge without a preceding Face ID or PIN prompt
      Then the keystore refuses the signing operation

  Rule: Each app installation holds exactly one key pair; a new key is a new device

    @edge @mvp
    Scenario: Reinstalling the app produces a new key and therefore a new device
      Given Anna's iPhone was enrolled as device dev-anna-1 with key K1
      When she deletes and reinstalls the app and activates it again
      Then a new key K2 is generated
      And the registration creates a new device record dev-anna-2
      And dev-anna-1 remains until Anna removes it

    @edge @mvp
    Scenario: Starting the activation twice before finishing replaces the unfinished key
      Given Anna tapped 'Activate' and closed the app before registration finished
      When she taps 'Activate' again
      Then the unfinished key is deleted from the keystore
      And one new key pair exists on the device

    @nominal @walking-skeleton
    Scenario: Two installs on two phones give two independent devices
      Given Anna activates the app on her iPhone and on her tablet
      When both registrations complete
      Then two device records exist with two different public keys
