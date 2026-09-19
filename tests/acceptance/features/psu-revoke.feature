# GENERATED from docs/stories/psu-revoke.examplemap — do not edit; change the example map and regenerate.
# source-sha256: c049dfe86f7358a0b11d6edbf8c68e2db3ed061bc1a2b64a1d4136a06df986e9
# generator: tools/sdlc/examplemap_to_feature.py
# 6 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-PSU-REVOKE
Feature: Withdraw a TPP's access on the consent screen
  As Account holder
  I want to withdraw a TPP's access on the consent screen
  So that the TPP cannot read my accounts any more

  # Rule R-REV-01: A PSU can revoke a valid consent they granted

  @MVP-01 @R-REV-01
  Scenario: The PSU revokes an AISP's access
    Given consent 123cons456, valid, granted by PSU PSU-1234 to Sandbox AISP Ltd
    When PSU PSU-1234 revokes Sandbox AISP Ltd's access on the consent screen on 2026-10-01
    Then consent 123cons456 has consentStatus revokedByPsu
    And consent 123cons456 has lastActionDate 2026-10-01

  @MVP-01 @R-REV-01 @edge-case
  Scenario: A PSU cannot revoke another PSU's consent
    Given consent 123cons456, valid, granted by PSU PSU-1234
    When PSU PSU-5678 opens the consent screen of Sandbox AISP Ltd
    Then consent 123cons456 is not shown

  # Rule R-REV-02: After revocation every read with that consent is refused

  @MVP-01 @R-REV-02
  Scenario: The AISP's next read fails
    Given consent 123cons456 in status revokedByPsu
    When Sandbox AISP Ltd reads GET /v1/accounts with Consent-ID 123cons456
    Then the response is a 401
    And no account data is returned

  # Rule R-REV-03: Revocation is final

  @MVP-01 @R-REV-03 @edge-case
  Scenario: A revoked consent cannot be authorised again
    Given consent 123cons456 in status revokedByPsu
    When Sandbox AISP Ltd posts POST /v1/consents/123cons456/authorisations
    Then consent 123cons456 still has consentStatus revokedByPsu

  # Rule R-REV-04: The consent screen shows what this TPP can see, and until when

  @MVP-01 @R-REV-04
  Scenario: The consent screen lists the AISP's access
    Given PSU PSU-1234 has consent 123cons456 to Sandbox AISP Ltd on DE40100100103307118608 for balances and transactions until 2017-11-01
    When PSU PSU-1234 opens the consent screen of Sandbox AISP Ltd to manage access
    Then the consent screen shows Sandbox AISP Ltd, DE40100100103307118608, balances and transactions, until 2017-11-01
