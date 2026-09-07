# Generated from docs/design/examplemap/4-complete-the-connection/confirm-with-the-bearer-token.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @bank-xs2a @spec-7.6.4 @mvp @analysing
Feature: Confirm with the bearer token
  As Bank security officer
  I want the TPP to PUT the authorisation with its token and the Bank to check consent id and client before finalising
  So that the consent becomes valid only for the TPP that created it

  @spec-7.6.4
  Rule: A PUT on the authorisation with a bearer token whose consent id and client match the resource finalises an unconfirmed authorisation and validates the consent

    @nominal @mvp
    Scenario: The nominal confirmation
      Given authorisation 123auth567 of 123cons456 is unconfirmed and the TPP holds a token with consent_id 123cons456, client_id PSDDE-BAFIN-123456
      When the TPP calls PUT /v1/consents/123cons456/authorisations/123auth567 with Authorization: Bearer, X-Request-ID and body {}
      Then the answer is 200 {scaStatus: finalised}
      And the consent status is valid

    @nominal @mvp
    Scenario: The TPP confirms right after the token exchange
      Given the connection holds a confirmation link
      When the token exchange succeeds
      Then the TPP sends the PUT before any GET /v1/accounts

    @edge @mvp
    Scenario: The PUT is idempotent
      Given the authorisation is already finalised
      When the TPP repeats the PUT
      Then the answer is 200 {scaStatus: finalised}

  @security
  Rule: A token for another consent, another client or none at all does not confirm

    @error @mvp
    Scenario: A token for another consent of the TPP
      Given a token with consent_id 111cons222
      When the TPP PUTs on 123cons456/authorisations/123auth567
      Then the answer is 401 TOKEN_INVALID and the authorisation stays unconfirmed

    @error @mvp
    Scenario: A token of the TPP presented over C's certificate
      Given the TPP's token and C's QWAC
      When the PUT is sent
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: No token
      Given the PUT without Authorization
      When it is sent
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: An expired token
      Given an access token past exp
      When the PUT is sent
      Then the answer is 401 TOKEN_EXPIRED
      And the TPP refreshes and repeats the PUT once

    @error @mvp
    Scenario: A consent created by C confirmed by the TPP
      Given consent 333cons444 of C and a token of the TPP for it (impossible to obtain; a forged one fails signature)
      When the PUT is sent
      Then the answer is 401 TOKEN_INVALID

  @spec-14.16
  Rule: Confirmation is possible only in the unconfirmed state

    @error @mvp
    Scenario: PUT while started
      Given the authorisation is started (no device approval yet)
      When the TPP PUTs
      Then the answer is 409 STATUS_INVALID and the status stays started

    @error @mvp
    Scenario: PUT while failed
      Given the authorisation is failed
      When the TPP PUTs
      Then the answer is 409 STATUS_INVALID

    @error @mvp
    Scenario: PUT on a rejected consent
      Given consent 123cons456 rejected
      When the TPP PUTs
      Then the answer is 409 STATUS_INVALID

  Rule: Until confirmed, the consent serves nothing

    @error @mvp
    Scenario: GET /v1/accounts before the PUT
      Given unconfirmed authorisation and a valid token
      When the TPP calls GET /v1/accounts
      Then the answer is 401 CONSENT_INVALID

    @nominal @mvp
    Scenario: GET /v1/accounts after the PUT
      Given the PUT answered finalised
      When the TPP calls GET /v1/accounts
      Then the answer is 200
