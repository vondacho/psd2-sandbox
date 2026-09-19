# GENERATED from docs/stories/psu-revoke.examplemap — do not edit; change the example map and regenerate.
# source-sha256: 5c9e5313a73c5209e51231d7dee98d5dbd093be545d789fef4451d4ab9791463
# generator: tools/sdlc/examplemap_to_feature.py
# 6 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-PSU-REVOKE
Feature: Withdraw a TPP's access from my bank app
  As Account holder
  I want to withdraw a TPP's access from my bank app
  So that the TPP cannot read my accounts any more

  # Rule R-REV-01: A PSU can revoke a valid consent they granted

  @MVP-01 @R-REV-01
  Scenario: The PSU revokes an AISP's access
    Given consent 123cons456, valid, granted by PSU PSU-1234 to Sandbox AISP Ltd
    When PSU PSU-1234 revokes Sandbox AISP Ltd's access in the bank app on 2026-10-01
    Then consent 123cons456 has consentStatus revokedByPsu
    And consent 123cons456 has lastActionDate 2026-10-01

  @MVP-01 @R-REV-01 @edge-case
  Scenario: A PSU cannot revoke another PSU's consent
    Given consent 123cons456, valid, granted by PSU PSU-1234
    When PSU PSU-5678 looks at their TPP access in the bank app
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

  # Rule R-REV-04: The overview shows who can see what, and until when

  @MVP-01 @R-REV-04
  Scenario: The overview lists one AISP
    Given PSU PSU-1234 has consent 123cons456 to Sandbox AISP Ltd on DE40100100103307118608 for balances and transactions until 2017-11-01
    When PSU PSU-1234 opens the TPP access overview in the bank app
    Then the overview shows Sandbox AISP Ltd, DE40100100103307118608, balances and transactions, until 2017-11-01
