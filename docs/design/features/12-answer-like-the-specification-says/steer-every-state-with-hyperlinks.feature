# Generated from docs/design/examplemap/12-answer-like-the-specification-says/steer-every-state-with-hyperlinks.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-4.15 @conformance @analysing
Feature: Steer every state with hyperlinks
  As TPP operator
  I want the links that fit the current state, and none that do not
  So that I never construct a URL or call a step that is not available

  @spec-4.15
  Rule: The links offered are exactly the steps that are possible next

    @nominal @conformance
    Scenario: A consent waiting for its SCA
      Given consent 123cons456 at received with an implicit authorisation
      When the answer is read
      Then _links holds self, status, scaStatus and scaOAuth

    @nominal @conformance
    Scenario: A consent waiting for an explicit start
      Given a consent created with the explicit preference
      When the answer is read
      Then _links holds startAuthorisation and no scaStatus

    @edge @conformance
    Scenario: A valid consent offers its data
      Given a valid consent
      When it is read
      Then _links holds self and status, and no authorisation link

    @nominal @conformance
    Scenario: An account entry offers only the access types granted
      Given an accounts and balances consent
      When the account list is read
      Then each entry holds a balances link and no transactions link

    @edge @conformance
    Scenario: A payment accepted for execution offers no confirmation
      Given a payment at ACTC with a finalised authorisation
      When it is read
      Then _links holds self and status only

    @edge @conformance
    Scenario: A terminal resource offers nothing to do
      Given a rejected consent
      When it is read
      Then _links holds self and status

  @spec-14.6
  Rule: Every link is usable as given, and the client never has to build one

    @nominal @conformance
    Scenario: A link resolves against the API base
      Given the href /psd2/v1/consents/123cons456/status
      When it is resolved against https://api.bank.sandbox
      Then the call answers 200

    @nominal @conformance
    Scenario: The scaOAuth link is absolute
      Given the scaOAuth link
      When it is read
      Then it is an absolute https URL to the authorization server metadata

    @nominal @conformance
    Scenario: Links carry ids, never IBANs or PSU identifiers
      Given every link the sandbox serves
      When they are inspected
      Then none carries an IBAN, a PAN or a customer number

    @nominal @conformance
    Scenario: A client that follows links only can complete the journey
      Given a client that never builds a URL
      When it runs the whole consent and payment journey
      Then every step it needs was offered as a link

  @spec-14.6
  Rule: Link names are the ones the specification defines

    @nominal @conformance
    Scenario: The names used by the sandbox
      Given every answer that carries links
      When the names are collected
      Then they are among self, status, scaStatus, scaOAuth, scaRedirect, startAuthorisation, confirmation, balances, transactions, next, account and cardAccount

    @error @conformance
    Scenario: No bank-specific link name is invented
      Given the collected names
      When they are compared with the specification
      Then none is outside it
