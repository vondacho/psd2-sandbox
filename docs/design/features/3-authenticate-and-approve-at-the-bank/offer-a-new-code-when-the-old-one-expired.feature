# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/offer-a-new-code-when-the-old-one-expired.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-ciam @mvp @ready
Feature: Offer a new code when the old one expired
  As PSU
  I want to request a fresh QR without starting over
  So that a slow scan does not cost me the whole journey

  Rule: After expiry the page offers a new code that creates a new challenge with the same dynamic link

    @nominal @mvp
    Scenario: New code after expiry
      Given chl-01 for Main Account until 2026-12-05 expired at 09:15:00
      When Anna clicks 'New code'
      Then chl-02 is created with the same dynamic-link hash H1, a new nonce and expiresAt 09:18:xx
      And the QR page shows the new QR and the countdown restarts

    @edge @mvp
    Scenario: The old QR is useless after the new code
      Given chl-02 replaced chl-01
      When the app scans the old QR of chl-01
      Then the app shows 'This code was replaced, scan the new one'

    @nominal @mvp
    Scenario: The scaStatus stays started
      Given chl-02 was created
      When the TPP reads the scaStatus
      Then the answer is started

    @nominal @mvp
    Scenario: The account selection is not asked again
      Given Anna clicks 'New code'
      When the page renders
      Then no selection or summary page is shown in between

  Rule: New code is offered only when the current challenge is over, and at most twice

    @nominal @mvp
    Scenario: No button while the code is live
      Given chl-01 pending with 2:10 left
      When the page renders
      Then there is no 'New code' button

    @edge @mvp
    Scenario: A second new code is still offered
      Given chl-01 and chl-02 expired
      When the page renders
      Then 'New code' is shown with 'last attempt'

    @error @mvp
    Scenario: After the third expiry the journey ends
      Given chl-01, chl-02 and chl-03 expired
      When the page renders
      Then it shows 'The approval was not completed in time. Start again from TPP App.' and no 'New code'
      And the authorisation is failed and the consent rejected

    @edge @mvp
    Scenario: A denied challenge does not offer a new code
      Given chl-01 denied
      When the page renders
      Then there is no 'New code' and the refusal is shown

  Rule: The session must still be alive and its PSU must still have an active device

    @error @mvp
    Scenario: New code after the session timed out
      Given the session has been inactive for eleven minutes
      When Anna clicks 'New code'
      Then the page shows 'Your session expired. Start again from TPP App.'

    @error @mvp
    Scenario: New code when the last device was blocked meanwhile
      Given Anna blocked her only active device while chl-01 was pending
      When she clicks 'New code'
      Then the page shows 'You have no registered device to approve with' and the consent is rejected

    @error @mvp
    Scenario: A direct POST to the new-code endpoint for another session is refused
      Given session sess-1
      When a browser without sess-1's cookie posts /challenge/new for sess-1
      Then the answer is 404
