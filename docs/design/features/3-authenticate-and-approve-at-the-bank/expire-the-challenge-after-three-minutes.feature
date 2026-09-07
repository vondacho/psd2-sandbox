# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/expire-the-challenge-after-three-minutes.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @sca @security @rts-art-4 @mvp @analysing
Feature: Expire the challenge after three minutes
  As Bank security officer
  I want a challenge unusable after its lifetime and after a retry limit
  So that a stale QR cannot be approved later

  @rts-art-4
  Rule: A challenge expires exactly 180 seconds after creation, by the server's clock

    @nominal @mvp
    Scenario: A response at 179 seconds is accepted
      Given chl-01 created at 09:12:00.000Z
      When a valid signature arrives at 09:14:59.000Z
      Then the challenge is approved

    @error @mvp
    Scenario: A response at 181 seconds is refused
      Given chl-01 created at 09:12:00.000Z
      When a valid signature arrives at 09:15:01.000Z
      Then the SCA engine answers 410 'challenge expired'
      And the status is expired

    @edge @mvp
    Scenario: A response at exactly 180 seconds is refused
      Given chl-01 created at 09:12:00.000Z
      When a valid signature arrives at 09:15:00.000Z
      Then the SCA engine answers 410

    @edge @mvp
    Scenario: The device's clock does not matter
      Given the phone's clock is 10 minutes behind
      When a signature arrives 30 seconds after creation by the server's clock
      Then the challenge is approved

    @edge @mvp
    Scenario: Expiry is applied even if nothing polled
      Given chl-01 created at 09:12:00 with no page polling and no app fetch
      When GET /sca/challenges/chl-01 is called at 09:20:00
      Then the status returned is expired

  Rule: A challenge is answered at most once

    @error @mvp
    Scenario: A second valid signature is refused
      Given chl-01 is approved
      When another valid signature arrives
      Then the SCA engine answers 409 'already answered'
      And the status stays approved and the stored signature is unchanged

    @error @mvp
    Scenario: An approval after a denial is refused
      Given chl-01 is denied
      When a valid signature arrives
      Then the SCA engine answers 409
      And the status stays denied

  @security
  Rule: Three invalid signatures end the challenge, and three challenges end the authorisation

    @error @mvp
    Scenario: Three bad signatures expire the challenge
      Given chl-01 pending
      When three signatures that do not verify arrive
      Then after the third the status is expired with reason 'too many attempts'
      And the QR page offers 'New code'

    @error @mvp
    Scenario: The third challenge of a session is the last
      Given chl-01 and chl-02 expired for session sess-1 and chl-03 is pending
      When chl-03 expires
      Then no 'New code' is offered, the authorisation is failed and the consent rejected

    @edge @mvp
    Scenario: A good signature after two bad ones is accepted
      Given two invalid signatures for chl-01
      When a valid signature arrives
      Then the challenge is approved

    @edge @mvp
    Scenario: Invalid signatures from another PSU's device do not count against Anna
      Given chl-01 for Anna
      When Ben's device posts three signatures
      Then each answers 403 and chl-01 is still pending with attempt count 0

  Rule: An expired or ended challenge cannot be fetched for approval by the app

    @error @mvp
    Scenario: Fetching an expired challenge tells the app so
      Given chl-01 expired
      When the app calls GET /sca/challenges/chl-01
      Then the answer is 410 with status expired
      And the app shows 'Code expired, request a new one on the Bank page'

    @edge @mvp
    Scenario: Fetching an approved challenge tells the app so
      Given chl-01 approved
      When the app calls GET /sca/challenges/chl-01
      Then the answer is 200 with status approved and no approve button is shown
