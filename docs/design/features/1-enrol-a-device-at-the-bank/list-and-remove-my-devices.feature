# Generated from docs/design/examplemap/1-enrol-a-device-at-the-bank/list-and-remove-my-devices.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @mvp @analysing
Feature: List and remove my devices
  As PSU
  I want to see my active devices and block one
  So that a lost phone cannot approve anything

  Rule: The list shows every device of the identity that is not removed

    @nominal @mvp
    Scenario: Anna sees her active phone and her blocked old phone
      Given Anna has dev-anna-1 'Anna's iPhone' active since 2026-03-02, last used 2026-09-05, and dev-anna-0 'Old phone' blocked
      When she opens 'My devices' in online banking
      Then two rows are shown: 'Anna's iPhone' active, 'Old phone' blocked
      And each row shows platform, enrolment date and last use

    @edge @mvp
    Scenario: A pending device is listed with a hint to finish activation
      Given Anna has dev-anna-2 pending
      When she opens 'My devices'
      Then dev-anna-2 is shown with status pending and the link 'finish activation'

    @edge @mvp
    Scenario: A removed device is not listed
      Given dev-anna-3 has status removed
      When Anna opens 'My devices'
      Then dev-anna-3 is absent

    @edge @mvp
    Scenario: A customer without devices sees how to enrol one
      Given Ben has no device records
      When he opens 'My devices'
      Then the page shows 'No device yet' and the enrolment instructions

    @error @mvp
    Scenario: Another customer's devices are never listed
      Given dev-ben-1 belongs to ben.weber
      When Anna opens 'My devices'
      Then dev-ben-1 is absent

  @security
  Rule: Blocking takes effect immediately, including for challenges already delivered

    @nominal @mvp
    Scenario: A blocked device cannot answer a challenge issued a minute ago
      Given challenge chl-01 was issued to Anna and pushed to dev-anna-1 one minute ago
      When Anna blocks dev-anna-1 from online banking
      And dev-anna-1 posts a valid signature for chl-01
      Then the SCA engine answers 403 'device blocked'
      And chl-01 stays pending

    @edge @mvp
    Scenario: Another active device can still answer the pending challenge
      Given chl-01 is pending and dev-anna-1 was just blocked
      When dev-anna-2, active, signs chl-01
      Then chl-01 is approved

    @edge @mvp
    Scenario: A blocked device's session in the app is terminated
      Given dev-anna-1 is blocked
      When the app on dev-anna-1 next calls the SCA engine
      Then it receives 403 and shows 'This device was blocked'

    @edge @mvp
    Scenario: Blocking is idempotent
      Given dev-anna-1 is already blocked
      When Anna blocks it again
      Then the status stays blocked and the page shows no error

  @security
  Rule: A device can only be blocked or removed by its own identity

    @error @mvp
    Scenario: Ben cannot block Anna's device
      Given Ben is logged in
      When he sends DELETE /devices/dev-anna-1
      Then the CIAM answers 404
      And dev-anna-1 stays active

    @nominal @mvp
    Scenario: Anna blocks her own device
      Given Anna is logged in
      When she sends DELETE /devices/dev-anna-1
      Then the CIAM answers 204
      And dev-anna-1 has status blocked

  Rule: Blocking the last active device warns that no approval will be possible

    @edge @mvp
    Scenario: Blocking the only active device shows a warning first
      Given dev-anna-1 is Anna's only active device
      When she clicks 'Block' on it
      Then the page warns 'You will not be able to approve consents or payments until you enrol a new device'
      And the block happens only after she confirms

    @nominal @mvp
    Scenario: Blocking one of two active devices needs no warning
      Given dev-anna-1 and dev-anna-2 are active
      When Anna blocks dev-anna-2
      Then it is blocked without the warning
