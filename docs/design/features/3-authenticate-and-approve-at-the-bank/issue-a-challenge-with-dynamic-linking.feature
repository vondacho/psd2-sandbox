# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/issue-a-challenge-with-dynamic-linking.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @sca @rts-art-5 @walking-skeleton @analysing
Feature: Issue a challenge with dynamic linking
  As Bank security officer
  I want the challenge hash to cover consentId, TPP, accounts and validity
  So that an approval cannot be replayed for a different consent

  @rts-art-5
  Rule: The dynamic-link hash is SHA-256 over the canonical string consentId|tppId|sorted IBAN+currency list|validUntil

    @nominal @walking-skeleton
    Scenario: The hash for Main Account until 2026-12-05
      Given consent 123cons456, tppId PSDDE-BAFIN-123456, selection [DE23100100100123456789 EUR], validUntil 2026-12-05
      When the challenge is created
      Then the canonical string is '123cons456|PSDDE-BAFIN-123456|DE23100100100123456789:EUR|2026-12-05'
      And the hash is the SHA-256 of that string, hex-encoded, 64 characters

    @nominal @walking-skeleton
    Scenario: The same inputs always give the same hash
      Given two challenges created for the same consent and the same selection
      When their hashes are compared
      Then they are equal

    @nominal @walking-skeleton
    Scenario: A different account changes the hash
      Given challenge H1 for Main Account
      When a challenge is created for Savings instead
      Then its hash differs from H1

    @nominal @walking-skeleton
    Scenario: A different validity changes the hash
      Given challenge H1 until 2026-12-05
      When a challenge is created until 2026-12-06
      Then its hash differs from H1

    @nominal @walking-skeleton
    Scenario: A different consent id changes the hash even for the same accounts
      Given challenge H1 for 123cons456
      When a challenge is created for 111cons222 with the same selection and validity
      Then its hash differs from H1

    @edge @mvp
    Scenario: The order of selected accounts does not matter
      Given selection [Savings, Main Account]
      When the challenge is created
      Then the canonical list is sorted and the hash equals the one for [Main Account, Savings]

    @edge @mvp
    Scenario: Two currencies of one IBAN are two list entries
      Given selection of the multicurrency account with EUR and USD
      When the canonical string is built
      Then it contains 'DE11…:EUR,DE11…:USD'

  Rule: A challenge is created with an id, a 128-bit nonce, the PSU, the subject and a three-minute expiry, in status pending

    @nominal @walking-skeleton
    Scenario: The challenge record
      Given Anna approved the summary at 2026-09-06T09:12:00Z
      When the challenge is created
      Then it has id chl-01J8…, psuId anna.mueller, subject AIS_CONSENT 123cons456, a 22-character base64url nonce, createdAt 09:12:00Z, expiresAt 09:15:00Z, status pending

    @nominal @walking-skeleton
    Scenario: Two challenges never share a nonce
      Given 1000 challenges
      When their nonces are compared
      Then all are distinct

    @nominal @walking-skeleton
    Scenario: The dynamic link record keeps a human summary
      Given the challenge for Main Account
      When its dynamicLink is read
      Then tppName is 'TPP App (TPP Fintech GmbH)' and summary is 'accounts and balances of DE23 …7 89 until 2026-12-05'

  @rts-art-5
  Rule: A challenge is issued only after the accounts were selected, and only one is pending per session

    @error @walking-skeleton
    Scenario: No challenge before selection
      Given a session in step firstFactorVerified
      When the SCA engine is asked to create a challenge for it
      Then it refuses with 'accounts not selected'

    @edge @mvp
    Scenario: A second challenge supersedes the first
      Given chl-01 is pending for session sess-1
      When a new challenge chl-02 is created for sess-1
      Then chl-01 is expired and chl-02 is pending

    @nominal @walking-skeleton
    Scenario: The authorisation moves to started
      Given the challenge was created
      When the TPP reads the scaStatus of 123auth567
      Then the answer is started

  @security
  Rule: A signature over any other hash is not an approval of this challenge

    @error @walking-skeleton
    Scenario: A signature over the hash of another consent is refused
      Given chl-01 for 123cons456 with hash H1, and a valid device signature over H2 (hash of 111cons222)
      When the signature is posted for chl-01
      Then the SCA engine answers 400 'signature does not match challenge'
      And chl-01 stays pending

    @error @mvp
    Scenario: A signature over the hash alone, without the nonce, is refused
      Given a device signature over H1 only
      When it is posted for chl-01
      Then the SCA engine answers 400
