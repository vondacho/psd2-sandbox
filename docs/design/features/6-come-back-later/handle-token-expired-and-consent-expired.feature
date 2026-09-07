# Generated from docs/design/examplemap/6-come-back-later/handle-token-expired-and-consent-expired.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @spec-14.11 @mvp @ready
Feature: Handle TOKEN_EXPIRED and CONSENT_EXPIRED
  As TPP operator
  I want the TPP to map the XS2A error codes to refresh, re-consent or alert
  So that the PSU sees the right next step

  @spec-14.11
  Rule: Each XS2A error code maps to one action on the connection and one message

    @nominal @mvp
    Scenario: 401 TOKEN_EXPIRED: refresh and retry
      Given the Bank answers 401 TOKEN_EXPIRED
      When the TPP handles it
      Then the TPP refreshes and retries once; the PSU sees nothing

    @error @mvp
    Scenario: 401 TOKEN_INVALID: alert
      Given the Bank answers 401 TOKEN_INVALID
      When the TPP handles it
      Then the connection is failed, an alert 'token rejected by the Bank: TOKEN_INVALID' is raised
      And the PSU sees 'Something went wrong with the Bank (ref)'

    @nominal @mvp
    Scenario: 401 CONSENT_EXPIRED: re-consent
      Given the Bank answers 401 CONSENT_EXPIRED
      When the TPP handles it
      Then the token set is deleted, the connection is needsReconsent with reason expired
      And the PSU sees 'Your connection to the Bank ended. Reconnect.'

    @nominal @mvp
    Scenario: 401 CONSENT_INVALID: re-consent
      Given the Bank answers 401 CONSENT_INVALID
      When the TPP handles it
      Then the connection is needsReconsent with reason revoked
      And the PSU sees 'Access was withdrawn at the Bank. Reconnect to share again.'

    @error @mvp
    Scenario: 403 CONSENT_UNKNOWN: re-consent and alert
      Given the Bank answers 403 CONSENT_UNKNOWN
      When the TPP handles it
      Then the connection is needsReconsent and an alert 'consent unknown at the Bank' is raised

    @nominal @mvp
    Scenario: 429 ACCESS_EXCEEDED: back off
      Given the Bank answers 429 ACCESS_EXCEEDED on a background call
      When the TPP handles it
      Then the scheduler skips this connection until the next day
      And PSU-present calls remain allowed

    @error @mvp
    Scenario: 401 CERTIFICATE_REVOKED: pause the bank
      Given the Bank answers 401 CERTIFICATE_REVOKED
      When the TPP handles it
      Then every background call to the Bank is paused and a critical alert is raised
      And PSUs see 'the Bank is temporarily unavailable'

    @error @mvp
    Scenario: 401 ROLE_INVALID: alert
      Given the Bank answers 401 ROLE_INVALID
      When the TPP handles it
      Then a critical alert is raised and the call is not retried

    @error @mvp
    Scenario: 400 FORMAT_ERROR: bug
      Given the Bank answers 400 FORMAT_ERROR with path withBalance
      When the TPP handles it
      Then an alert with the path is raised and the call is not retried

    @error @mvp
    Scenario: 503: retry with backoff
      Given the Bank answers 503 three times
      When the TPP handles it
      Then the TPP retries after 1, 2 and 4 seconds, then shows 'the Bank is temporarily unavailable'

    @edge @mvp
    Scenario: An unknown code
      Given the Bank answers 401 with code SOMETHING_NEW
      When the TPP handles it
      Then the TPP treats it like TOKEN_INVALID and the alert names SOMETHING_NEW

  @spec-4.13
  Rule: The error body is parsed as tppMessages; a malformed body is treated by status code

    @nominal @mvp
    Scenario: A well-formed body
      Given {tppMessages: [{category: ERROR, code: CONSENT_EXPIRED, text: 'consent expired'}]}
      When the TPP parses it
      Then the code is CONSENT_EXPIRED and the text is logged

    @edge @mvp
    Scenario: An HTML body with 502
      Given a 502 with an HTML body
      When the TPP parses it
      Then the TPP treats it as a transient failure

    @edge @mvp
    Scenario: Two messages: the first ERROR wins
      Given tppMessages with a WARNING then an ERROR CONSENT_INVALID
      When the TPP parses it
      Then the action is re-consent

  Rule: The TPP never loops: one refresh, one retry, then a decision

    @edge @mvp
    Scenario: TOKEN_EXPIRED twice
      Given TOKEN_EXPIRED after a successful refresh
      When the TPP handles the second
      Then no second refresh; the connection is failed with an alert

    @edge @mvp
    Scenario: A 503 during the retry of a TOKEN_EXPIRED
      Given the retried call answers 503
      When the TPP handles it
      Then the 503 backoff applies once, then the failure is shown
