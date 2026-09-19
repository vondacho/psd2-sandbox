# GENERATED from docs/stories/read-account-list.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 9548e1f0a98cab921a537408a5be484b311cea9b0ef3553fd0975f8b3397ea9a
# generator: tools/sdlc/examplemap_to_feature.py
# 2 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-READ-ACCOUNT-LIST
Feature: Read the accounts a consent covers
  As AISP
  I want to list the accounts my consent covers, with a resourceId for each
  So that I can address each account without handling raw account numbers in URLs

  # Rule R-ACC-01: The list contains only the accounts the consent covers

  @WS-01 @R-ACC-01
  Scenario: Only the consented IBAN is listed
    Given PSU PSU-1234 holds DE40100100103307118608 and DE02100100109307118603
    And a valid consent with balances and transactions on DE40100100103307118608 only
    When the AISP reads GET /v1/accounts with that Consent-ID
    Then the response is 200 with one account, DE40100100103307118608
    And the account carries a resourceId and links to balances and transactions

  @MVP-01 @R-ACC-01 @edge-case
  Scenario: Balances-only access gives no transactions link
    Given a valid consent with balances on DE40100100103307118608 and nothing else
    When the AISP reads GET /v1/accounts
    Then the account has a balances link
    And the account has no transactions link

  # Rule R-ACC-02: No accessible account is still a 200 with an empty list

  @MVP-01 @R-ACC-02 @edge-case
  Scenario: The only consented account was closed
    Given a valid consent on DE40100100103307118608
    And DE40100100103307118608 has been closed
    When the AISP reads GET /v1/accounts
    Then the response is 200 with an empty accounts array

  # Rule R-ACC-03: Paths use the resourceId, never the IBAN, and it stays constant for the consent's life

  @MVP-01 @R-ACC-03
  Scenario: The same resourceId comes back on every read
    Given a valid consent on DE40100100103307118608
    And the first GET /v1/accounts returned resourceId 3dc3d5b3-7023-4848-9853-f5400a64e80f
    When the AISP reads GET /v1/accounts again the next day
    Then DE40100100103307118608 has resourceId 3dc3d5b3-7023-4848-9853-f5400a64e80f

  # Rule R-ACC-04: Reading requires the Consent-ID of a valid consent of this TPP

  @WS-01 @R-ACC-04 @edge-case
  Scenario: A consent still waiting for authorisation cannot be used
    Given consent 123cons456 in status received
    When the AISP reads GET /v1/accounts with Consent-ID 123cons456
    Then the response is 401 with code CONSENT_INVALID

  @MVP-01 @R-ACC-04 @edge-case
  Scenario: An expired consent cannot be used
    Given consent 123cons456 in status expired
    When the AISP reads GET /v1/accounts with Consent-ID 123cons456
    Then the response is 401 with code CONSENT_EXPIRED

  @MVP-01 @R-ACC-04 @edge-case
  Scenario: An unknown Consent-ID header is refused
    Given no consent 999cons999 exists for this TPP
    When the AISP reads GET /v1/accounts with Consent-ID 999cons999
    Then the response is 400 with code CONSENT_UNKNOWN
