# Generated from docs/design/examplemap/10-cancel-the-payment/issue-a-cancel-pis-scoped-token.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@oidc-provider @spec-13.1 @pis-cancellation @ready
Feature: Issue a Cancel-PIS scoped token
  As Bank security officer
  I want the cancellation authorised with scope Cancel-PIS:<paymentId>
  So that a payment token cannot cancel and a cancellation token cannot pay

  @spec-13.1
  Rule: A cancellation is authorised with its own scope kind, validated against the payment

    @nominal @pis-cancellation
    Scenario: The cancellation scope is accepted
      Given pay002 is ACTC with a pending cancellation and belongs to the requesting client
      When the client requests scope Cancel-PIS:pay002
      Then the OIDC-provider brokers the PSU to the Bank for the cancellation

    @error @pis-cancellation
    Scenario: A cancellation scope for a payment that has no pending cancellation is refused
      Given pay001 with no cancellation started
      When Cancel-PIS:pay001 is requested
      Then the answer redirects with error=invalid_scope

    @error @pis-cancellation
    Scenario: A cancellation scope for another TPP's payment is refused
      Given pay003 belongs to the other TPP
      When Cancel-PIS:pay003 is requested
      Then the answer redirects with error=invalid_scope

    @error @pis-cancellation
    Scenario: The PISP role is required
      Given a client with the AISP role only
      When Cancel-PIS:pay002 is requested
      Then the answer redirects with error=invalid_scope

  @security
  Rule: The token that comes back cancels and does nothing else

    @nominal @pis-cancellation
    Scenario: The claims of a cancellation token
      Given the cancellation was approved
      When the token is issued
      Then its scope is 'Cancel-PIS:pay002', its audience is the Bank's API and it carries the certificate thumbprint

    @error @pis-cancellation
    Scenario: A cancellation token cannot confirm a payment authorisation
      Given a token with scope Cancel-PIS:pay002
      When it is used to confirm the payment authorisation pay002auth1
      Then the answer is 401 TOKEN_INVALID

    @error @pis-cancellation
    Scenario: A payment token cannot confirm a cancellation
      Given a token with scope PIS:pay002
      When it is used on the cancellation authorisation
      Then the answer is 401 TOKEN_INVALID

    @error @pis-cancellation
    Scenario: A cancellation token reads no account data
      Given a token with scope Cancel-PIS:pay002
      When the account list is called with it
      Then the answer is 401 TOKEN_INVALID

    @nominal @pis-cancellation
    Scenario: The token lives no longer than any other access token
      Given the cancellation token
      When its lifetime is read
      Then it is at most ten minutes

  @spec-13.5
  Rule: No refresh token is issued for a cancellation

    @nominal @pis-cancellation
    Scenario: The token response carries no refresh token
      Given the cancellation flow
      When the tokens are issued
      Then the response holds an access token and no refresh token, because a cancellation happens once

    @error @pis-cancellation
    Scenario: A refresh attempt is refused
      Given no refresh token exists for the cancellation grant
      When a refresh is attempted
      Then the OIDC-provider answers invalid_grant
