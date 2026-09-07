# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/serve-the-owner-name-and-additional-information.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-14.18 @consent-models @analysing
Feature: Serve the owner name and additional information
  As PSU
  I want my name released only when the consent asked for it
  So that an app learns no more about me than I agreed

  @spec-14.18
  Rule: The owner name is served only for the accounts named under ownerName in the additional information

    @nominal @consent-models
    Scenario: Owner name asked for one account
      Given access with additionalInformation {ownerName: [DE23100100100123456789]}
      When the consent is valid and the account details of Main Account are read
      Then the answer carries ownerName 'Anna Müller'

    @nominal @consent-models
    Scenario: The other account keeps the name hidden
      Given the same consent
      When the details of Savings are read
      Then the answer carries no ownerName

    @nominal @consent-models
    Scenario: No additional information means no owner name anywhere
      Given a consent without additionalInformation
      When any account is read
      Then no answer carries ownerName

    @edge @consent-models
    Scenario: The account list carries the owner name too when granted
      Given ownerName granted on Main Account
      When GET /v1/accounts is called
      Then the Main Account entry carries ownerName and the Savings entry does not

    @error @consent-models
    Scenario: An account named under ownerName must also be in the access
      Given additionalInformation {ownerName: [DE89370400440532013000]} while access.accounts holds DE23… only
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

  Rule: The consent screen shows the additional information as part of what is granted

    @nominal @consent-models
    Scenario: The summary names the owner name
      Given a consent asking for ownerName
      When the consent summary renders
      Then it says that the app will also see the name of the account holder

    @nominal @consent-models
    Scenario: The approval on the device shows the same
      Given the same consent
      When the approval screen renders
      Then it lists the owner name alongside the accounts and the validity

  @spec-14.11
  Rule: A bank that does not support an additional-information type refuses it rather than ignoring it

    @error @consent-models
    Scenario: Trusted beneficiaries when the Bank does not offer them
      Given additionalInformation {trustedBeneficiaries: [DE23…]} and the sandbox runs without that feature
      When POST /v1/consents is called
      Then the answer is 400 SERVICE_INVALID
      And no consent is created

    @error @consent-models
    Scenario: An unknown additional-information field is refused
      Given additionalInformation {favouriteColour: [DE23…]}
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR
