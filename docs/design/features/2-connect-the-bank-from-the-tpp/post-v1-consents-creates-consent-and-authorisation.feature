# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/post-v1-consents-creates-consent-and-authorisation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-6.3.1.1 @spec-4.6 @walking-skeleton @analysing
Feature: POST /v1/consents creates consent and authorisation
  As TPP operator
  I want a 201 with consentId, ASPSP-SCA-Approach REDIRECT and the scaOAuth, scaStatus, self and status links
  So that the TPP can steer the next step from the hyperlinks

  @spec-6.3.1.1
  Rule: A valid bank-offered request creates a consent in status received and answers 201 with the steering links

    @nominal @walking-skeleton
    Scenario: The nominal 201
      Given the TPP's QWAC, X-Request-ID 99391c7e-…, TPP-Redirect-URI and TPP-Nok-Redirect-URI set, PSU-IP-Address 192.168.8.78
      And body access {accounts: [], balances: []}, recurringIndicator true, validUntil 2026-12-05, frequencyPerDay 4
      When POST /v1/consents is called
      Then the status is 201, ASPSP-SCA-Approach is REDIRECT, Location is /psd2/v1/consents/123cons456
      And the body has consentStatus received, consentId 123cons456 and _links self, status, scaStatus, scaOAuth
      And _links.scaOAuth.href is https://oidc-provider.sandbox/.well-known/oauth-authorization-server

    @nominal @walking-skeleton
    Scenario: X-Request-ID is echoed
      Given X-Request-ID 99391c7e-ad88-49ec-a2ad-99ddcb1f7756
      When POST /v1/consents is called
      Then the response header X-Request-ID is 99391c7e-ad88-49ec-a2ad-99ddcb1f7756

    @nominal @walking-skeleton
    Scenario: The consent stores the TPP, the redirect URIs and the PSU context
      Given the nominal request
      When the consent 123cons456 is read in consent management
      Then tppId is PSDDE-BAFIN-123456, tppRedirectUri and tppNokRedirectUri are stored, psuId is empty, scaApproach is REDIRECT

    @edge @walking-skeleton
    Scenario: Two requests create two distinct consents
      Given the nominal request sent twice
      When both answers arrive
      Then the consentId values differ
      And both consents are in status received

    @edge @walking-skeleton
    Scenario: The confirmation link is present when the Bank is configured for confirmation
      Given the Bank runs with confirmationRequired true
      When POST /v1/consents is called
      Then _links.confirmation.href is /psd2/v1/consents/123cons456/authorisations/123auth567

  @spec-4.6 @spec-14.16
  Rule: An authorisation sub-resource is created implicitly with scaStatus received

    @nominal @walking-skeleton
    Scenario: The scaStatus link resolves to received
      Given the 201 answer with _links.scaStatus /psd2/v1/consents/123cons456/authorisations/123auth567
      When the TPP calls GET on that link
      Then the answer is 200 {scaStatus: received}

    @nominal @mvp
    Scenario: The authorisation list has exactly one entry
      Given the consent 123cons456
      When GET /v1/consents/123cons456/authorisations is called
      Then the answer is {authorisationIds: [123auth567]}

    @nominal @walking-skeleton
    Scenario: The authorisation belongs to the consent
      Given consent 123cons456 and authorisation 123auth567
      When GET /v1/consents/999cons000/authorisations/123auth567 is called
      Then the answer is 403 CONSENT_UNKNOWN

  @spec-14.17
  Rule: Body values are validated: validUntil not in the past, frequencyPerDay at least 1 and 1 for one-off consents, access present

    @error @mvp
    Scenario: validUntil yesterday is refused
      Given validUntil 2026-09-05 and today 2026-09-06
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path validUntil

    @edge @mvp
    Scenario: validUntil today is accepted
      Given validUntil 2026-09-06 and today 2026-09-06
      When POST /v1/consents is called
      Then the answer is 201

    @edge @mvp
    Scenario: validUntil beyond the bank's cap is shortened, not refused
      Given the Bank caps validity at 180 days and validUntil is 2027-09-06
      When POST /v1/consents is called
      Then the answer is 201
      And GET /v1/consents/123cons456 shows validUntil 2027-03-05

    @edge @mvp
    Scenario: validUntil 9999-12-31 means 'maximum' and is shortened
      Given validUntil 9999-12-31
      When POST /v1/consents is called
      Then the answer is 201 and the stored validUntil is 2027-03-05

    @error @mvp
    Scenario: frequencyPerDay 0 is refused
      Given frequencyPerDay 0
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path frequencyPerDay

    @error @mvp
    Scenario: A one-off consent with frequencyPerDay 4 is refused
      Given recurringIndicator false and frequencyPerDay 4
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with text 'frequencyPerDay must be 1 when recurringIndicator is false'

    @edge @mvp
    Scenario: frequencyPerDay above the bank's maximum is capped
      Given the Bank caps frequencyPerDay at 4 and the request asks 10
      When POST /v1/consents is called
      Then the answer is 201 and the stored frequencyPerDay is 4

    @error @mvp
    Scenario: A body without access is refused
      Given a body without the access object
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path access

    @error @mvp
    Scenario: A body that is not JSON is refused
      Given the body 'hello'
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR

    @edge @mvp
    Scenario: An unknown field is ignored
      Given the nominal body plus a field colour: blue
      When POST /v1/consents is called
      Then the answer is 201

  @spec-4.10
  Rule: Mandatory headers are checked: X-Request-ID must be a UUID, redirect URIs must be present for the redirect approach and lie in the QWAC domain

    @error @mvp
    Scenario: A missing X-Request-ID is refused
      Given no X-Request-ID header
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path X-Request-ID

    @error @mvp
    Scenario: An X-Request-ID that is not a UUID is refused
      Given X-Request-ID 'req-1'
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path X-Request-ID

    @error @mvp
    Scenario: A missing TPP-Redirect-URI is refused
      Given no TPP-Redirect-URI header
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path TPP-Redirect-URI

    @error @mvp
    Scenario: A TPP-Redirect-URI outside the QWAC domain is refused
      Given TPP-Redirect-URI https://evil.example/cb and a QWAC for tpp.sandbox
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with text 'TPP-Redirect-URI not in certificate domain'

    @edge @walking-skeleton
    Scenario: A missing TPP-Nok-Redirect-URI is accepted
      Given no TPP-Nok-Redirect-URI header
      When POST /v1/consents is called
      Then the answer is 201
      And a failed SCA will redirect to TPP-Redirect-URI with an error parameter

    @edge @mvp
    Scenario: A missing PSU-IP-Address at creation is accepted
      Given no PSU-IP-Address header
      When POST /v1/consents is called
      Then the answer is 201

    @edge @mvp
    Scenario: A PSU-ID header is stored on the consent
      Given PSU-ID anna.mueller
      When POST /v1/consents is called
      Then the consent's psuId is anna.mueller before any login
