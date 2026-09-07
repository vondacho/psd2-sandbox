# Generated from docs/design/examplemap/4-complete-the-connection/use-a-pairwise-subject.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@oidc-provider @security @oidc-core-8 @mvp @analysing
Feature: Use a pairwise subject
  As PSU
  I want the OIDC-provider to give the TPP a pseudonymous identifier instead of my bank customer id
  So that the TPP cannot correlate me across banks

  @oidc-core-8
  Rule: The subject is a keyed hash of the sector identifier of the client and the bank's PSU identifier, stable per client and different per client

    @nominal @mvp
    Scenario: Anna through the TPP
      Given the TPP client with sector identifier tpp.sandbox and Anna's bank subject anna.mueller
      When the OIDC-provider issues a token
      Then sub is 8f6c2b1e-…

    @nominal @mvp
    Scenario: Anna through the TPP again, months later
      Given the same client and PSU
      When the OIDC-provider issues a token for a new consent
      Then sub is again 8f6c2b1e-…

    @nominal @mvp
    Scenario: Anna through C
      Given client C with sector identifier tpp-c.sandbox
      When the OIDC-provider issues a token for Anna
      Then sub differs from 8f6c2b1e-…

    @nominal @mvp
    Scenario: Ben through the TPP
      Given the TPP client and ben.weber
      When the OIDC-provider issues a token
      Then sub differs from Anna's

    @edge @mvp
    Scenario: The salt is secret and rotates never
      Given the pairwise salt
      When it is inspected
      Then it is a 256-bit value held in the OIDC-provider's KMS, and rotating it is documented as breaking every stored sub

  @security
  Rule: The bank PSU-ID never reaches the TPP

    @nominal @mvp
    Scenario: Not in the access token
      Given the access token
      When its claims are listed
      Then none equals anna.mueller

    @nominal @mvp
    Scenario: Not in the token response
      Given the token response body
      When it is inspected
      Then it holds no psu_id or id_token

    @edge @mvp
    Scenario: Not at /userinfo
      Given the TPP calls GET https://oidc-provider.sandbox/userinfo with the access token
      When the OIDC-provider answers
      Then the body is {sub: 8f6c2b1e-…} only

    @edge @mvp
    Scenario: Not in an error
      Given a failing refresh
      When the OIDC-provider answers invalid_grant
      Then error_description names no PSU

  Rule: The Bank serves data from the consent, not from the subject

    @nominal @mvp
    Scenario: The XS2A API finds the PSU through the consent
      Given GET /v1/accounts with a token whose sub is 8f6c2b1e-… and Consent-ID 123cons456
      When the Bank resolves the accounts
      Then it uses consent 123cons456's psuId anna.mueller and never maps sub back

    @error @mvp
    Scenario: A token with a forged sub changes nothing
      Given a token whose sub was altered (and therefore fails signature)
      When GET /v1/accounts is called
      Then the answer is 401 TOKEN_INVALID
