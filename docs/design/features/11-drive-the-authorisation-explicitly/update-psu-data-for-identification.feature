# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/update-psu-data-for-identification.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-7.2.1 @authorisation-resources @analysing
Feature: Update PSU data for identification
  As TPP operator
  I want PUT on the authorisation with a PSU-ID to move it to psuIdentified
  So that the bank knows whose accounts are addressed before authentication

  @spec-7.2.1
  Rule: A PSU identification moves the authorisation to psuIdentified and records the PSU on the resource

    @nominal @authorisation-resources
    Scenario: Identifying Anna on a consent authorisation
      Given the authorisation 123auth567 is in status received
      When the TPP calls PUT on it with the header PSU-ID anna.mueller
      Then the answer is 200 {scaStatus: psuIdentified}
      And the consent carries psuId anna.mueller

    @nominal @authorisation-resources
    Scenario: Identifying on a payment authorisation
      Given pay001auth1 in status received
      When the PSU is identified
      Then the answer is psuIdentified

    @error @authorisation-resources
    Scenario: An unknown PSU-ID is refused without saying it is unknown
      Given the PSU-ID nobody.here
      When the identification is called
      Then the answer is 401 PSU_CREDENTIALS_INVALID
      And the response time matches that of a known PSU-ID

    @edge @authorisation-resources
    Scenario: A second identification with the same PSU-ID is harmless
      Given the authorisation is already psuIdentified for anna.mueller
      When the same identification is repeated
      Then the answer is 200 and the status stays psuIdentified

    @error @authorisation-resources
    Scenario: A different PSU-ID on an identified authorisation is refused
      Given the authorisation is psuIdentified for anna.mueller
      When an identification for ben.weber is called
      Then the answer is 409 STATUS_INVALID

    @error @authorisation-resources
    Scenario: Identification after authentication is refused
      Given the authorisation is psuAuthenticated
      When an identification is called
      Then the answer is 409 STATUS_INVALID

  Rule: In the redirect approach the identification is optional, and the Bank asks anyway

    @nominal @authorisation-resources
    Scenario: Without an identification the redirect still works
      Given an authorisation in status received
      When the PSU is redirected and logs in at the Bank
      Then the authorisation reaches psuAuthenticated without the TPP identifying anybody

    @nominal @authorisation-resources
    Scenario: With an identification the Bank still asks for the password
      Given the authorisation is psuIdentified for anna.mueller
      When the PSU arrives at the Bank's login page
      Then the page asks for the password of that customer

    @error @authorisation-resources
    Scenario: A PSU who logs in as somebody else fails the authorisation
      Given the authorisation is psuIdentified for anna.mueller
      When Ben logs in with his own credentials
      Then the authorisation is failed and the resource is rejected

  @security
  Rule: The identification carries no credential in the redirect approach

    @error @authorisation-resources
    Scenario: A password sent in the redirect approach is refused
      Given the sandbox announces REDIRECT
      When the identification body carries psuData with a password
      Then the answer is 400 FORMAT_ERROR with text 'credentials are not accepted in the redirect approach'

    @nominal @authorisation-resources
    Scenario: The PSU-ID is not echoed to the TPP afterwards
      Given an identified authorisation
      When the SCA status is read
      Then the answer holds the status only
