# Generated from docs/design/examplemap/5-view-my-accounts/refuse-accounts-outside-the-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @security @mvp @analysing
Feature: Refuse accounts outside the consent
  As Bank security officer
  I want a resourceId not covered by the consent to return CONSENT_INVALID
  So that the TPP cannot enumerate other accounts

  Rule: Any account resource not in the consent's accessible list answers 401 CONSENT_INVALID, on the account, its balances and its transactions

    @nominal @mvp
    Scenario: Anna's unselected Savings
      Given consent 123cons456 with Main Account only, and Savings has resourceId 7a1f… under another consent of Anna
      When the TPP calls GET /v1/accounts/7a1f…
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Ben's account
      Given resourceId b0b0… of Ben's account under Ben's consent with the TPP
      When the TPP calls GET /v1/accounts/b0b0… with Consent-ID 123cons456 (Anna's)
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: An account of Anna's replaced consent
      Given resourceId 9e9e… of Main Account under 111cons222 (terminatedByTpp)
      When the TPP calls GET /v1/accounts/9e9e… with Consent-ID 123cons456
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Balances of an unselected account
      Given the same
      When the TPP calls GET /v1/accounts/7a1f…/balances
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Transactions of an unselected account
      Given the same
      When the TPP calls GET /v1/accounts/7a1f…/transactions?bookingStatus=booked&dateFrom=2026-08-01
      Then the answer is 401 CONSENT_INVALID

    @nominal @mvp
    Scenario: A selected account is served
      Given Main Account 3dc3d5b3-… in the consent
      When the TPP calls GET /v1/accounts/3dc3d5b3-…
      Then the answer is 200

  @security
  Rule: The refusal gives no clue about the account

    @nominal @mvp
    Scenario: The body of the refusal
      Given the refusal for 7a1f…
      When the body is inspected
      Then it is {tppMessages: [{category: ERROR, code: CONSENT_INVALID, text: 'resource not covered by consent'}]} with no IBAN, owner or currency

    @edge @mvp
    Scenario: Timing does not reveal existence
      Given 100 calls with random UUIDs and 100 with real ids of other consents
      When the response times are compared
      Then the medians differ by less than 20 ms

  Rule: Every refusal is logged for audit with the TPP, the consent and the resource

    @nominal @mvp
    Scenario: The audit entry
      Given the refusal for 7a1f… by PSDDE-BAFIN-123456 under 123cons456
      When the audit log is read
      Then one entry has tppId, consentId, resourceId, code CONSENT_INVALID and the X-Request-ID

    @edge @mvp
    Scenario: Twenty refusals in a minute raise a security alert
      Given A produced 20 CONSENT_INVALID answers in 60 seconds
      When the monitoring rule runs
      Then an alert 'possible enumeration by PSDDE-BAFIN-123456' is raised
