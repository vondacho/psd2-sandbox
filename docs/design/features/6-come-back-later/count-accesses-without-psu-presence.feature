# Generated from docs/design/examplemap/6-come-back-later/count-accesses-without-psu-presence.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6 @rts-art-36 @mvp @analysing
Feature: Count accesses without PSU presence
  As Bank product owner
  I want calls without PSU-IP-Address counted per account per day against frequencyPerDay and refused with ACCESS_EXCEEDED
  So that background polling stays within the consented frequency

  @spec-6
  Rule: A call without PSU-IP-Address counts one access for every account it touches; when a touched account is already at frequencyPerDay, the call is refused with 429 ACCESS_EXCEEDED

    @nominal @mvp
    Scenario: Four list calls pass, the fifth is refused
      Given consent 123cons456 with frequencyPerDay 4 on Main Account and counters at 0
      When the TPP calls GET /v1/accounts four times without PSU-IP-Address
      Then each answers 200 and Main Account's counter goes 1, 2, 3, 4
      When the TPP calls a fifth time
      Then the answer is 429 ACCESS_EXCEEDED

    @nominal @mvp
    Scenario: A detail call counts that account only
      Given counters Main 2, Savings 2
      When the TPP reads Main Account without presence
      Then Main is 3, Savings is 2

    @nominal @mvp
    Scenario: A list with two accounts counts one on each
      Given counters Main 0, Savings 0
      When the TPP calls GET /v1/accounts without presence
      Then Main is 1 and Savings is 1

    @edge @mvp
    Scenario: One exhausted account blocks the list
      Given counters Main 4, Savings 1
      When the TPP calls GET /v1/accounts without presence
      Then the answer is 429 ACCESS_EXCEEDED and no counter changes

    @nominal @mvp
    Scenario: Balances and transactions count the same way
      Given counters Main 3
      When the TPP reads Main Account's balances without presence
      Then Main is 4
      When the TPP reads Main Account's transactions without presence
      Then the answer is 429

    @nominal @mvp
    Scenario: The error body
      Given the refusal
      When the body is inspected
      Then it is {tppMessages: [{category: ERROR, code: ACCESS_EXCEEDED, text: 'daily access limit reached for this account'}]}

  @spec-6
  Rule: A call with PSU-IP-Address is never counted and never refused for frequency

    @nominal @mvp
    Scenario: PSU present after the limit
      Given counters Main 4
      When the TPP calls GET /v1/accounts with PSU-IP-Address 192.168.8.78
      Then the answer is 200 and Main stays 4

    @edge @mvp
    Scenario: Twenty PSU-present calls in a minute
      Given Anna refreshes the page twenty times
      When each call carries PSU-IP-Address
      Then each answers 200

    @error @mvp
    Scenario: A garbage PSU-IP-Address does not count as presence
      Given PSU-IP-Address 'present'
      When the call is made
      Then the answer is 400 FORMAT_ERROR with path PSU-IP-Address

  Rule: Counters are per consent, per account and per calendar day in the Bank's time zone

    @edge @mvp
    Scenario: Midnight resets
      Given Main at 4 on 2026-09-06
      When the TPP calls at 2026-09-07 00:00:01 Europe/Berlin without presence
      Then the answer is 200 and Main is 1 for 2026-09-07

    @edge @mvp
    Scenario: Another consent of the same account has its own counter
      Given Main at 4 under 123cons456 (the TPP) and at 0 under 333cons444 (C)
      When C reads Main Account without presence
      Then the answer is 200

    @nominal @mvp
    Scenario: Consent status and consent object reads do not count
      Given Main at 4
      When the TPP reads GET /v1/consents/123cons456/status and GET /v1/consents/123cons456 without presence
      Then both answer 200 and Main stays 4

    @edge @mvp
    Scenario: The counters are visible on the Bank's consent dashboard
      Given Main at 3 today
      When Anna opens her consent dashboard
      Then TPP App's consent shows 'accessed 3 of 4 times today without you'

  @spec-14.17
  Rule: frequencyPerDay is the value stored on the consent, capped by the Bank

    @edge @mvp
    Scenario: A capped frequency applies
      Given the TPP asked 10 and the Bank stored 4
      When the fifth call without presence is made
      Then the answer is 429

    @edge @mvp
    Scenario: A one-off consent allows one access without presence
      Given consent 777cons888 with frequencyPerDay 1
      When the TPP calls twice without presence
      Then the first answers 200 and the second 429
