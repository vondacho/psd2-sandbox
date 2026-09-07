# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/offer-the-sca-methods-and-record-the-selection.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @bank-ciam @spec-7.2.3 @authorisation-resources @analysing
Feature: Offer the SCA methods and record the selection
  As PSU
  I want the methods I have to choose from, and my choice remembered
  So that I approve with the device I have at hand

  @spec-7.2.3
  Rule: After the first factor, the Bank lists the SCA methods the PSU can use

    @nominal @authorisation-resources
    Scenario: Two registered devices are two methods
      Given Anna has the active devices Anna's iPhone and Browser simulator
      When the first factor is verified in an embedded or decoupled flow
      Then the answer carries scaMethods with two authentication objects, each with an id, a type and a name

    @edge @authorisation-resources
    Scenario: One device means one method
      Given Anna has one active device
      When the first factor is verified
      Then the answer carries one method, and the Bank may select it without asking

    @error @authorisation-resources
    Scenario: No active device is a refusal, not an empty list
      Given Anna has no active device
      When the first factor is verified
      Then the answer is 401 SCA_METHOD_UNKNOWN and the authorisation is failed

    @nominal @authorisation-resources
    Scenario: The method objects carry no secret
      Given the listed methods
      When their fields are read
      Then each holds authenticationMethodId, authenticationType and a name, and no key or push token

  @spec-7.2.3
  Rule: The PSU's selection is recorded on the authorisation and drives the challenge

    @nominal @authorisation-resources
    Scenario: Selecting a device issues its challenge
      Given the two methods above
      When the TPP puts authenticationMethodId dev-anna-1 on the authorisation
      Then the answer is 200 {scaStatus: scaMethodSelected} with the challenge data
      And the challenge is issued to that device

    @error @authorisation-resources
    Scenario: Selecting an unknown method is refused
      Given the same methods
      When the id dev-nope is selected
      Then the answer is 400 SCA_METHOD_UNKNOWN

    @error @authorisation-resources
    Scenario: Selecting a method of another PSU is refused
      Given dev-ben-1 belongs to Ben
      When it is selected on Anna's authorisation
      Then the answer is 400 SCA_METHOD_UNKNOWN

    @edge @authorisation-resources
    Scenario: Selecting twice replaces the challenge
      Given a challenge was issued for the first device
      When the other device is selected
      Then the first challenge is expired and a new one is issued

    @error @authorisation-resources
    Scenario: The selection is refused before the first factor
      Given the authorisation is psuIdentified
      When a method is selected
      Then the answer is 409 STATUS_INVALID

  Rule: In the redirect approach the selection happens at the Bank, not through the interface

    @nominal @authorisation-resources
    Scenario: The Bank asks on its own page
      Given the redirect approach and two active devices
      When the PSU reaches the SCA page
      Then the Bank's page offers the choice and the interface exposes no method list

    @error @authorisation-resources
    Scenario: A selection call in the redirect approach is refused
      Given the redirect approach
      When the TPP selects a method through the interface
      Then the answer is 409 STATUS_INVALID
