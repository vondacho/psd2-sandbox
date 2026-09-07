# Generated from docs/design/examplemap/6-come-back-later/delete-a-consent-from-the-tpp.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @bank-xs2a @spec-6.4 @mvp @analysing
Feature: Delete a consent from the TPP
  As PSU
  I want to disconnect the Bank inside the TPP
  So that the consent is terminated by the TPP at the bank

  @spec-6.4
  Rule: Disconnect calls DELETE /v1/consents/{id}; the Bank sets terminatedByTpp, revokes the tokens at the OIDC-provider, and the TPP deletes its token set and disconnects

    @nominal @mvp
    Scenario: The nominal disconnect
      Given Anna's connection to the Bank connected on consent 123cons456
      When she clicks 'Disconnect the Bank' and confirms
      Then the TPP calls DELETE /v1/consents/123cons456 with its QWAC and X-Request-ID
      And the Bank answers 204, the consent is terminatedByTpp and the revocation is posted to the OIDC-provider
      And the TPP deletes the vault row, the connection is disconnected and the page says 'the Bank disconnected'

    @nominal @mvp
    Scenario: GET status afterwards
      Given the deletion
      When the TPP calls GET /v1/consents/123cons456/status
      Then the answer is terminatedByTpp

    @edge @mvp
    Scenario: A pending consent can be deleted
      Given consent 123cons456 received (Anna abandoned the SCA)
      When the TPP deletes it
      Then the answer is 204, the consent is terminatedByTpp and the authorisation failed

    @edge @mvp
    Scenario: Deleting a consent also removes it from the Bank's dashboard actions
      Given the deletion
      When Anna opens 'Connected apps' at the Bank
      Then TPP App's row says 'ended by the app' with no Revoke button

  @security
  Rule: Only the creating TPP may delete, and terminal consents are not deleted again

    @error @mvp
    Scenario: C deletes the TPP's consent
      Given C's QWAC
      When DELETE /v1/consents/123cons456 is called
      Then the answer is 403 CONSENT_UNKNOWN and the consent stays valid

    @edge @mvp
    Scenario: Delete twice
      Given 123cons456 already terminatedByTpp
      When the TPP deletes it again
      Then the answer is 204

    @edge @mvp
    Scenario: Delete a revoked consent
      Given 123cons456 revokedByPsu
      When the TPP deletes it
      Then the answer is 409 STATUS_INVALID and the status stays revokedByPsu

    @edge @mvp
    Scenario: Delete an expired consent
      Given 123cons456 expired
      When the TPP deletes it
      Then the answer is 409 STATUS_INVALID

    @error @mvp
    Scenario: Delete an unknown consent
      Given no consent 999cons000
      When the TPP deletes it
      Then the answer is 403 CONSENT_UNKNOWN

  Rule: The TPP cleans up locally whatever the Bank answers, except when the Bank is unreachable

    @edge @mvp
    Scenario: 409 still disconnects locally
      Given the Bank answers 409 STATUS_INVALID
      When the TPP handles it
      Then the vault row is deleted and the connection is disconnected

    @edge @mvp
    Scenario: 403 disconnects locally and alerts
      Given the Bank answers 403 CONSENT_UNKNOWN
      When the TPP handles it
      Then the connection is disconnected and an alert is raised

    @error @mvp
    Scenario: The Bank unreachable
      Given the DELETE times out
      When the TPP handles it
      Then the connection stays connected, the page says 'the Bank did not answer, try again' and nothing is deleted
