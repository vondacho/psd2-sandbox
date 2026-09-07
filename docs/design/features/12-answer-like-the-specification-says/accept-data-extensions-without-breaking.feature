# Generated from docs/design/examplemap/12-answer-like-the-specification-says/accept-data-extensions-without-breaking.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-4.16 @conformance @analysing
Feature: Accept data extensions without breaking
  As TPP operator
  I want unknown extension fields ignored rather than rejected
  So that a bank-specific extension does not break a standard client

  @spec-4.16
  Rule: An unknown field in a request body is ignored, not refused

    @nominal @conformance
    Scenario: An extra field on a consent request
      Given a valid consent body plus a field 'colour': 'blue'
      When the consent is created
      Then the answer is 201 and the stored consent has no colour

    @nominal @conformance
    Scenario: An extra field on a payment initiation
      Given a valid payment body plus an unknown field
      When the payment is created
      Then the answer is 201

    @error @conformance
    Scenario: An unknown field never overrides a known one
      Given a body with validUntil and an extra field 'validUntilReally'
      When the consent is created
      Then the stored validity comes from validUntil

    @error @conformance
    Scenario: A mandatory field is still mandatory
      Given a body with extension fields and no access object
      When the consent is created
      Then the answer is 400 FORMAT_ERROR naming access

    @error @conformance
    Scenario: An extension cannot smuggle a larger access
      Given an accounts-only consent body plus 'allPsd2': 'allAccounts' outside the access object
      When the consent is authorised
      Then only the account list is granted

  Rule: Unknown headers and query parameters are ignored the same way

    @nominal @conformance
    Scenario: An unknown header
      Given a call with the header X-Bank-Experiment: 1
      When it is made
      Then the answer is the same as without it

    @edge @conformance
    Scenario: An unknown query parameter
      Given the account list called with ?colour=blue
      When it is made
      Then the answer is 200 and the parameter is ignored

    @error @conformance
    Scenario: A misspelled known parameter is not silently ignored
      Given the transaction list called with bookingstatus=booked in the wrong case
      When it is made
      Then the answer is 400 FORMAT_ERROR naming bookingStatus, because it is missing

  @spec-4.16
  Rule: The Bank's own extensions are additive and namespaced

    @nominal @conformance
    Scenario: An extension field in an answer is ignorable
      Given the sandbox adds a field under an extension object
      When a standard client parses the answer
      Then it can ignore the extension and still read every standard field

    @nominal @conformance
    Scenario: No standard field changes meaning
      Given an answer with an extension
      When the standard fields are read
      Then each has the value and the meaning the specification defines
