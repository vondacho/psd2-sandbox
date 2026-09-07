# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/serve-challenge-data-for-the-selected-method.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @sca @spec-14.8 @spec-14.10 @authorisation-resources @analysing
Feature: Serve challenge data for the selected method
  As TPP operator
  I want the challenge object of the chosen method, with its image or data and its expiry
  So that an embedded flow can show the challenge to the PSU

  @spec-14.10
  Rule: The challenge object carries what the PSU needs and nothing that would let a TPP answer for them

    @nominal @authorisation-resources
    Scenario: A photo challenge for the registered device
      Given the method dev-anna-1 was selected in an embedded flow
      When the answer is built
      Then challengeData holds the image of the QR, the expiry and an explanatory text
      And it holds no device key, no nonce that the device did not receive and no signature

    @nominal @authorisation-resources
    Scenario: The expiry matches the challenge itself
      Given a challenge created at 09:12:00Z with a three-minute life
      When the challenge data is read
      Then its expiry is 09:15:00Z

    @edge @authorisation-resources
    Scenario: The additional information tells the PSU what to do
      Given the challenge data
      When it is read
      Then it holds a text such as 'Scan this code with the Bank app on your registered device'

    @error @authorisation-resources
    Scenario: The data cannot be replayed to approve
      Given the challenge data of an authorisation
      When a client posts it back as an approval
      Then the approval is refused, because only a device signature approves

  @security
  Rule: The challenge data is available only while the challenge is pending, to the owning TPP

    @edge @authorisation-resources
    Scenario: After approval there is no challenge data
      Given the challenge was approved
      When the authorisation is read
      Then the answer carries the status and no challenge data

    @edge @authorisation-resources
    Scenario: After expiry there is no challenge data
      Given the challenge expired
      When the authorisation is read
      Then the answer carries the status and no challenge data

    @error @authorisation-resources
    Scenario: Another TPP cannot read it
      Given the other TPP's certificate
      When the authorisation is read
      Then the answer is 403 and no challenge data is served

  Rule: In the redirect approach no challenge data crosses the interface

    @nominal @authorisation-resources
    Scenario: The QR stays on the Bank's page
      Given the redirect approach
      When the authorisation is read while the challenge is pending
      Then the answer holds the SCA status only

    @nominal @authorisation-resources
    Scenario: The device fetches the challenge from the Bank, not from the TPP
      Given the redirect approach
      When the app loads the challenge
      Then it calls the Bank's SCA engine over its device-authenticated channel
