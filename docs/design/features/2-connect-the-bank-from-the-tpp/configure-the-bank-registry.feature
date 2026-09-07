# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/configure-the-bank-registry.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @walking-skeleton @analysing
Feature: Configure the bank registry
  As TPP operator
  I want each bank's XS2A base URL, metadata URL and consent model in a config file
  So that adding a bank does not need a code change

  Rule: The registry is a YAML file read at startup; each entry needs id, displayName, xs2aBaseUrl, oauthMetadataUrl and consentModels

    @nominal @walking-skeleton
    Scenario: A file with two complete entries is loaded
      Given banks.yaml with entries bank ('Bank', https://api.bank.sandbox/psd2, https://oidc-provider.sandbox/.well-known/oauth-authorization-server, [bankOffered]) and bank-c
      When the TPP starts
      Then the registry holds two entries
      And the log says 'bank registry: 2 banks loaded'

    @error @walking-skeleton
    Scenario: A missing xs2aBaseUrl stops the start-up and names the entry
      Given entry bank-c has no xs2aBaseUrl
      When the TPP starts
      Then the TPP exits with 'banks.yaml: bank-c: xs2aBaseUrl is required'

    @error @walking-skeleton
    Scenario: A duplicate id stops the start-up
      Given two entries with id bank
      When the TPP starts
      Then the TPP exits with 'banks.yaml: duplicate bank id bank'

    @error @mvp
    Scenario: An unknown consent model stops the start-up
      Given entry bank-c has consentModels [everything]
      When the TPP starts
      Then the TPP exits with 'banks.yaml: bank-c: unknown consent model everything'

    @error @mvp
    Scenario: An entry without consent model stops the start-up
      Given entry bank-c has consentModels []
      When the TPP starts
      Then the TPP exits with 'banks.yaml: bank-c: at least one consent model is required'

    @error @walking-skeleton
    Scenario: A missing file stops the start-up
      Given banks.yaml does not exist
      When the TPP starts
      Then the TPP exits with 'banks.yaml not found'

    @edge @mvp
    Scenario: An empty file is a valid empty registry
      Given banks.yaml contains 'banks: []'
      When the TPP starts
      Then the registry holds no entry and the TPP runs

  @security
  Rule: Every URL in the registry uses https

    @error @walking-skeleton
    Scenario: An http XS2A base URL is refused
      Given entry bank-c has xs2aBaseUrl http://api.bank-c.sandbox/psd2
      When the TPP starts
      Then the TPP exits with 'banks.yaml: bank-c: xs2aBaseUrl must use https'

    @error @walking-skeleton
    Scenario: An http metadata URL is refused
      Given entry bank-c has oauthMetadataUrl http://oidc-provider.sandbox/.well-known/oauth-authorization-server
      When the TPP starts
      Then the TPP exits naming oauthMetadataUrl

    @edge @mvp
    Scenario: A URL with a trailing slash is normalised
      Given entry bank has xs2aBaseUrl https://api.bank.sandbox/psd2/
      When the TPP starts
      Then the entry's base URL is https://api.bank.sandbox/psd2
      And consent requests go to https://api.bank.sandbox/psd2/v1/consents, not to //v1

  Rule: Optional settings have defaults: requiresSignature false, maxValidityDays 180

    @nominal @walking-skeleton
    Scenario: An entry without maxValidityDays gets 180
      Given entry bank has no maxValidityDays
      When the TPP starts
      Then bank.maxValidityDays is 180

    @nominal @walking-skeleton
    Scenario: An explicit maxValidityDays 30 is kept
      Given entry bank-c has maxValidityDays 30
      When the TPP starts
      Then bank-c.maxValidityDays is 30

    @error @mvp
    Scenario: maxValidityDays 0 is refused
      Given entry bank-c has maxValidityDays 0
      When the TPP starts
      Then the TPP exits with 'banks.yaml: bank-c: maxValidityDays must be between 1 and 180'

    @error @mvp
    Scenario: maxValidityDays above 180 is refused
      Given entry bank-c has maxValidityDays 365
      When the TPP starts
      Then the TPP exits naming maxValidityDays

    @nominal @walking-skeleton
    Scenario: requiresSignature defaults to false
      Given entry bank has no requiresSignature
      When the TPP starts
      Then consent requests to the Bank carry no Signature header

  Rule: Adding a bank is a configuration change only

    @nominal @walking-skeleton
    Scenario: A new entry appears in the picker after a restart
      Given the TPP runs with the entry bank only
      When the operator adds bank-c to banks.yaml and restarts the TPP
      Then the picker lists the Bank and Bank C
      And no code was changed

    @edge @mvp
    Scenario: Removing an entry keeps existing connections but hides the bank from the picker
      Given Anna is connected to bank-c
      When the operator removes bank-c and restarts the TPP
      Then Bank C is absent from the picker
      And Anna's connection to bank-c is shown as 'bank no longer supported'
