# Generated from docs/design/examplemap/12-answer-like-the-specification-says/serve-the-message-codes-of-each-service.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-14.11 @conformance @analysing
Feature: Serve the message codes of each service
  As TPP operator
  I want every refusal to carry the code the specification defines for that service
  So that my error handling is written once against the standard, not against this bank

  @spec-14.11
  Rule: A refusal carries a code from the catalogue of the service that refused it

    @nominal @conformance
    Scenario: The account endpoints use the AIS codes
      Given the account, balance and transaction endpoints
      When their refusals are collected
      Then every code is one of CONSENT_INVALID, CONSENT_EXPIRED, CONSENT_UNKNOWN, ACCESS_EXCEEDED, RESOURCE_UNKNOWN, PERIOD_INVALID or a general code

    @nominal @conformance
    Scenario: The payment endpoints use the PIS codes
      Given the payment endpoints
      When their refusals are collected
      Then every code is one of PRODUCT_UNKNOWN, PAYMENT_FAILED, CANCELLATION_INVALID, EXECUTION_DATE_INVALID, RESOURCE_UNKNOWN or a general code

    @nominal @conformance
    Scenario: The general codes appear everywhere
      Given any endpoint
      When the certificate, the token or the syntax is wrong
      Then the code is one of CERTIFICATE_INVALID, CERTIFICATE_EXPIRED, CERTIFICATE_REVOKED, CERTIFICATE_MISSING, CERTIFICATE_BLOCKED, ROLE_INVALID, TOKEN_INVALID, TOKEN_EXPIRED, FORMAT_ERROR, SERVICE_INVALID or SERVICE_BLOCKED

    @error @conformance
    Scenario: A code from another service is never used
      Given an account endpoint refusing a call
      When the code is read
      Then it is never PRODUCT_UNKNOWN or CANCELLATION_INVALID

    @nominal @conformance
    Scenario: No bank-specific code is invented
      Given every refusal the sandbox can produce
      When the codes are compared with the catalogue
      Then each one is in it

  @spec-4.13
  Rule: The error body has the shape the specification prescribes

    @nominal @conformance
    Scenario: One message with category, code and text
      Given a refusal for an expired consent
      When the body is read
      Then it is {tppMessages: [{category: ERROR, code: CONSENT_EXPIRED, text: …}]}

    @nominal @conformance
    Scenario: A syntax error names the faulty field
      Given a body with a bad validUntil
      When the refusal is read
      Then the message carries path 'validUntil'

    @edge @conformance
    Scenario: Several faults produce several messages
      Given two faulty fields
      When the refusal is read
      Then tppMessages holds two entries

    @edge @conformance
    Scenario: A warning does not turn a success into a failure
      Given a call that succeeds with a remark
      When the answer is read
      Then the status is 200 and tppMessages carries a WARNING entry

    @nominal @conformance
    Scenario: The text is human-readable and carries no internals
      Given any error text
      When it is read
      Then it explains the refusal without a stack trace, a table name or an internal id

  Rule: The same fault always gets the same code, on every endpoint

    @nominal @conformance
    Scenario: An expired token on four endpoints
      Given an expired access token
      When the account list, an account detail, the balances and a payment status are called
      Then each answers 401 TOKEN_EXPIRED

    @nominal @conformance
    Scenario: A revoked certificate on an account and on a payment endpoint
      Given a revoked certificate
      When both endpoints are called
      Then both answer 401 CERTIFICATE_REVOKED
