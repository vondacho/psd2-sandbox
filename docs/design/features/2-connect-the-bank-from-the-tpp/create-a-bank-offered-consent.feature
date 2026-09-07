# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/create-a-bank-offered-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @spec-6.3.1.2 @walking-skeleton @analysing
Feature: Create a bank-offered consent
  As PSU
  I want the TPP to ask the Bank for access to the accounts I will choose at the bank
  So that I decide at the Bank which accounts the TPP may see

  @spec-6.3.1.2
  Rule: A bank-offered request has empty accounts and balances arrays, is recurring and asks for 90 days capped by the bank's maximum

    @nominal @walking-skeleton
    Scenario: The default request for the Bank
      Given today is 2026-09-06 and the entry bank has maxValidityDays 180
      When Anna connects the Bank
      Then the body is access {accounts: [], balances: []}, recurringIndicator true, validUntil 2026-12-05, frequencyPerDay 4, combinedServiceIndicator false

    @edge @walking-skeleton
    Scenario: A bank with a 30-day cap gets validUntil in 30 days
      Given today is 2026-09-06 and bank-c has maxValidityDays 30
      When Anna connects Bank C
      Then validUntil is 2026-10-06

    @edge @walking-skeleton
    Scenario: validUntil is a calendar date, not a timestamp
      Given the request is built at 2026-09-06T23:59:59+02:00
      When the body is serialised
      Then validUntil is the string 2026-12-05 without time

    @nominal @walking-skeleton
    Scenario: The request never names an IBAN
      Given the TPP knows Anna's IBAN from an earlier consent
      When a new bank-offered consent is created
      Then the access object contains no accountReference

  @spec-4.8
  Rule: Every request carries the mandatory headers with fresh values

    @nominal @walking-skeleton
    Scenario: The headers of a consent request
      Given Anna's browser session at the TPP
      When the request is sent
      Then it carries X-Request-ID as a new UUID v4, TPP-Redirect-URI https://tpp.sandbox/xs2a/callback/bank, TPP-Nok-Redirect-URI https://tpp.sandbox/xs2a/callback/bank?outcome=nok, TPP-Redirect-Preferred true, PSU-IP-Address of Anna's browser and TPP-Brand-Logging-Information 'TPP App'

    @nominal @walking-skeleton
    Scenario: Two requests never share an X-Request-ID
      Given Anna connects the Bank twice in a row
      When the two requests are compared
      Then their X-Request-ID values differ

    @nominal @walking-skeleton
    Scenario: The redirect URIs are exactly the ones registered at the OIDC-provider for this bank
      Given the OIDC-provider has https://tpp.sandbox/xs2a/callback/bank registered for client PSDDE-BAFIN-123456
      When the request is sent
      Then TPP-Redirect-URI equals that value character for character

  @spec-6.3.1.1
  Rule: A 201 answer is stored on the connection and steers the next step

    @nominal @walking-skeleton
    Scenario: consentId, authorisationId and links are stored
      Given the Bank answers 201 with consentId 123cons456, ASPSP-SCA-Approach REDIRECT and links self, status, scaStatus (…/authorisations/123auth567), confirmation, scaOAuth
      When the TPP processes the answer
      Then the connection holds consentId 123cons456, authorisationId 123auth567 and the five links
      And the connection state is consentRequested

    @edge @walking-skeleton
    Scenario: An answer without confirmation link is stored without it
      Given the Bank answers 201 without _links.confirmation
      When the TPP processes the answer
      Then the connection has no confirmation link
      And after the token exchange the TPP will skip the confirmation call

    @error @mvp
    Scenario: An SCA approach other than REDIRECT aborts the connection
      Given the Bank answers 201 with ASPSP-SCA-Approach DECOUPLED
      When the TPP processes the answer
      Then the connection state is failed with reason 'unsupported SCA approach DECOUPLED'
      And Anna sees 'the Bank uses a method TPP App does not support yet'

    @error @mvp
    Scenario: A 201 without scaOAuth link aborts the connection
      Given the Bank answers 201 with ASPSP-SCA-Approach REDIRECT but no scaOAuth link
      When the TPP processes the answer
      Then the connection state is failed with reason 'scaOAuth link missing'

  @spec-14.11
  Rule: A refused or failed request leaves a failed connection with a message and no retry loop

    @error @mvp
    Scenario: 400 FORMAT_ERROR is a bug, not something to retry
      Given the Bank answers 400 with tppMessages [{category ERROR, code FORMAT_ERROR, path validUntil}]
      When the TPP processes the answer
      Then the connection state is failed
      And an alert 'consent request rejected: FORMAT_ERROR at validUntil' is raised
      And Anna sees 'Something went wrong on our side'

    @error @mvp
    Scenario: 401 CERTIFICATE_INVALID raises an operational alert
      Given the Bank answers 401 CERTIFICATE_INVALID
      When the TPP processes the answer
      Then an operational alert is raised
      And Anna sees 'the Bank is temporarily unavailable'

    @error @mvp
    Scenario: A timeout after 10 seconds fails the attempt and allows a retry
      Given the Bank does not answer within 10 seconds
      When the request times out
      Then the connection state is failed with 'the Bank did not answer'
      And Anna sees 'Try again'

    @error @mvp
    Scenario: A 503 is retried once, then fails
      Given the Bank answers 503 twice
      When the TPP sends the request
      Then the TPP sends it exactly twice
      And the connection state is failed
