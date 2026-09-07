# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/record-the-approved-authorisation.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-14.16 @walking-skeleton @ready
Feature: Record the approved authorisation
  As Bank product owner
  I want the accessible accounts stored and the authorisation set to unconfirmed or finalised
  So that the XS2A API can serve exactly the approved accounts

  @spec-14.16
  Rule: On an approved challenge, consent management records the PSU, the accessible accounts with their access types, and the authorisation status according to the confirmation setting

    @nominal @walking-skeleton
    Scenario: With a confirmation link: unconfirmed and received
      Given consent 123cons456 (accounts, balances requested) with confirmationRequired true, and the outcome {challengeId chl-01J8, psuId anna.mueller, accounts [DE23100100100123456789 EUR]}
      When the CIAM posts the outcome
      Then the consent has psuId anna.mueller and one accessible account DE23… EUR with access types accounts, balances
      And authorisation 123auth567 is unconfirmed and the consent status is received

    @nominal @walking-skeleton
    Scenario: Without a confirmation link: finalised and valid
      Given the same consent with confirmationRequired false
      When the CIAM posts the outcome
      Then authorisation 123auth567 is finalised, finalisedAt set, and the consent status is valid

    @nominal @walking-skeleton
    Scenario: Two accounts are two accessible accounts
      Given the outcome with accounts [DE23… EUR, DE89… EUR]
      When it is recorded
      Then the consent has two accessible accounts

    @nominal @walking-skeleton
    Scenario: Each accessible account gets a fresh opaque resourceId
      Given the outcome with one account
      When it is recorded
      Then the accessible account has a resourceId that is a UUID v4 and is not derived from the IBAN

    @nominal @mvp
    Scenario: lastActionDate is today
      Given the outcome recorded on 2026-09-06
      When GET /v1/consents/123cons456 is read
      Then lastActionDate is 2026-09-06

  @spec-6.3.1.2
  Rule: Access types recorded never exceed the access requested

    @nominal @walking-skeleton
    Scenario: Transactions are not recorded for an accounts+balances request
      Given the consent requested accounts and balances
      When the outcome is recorded
      Then no accessible account has the access type transactions

    @edge @mvp
    Scenario: An outcome that claims transactions is trimmed
      Given an outcome with accessTypes [accounts, balances, transactions] for an accounts+balances consent
      When it is recorded
      Then the accessible account has accounts, balances only and a warning is logged

    @edge @mvp
    Scenario: An accounts-only request records accounts only
      Given a consent that requested access {accounts: []} only
      When the outcome is recorded
      Then the accessible account has the access type accounts only

  @security
  Rule: The outcome is accepted only for a challenge that is approved and belongs to this authorisation, and is idempotent

    @edge @mvp
    Scenario: A duplicate outcome changes nothing
      Given the outcome for chl-01J8 was recorded
      When the same outcome is posted again
      Then the answer is 200 and the consent is unchanged, still one accessible account

    @error @mvp
    Scenario: An outcome for a pending challenge is refused
      Given chl-01J8 is pending
      When an outcome for it is posted
      Then consent management answers 409 'challenge not approved'
      And the consent is unchanged

    @error @mvp
    Scenario: An outcome for a challenge of another consent is refused
      Given chl-77 belongs to consent 111cons222
      When an outcome for chl-77 is posted to 123cons456
      Then consent management answers 409

    @error @mvp
    Scenario: An outcome for a rejected consent is refused
      Given consent 123cons456 is rejected
      When an outcome is posted
      Then consent management answers 409 'consent not received'

    @error @mvp
    Scenario: An outcome with accounts that are not the PSU's is refused
      Given an outcome listing DE75… (Ben's) for anna.mueller
      When it is posted
      Then consent management answers 400 'account not owned by PSU'
