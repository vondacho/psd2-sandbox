# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/show-the-tpp-brand-name.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @spec-4.9 @mvp @analysing
Feature: Show the TPP brand name
  As PSU
  I want the name I know the app by, not only its legal name
  So that I recognise who is asking

  @spec-4.9
  Rule: When the consent request carried TPP-Brand-Logging-Information, the brand is shown with the legal name; otherwise the legal name alone

    @nominal @mvp
    Scenario: Brand and legal name
      Given consent 123cons456 created with TPP-Brand-Logging-Information 'TPP App' by TPP Fintech GmbH
      When the login page, the summary and the app's approval screen render
      Then each shows 'TPP App (TPP Fintech GmbH)'

    @edge @mvp
    Scenario: No brand header
      Given a consent created without TPP-Brand-Logging-Information
      When the pages render
      Then each shows 'TPP Fintech GmbH'

    @edge @mvp
    Scenario: A brand equal to the legal name is shown once
      Given TPP-Brand-Logging-Information 'TPP Fintech GmbH'
      When the pages render
      Then each shows 'TPP Fintech GmbH'

    @nominal @mvp
    Scenario: The brand is stored on the consent so every screen agrees
      Given the consent with brand 'TPP App'
      When the consent dashboard lists it a month later
      Then it shows 'TPP App (TPP Fintech GmbH)'

  @security
  Rule: The brand text is untrusted input

    @error @mvp
    Scenario: Markup is shown literally
      Given TPP-Brand-Logging-Information '<script>alert(1)</script>'
      When the summary renders
      Then the text '<script>alert(1)</script>' is visible as text and no script runs

    @error @mvp
    Scenario: An over-long brand is refused at consent creation
      Given TPP-Brand-Logging-Information of 141 characters
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path TPP-Brand-Logging-Information

    @edge @mvp
    Scenario: Control characters are stripped
      Given TPP-Brand-Logging-Information 'ApptA'
      When the summary renders
      Then it shows 'TPP App'

    @nominal @mvp
    Scenario: A brand cannot hide the legal name
      Given TPP-Brand-Logging-Information 'the Bank'
      When the summary renders
      Then it shows 'the Bank (TPP Fintech GmbH)' and a note 'a third-party app, not the Bank'

  Rule: The legal name comes from the certificate, never from the request

    @nominal @mvp
    Scenario: The legal name is the O of the QWAC
      Given the TPP's QWAC with O 'TPP Fintech GmbH'
      When the consent is created
      Then the stored legal name is 'TPP Fintech GmbH'

    @error @mvp
    Scenario: A request cannot override the legal name
      Given a request with a body field tppName 'the Bank Official'
      When the consent is created
      Then the field is ignored and the legal name is still 'TPP Fintech GmbH'
