# GENERATED from docs/stories/read-account-list.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 97444b02037280735618f6e9813b12e54887057907284bba474180eb2fd62461
# generator: tools/sdlc/examplemap_to_feature.py
# 3 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-READ-ACCOUNT-LIST
Feature: Read the list of accessible accounts
  As AISP
  I want to read the accounts my consent covers, with their resource identifiers
  So that I can address balances and transactions afterwards

  # Rule R-ACC-01: Accounts are addressed by a resourceId, never by an IBAN in the path

  @WS-01 @R-ACC-01
  Scenario: The account list returns a resourceId that addresses the balances endpoint
    Given a valid consent for balances on DE40100100103307118608
    When the AISP reads GET /v1/accounts
    Then the account carries a resourceId that is not the IBAN
    And the balances link uses that resourceId

  # Rule R-ACC-02: A transactions or balances access also gives the account list

  @MVP-01 @R-ACC-02
  Scenario: Transactions access alone shows the account in the list
    Given a valid consent with access.transactions = [DE40100100103307118608] and no access.accounts
    When the AISP reads GET /v1/accounts
    Then the list contains the account DE40100100103307118608

  @MVP-01 @R-ACC-02 @edge-case
  Scenario: An account outside the consent is not listed
    Given a PSU holding DE40100100103307118608 and DE02100100109307118603
    And a valid consent naming only DE40100100103307118608
    When the AISP reads GET /v1/accounts
    Then the list contains only DE40100100103307118608

  # Rule R-ACC-03: Only a valid consent authorises a read

  @WS-01 @R-ACC-03 @edge-case
  Scenario: A read with a consent still at received is refused
    Given a consent whose authorisation has not been finalised
    When the AISP reads GET /v1/accounts with that Consent-ID
    Then no account data is returned

  @MVP-01 @R-ACC-03 @edge-case
  Scenario: A read with an expired consent is refused
    Given a consent whose validUntil passed yesterday
    When the AISP reads GET /v1/accounts with that Consent-ID
    Then the response is 401 with code CONSENT_EXPIRED

  # Rule R-ACC-04: Available accounts and accessible accounts are different lists

  @MVP-01 @R-ACC-04
  Scenario: A consent on one of two accounts makes only that one accessible
    Given a PSU holding DE40100100103307118608 and DE02100100109307118603
    And a consent granting transactions and balances on DE40100100103307118608
    When the AISP reads GET /v1/accounts
    Then the list contains one account
