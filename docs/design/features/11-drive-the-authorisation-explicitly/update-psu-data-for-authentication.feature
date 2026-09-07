# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/update-psu-data-for-authentication.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @bank-ciam @security @spec-7.2.2 @authorisation-resources @analysing
Feature: Update PSU data for authentication
  As Bank security officer
  I want a password accepted on the authorisation resource only in the decoupled or embedded approach
  So that credentials never travel through a TPP in the redirect approach

  @spec-7.2.2
  Rule: A credential on the authorisation is accepted only when the announced approach is decoupled or embedded

    @error @authorisation-resources
    Scenario: Refused under the redirect approach
      Given the resource announced REDIRECT
      When PUT on the authorisation carries psuData {password: 'correct-horse-battery'}
      Then the answer is 400 FORMAT_ERROR and no authentication is attempted

    @nominal @authorisation-resources
    Scenario: Accepted under the embedded approach
      Given the sandbox runs with the embedded approach and the authorisation is psuIdentified
      When the correct password is sent on the authorisation
      Then the answer is 200 {scaStatus: psuAuthenticated} with the available SCA methods

    @nominal @authorisation-resources
    Scenario: Accepted under the decoupled approach
      Given the decoupled approach and an identified PSU
      When the password is sent
      Then the answer is psuAuthenticated and the Bank pushes the challenge to the device

    @error @authorisation-resources
    Scenario: A wrong password is refused and counted
      Given the embedded approach
      When a wrong password is sent
      Then the answer is 401 PSU_CREDENTIALS_INVALID and the failure counts towards the lock

    @error @authorisation-resources
    Scenario: A locked identity is refused
      Given anna.mueller is locked
      When the correct password is sent
      Then the answer is 401 PSU_CREDENTIALS_INVALID and the authorisation is failed

  @security
  Rule: The credential is never stored, logged or echoed

    @nominal @authorisation-resources
    Scenario: The password does not reach the audit log
      Given an embedded authentication
      When the audit trail and the access log are read
      Then neither holds the password or a fragment of it

    @nominal @authorisation-resources
    Scenario: The answer carries no credential
      Given the answer of a successful authentication
      When its fields are listed
      Then it holds the SCA status and the methods, and no psuData

    @nominal @authorisation-resources
    Scenario: The credential is verified by the CIAM, not by the XS2A service
      Given an embedded authentication
      When the call is traced
      Then the XS2A service passes the credential to the CIAM and keeps nothing

  @spec-14.16
  Rule: Authentication is possible only from an identified authorisation

    @error @authorisation-resources
    Scenario: From received it is refused
      Given the authorisation is in status received with no PSU
      When a password is sent
      Then the answer is 409 STATUS_INVALID

    @error @authorisation-resources
    Scenario: From psuAuthenticated it is refused
      Given the authorisation is already psuAuthenticated
      When a password is sent again
      Then the answer is 409 STATUS_INVALID

    @error @authorisation-resources
    Scenario: From failed it is refused
      Given the authorisation is failed
      When a password is sent
      Then the answer is 409 STATUS_INVALID
