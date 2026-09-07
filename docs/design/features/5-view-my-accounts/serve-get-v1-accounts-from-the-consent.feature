# Generated from docs/design/examplemap/5-view-my-accounts/serve-get-v1-accounts-from-the-consent.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-6.5.1 @walking-skeleton @ready
Feature: Serve GET /v1/accounts from the consent
  As PSU
  I want the TPP to show the accounts I selected at the Bank
  So that I see my accounts inside the TPP

  @spec-6.5.1
  Rule: The list contains exactly the accessible accounts of the consent named by Consent-ID, with resourceId, identifiers, product data and links

    @nominal @walking-skeleton
    Scenario: Two selected accounts
      Given consent 123cons456 valid with Main Account and Savings, the TPP's token, Consent-ID 123cons456, X-Request-ID, PSU-IP-Address
      When the TPP calls GET /v1/accounts
      Then the answer is 200 {accounts: [{resourceId: 3dc3d5b3-…, iban: DE23100100100123456789, currency: EUR, name: Main Account, product: Girokonto, cashAccountType: CACC, _links: {balances: …}}, {resourceId: 7a1f…, iban: DE89370400440532013000, currency: EUR, name: Savings, product: Sparkonto, cashAccountType: SVGS, _links: {balances: …}}]}

    @nominal @walking-skeleton
    Scenario: One selected account: the other is absent
      Given consent 123cons456 with Main Account only
      When the TPP calls GET /v1/accounts
      Then the list holds one entry, and DE89… is absent although Anna owns it

    @nominal @walking-skeleton
    Scenario: No balances without withBalance
      Given the call without withBalance
      When the answer is inspected
      Then no entry has a balances field

    @edge @mvp
    Scenario: An account closed at the bank since the consent
      Given Savings was closed in the ledger yesterday
      When the TPP calls GET /v1/accounts
      Then the Savings entry is present with status deleted and no balances link

    @edge @mvp
    Scenario: A multicurrency account lists its sub-accounts
      Given the multicurrency account with EUR and USD in the consent
      When the TPP calls GET /v1/accounts
      Then two entries share the IBAN with currencies EUR and USD, each with its own resourceId

    @nominal @walking-skeleton
    Scenario: X-Request-ID is echoed
      Given X-Request-ID 6b2d…
      When the answer arrives
      Then its X-Request-ID header is 6b2d…

  @spec-14.11
  Rule: Consent-ID is mandatory and must name a valid consent of the calling TPP

    @error @walking-skeleton
    Scenario: Missing Consent-ID
      Given no Consent-ID header
      When the TPP calls GET /v1/accounts
      Then the answer is 400 FORMAT_ERROR with path Consent-ID

    @error @mvp
    Scenario: Unknown Consent-ID
      Given Consent-ID 999cons000 and a token for it (impossible; a token for another consent is used)
      When the TPP calls GET /v1/accounts
      Then the answer is 401 TOKEN_INVALID because the token scope does not match

    @error @walking-skeleton
    Scenario: Consent received, not yet valid
      Given consent 123cons456 received
      When the TPP calls with a token for it
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Consent expired
      Given consent 123cons456 expired
      When the TPP calls
      Then the answer is 401 CONSENT_EXPIRED

    @error @mvp
    Scenario: Consent revoked
      Given consent 123cons456 revokedByPsu
      When the TPP calls
      Then the answer is 401 CONSENT_INVALID

    @error @mvp
    Scenario: Consent terminated by the TPP
      Given consent 123cons456 terminatedByTpp
      When the TPP calls
      Then the answer is 401 CONSENT_INVALID

  @security
  Rule: The list is served only to the TPP that created the consent

    @error @mvp
    Scenario: C with its own token and the TPP's consent id
      Given C's QWAC, C's token for 333cons444, Consent-ID 123cons456
      When C calls GET /v1/accounts
      Then the answer is 401 TOKEN_INVALID

    @error @mvp
    Scenario: C with the TPP's token
      Given C's QWAC and the TPP's token
      When C calls
      Then the answer is 401 TOKEN_INVALID (certificate binding)

  Rule: The list reflects the ledger at call time, filtered by the consent

    @edge @mvp
    Scenario: A renamed account shows its new name
      Given Anna renamed Main Account to Haushalt in online banking
      When the TPP calls GET /v1/accounts
      Then the entry's name is Haushalt and its resourceId is unchanged

    @edge @mvp
    Scenario: A new account opened after the consent is not listed
      Given Anna opened a third account yesterday
      When the TPP calls GET /v1/accounts
      Then the list still holds the two consented accounts
