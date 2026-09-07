# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/forward-psu-context-headers.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @spec-4.8 @mvp @analysing
Feature: Forward PSU context headers
  As Bank security officer
  I want the TPP to send PSU-IP-Address, PSU-User-Agent, PSU-Device-ID and geo location
  So that the risk engine can assess the session

  @spec-4.8
  Rule: A call made while the PSU's browser request is in flight carries the PSU's context

    @nominal @mvp
    Scenario: Consent creation carries all four headers
      Given Anna's browser request comes from 192.168.8.78 with user agent 'Mozilla/5.0 (Macintosh…) Safari/605.1.15', device cookie 3f1d2c3a-… and the browser reported latitude 52.506931 longitude 13.144558
      When the TPP sends POST /v1/consents
      Then PSU-IP-Address is 192.168.8.78, PSU-User-Agent is the browser's user agent, PSU-Device-ID is 3f1d2c3a-…, PSU-Geo-Location is GEO:52.506931;13.144558

    @nominal @mvp
    Scenario: The account list requested by Anna carries the headers
      Given Anna clicks 'View accounts'
      When the TPP sends GET /v1/accounts
      Then PSU-IP-Address is Anna's address

    @edge @mvp
    Scenario: Without geolocation permission the header is omitted
      Given Anna denied the geolocation prompt
      When the TPP sends POST /v1/consents
      Then PSU-Geo-Location is absent and the other three headers are present

    @edge @mvp
    Scenario: An IPv6 address is forwarded as is
      Given Anna's browser request comes from 2001:db8::1
      When the TPP sends the call
      Then PSU-IP-Address is 2001:db8::1

  Rule: The address is the PSU's, not a proxy's

    @nominal @mvp
    Scenario: Behind the TPP's load balancer the first X-Forwarded-For hop is used
      Given the request reaches the TPP with X-Forwarded-For '192.168.8.78, 10.0.0.5' from the trusted load balancer 10.0.0.5
      When the TPP sends the call
      Then PSU-IP-Address is 192.168.8.78

    @error @mvp
    Scenario: An X-Forwarded-For from an untrusted peer is ignored
      Given a request to the TPP directly from 203.0.113.9 with X-Forwarded-For '1.2.3.4'
      When the TPP sends the call
      Then PSU-IP-Address is 203.0.113.9

  @spec-6
  Rule: A background call sends no PSU header at all, so the Bank counts it

    @nominal @mvp
    Scenario: The nightly refresh has no PSU headers
      Given the scheduler refreshes Anna's accounts at 03:00
      When the TPP sends GET /v1/accounts
      Then none of PSU-IP-Address, PSU-User-Agent, PSU-Device-ID, PSU-Geo-Location is present

    @error @mvp
    Scenario: A cached address is never replayed on a background call
      Given the TPP stored Anna's last address 192.168.8.78 from the morning
      When the scheduler calls at 03:00
      Then PSU-IP-Address is absent

    @edge @mvp
    Scenario: A PSU click after a background call is again marked present
      Given the 03:00 background call was counted
      When Anna opens the account list at 08:00
      Then the call carries PSU-IP-Address and is not counted

  Rule: Header values are well-formed

    @nominal @mvp
    Scenario: Geo location is formatted GEO:lat;lon with a dot decimal separator
      Given latitude 52.506931 and longitude 13.144558
      When the header is built
      Then PSU-Geo-Location is exactly GEO:52.506931;13.144558

    @edge @mvp
    Scenario: A user agent longer than the bank accepts is truncated, not dropped
      Given a user agent of 600 characters
      When the header is built
      Then PSU-User-Agent has 512 characters

    @nominal @mvp
    Scenario: PSU-Device-ID is a UUID v4 stored in a first-party cookie for one year
      Given Anna's first visit
      When the TPP sets the device cookie
      Then its value is a UUID v4 and it is sent as PSU-Device-ID on later calls
