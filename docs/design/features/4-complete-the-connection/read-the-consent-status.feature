# Generated from docs/design/examplemap/4-complete-the-connection/read-the-consent-status.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @bank-xs2a @spec-6.3.2 @walking-skeleton @analysing
Feature: Read the consent status
  As TPP operator
  I want GET /v1/consents/{id}/status to return valid once SCA is done
  So that the TPP can show the PSU that the bank is connected

  @spec-6.3.2
  Rule: The creating TPP, identified by its QWAC, reads the current consent status; a token is optional

    @nominal @walking-skeleton
    Scenario: valid after SCA and confirmation
      Given consent 123cons456 finalised
      When the TPP calls GET /v1/consents/123cons456/status with X-Request-ID
      Then the answer is 200 {consentStatus: valid}

    @nominal @walking-skeleton
    Scenario: received before the SCA
      Given consent 123cons456 just created
      When the TPP reads the status without a token
      Then the answer is 200 {consentStatus: received}

    @nominal @mvp
    Scenario: rejected after a denial
      Given Anna denied
      When the TPP reads the status
      Then the answer is rejected

    @nominal @mvp
    Scenario: expired after validUntil
      Given validUntil 2026-12-05 and today 2026-12-06
      When the TPP reads the status
      Then the answer is expired

    @nominal @mvp
    Scenario: revokedByPsu after revocation
      Given Anna revoked at the Bank
      When the TPP reads the status
      Then the answer is revokedByPsu

    @nominal @mvp
    Scenario: terminatedByTpp after deletion or replacement
      Given A deleted the consent
      When the TPP reads the status
      Then the answer is terminatedByTpp

    @edge @mvp
    Scenario: received while the authorisation is unconfirmed
      Given the device approved and no PUT yet
      When the TPP reads the status
      Then the answer is received

  @security
  Rule: Another TPP or an unknown id gets CONSENT_UNKNOWN, revealing nothing

    @error @walking-skeleton
    Scenario: C reads the TPP's consent
      Given C's QWAC
      When GET /v1/consents/123cons456/status is called
      Then the answer is 403 CONSENT_UNKNOWN

    @error @walking-skeleton
    Scenario: An unknown id
      Given the TPP's QWAC
      When GET /v1/consents/999cons000/status is called
      Then the answer is 403 CONSENT_UNKNOWN

    @nominal @mvp
    Scenario: Unknown and foreign look the same
      Given the two refusals
      When the bodies are compared
      Then they are identical apart from X-Request-ID

  Rule: A status read is cheap: it needs X-Request-ID, does not count against the frequency and does not change lastActionDate

    @error @mvp
    Scenario: Missing X-Request-ID
      Given no X-Request-ID
      When the status is read
      Then the answer is 400 FORMAT_ERROR

    @nominal @mvp
    Scenario: Not counted
      Given the usage counters at 4 of 4 for today
      When the TPP reads the status without PSU-IP-Address
      Then the answer is 200 and the counters are unchanged

    @edge @mvp
    Scenario: The TPP polls the status every 2 seconds while pending
      Given the connection is authorizing
      When the TPP polls 30 times
      Then every poll answers 200 and none is refused as too frequent
