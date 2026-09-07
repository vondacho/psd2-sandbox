# Generated from docs/design/examplemap/11-drive-the-authorisation-explicitly/announce-the-sca-approach-on-every-resource.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-4.3 @authorisation-resources @analysing
Feature: Announce the SCA approach on every resource
  As TPP operator
  I want the ASPSP-SCA-Approach header on every resource that starts an authorisation
  So that I know which flow to drive before I read the links

  @spec-4.3
  Rule: Every answer that creates or starts an authorisation carries the approach

    @nominal @authorisation-resources
    Scenario: On a consent creation
      Given a consent is created
      When the answer is inspected
      Then the header ASPSP-SCA-Approach is REDIRECT

    @nominal @authorisation-resources
    Scenario: On a payment initiation
      Given a payment is created
      When the answer is inspected
      Then the header is REDIRECT

    @nominal @authorisation-resources
    Scenario: On an explicit start of an authorisation
      Given POST on the authorisations endpoint
      When the answer is inspected
      Then the header is present with the same value

    @nominal @authorisation-resources
    Scenario: On a cancellation that needs an authorisation
      Given a cancellation accepted for authorisation
      When the answer is inspected
      Then the header is present

    @edge @authorisation-resources
    Scenario: Not on a plain read
      Given a status or account read
      When the answer is inspected
      Then no SCA approach header is sent, because nothing is being authorised

  @spec-4.15
  Rule: The announced approach matches the links the answer carries

    @nominal @authorisation-resources
    Scenario: REDIRECT with an OAuth2 link
      Given the sandbox uses the OAuth2 approach
      When a consent is created
      Then the header is REDIRECT and the links carry scaOAuth

    @edge @authorisation-resources
    Scenario: REDIRECT with a plain redirect link
      Given a bank that redirects to its own page instead of an authorization server
      When a consent is created
      Then the header is REDIRECT and the links carry scaRedirect rather than scaOAuth

    @nominal @authorisation-resources
    Scenario: A client can tell the two apart from the links alone
      Given either answer
      When the client reads the links
      Then the presence of scaOAuth or scaRedirect decides what it does next

  Rule: The approach is chosen per resource and does not change once announced

    @nominal @authorisation-resources
    Scenario: The approach is stable for one consent
      Given a consent announced as REDIRECT
      When its authorisation is read later
      Then the approach is still REDIRECT

    @edge @authorisation-resources
    Scenario: A configuration change does not move a live resource
      Given the operator changes the sandbox default while a consent is being authorised
      When that consent continues
      Then it keeps the approach it was created with

    @edge @authorisation-resources
    Scenario: The preference header of the TPP is honoured when the Bank supports it
      Given TPP-Redirect-Preferred: false on a bank that also offers decoupled
      When the consent is created
      Then the announced approach is DECOUPLED
