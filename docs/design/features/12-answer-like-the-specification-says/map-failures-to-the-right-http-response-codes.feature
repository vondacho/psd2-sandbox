# Generated from docs/design/examplemap/12-answer-like-the-specification-says/map-failures-to-the-right-http-response-codes.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-4.12 @conformance @ready
Feature: Map failures to the right HTTP response codes
  As TPP operator
  I want 400, 401, 403, 404, 405, 406, 409 and 429 used as the specification prescribes
  So that I can act on the status line before parsing the body

  @spec-4.12
  Rule: Each class of failure has its status code

    @nominal @conformance
    Scenario: A syntactically wrong request is 400
      Given a consent body without the access object
      When it is posted
      Then the answer is 400 with FORMAT_ERROR

    @nominal @conformance
    Scenario: A certificate or token problem is 401
      Given an expired token
      When the account list is called
      Then the answer is 401 with TOKEN_EXPIRED

    @nominal @conformance
    Scenario: A resource that exists but is not yours is 403
      Given a consent of the other TPP
      When its status is read
      Then the answer is 403 with CONSENT_UNKNOWN

    @nominal @conformance
    Scenario: A path that names nothing is 404
      Given an unknown resource id under a valid consent
      When it is read
      Then the answer is 404 with RESOURCE_UNKNOWN

    @nominal @conformance
    Scenario: A method the resource does not offer is 405
      Given a payment that cannot be cancelled
      When DELETE is called on it
      Then the answer is 405 with CANCELLATION_INVALID

    @nominal @conformance
    Scenario: A format the interface does not serve is 406
      Given Accept: text/csv on the transaction list
      When the call is made
      Then the answer is 406 with REQUESTED_FORMATS_INVALID

    @nominal @conformance
    Scenario: A call that contradicts the resource state is 409
      Given a confirmation on an authorisation that is only started
      When it is called
      Then the answer is 409 with STATUS_INVALID

    @nominal @conformance
    Scenario: Too many accesses is 429
      Given the daily frequency is used up
      When a background read is made
      Then the answer is 429 with ACCESS_EXCEEDED

    @nominal @conformance
    Scenario: A created resource is 201 with a Location
      Given a valid consent request
      When it is posted
      Then the answer is 201 with a Location header naming the new resource

    @nominal @conformance
    Scenario: A deletion that succeeded is 204 with no body
      Given a consent that can be deleted
      When DELETE is called
      Then the answer is 204 and the body is empty

  @spec-4.13
  Rule: The status code and the message code agree

    @nominal @conformance
    Scenario: No 200 carries an ERROR message
      Given every successful answer of the sandbox
      When their bodies are inspected
      Then none holds a tppMessage of category ERROR

    @nominal @conformance
    Scenario: No refusal carries an empty body
      Given every refusal from 400 to 429
      When their bodies are inspected
      Then each holds at least one tppMessage

    @edge @conformance
    Scenario: A 500 says nothing about internals
      Given an unexpected failure inside the Bank
      When the answer is built
      Then it is 500 with a generic INTERNAL_ERROR message and a request id, and no detail

  @spec-4.1
  Rule: Every answer carries the request id and the standard headers

    @nominal @conformance
    Scenario: X-Request-ID is echoed on success and on failure
      Given a call with X-Request-ID 6b2d1f4a-…
      When it succeeds and when it fails
      Then both answers carry that X-Request-ID

    @nominal @conformance
    Scenario: The content type is JSON
      Given any answer with a body
      When its headers are read
      Then Content-Type is application/json
