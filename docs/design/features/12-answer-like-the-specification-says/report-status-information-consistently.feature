# Generated from docs/design/examplemap/12-answer-like-the-specification-says/report-status-information-consistently.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-4.14 @conformance @ready
Feature: Report status information consistently
  As TPP operator
  I want consent, transaction and SCA status returned in the same shape everywhere
  So that one parser serves every status endpoint

  @spec-4.14
  Rule: Each status endpoint answers with its one status field and the vocabulary of the specification

    @nominal @conformance
    Scenario: The consent status endpoint
      Given a valid consent
      When its status endpoint is called
      Then the answer is {consentStatus: valid}, using the values of the consent status list

    @nominal @conformance
    Scenario: The payment status endpoint
      Given an accepted payment
      When its status endpoint is called
      Then the answer is {transactionStatus: ACTC}, using the transaction status list

    @nominal @conformance
    Scenario: The SCA status endpoint
      Given an authorisation waiting for the device
      When its status endpoint is called
      Then the answer is {scaStatus: started}, using the SCA status list

    @nominal @conformance
    Scenario: The status also appears on the resource itself
      Given the consent object and the payment resource
      When they are read
      Then each carries the same status value as its status endpoint

    @error @conformance
    Scenario: A status value outside the list is never served
      Given an internal state such as 'queued'
      When any status is served
      Then it is mapped to a value of the specification's list

  Rule: The status a client reads is the status the Bank acts on

    @nominal @conformance
    Scenario: A revoked consent reads revoked and serves nothing
      Given the PSU revoked the consent a second ago
      When the status is read and the account list is called
      Then the status is revokedByPsu and the account call answers 401 CONSENT_INVALID

    @nominal @conformance
    Scenario: An accepted payment reads ACTC and is executed
      Given a payment whose status reads ACTC
      When the execution job runs
      Then that payment is handed to the core

    @edge @conformance
    Scenario: Two reads a second apart do not disagree
      Given no event between them
      When the status is read twice
      Then both answers are the same

  Rule: A status read is available to the resource owner at any point of the lifecycle

    @nominal @conformance
    Scenario: Before, during and after the SCA
      Given a consent at received, then started, then valid
      When the status is read at each point
      Then each read answers 200 with the current value

    @edge @conformance
    Scenario: After a terminal status the endpoint still answers
      Given an expired consent
      When its status is read
      Then the answer is 200 with expired, not 404
