# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/app-to-app-redirect-on-a-mobile-browser.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @bank-app @spec-4.8 @hardening @analysing
Feature: App-to-app redirect on a mobile browser
  As PSU
  I want the Bank to open its app directly when I am already on my phone
  So that I do not scan a QR on the same screen

  @spec-4.8
  Rule: On a mobile browser the QR page offers to open the Bank app with a link that carries the challenge id only

    @nominal @hardening
    Scenario: iOS Safari shows the button
      Given the QR page is opened from an iPhone (user agent contains 'iPhone')
      When the page renders
      Then it shows 'Open the Bank app' above the QR
      And the button links to https://app.bank.sandbox/sca/chl-01J8 (a universal link)

    @nominal @hardening
    Scenario: Android Chrome shows the button
      Given the QR page is opened from an Android phone
      When the page renders
      Then it shows 'Open the Bank app' linking to https://app.bank.sandbox/sca/chl-01J8

    @nominal @hardening
    Scenario: A desktop browser shows no button
      Given the QR page is opened from macOS Safari
      When the page renders
      Then only the QR is shown

    @nominal @hardening
    Scenario: The link contains no hash, nonce or account data
      Given the universal link
      When it is inspected
      Then its only variable part is the challenge id

  Rule: If the app is not installed, the link falls back to a web page that explains and shows the QR again

    @edge @hardening
    Scenario: No app installed
      Given an iPhone without the Bank app
      When Anna taps 'Open the Bank app'
      Then Safari opens https://app.bank.sandbox/sca/chl-01J8 as a web page saying 'Install the Bank app or scan this code with a registered device' with the QR

    @edge @hardening
    Scenario: App installed but not enrolled on this phone
      Given the app is installed but this phone is not a registered device
      When the app opens with chl-01J8
      Then it shows 'This phone is not registered. Activate it first or approve on your registered device.'

  Rule: The app loads the challenge over the authenticated channel, and the browser tab continues by polling

    @nominal @hardening
    Scenario: Approval in the app moves the browser tab on
      Given the app opened chl-01J8 from the link and Anna approved with Face ID
      When she switches back to Safari
      Then the tab, which kept polling, has redirected to the OIDC-provider and on to TPP App

    @nominal @hardening
    Scenario: The app fetches details, never trusts the link
      Given the app opened with challenge id chl-01J8
      When it loads the approval screen
      Then the details come from GET /sca/challenges/chl-01J8 over the device-authenticated channel

    @error @hardening
    Scenario: A link with a foreign challenge id is refused by the app
      Given Anna's phone opens https://app.bank.sandbox/sca/chl-of-ben
      When the app fetches it
      Then the SCA engine answers 403 and the app shows 'This code is not for this device'
