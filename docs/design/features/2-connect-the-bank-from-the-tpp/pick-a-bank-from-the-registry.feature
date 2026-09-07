# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/pick-a-bank-from-the-registry.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @walking-skeleton @analysing
Feature: Pick a bank from the registry
  As PSU
  I want to choose the Bank from a list of registered banks
  So that the TPP knows which XS2A API and authorization server to talk to

  Rule: The picker lists every registry entry, sorted by display name

    @nominal @walking-skeleton
    Scenario: Two registered banks are listed in alphabetical order
      Given the registry holds bank-c 'Bank C' and bank 'Bank'
      And Anna is signed in to the TPP
      When she opens 'Add a bank'
      Then the picker shows 'Bank' then 'Bank C'

    @edge @mvp
    Scenario: An empty registry shows an explanation instead of a list
      Given the registry holds no entry
      When Anna opens 'Add a bank'
      Then the picker shows 'No banks are available yet'
      And no bank can be selected

    @edge @mvp
    Scenario: A bank whose consent models the TPP does not support is shown but not selectable
      Given bank-d supports only the consent model dedicated
      When Anna opens 'Add a bank'
      Then 'Bank D' is listed greyed out with 'not supported yet'

  Rule: Selecting a bank creates or reuses the one connection the TPP keeps per user and bank

    @nominal @walking-skeleton
    Scenario: First selection creates a connection in state selected
      Given Anna has no connection to the Bank
      When she selects 'Bank' and clicks 'Connect'
      Then a BankConnection (anna, bank) exists in state selected
      And the consent request to the Bank starts

    @edge @mvp
    Scenario: Selecting an already connected bank opens its accounts instead of a new consent
      Given Anna's connection to the Bank is connected until 2026-12-05
      When she selects 'Bank' in the picker
      Then the TPP opens the account list of the Bank
      And no new consent is created

    @edge @mvp
    Scenario: Selecting a bank that needs re-consent starts a new consent on the same connection
      Given Anna's connection to the Bank is in state needsReconsent
      When she selects 'Bank'
      Then a new consent request starts
      And the same BankConnection is reused, no second connection appears

    @edge @mvp
    Scenario: Selecting a bank while a connection attempt is pending resumes it
      Given Anna's connection to the Bank is in state authorizing since two minutes
      When she selects 'Bank' again
      Then the TPP offers 'Continue at the Bank' and 'Start over'

    @nominal @walking-skeleton
    Scenario: Ben selecting the Bank does not touch Anna's connection
      Given Anna is connected to the Bank
      When Ben selects 'Bank'
      Then a connection (ben, bank) is created
      And Anna's connection is unchanged

  Rule: The selected entry fixes every URL used for that connection

    @nominal @walking-skeleton
    Scenario: The Bank's XS2A base URL is used for the consent request
      Given the entry bank has xs2aBaseUrl https://api.bank.sandbox/psd2
      When Anna selects the Bank
      Then the TPP sends POST https://api.bank.sandbox/psd2/v1/consents

    @nominal @walking-skeleton
    Scenario: Bank C's URLs are used for Bank C
      Given bank-c has xs2aBaseUrl https://api.bank-c.sandbox/psd2
      When Anna selects Bank C
      Then the TPP sends POST https://api.bank-c.sandbox/psd2/v1/consents

    @error @walking-skeleton
    Scenario: A bank id that is not in the registry is refused
      Given the registry has no entry bank-z
      When a request POST /banks/bank-z/connect arrives
      Then the TPP answers 404
      And no connection is created
