# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/see-what-i-am-approving.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-app @rts-art-5 @walking-skeleton @analysing
Feature: See what I am approving
  As PSU
  I want the TPP, the accounts and the validity shown on my phone before I approve
  So that I cannot be tricked into approving something else

  @rts-art-5
  Rule: The approval screen shows the TPP, the access, every account, the validity, the frequency and the time left

    @nominal @walking-skeleton
    Scenario: The screen for the TPP's consent on Main Account
      Given chl-01J8: TPP App (TPP Fintech GmbH), accounts and balances, Main Account DE23 …7 89 EUR, until 2026-12-05, 4 times a day, 2:40 left
      When the approval screen renders
      Then it shows 'TPP App (TPP Fintech GmbH) wants to read', 'the list of your accounts and their balances', 'Main Account, DE23 1001 0010 0123 4567 89, EUR', 'until 5 Dec 2026', 'up to 4 times a day without you' and 'expires in 2:40'

    @edge @mvp
    Scenario: Six accounts are all listed, none hidden
      Given a challenge for six accounts
      When the screen renders
      Then six rows are listed in a scrollable area and the approve button sits below the last

    @edge @mvp
    Scenario: A one-off consent says once
      Given a challenge for a one-off consent
      When the screen renders
      Then it says 'one time only, today'

    @edge @hardening
    Scenario: A payment challenge shows the amount and the payee
      Given a challenge of kind PIS_PAYMENT: 12.50 EUR to Payee X from Main Account
      When the screen renders
      Then it shows 'Pay 12.50 EUR to Payee X from Main Account'

  @security
  Rule: Approve is available only once the server details are loaded and consistent

    @nominal @walking-skeleton
    Scenario: Approve is disabled while loading
      Given the fetch is in flight
      When the screen renders
      Then the approve button is disabled and a spinner is shown

    @error @mvp
    Scenario: A fetch error offers retry, never approve
      Given the fetch answered 503
      When the screen renders
      Then it shows 'the Bank did not answer' and 'Retry', no approve button

    @error @mvp
    Scenario: A tampered QR offers no approve
      Given the QR hash disagrees with the server
      When the screen renders
      Then no approve button is shown

  @rts-art-5
  Rule: What is displayed is exactly what the signature will cover

    @nominal @walking-skeleton
    Scenario: The screen is rendered from the dynamic-link fields
      Given the challenge's dynamicLink {subjectId 123cons456, tppName 'TPP App (TPP Fintech GmbH)', summary, hash H1}
      When the screen renders
      Then every value on screen is a field of the dynamic link or of the server's account list for it

    @edge @mvp
    Scenario: A value not covered by the hash is not shown as part of the approval
      Given the server also returns the TPP's logo URL
      When the screen renders
      Then the logo is shown as decoration and the text says 'Check the name, not the logo'
