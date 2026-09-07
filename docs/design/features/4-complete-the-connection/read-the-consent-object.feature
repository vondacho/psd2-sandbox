# Generated from docs/design/examplemap/4-complete-the-connection/read-the-consent-object.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @bank-xs2a @spec-6.3.3 @mvp @ready
Feature: Read the consent object
  As TPP operator
  I want GET /v1/consents/{id} to return the access finally granted
  So that the TPP knows which accounts and access types were approved at the bank

  @spec-6.3.3
  Rule: After authorisation, the consent object shows the access as granted: the selected accounts under each granted access type, the stored validity and frequency, the status and lastActionDate

    @nominal @mvp
    Scenario: The valid consent on two accounts
      Given consent 123cons456 valid with Main Account and Savings, accounts and balances
      When the TPP calls GET /v1/consents/123cons456
      Then the body is {access: {accounts: [{iban: DE23100100100123456789, currency: EUR}, {iban: DE89370400440532013000, currency: EUR}], balances: [the same two]}, recurringIndicator: true, validUntil: 2026-12-05, frequencyPerDay: 4, lastActionDate: 2026-09-06, consentStatus: valid, _links: {…}}

    @edge @mvp
    Scenario: Before the SCA the access is as requested
      Given consent 123cons456 received
      When the TPP reads it
      Then access is {accounts: [], balances: []} and consentStatus received

    @edge @mvp
    Scenario: A shortened validity is shown
      Given the bank stored 2027-03-05
      When the TPP reads the consent
      Then validUntil is 2027-03-05

    @edge @mvp
    Scenario: A multicurrency selection shows one entry per currency
      Given the multicurrency account with EUR and USD selected
      When the TPP reads the consent
      Then accounts holds two entries with the same IBAN and currencies EUR and USD

    @nominal @mvp
    Scenario: No transactions array when transactions were not granted
      Given the accounts+balances consent
      When the TPP reads it
      Then access has no transactions field

  @security
  Rule: Only the creating TPP reads the consent object

    @error @mvp
    Scenario: C reads the TPP's consent
      Given C's QWAC
      When GET /v1/consents/123cons456 is called
      Then the answer is 403 CONSENT_UNKNOWN

    @edge @mvp
    Scenario: The TPP reads a terminated consent
      Given consent 111cons222 terminatedByTpp
      When the TPP reads it
      Then the answer is 200 with consentStatus terminatedByTpp and the access as it was

  Rule: The TPP updates its connection from the consent object

    @nominal @mvp
    Scenario: The granted accounts are stored
      Given the consent object with two accounts
      When the TPP processes it
      Then the connection shows '2 accounts shared' and validUntil 2026-12-05

    @edge @mvp
    Scenario: A validity shorter than requested is shown to the PSU
      Given A requested 2026-12-05 and the object says 2026-10-06
      When the TPP processes it
      Then the connection page says 'Connected until 6 Oct 2026'

    @nominal @mvp
    Scenario: The IBANs in the consent object are not used as resource ids
      Given the consent object
      When the TPP builds its account views
      Then it waits for GET /v1/accounts to learn the resourceIds and never puts an IBAN in a path
