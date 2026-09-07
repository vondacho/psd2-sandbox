# Generated from docs/design/examplemap/1-enrol-a-device-at-the-bank/protect-enrolment-with-an-existing-sca.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @security @mvp @analysing
Feature: Protect enrolment with an existing SCA
  As Bank security officer
  I want a new device confirmed with an activation code or an already active device
  So that an attacker with a password alone cannot enrol a device

  @rts-art-4
  Rule: A pending device becomes active only through a second factor the PSU already holds

    @nominal @mvp
    Scenario: The activation code from the letter activates the device
      Given dev-anna-1 is pending
      And Anna received the letter with activation code 4711-8823
      When she enters 4711-8823 in the app
      Then POST /devices/dev-anna-1/activate answers 200
      And dev-anna-1 has status active

    @nominal @mvp
    Scenario: An already active device approves the new one
      Given dev-anna-1 is active and dev-anna-2 is pending
      When Anna approves the enrolment challenge for dev-anna-2 on dev-anna-1 with Face ID
      Then the challenge of kind DEVICE_ENROLMENT is approved with a signature from dev-anna-1
      And dev-anna-2 has status active

    @error @mvp
    Scenario: The new device cannot approve its own enrolment
      Given dev-anna-2 is pending
      When dev-anna-2 signs its own enrolment challenge
      Then the SCA engine answers 403 'device not active'
      And dev-anna-2 stays pending

    @error @mvp
    Scenario: A password session alone leaves the device pending
      Given Anna registered dev-anna-1 with her password session and does nothing else
      When seven days pass
      Then dev-anna-1 is still not active
      And the record is set to removed by the expiry job

  Rule: An activation code is single-use, time-limited and bound to one device

    @error @mvp
    Scenario: A wrong code is refused and counted
      Given dev-anna-1 is pending with letter code 4711-8823
      When Anna enters 4711-0000
      Then the CIAM answers 400 'code invalid', attempt 1 of 3
      And dev-anna-1 stays pending

    @error @mvp
    Scenario: Three wrong codes remove the pending device
      Given two wrong codes were already entered for dev-anna-1
      When a third wrong code is entered
      Then dev-anna-1 is set to removed
      And the letter code is invalidated
      And Anna must register the device again and request a new letter

    @error @mvp
    Scenario: An expired letter code is refused
      Given the letter code was issued on 2026-08-01 and is valid 30 days
      When Anna enters the correct code on 2026-09-06
      Then the CIAM answers 400 'code expired'

    @error @mvp
    Scenario: A code issued for another device is refused
      Given code 4711-8823 was issued for dev-anna-1
      When it is entered for pending device dev-anna-2
      Then the CIAM answers 400 'code invalid'

    @error @mvp
    Scenario: A code cannot be used twice
      Given code 4711-8823 already activated dev-anna-1
      When it is entered again for a new pending device
      Then the CIAM answers 400 'code invalid'

    @edge @mvp
    Scenario: A code entered on the last valid day is accepted
      Given the letter code was issued on 2026-08-07 and is valid 30 days
      When Anna enters it on 2026-09-06 at 23:59 Europe/Berlin
      Then dev-anna-1 becomes active

  @security
  Rule: A pending or blocked device cannot answer any challenge

    @error @mvp
    Scenario: A pending device signing a consent challenge is refused
      Given dev-anna-1 is pending and challenge chl-01 is pending for Anna
      When dev-anna-1 posts a valid signature for chl-01
      Then the SCA engine answers 403 'device not active'
      And chl-01 stays pending

    @error @mvp
    Scenario: A blocked device cannot approve an enrolment
      Given dev-anna-0 is blocked and dev-anna-2 is pending
      When dev-anna-0 signs the enrolment challenge of dev-anna-2
      Then the SCA engine answers 403
      And dev-anna-2 stays pending

  Rule: The first device of a customer can only be activated with a code, never with another device

    @edge @mvp
    Scenario: A customer without any active device is offered the letter only
      Given Anna has no active device
      When she registers dev-anna-1
      Then the app offers 'Enter the code from your letter' and no 'approve on another device' option

    @nominal @mvp
    Scenario: A customer with an active device is offered both
      Given Anna has active device dev-anna-1
      When she registers dev-anna-2
      Then the app offers both the letter code and approval on dev-anna-1
