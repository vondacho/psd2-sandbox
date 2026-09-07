# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/explain-a-refusal-to-the-psu.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @mvp @analysing
Feature: Explain a refusal to the PSU
  As PSU
  I want a clear message and a way back to the TPP when the Bank refuses
  So that I am not left on a dead page

  Rule: Every refusal page names the cause in plain words, shows a reference id and offers a way back to the TPP

    @nominal @mvp
    Scenario: Locked access
      Given the fifth wrong password locked anna.mueller in the session for TPP App
      When the refusal page renders
      Then it says 'Your access to the Bank is locked. Contact the Bank to unlock it.'
      And it shows 'Reference BB-2026-09-06-8F3A'
      And it has the button 'Back to TPP App'

    @nominal @mvp
    Scenario: No registered device
      Given Anna has no active device
      When the refusal page renders
      Then it says 'You have no registered device to approve with. Activate the Bank app first.'
      And it links to the device enrolment help

    @nominal @mvp
    Scenario: Challenge expired for the last time
      Given the third QR code expired
      When the refusal page renders
      Then it says 'The approval was not completed in time. Start again from TPP App.'

    @nominal @mvp
    Scenario: Session expired
      Given ten minutes of inactivity on the login page
      When the refusal page renders
      Then it says 'Your session expired. Start again from TPP App.'

    @nominal @mvp
    Scenario: Risk refusal
      Given the risk engine refused
      When the refusal page renders
      Then it says 'the Bank cannot continue this request. Contact the Bank and quote the reference.'

    @nominal @mvp
    Scenario: The PSU declined
      Given Anna clicked 'Decline' on the consent summary
      When the refusal page renders
      Then it says 'You declined. TPP App was not given access.'

  @spec-7.6
  Rule: The way back goes through the OIDC-provider to the TPP's nok redirect URI with error=access_denied and the TPP's state

    @nominal @mvp
    Scenario: Back to TPP App lands on the nok URI
      Given consent 123cons456 has TPP-Nok-Redirect-URI https://tpp.sandbox/xs2a/callback/bank?outcome=nok
      When Anna clicks 'Back to TPP App'
      Then the browser ends at https://tpp.sandbox/xs2a/callback/bank?outcome=nok&error=access_denied&state=S8NJ7…

    @edge @mvp
    Scenario: Without a nok URI the ok URI is used with an error parameter
      Given the consent has no TPP-Nok-Redirect-URI
      When Anna clicks 'Back to TPP App'
      Then the browser ends at https://tpp.sandbox/xs2a/callback/bank?error=access_denied&state=S8NJ7…

    @edge @mvp
    Scenario: The button is shown even when the redirect fails
      Given the TPP's callback answers 502
      When Anna clicks 'Back to TPP App'
      Then the browser shows the TPP's error, and the CIAM page had told her 'If TPP App does not open, return to it manually'

  @security
  Rule: A refusal reveals nothing that helps an attacker

    @nominal @mvp
    Scenario: Unknown customer id and wrong password read the same
      Given two refusals: unknown id, wrong password
      When the pages are compared
      Then the text is identical

    @nominal @mvp
    Scenario: The page does not say which factor failed after the password
      Given a risk refusal
      When the page renders
      Then it does not mention risk, address or device

    @nominal @mvp
    Scenario: The reference id is random and maps to the log only inside the Bank
      Given reference BB-2026-09-06-8F3A
      When support searches for it
      Then one audit entry with the full cause is found
      And the reference is not derivable from the consent id or PSU-ID

  @spec-14.15
  Rule: The consent and the authorisation reflect the refusal immediately

    @nominal @mvp
    Scenario: The TPP reads rejected right after the refusal
      Given the refusal page rendered for 123cons456
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is rejected

    @edge @mvp
    Scenario: An abandoned session is rejected after 30 minutes
      Given Anna closed the tab at 09:00 with the consent received
      When the clock reaches 09:31
      Then the consent is rejected and the authorisation failed
