# Generated from docs/design/examplemap/12-answer-like-the-specification-says/announce-notification-support-and-accept-a-notification-uri.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-xs2a @spec-4.8 @conformance @analysing
Feature: Announce notification support and accept a notification URI
  As TPP operator
  I want the bank to say whether it notifies, and to take my notification URI and content preference
  So that I know whether to poll or to wait

  @spec-4.8
  Rule: The Bank answers every resource creation with whether it will notify

    @nominal @conformance
    Scenario: Notification support announced on a consent
      Given the sandbox runs with notifications enabled
      And the request carries TPP-Notification-URI https://tpp.sandbox/xs2a/notifications/bank and TPP-Notification-Content status
      When the consent is created
      Then the answer carries ASPSP-Notification-Support true and ASPSP-Notification-Content status

    @nominal @conformance
    Scenario: Notification support announced on a payment
      Given the same headers on a payment initiation
      When the payment is created
      Then the answer carries the same two headers

    @nominal @conformance
    Scenario: A bank that does not notify says so
      Given the sandbox runs with notifications disabled
      When a resource is created with a notification URI
      Then the answer carries ASPSP-Notification-Support false
      And the TPP knows it has to poll

    @edge @conformance
    Scenario: Without a notification URI nothing is promised
      Given a request without TPP-Notification-URI
      When the resource is created
      Then no notification headers are returned and no notification is ever sent

    @edge @conformance
    Scenario: A content preference the Bank cannot meet is answered with what it will send
      Given TPP-Notification-Content asking for the full resource on a bank that sends the status only
      When the resource is created
      Then ASPSP-Notification-Content is status

  @spec-4.10 @security
  Rule: The notification URI is checked like every other TPP URI

    @nominal @conformance
    Scenario: A URI inside the certificate domain is accepted
      Given the certificate names tpp.sandbox
      When the notification URI is https://tpp.sandbox/xs2a/notifications/bank
      Then it is stored on the resource

    @error @conformance
    Scenario: A URI outside the certificate domain is refused
      Given the notification URI https://evil.example/n
      When the resource is created
      Then the answer is 400 FORMAT_ERROR naming TPP-Notification-URI

    @error @conformance
    Scenario: An http URI is refused
      Given the notification URI http://tpp.sandbox/n
      When the resource is created
      Then the answer is 400 FORMAT_ERROR

    @edge @conformance
    Scenario: The URI is stored per resource, not per TPP
      Given two consents created with different notification URIs
      When each changes status
      Then each notification goes to the URI its own consent carried

  Rule: The notification promise does not change what the interface owes otherwise

    @nominal @conformance
    Scenario: Polling still works when notifications are on
      Given notifications enabled for a consent
      When the TPP polls the status anyway
      Then the answer is 200 as usual

    @edge @conformance
    Scenario: A failed notification does not change the resource
      Given the notification endpoint of the TPP is down
      When the consent becomes valid
      Then the consent is valid and readable, whatever the notification did
