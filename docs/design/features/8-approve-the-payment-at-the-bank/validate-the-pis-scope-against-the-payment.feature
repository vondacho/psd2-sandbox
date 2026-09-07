# Generated from docs/design/examplemap/8-approve-the-payment-at-the-bank/validate-the-pis-scope-against-the-payment.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@oidc-provider @bank-xs2a @spec-13.1 @pis-core @ready
Feature: Validate the PIS scope against the payment
  As Bank security officer
  I want PIS:<paymentId> accepted only for a payment that exists, is RCVD and belongs to this client
  So that a TPP cannot authorise somebody else's payment

  @spec-13.1
  Rule: The scope names exactly one payment resource, optionally with offline access

    @nominal @pis-core
    Scenario: PIS:pay001 is accepted
      Given scope 'PIS:pay001' from the client that created pay001
      When the OIDC-provider parses it
      Then the target is kind PIS, resource pay001

    @error @pis-core
    Scenario: Two payment scopes are refused
      Given scope 'PIS:pay001 PIS:pay002'
      When it is parsed
      Then the OIDC-provider redirects with error=invalid_scope

    @error @pis-core
    Scenario: A payment scope mixed with a consent scope is refused
      Given scope 'PIS:pay001 AIS:123cons456'
      When it is parsed
      Then the OIDC-provider redirects with error=invalid_scope

    @error @pis-core
    Scenario: A payment scope with an empty id is refused
      Given scope 'PIS:'
      When it is parsed
      Then the OIDC-provider redirects with error=invalid_scope

  Rule: The payment must exist, be in status RCVD and belong to the requesting client

    @nominal @pis-core
    Scenario: A received payment of the requesting client is accepted
      Given pay001 exists with RCVD and tppId PSDDE-BAFIN-123456
      When that client requests PIS:pay001
      Then the OIDC-provider brokers the PSU to the Bank

    @error @pis-core
    Scenario: An unknown payment is refused
      Given no payment pay999
      When PIS:pay999 is requested
      Then the answer redirects with error=invalid_scope and error_description 'unknown resource'

    @error @pis-core
    Scenario: A payment of another TPP is refused
      Given pay003 was created by the other TPP
      When PIS:pay003 is requested by this client
      Then the request is refused and both client ids are logged

    @error @pis-core
    Scenario: An already accepted payment cannot be authorised again
      Given pay001 is ACTC
      When PIS:pay001 is requested
      Then the answer redirects with error=invalid_scope and error_description 'resource not in status received'

    @error @pis-core
    Scenario: A rejected payment is refused
      Given pay001 is RJCT
      When PIS:pay001 is requested
      Then the answer redirects with error=invalid_scope

  @spec-13.1
  Rule: A PISP role is needed for a payment scope, and the scope kind decides the role

    @error @pis-core
    Scenario: An AISP-only client may not request a payment scope
      Given a client registered with the AISP role only
      When PIS:pay001 is requested
      Then the answer redirects with error=invalid_scope

    @nominal @pis-core
    Scenario: A PISP client may request a payment scope
      Given the client holds the PISP role
      When PIS:pay001 is requested
      Then the request proceeds

    @edge @pis-core
    Scenario: The cancellation kind needs the same role
      Given a PISP client
      When Cancel-PIS:pay001 is requested
      Then the scope kind is accepted for role checking

  @security
  Rule: The Bank tells the OIDC-provider only what it needs about a payment

    @nominal @pis-core
    Scenario: The internal answer carries existence, owner and status
      Given the scope validation for PIS:pay001
      When the OIDC-provider calls the internal payment endpoint
      Then the answer is {exists: true, ownedByClient: true, status: RCVD}

    @nominal @pis-core
    Scenario: No amount or payee crosses to the OIDC-provider
      Given the internal answer
      When its fields are listed
      Then there is no amount, creditor, debtor or PSU field
