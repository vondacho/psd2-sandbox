# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/validate-the-scope-against-the-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@oidc-provider @bank-xs2a @spec-13.1 @walking-skeleton @analysing
Feature: Validate the scope against the consent
  As Bank security officer
  I want the OIDC-provider to accept AIS:<consentId> only if the consent exists, is received and belongs to this client
  So that a TPP cannot authorise somebody else's consent

  @spec-13.1
  Rule: The scope names exactly one AIS, PIS or PIIS resource, optionally with offline_access

    @nominal @walking-skeleton
    Scenario: AIS:123cons456 offline_access is accepted
      Given scope 'AIS:123cons456 offline_access'
      When the OIDC-provider parses it
      Then the target is kind AIS, resource 123cons456, with offline_access

    @edge @walking-skeleton
    Scenario: AIS:123cons456 alone is accepted
      Given scope 'AIS:123cons456'
      When the OIDC-provider parses it
      Then the target is kind AIS, resource 123cons456, without offline_access

    @error @walking-skeleton
    Scenario: Two AIS scopes are refused
      Given scope 'AIS:123cons456 AIS:111cons222'
      When the OIDC-provider parses it
      Then the OIDC-provider redirects to the TPP with error=invalid_scope and the state

    @error @mvp
    Scenario: An AIS and a PIS scope together are refused
      Given scope 'AIS:123cons456 PIS:pay001'
      When the OIDC-provider parses it
      Then the OIDC-provider redirects with error=invalid_scope

    @error @walking-skeleton
    Scenario: A scope without any resource is refused
      Given scope 'offline_access'
      When the OIDC-provider parses it
      Then the OIDC-provider redirects with error=invalid_scope

    @error @mvp
    Scenario: An unknown scope word is refused
      Given scope 'AIS:123cons456 admin'
      When the OIDC-provider parses it
      Then the OIDC-provider redirects with error=invalid_scope

    @error @mvp
    Scenario: An AIS scope with an empty id is refused
      Given scope 'AIS:'
      When the OIDC-provider parses it
      Then the OIDC-provider redirects with error=invalid_scope

  Rule: The named consent must exist, be in status received and have been created by the requesting client

    @nominal @walking-skeleton
    Scenario: A received consent of the TPP is accepted
      Given consent 123cons456 exists, status received, tppId PSDDE-BAFIN-123456
      When client PSDDE-BAFIN-123456 requests AIS:123cons456
      Then the OIDC-provider proceeds to broker the PSU to the Bank

    @error @walking-skeleton
    Scenario: An unknown consent is refused
      Given no consent 999cons000
      When the TPP requests AIS:999cons000
      Then the OIDC-provider redirects with error=invalid_scope and error_description 'unknown resource'

    @error @walking-skeleton
    Scenario: A consent of another TPP is refused
      Given consent 333cons444 was created by C
      When the TPP requests AIS:333cons444
      Then the OIDC-provider redirects with error=invalid_scope
      And the refusal is logged with both client ids

    @error @mvp
    Scenario: An already valid consent cannot be authorised again
      Given consent 123cons456 is valid
      When the TPP requests AIS:123cons456
      Then the OIDC-provider redirects with error=invalid_scope and error_description 'resource not in status received'

    @error @mvp
    Scenario: A rejected consent is refused
      Given consent 123cons456 is rejected
      When the TPP requests AIS:123cons456
      Then the OIDC-provider redirects with error=invalid_scope

    @edge @mvp
    Scenario: A consent whose authorisation is already started is still accepted
      Given consent 123cons456 is received and its authorisation is psuAuthenticated because Anna abandoned a first attempt
      When the TPP requests AIS:123cons456 again
      Then the OIDC-provider proceeds

  @anticorruption-layer
  Rule: The OIDC-provider sees only existence, owner and status of a consent, through the internal contract

    @nominal @walking-skeleton
    Scenario: The internal call carries the consent id and the client id
      Given the request for AIS:123cons456 by PSDDE-BAFIN-123456
      When the OIDC-provider validates the scope
      Then it calls GET /internal/consents/123cons456?client_id=PSDDE-BAFIN-123456
      And the answer is {exists: true, ownedByClient: true, status: received}

    @nominal @walking-skeleton
    Scenario: The OIDC-provider never receives the access object or the PSU
      Given the internal answer
      When its fields are listed
      Then there is no access, psuId, validUntil or accounts field

    @error @mvp
    Scenario: Consent management unreachable yields temporarily_unavailable
      Given the internal endpoint times out after 3 seconds
      When the OIDC-provider validates the scope
      Then the OIDC-provider redirects to the TPP with error=temporarily_unavailable and the state
      And the TPP shows 'the Bank is temporarily unavailable'
