# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/serve-the-sca-status-of-an-authorisation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-7.5 @spec-14.16 @authorisation-resources @ready
Feature: Serve the SCA status of an authorisation
  As TPP operator
  I want GET on one authorisation to return its scaStatus and nothing else
  So that polling never leaks who the PSU is

  @spec-7.5
  Rule: The endpoint returns the current SCA status of that authorisation

    @nominal @authorisation-resources
    Scenario: Before anything happens
      Given the authorisation 123auth567 was just created
      When GET /v1/consents/123cons456/authorisations/123auth567 is called
      Then the answer is 200 {scaStatus: received}

    @nominal @authorisation-resources
    Scenario: After the PSU authenticated
      Given the password was verified
      When the status is read
      Then the answer is {scaStatus: psuAuthenticated}

    @nominal @authorisation-resources
    Scenario: While the challenge is pending
      Given the QR challenge was issued
      When the status is read
      Then the answer is {scaStatus: started}

    @nominal @authorisation-resources
    Scenario: After the approval, before the confirmation
      Given the device approved and a confirmation is required
      When the status is read
      Then the answer is {scaStatus: unconfirmed}

    @nominal @authorisation-resources
    Scenario: After the confirmation
      Given the confirmation was called
      When the status is read
      Then the answer is {scaStatus: finalised}

    @nominal @authorisation-resources
    Scenario: After a failure
      Given the PSU denied the challenge
      When the status is read
      Then the answer is {scaStatus: failed}

    @nominal @authorisation-resources
    Scenario: The same endpoint serves payment authorisations
      Given pay001auth1 at started
      When its status is read
      Then the answer is {scaStatus: started}

  @security
  Rule: The answer carries the status alone, with no PSU or device data

    @nominal @authorisation-resources
    Scenario: The fields of the answer
      Given any status answer
      When its fields are listed
      Then it holds scaStatus, optionally links, and no psuId, device name or challenge data

    @nominal @authorisation-resources
    Scenario: A failed status does not say why
      Given the authorisation failed because the identity was locked
      When the status is read
      Then the answer is failed with no reason, and the reason lives in the Bank's audit trail

  Rule: Polling is allowed, cheap and bounded by the resource's own access rules

    @edge @authorisation-resources
    Scenario: Polling every two seconds during the SCA
      Given the challenge is pending
      When the status is polled thirty times
      Then every call answers 200

    @nominal @authorisation-resources
    Scenario: A status read is not counted against the consent frequency
      Given the usage counters are at their limit
      When the SCA status is read without the PSU
      Then the answer is 200 and no counter changes

    @error @authorisation-resources
    Scenario: Another TPP cannot poll it
      Given the other TPP's certificate
      When the status of 123auth567 is read
      Then the answer is 403 CONSENT_UNKNOWN

    @error @authorisation-resources
    Scenario: An unknown authorisation id
      Given no authorisation nope on that consent
      When its status is read
      Then the answer is 404 RESOURCE_UNKNOWN
