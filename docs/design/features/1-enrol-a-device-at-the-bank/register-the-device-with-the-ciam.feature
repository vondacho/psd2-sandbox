# Generated from docs/design/examplemap/1-enrol-a-device-at-the-bank/register-the-device-with-the-ciam.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @walking-skeleton @analysing
Feature: Register the device with the CIAM
  As PSU
  I want my activated device listed under my identity at the Bank
  So that the Bank knows where to send my challenges

  @security
  Rule: Registration needs an authenticated online-banking session of the PSU

    @nominal @walking-skeleton
    Scenario: Anna, logged in to online banking, registers her iPhone
      Given Anna is logged in to the Bank online banking as anna.mueller
      When the app sends POST /devices with the public key, appInstanceId, platform iOS and name 'Anna's iPhone'
      Then the CIAM answers 201 with deviceId dev-anna-1
      And the device is stored under psuId anna.mueller with status pending

    @error @walking-skeleton
    Scenario: Registration without a session is refused
      Given no online-banking session
      When the app sends POST /devices
      Then the CIAM answers 401
      And no device record is created

    @error @mvp
    Scenario: A locked identity cannot register a device
      Given the identity anna.mueller has status locked
      When the app sends POST /devices in a session that was opened before the lock
      Then the CIAM answers 403 with reason 'identity locked'
      And no device record is created

    @error @mvp
    Scenario: A closed identity cannot register a device
      Given the identity of a former customer has status closed
      When POST /devices is sent for it
      Then the CIAM answers 403

  @security
  Rule: A device belongs to exactly one identity

    @error @walking-skeleton
    Scenario: The same public key cannot be registered under a second identity
      Given public key K1 is registered as dev-anna-1 under anna.mueller
      When Ben, logged in as ben.weber, registers a device with public key K1
      Then the CIAM answers 409 'key already registered'
      And Ben has no new device

    @nominal @walking-skeleton
    Scenario: The device record carries the identity it was registered under
      Given Anna registered dev-anna-1
      When the device registry is read for dev-anna-1
      Then psuId is anna.mueller

    @nominal @walking-skeleton
    Scenario: A device registered by Ben never appears under Anna
      Given Ben registered dev-ben-1
      When Anna's device list is read
      Then dev-ben-1 is not in it

  Rule: The registration stores what the SCA engine needs: key, app instance, platform, name, push token, enrolment time

    @nominal @walking-skeleton
    Scenario: A complete registration is stored with every field
      Given a registration with publicKey K1, appInstanceId 6f1c-…, platform iOS 18, name 'Anna's iPhone', pushToken apns-abc, hardwareBacked true
      When the CIAM stores it
      Then the record has all those fields, enrolledAt = 2026-09-06T09:12:00Z and status pending

    @edge @walking-skeleton
    Scenario: A registration without push token is stored with push disabled
      Given the browser device simulator registers without a pushToken
      When the CIAM stores it
      Then the record has no pushToken
      And the device is listed as 'QR only'

    @error @mvp
    Scenario: A device name longer than 70 characters is refused
      Given a registration whose name has 71 characters
      When the CIAM validates it
      Then it answers 400 naming the field name

    @edge @mvp
    Scenario: A missing device name gets the platform name
      Given a registration without name on platform Android
      When the CIAM stores it
      Then the name is 'Android device'

  Rule: Only a P-256 public key in JWK form is accepted

    @nominal @walking-skeleton
    Scenario: A P-256 JWK is accepted
      Given a JWK with kty EC and crv P-256
      When the CIAM validates the registration
      Then the key is accepted

    @error @walking-skeleton
    Scenario: An RSA key is refused
      Given a JWK with kty RSA
      When the CIAM validates the registration
      Then it answers 400 'unsupported key type'

    @error @mvp
    Scenario: A JWK that carries a private parameter is refused
      Given a JWK with kty EC, crv P-256 and a d parameter
      When the CIAM validates the registration
      Then it answers 400 'private key material must not be sent'
      And the request is logged as a security event

    @error @walking-skeleton
    Scenario: A malformed key is refused
      Given publicKey is the string 'not-a-key'
      When the CIAM validates the registration
      Then it answers 400 naming the field publicKey

  Rule: A newly registered device is pending until an existing SCA confirms it

    @nominal @walking-skeleton
    Scenario: The new device appears in Anna's list as pending
      Given Anna registered dev-anna-1 a minute ago
      When she opens her device list
      Then dev-anna-1 is shown with status pending and the hint 'finish activation'

    @error @walking-skeleton
    Scenario: A pending device gets no challenge
      Given dev-anna-1 is pending
      When a consent challenge is issued for Anna
      Then no push is sent to dev-anna-1
      And a signature from dev-anna-1 is refused
