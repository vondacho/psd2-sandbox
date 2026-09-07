# Generated from docs/design/examplemap/6-come-back-later/multilevel-sca-for-corporate-accounts.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 3 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @bank-ciam @spec-6.3.4 @spec-7 @analysing
Feature: Multilevel SCA for corporate accounts
  As PSU
  I want a consent on a corporate account authorised by every required signer
  So that company accounts can be connected too

  @spec-6.3.4
  Rule: A corporate account that needs two signers makes the consent partiallyAuthorised after the first SCA and valid after the second

    @nominal
    Scenario: Two signers
      Given the corporate account DE44… of Muster GmbH needs signers Anna and Ben, and consent 900cons001 by the TPP with PSU-Corporate-ID muster-gmbh
      When Anna completes her SCA
      Then authorisation auth-1 is finalised and the consent is partiallyAuthorised
      When Ben completes his SCA on a second authorisation auth-2
      Then the consent is valid

    @error
    Scenario: The same signer twice does not count
      Given Anna finalised auth-1
      When Anna starts and completes auth-2
      Then auth-2 is failed with 'already signed by this PSU' and the consent stays partiallyAuthorised

    @error
    Scenario: A PSU who is not a signer
      Given Carla is not a signer of Muster GmbH
      When she completes an authorisation for 900cons001
      Then the authorisation is failed and the consent stays partiallyAuthorised

    @nominal
    Scenario: The authorisation list shows both
      Given auth-1 and auth-2 exist
      When the TPP calls GET /v1/consents/900cons001/authorisations
      Then the answer is {authorisationIds: [auth-1, auth-2]}

    @nominal
    Scenario: A second authorisation is started explicitly
      Given the consent is partiallyAuthorised
      When the TPP calls POST /v1/consents/900cons001/authorisations
      Then the answer is 201 with a new authorisationId and a scaOAuth link

  @spec-14.15
  Rule: While partiallyAuthorised, the consent serves nothing and the TPP shows who is missing

    @error
    Scenario: GET /v1/accounts while partiallyAuthorised
      Given one of two signatures
      When the TPP calls GET /v1/accounts
      Then the answer is 401 CONSENT_INVALID

    @nominal
    Scenario: The TPP shows the waiting state
      Given GET status answers partiallyAuthorised
      When the connection page renders
      Then it says 'Waiting for another authorised signer of Muster GmbH'

  @spec-14.11
  Rule: The corporate identifier must be known and the PSU must belong to it

    @error
    Scenario: Unknown corporate id
      Given PSU-Corporate-ID nobody-gmbh
      When POST /v1/consents is called
      Then the answer is 400 CORPORATE_ID_INVALID

    @error
    Scenario: A private customer on a corporate consent
      Given consent 900cons001 for muster-gmbh
      When Ben's private identity logs in for it
      Then the CIAM shows 'This request is for a company account you cannot sign for'
