# Generated from docs/design/examplemap/5-view-my-accounts/tokenise-account-identifiers.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-4.11.2 @walking-skeleton @ready
Feature: Tokenise account identifiers
  As Bank security officer
  I want opaque resourceIds in paths instead of IBANs
  So that account numbers never appear in URLs or logs

  @spec-6.5.2
  Rule: A resourceId is a random UUID assigned per consent, IBAN and currency at authorisation, and stable for the life of the consent

    @nominal @walking-skeleton
    Scenario: The same id on two calls
      Given consent 123cons456 with Main Account
      When the TPP calls GET /v1/accounts twice
      Then Main Account has resourceId 3dc3d5b3-7023-4848-9853-f5400a64e80f both times

    @nominal @walking-skeleton
    Scenario: The id is a UUID v4
      Given any resourceId
      When it is inspected
      Then it matches the UUID v4 format and its 122 random bits are not derived from the IBAN

    @edge @mvp
    Scenario: The same IBAN under a new consent gets a new id
      Given Main Account under 123cons456 has id 3dc3d5b3-…
      When Anna reconnects with consent 123cons999
      Then Main Account has a different resourceId under 123cons999

    @edge @mvp
    Scenario: The same IBAN under C's consent gets another id
      Given Anna shared Main Account with C under 333cons444
      When C calls GET /v1/accounts
      Then Main Account's resourceId differs from the one the TPP sees

    @edge @mvp
    Scenario: Two currencies of one IBAN get two ids
      Given the multicurrency account with EUR and USD
      When the ids are assigned
      Then EUR and USD sub-accounts have different resourceIds

  @spec-4.11.2
  Rule: Paths never accept an IBAN, PAN or BBAN

    @error @walking-skeleton
    Scenario: An IBAN in the path
      Given the TPP's valid token and consent
      When GET /v1/accounts/DE23100100100123456789 is called
      Then the answer is 404 RESOURCE_UNKNOWN

    @error @mvp
    Scenario: A masked PAN in the path
      Given the same
      When GET /v1/accounts/1234XXXXXXXX5678 is called
      Then the answer is 404 RESOURCE_UNKNOWN

    @error @walking-skeleton
    Scenario: A resourceId of another consent
      Given resourceId 9e9e… belongs to consent 111cons222
      When GET /v1/accounts/9e9e… is called with Consent-ID 123cons456
      Then the answer is 401 CONSENT_INVALID

  Rule: Logs and audit trails carry resourceIds, never IBANs from URLs

    @nominal @walking-skeleton
    Scenario: The gateway access log
      Given a call to GET /v1/accounts/3dc3d5b3-…/balances
      When the access log is read
      Then the path is logged as is and contains no IBAN

    @edge @mvp
    Scenario: A refused IBAN path is logged masked
      Given a call to GET /v1/accounts/DE23100100100123456789
      When the access log is read
      Then the path is logged as /v1/accounts/[masked]

    @nominal @walking-skeleton
    Scenario: The mapping table is inside consent management only
      Given the resourceId to IBAN mapping
      When the components that can read it are listed
      Then only consent management and the account information service can, never the gateway log or the OIDC-provider
