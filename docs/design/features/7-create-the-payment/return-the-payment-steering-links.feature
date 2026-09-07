# Generated from docs/design/examplemap/7-create-the-payment/return-the-payment-steering-links.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-4.15 @spec-5.1.5 @pis-core @ready
Feature: Return the payment steering links
  As TPP operator
  I want scaOAuth, scaStatus, self and status links with the SCA approach header
  So that the client never guesses a payment URL

  @spec-5.1.5
  Rule: The 201 carries the links that fit the OAuth2 approach with an implicit authorisation

    @nominal @pis-core
    Scenario: The links of a freshly created payment
      Given pay001 created with the OAuth2 approach
      When the answer is inspected
      Then _links holds self /psd2/v1/payments/sepa-credit-transfers/pay001, status …/status, scaStatus …/authorisations/pay001auth1 and scaOAuth https://oidc-provider.sandbox/.well-known/oauth-authorization-server

    @edge @pis-core
    Scenario: The confirmation link appears when the Bank requires confirmation
      Given the sandbox runs with confirmationRequired true
      When the payment is created
      Then _links also holds confirmation, equal to the scaStatus href

    @nominal @pis-core
    Scenario: The header announces the approach
      Given the created payment
      When the response headers are read
      Then ASPSP-SCA-Approach is REDIRECT

    @nominal @pis-core
    Scenario: Every href is a path under the API base
      Given the links
      When they are inspected
      Then each starts with /psd2/v1/ except scaOAuth, which is an absolute https URL

    @nominal @pis-core
    Scenario: No link carries an IBAN or a PSU identifier
      Given the links
      When they are inspected
      Then they hold the payment id and the authorisation id only

  @spec-4.15
  Rule: The links follow the state: what cannot be done next is not linked

    @edge @pis-core
    Scenario: An explicit start offers startAuthorisation instead of scaStatus
      Given TPP-Explicit-Authorisation-Preferred: true
      When the payment is created
      Then _links holds startAuthorisation and no scaStatus

    @edge @pis-core
    Scenario: A finalised authorisation no longer offers confirmation
      Given the authorisation is finalised
      When the payment is read
      Then _links holds self and status, and no confirmation

    @edge @pis-core
    Scenario: A rejected payment offers status only
      Given pay001 was rejected on validation of the debtor account
      When the payment is read
      Then _links holds self and status

  Rule: The steering links are stable for the life of the payment

    @nominal @pis-core
    Scenario: The self link resolves to the payment
      Given the self link of pay001
      When it is followed with the TPP's certificate
      Then the answer is 200 with the payment

    @nominal @pis-core
    Scenario: The status link resolves to the transaction status
      Given the status link
      When it is followed
      Then the answer is {transactionStatus: RCVD}

    @edge @pis-core
    Scenario: The links do not change after authorisation
      Given the payment before and after the SCA
      When the self and status hrefs are compared
      Then they are identical
