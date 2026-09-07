# Generated from docs/design/examplemap/4-complete-the-connection/store-tokens-encrypted.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@tpp @security @mvp @analysing
Feature: Store tokens encrypted
  As TPP operator
  I want tokens encrypted at rest and keyed by PSU, bank and consent
  So that a database leak does not expose bank access

  Rule: Tokens are encrypted with a KMS-managed key (AES-256-GCM, envelope) and stored under (user, bank, consent)

    @nominal @mvp
    Scenario: A stored token set
      Given the token response for anna, bank, 123cons456
      When the TPP stores it
      Then the vault row has key (anna, bank, 123cons456), a ciphertext, a wrapped data key, the KMS key id kms-tokens-1 and accessExpiresAt
      And the row contains neither 'eyJ' nor the refresh token in clear

    @nominal @mvp
    Scenario: A database dump shows ciphertext only
      Given the vault table
      When it is dumped with pg_dump
      Then no line contains an access or refresh token in clear

    @nominal @mvp
    Scenario: Reading through the vault returns the tokens
      Given the stored row
      When the XS2A client asks the vault for (anna, bank, 123cons456)
      Then it receives the access token and the refresh token in clear, in memory only

    @error @mvp
    Scenario: A tampered ciphertext is refused
      Given one byte of the ciphertext flipped in the database
      When the vault reads the row
      Then decryption fails with an integrity error and the connection is marked needsReconsent

  @security
  Rule: Tokens never appear in logs, sessions, cookies or error messages

    @nominal @mvp
    Scenario: Logs redact tokens
      Given a debug log of an XS2A call
      When the log line is inspected
      Then the Authorization header reads 'Bearer [redacted]'

    @edge @mvp
    Scenario: An exception message does not carry the token
      Given the OIDC-provider answers 500 during a refresh
      When the error is logged
      Then the log holds the status and the request id, not the refresh token

    @nominal @mvp
    Scenario: The browser session holds a vault reference only
      Given Anna's session at the TPP
      When the session store is inspected
      Then it holds no token, only connection ids

  Rule: One token set per connection; a new set replaces the old and the old refresh token is revoked at the OIDC-provider

    @nominal @mvp
    Scenario: A reconnect replaces the set
      Given the vault holds R1 for (anna, bank, 111cons222)
      When the reconnect stores R2 for (anna, bank, 123cons456)
      Then the row for 111cons222 is deleted and the TPP calls POST https://oidc-provider.sandbox/revoke with R1

    @nominal @mvp
    Scenario: A refresh updates the set in place
      Given the vault holds R1
      When a refresh returns R2
      Then the row holds R2 and R1 is gone

  Rule: Tokens are deleted when the consent ends, and the KMS being down fails closed

    @nominal @mvp
    Scenario: CONSENT_EXPIRED deletes the set
      Given the Bank answered 401 CONSENT_EXPIRED
      When the TPP processes it
      Then the vault row for (anna, bank, 123cons456) is deleted

    @nominal @mvp
    Scenario: Disconnect deletes the set
      Given Anna disconnects the Bank
      When the TPP processes it
      Then the vault row is deleted

    @error @mvp
    Scenario: KMS unavailable
      Given the KMS answers 503
      When the vault is asked to store a token set
      Then the store fails with 503 and nothing is written in clear
      And Anna sees 'Please try again in a moment'

    @edge @mvp
    Scenario: Key rotation re-encrypts lazily
      Given the KMS key rotated to kms-tokens-2
      When a row encrypted under kms-tokens-1 is read
      Then it decrypts, and on the next write it is stored under kms-tokens-2
