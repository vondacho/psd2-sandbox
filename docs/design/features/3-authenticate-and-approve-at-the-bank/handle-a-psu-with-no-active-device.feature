# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/handle-a-psu-with-no-active-device.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @mvp @analysing
Feature: Handle a PSU with no active device
  As Bank product owner
  I want the journey to explain how to enrol a device or to abort cleanly
  So that the PSU is never stuck at the QR page

  Rule: The device check happens after account selection and before any challenge; without an active device no QR is shown

    @nominal @mvp
    Scenario: No device at all
      Given Ben has no device record
      When he approves the consent summary
      Then no challenge is created
      And the page shows 'You have no registered device to approve with. Activate the Bank app first.' with the enrolment help link and 'Back to TPP App'
      And the authorisation is failed and the consent rejected

    @edge @mvp
    Scenario: Only blocked devices
      Given Anna's only device dev-anna-0 is blocked
      When she approves the summary
      Then the same page is shown with 'Your device Old phone is blocked'

    @edge @mvp
    Scenario: Only a pending device
      Given Anna's only device dev-anna-3 is pending
      When she approves the summary
      Then the page shows 'Finish activating Anna's iPhone with the code from your letter, then start again from TPP App'

    @nominal @mvp
    Scenario: An active device exists: the QR shows
      Given dev-anna-1 active
      When she approves the summary
      Then a challenge is created and the QR page renders

  Rule: A device lost during the session is handled at the next step, never with a dead page

    @edge @mvp
    Scenario: The only device is blocked while the QR is pending
      Given chl-01 pending and dev-anna-1 is blocked from another browser
      When chl-01 expires
      Then 'New code' is not offered and the no-device page is shown

    @edge @mvp
    Scenario: A device is enrolled while the QR is pending
      Given chl-01 pending and dev-anna-2 becomes active meanwhile
      When dev-anna-2 fetches chl-01
      Then the answer is 200 and it can approve

  @spec-14.15
  Rule: The way back and the status are consistent with any other refusal

    @nominal @mvp
    Scenario: Back to TPP App goes to the nok URI
      Given the no-device page
      When Anna clicks 'Back to TPP App'
      Then the browser ends at the TPP's nok URI with error=access_denied and error_description 'no registered device'

    @nominal @mvp
    Scenario: The TPP reads rejected
      Given the no-device refusal
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is rejected

    @nominal @mvp
    Scenario: The TPP shows a useful message
      Given the TPP received error_description 'no registered device'
      When the callback page renders
      Then it says 'the Bank needs its app activated on your phone before you can connect. Do that at the Bank, then try again.'

    @nominal @mvp
    Scenario: The enrolment help never points into the TPP journey
      Given the no-device page
      When the enrolment link is followed
      Then it opens the Bank's own online-banking device page, not a page of TPP App
