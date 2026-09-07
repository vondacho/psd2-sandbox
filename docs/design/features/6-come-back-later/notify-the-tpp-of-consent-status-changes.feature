# Generated from docs/design/examplemap/6-come-back-later/notify-the-tpp-of-consent-status-changes.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @tpp @xs2a-rsns @analysing
Feature: Notify the TPP of consent status changes
  As TPP operator
  I want the Bank to push consent status changes to a notification URI
  So that the TPP does not learn about a revocation from a failed call

  Rule: The TPP registers a notification URI at consent creation, and the Bank posts a signed notification on every status change

    @nominal
    Scenario: Registration and a revocation notification
      Given POST /v1/consents with TPP-Notification-URI https://tpp.sandbox/xs2a/notifications/bank and TPP-Notification-Content-Preferred status
      When the Bank answers 201
      Then the response has ASPSP-Notification-Support true and ASPSP-Notification-Content status
      When Anna revokes 123cons456 at the Bank
      Then within 5 seconds the Bank posts {consentId: 123cons456, consentStatus: revokedByPsu, timestamp: …} to that URI with a Signature header
      And the TPP marks the connection needsReconsent before its next call

    @nominal
    Scenario: Expiry notification
      Given the registration
      When the consent expires at midnight
      Then a notification with consentStatus expired is posted

    @edge
    Scenario: No notification URI: no notifications
      Given a consent created without TPP-Notification-URI
      When it is revoked
      Then nothing is posted and ASPSP-Notification-Support was false

    @error
    Scenario: A notification URI outside the QWAC domain is refused
      Given TPP-Notification-URI https://evil.example/n
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path TPP-Notification-URI

  @security
  Rule: The TPP trusts a notification only after verifying it, and confirms with a status read

    @error
    Scenario: An unsigned notification is ignored
      Given a POST to the notification URI without a valid signature
      When the TPP handles it
      Then the TPP answers 401 and changes nothing

    @nominal
    Scenario: A signed notification is verified against the Bank's certificate
      Given a notification signed with the Bank's QSEAL
      When the TPP handles it
      Then the TPP verifies the signature, calls GET /v1/consents/123cons456/status, and acts on the status read

    @edge
    Scenario: A notification for an unknown consent
      Given a notification for 999cons000
      When the TPP handles it
      Then the TPP answers 404 and logs it

    @edge
    Scenario: A duplicate notification
      Given the same notification posted twice
      When the TPP handles the second
      Then the TPP answers 200 and changes nothing

  Rule: The Bank retries failed deliveries and gives up after a day; the TPP still learns from its next call

    @error
    Scenario: The TPP's endpoint down
      Given the notification URI answers 503
      When the Bank delivers
      Then it retries after 1, 5, 30, 120 and 600 minutes, then stops

    @nominal
    Scenario: The TPP learns anyway
      Given every delivery failed
      When the TPP's next call to the Bank answers 401 CONSENT_INVALID
      Then the TPP marks the connection needsReconsent
