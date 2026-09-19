# GENERATED from docs/stories/enforce-frequency.examplemap — do not edit; change the example map and regenerate.
# source-sha256: a46ecf34772241fcabfee39e5642cf59aa6a0fb2f7d23595d847a01e0d696db1
# generator: tools/sdlc/examplemap_to_feature.py
# 3 open question(s) on the map have no Gherkin and are NOT represented here.
# Status: PROPOSED examples, not yet accepted by a Three Amigos session.
@STORY-ENFORCE-FREQUENCY
Feature: Enforce the daily access frequency
  As AISP
  I want a clear ACCESS_EXCEEDED answer once I have used today's reads without my PSU
  So that I can schedule reads within my consent instead of being blocked silently

  # Rule R-FRQ-01: Unattended reads per account per day do not exceed frequencyPerDay

  @MVP-01 @R-FRQ-01 @edge-case
  Scenario: The fifth unattended balance read of the day is refused
    Given a valid consent 123cons456 with frequencyPerDay 4 on DE40100100103307118608 (resourceId 3dc3d5b3-7023-4848-9853-f5400a64e80f)
    And four balance reads of that account today without PSU-IP-Address
    When the AISP reads GET /v1/accounts/3dc3d5b3-7023-4848-9853-f5400a64e80f/balances without PSU-IP-Address
    Then the response is 429 with code ACCESS_EXCEEDED

  @MVP-01 @R-FRQ-01
  Scenario: The fourth unattended balance read of the day is served
    Given a valid consent 123cons456 with frequencyPerDay 4 on DE40100100103307118608
    And three balance reads of that account today without PSU-IP-Address
    When the AISP reads the balances without PSU-IP-Address
    Then the response is 200

  # Rule R-FRQ-02: Reads the PSU actively started do not count against the frequency

  @MVP-01 @R-FRQ-02 @edge-case
  Scenario: A PSU-initiated read after the limit is served
    Given four unattended balance reads of DE40100100103307118608 today under consent 123cons456 with frequencyPerDay 4
    When the AISP reads the balances with PSU-IP-Address 192.168.8.78
    Then the response is 200

  # Rule R-FRQ-03: The count is kept per account

  @MVP-01 @R-FRQ-03
  Scenario: Exhausting one account leaves the other readable
    Given a valid consent with frequencyPerDay 4 on DE40100100103307118608 and DE02100100109307118603
    And four unattended balance reads of DE40100100103307118608 today
    When the AISP reads the balances of DE02100100109307118603 without PSU-IP-Address
    Then the response is 200
