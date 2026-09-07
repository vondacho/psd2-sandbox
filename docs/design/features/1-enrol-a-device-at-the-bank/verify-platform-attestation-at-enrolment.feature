# Generated from docs/design/examplemap/1-enrol-a-device-at-the-bank/verify-platform-attestation-at-enrolment.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @security @hardening @analysing
Feature: Verify platform attestation at enrolment
  As Bank security officer
  I want the key attested by the platform before the device is activated
  So that software-only keys are refused

  Rule: The attestation statement must chain to the platform vendor's attestation root

    @nominal @hardening
    Scenario: A valid Apple App Attest statement is accepted
      Given a registration with an App Attest statement chaining to the Apple App Attestation Root CA
      When the CIAM verifies the attestation
      Then the device is stored with hardwareBacked = true and attestation = apple-app-attest

    @nominal @hardening
    Scenario: A valid Android key attestation chain is accepted
      Given a registration with a key attestation certificate chain ending at the Google hardware attestation root
      When the CIAM verifies the attestation
      Then the device is stored with hardwareBacked = true and attestation = android-key-attestation

    @error @hardening
    Scenario: A registration without attestation is refused
      Given a registration with no attestation field
      When the CIAM verifies it
      Then it answers 400 'attestation required'
      And no device record is created

    @error @hardening
    Scenario: An attestation chaining to an unknown root is refused
      Given an attestation chain whose root is a self-signed test certificate
      When the CIAM verifies it
      Then it answers 400 'attestation not trusted'

    @error @hardening
    Scenario: An attestation for a different public key is refused
      Given an attestation that certifies key K9 while the registration presents key K1
      When the CIAM verifies it
      Then it answers 400 'attestation does not match key'
      And the event is logged as a security event

  @rts-art-7
  Rule: Only keys attested as hardware-backed are accepted

    @nominal @hardening
    Scenario: Android attestation with securityLevel StrongBox is accepted
      Given an attestation whose keymaster securityLevel is StrongBox
      When the CIAM verifies it
      Then the device may be activated

    @edge @hardening
    Scenario: Android attestation with securityLevel TrustedEnvironment is accepted
      Given an attestation whose keymaster securityLevel is TrustedEnvironment
      When the CIAM verifies it
      Then the device may be activated

    @error @hardening
    Scenario: Android attestation with securityLevel Software is refused
      Given an attestation whose keymaster securityLevel is Software
      When the CIAM verifies it
      Then it answers 400 'device not supported: software key'
      And the app shows 'This phone cannot be used to approve'

    @error @hardening
    Scenario: A registration claiming hardwareBacked true without a matching attestation is refused
      Given hardwareBacked = true in the request and an attestation saying Software
      When the CIAM verifies it
      Then the attestation wins and the registration is refused

  @security
  Rule: The attestation must be fresh: it covers a nonce the CIAM issued for this registration

    @nominal @hardening
    Scenario: An attestation over the issued nonce is accepted
      Given the CIAM issued nonce n-5521 for Anna's registration 30 seconds ago
      When the attestation's client data hash covers n-5521
      Then the attestation is accepted

    @error @hardening
    Scenario: A replayed attestation is refused
      Given an attestation over nonce n-1000 that was already used for another registration
      When it is presented again
      Then the CIAM answers 400 'attestation replayed'

    @error @hardening
    Scenario: An attestation over a nonce older than five minutes is refused
      Given nonce n-5521 was issued six minutes ago
      When the attestation arrives
      Then the CIAM answers 400 'attestation nonce expired'
      And the app restarts the registration with a fresh nonce

  @sandbox
  Rule: The sandbox may accept unattested keys when configured, and marks them

    @edge @hardening
    Scenario: With attestation = optional the browser simulator is accepted and flagged
      Given the sandbox CIAM runs with attestation = optional
      When the browser device simulator registers a WebCrypto key without attestation
      Then the device is stored with hardwareBacked = false and attestation = none
      And the device list shows 'simulator, not attested'

    @error @hardening
    Scenario: With attestation = required the simulator is refused
      Given the sandbox CIAM runs with attestation = required
      When the browser device simulator registers without attestation
      Then the CIAM answers 400 'attestation required'
