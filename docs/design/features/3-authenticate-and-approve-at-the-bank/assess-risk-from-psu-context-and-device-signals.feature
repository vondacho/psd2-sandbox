# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/assess-risk-from-psu-context-and-device-signals.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @security @spec-4.8 @hardening @analysing
Feature: Assess risk from PSU context and device signals
  As Bank security officer
  I want the session scored before the second factor is offered
  So that suspicious sessions are refused or stepped up

  @spec-4.8
  Rule: The assessment runs after the first factor and before any challenge, from the forwarded PSU context and the CIAM's own signals

    @nominal @hardening
    Scenario: A known address and device give a low score and the journey continues
      Given PSU-IP-Address 192.168.8.78 seen for anna.mueller last week, PSU-Device-ID seen before, user agent unchanged
      When the first factor is verified
      Then the assessment has score 10 and decision allow
      And the session step is riskAssessed and account selection is shown

    @edge @hardening
    Scenario: Missing context headers raise the score but allow
      Given the TPP forwarded no PSU-IP-Address, PSU-User-Agent or PSU-Device-ID
      When the first factor is verified
      Then the score is 30 with reason 'no PSU context' and the decision is allow

    @edge @hardening
    Scenario: A new country steps up
      Given PSU-IP-Address geolocates to a country Anna has never used
      When the first factor is verified
      Then the decision is step-up
      And the consent validity offered is capped at 30 days and the summary says so

    @error @hardening
    Scenario: A blocklisted address refuses
      Given PSU-IP-Address 203.0.113.66 is on the fraud blocklist
      When the first factor is verified
      Then the decision is refuse
      And the session step is refused, the authorisation is failed, the consent is rejected
      And Anna sees 'the Bank cannot continue this request' with a reference id and a way back to TPP App

    @error @hardening
    Scenario: Ten logins from the same address for ten different customers within a minute refuse
      Given nine sessions from 203.0.113.9 for nine PSUs in the last 60 seconds
      When a tenth session from 203.0.113.9 verifies its first factor
      Then the decision is refuse with reason 'velocity'

    @edge @hardening
    Scenario: A PSU-Geo-Location 8000 km from the last login an hour ago steps up
      Given Anna logged in from Berlin an hour ago and PSU-Geo-Location is GEO:35.6762;139.6503
      When the first factor is verified
      Then the decision is step-up with reason 'impossible travel'

  @rts-art-4
  Rule: A refused session never reaches the second factor

    @nominal @hardening
    Scenario: No challenge is created for a refused session
      Given the decision was refuse
      When the SCA engine is queried for challenges of the session
      Then there is none

    @error @hardening
    Scenario: The QR page cannot be opened by URL after a refusal
      Given the session was refused
      When the browser opens the QR page URL of that session
      Then the CIAM shows the refusal page again

  Rule: Every assessment is recorded on the session with its inputs and is auditable

    @nominal @hardening
    Scenario: The assessment is stored
      Given a session assessed with score 10
      When the session is read
      Then riskAssessment has score 10, psuIpAddress 192.168.8.78, psuUserAgent, psuDeviceId and decision allow

    @nominal @hardening
    Scenario: The audit log links the assessment to the consent and the TPP
      Given a refused session for consent 123cons456
      When the audit log is searched for 123cons456
      Then one entry shows decision refuse, reason, TPP PSDDE-BAFIN-123456 and the session id

    @edge @hardening
    Scenario: Raw addresses are kept 90 days, then pseudonymised
      Given an assessment recorded 91 days ago
      When it is read
      Then psuIpAddress is a salted hash
