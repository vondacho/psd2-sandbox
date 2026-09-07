# Generated from docs/design/examplemap/8-approve-the-payment-at-the-bank/cover-amount-and-payee-in-the-dynamic-link.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-ciam @sca @rts-art-5 @pis-core @ready
Feature: Cover amount and payee in the dynamic link
  As Bank security officer
  I want the challenge hash to cover paymentId, payee, amount and debtor account
  So that an approval cannot be replayed for another payment

  @rts-art-5
  Rule: The dynamic-link hash of a payment covers the payment id, the TPP, the amount, the payee and the debtor account

    @nominal @pis-core
    Scenario: The canonical string of pay001
      Given pay001, TPP PSDDE-BAFIN-123456, 12.50 EUR, creditor DE12500105170648489890, debtor DE23100100100123456789
      When the challenge is created
      Then the canonical string is 'pay001|PSDDE-BAFIN-123456|12.50 EUR|DE12500105170648489890|DE23100100100123456789'
      And the hash is its SHA-256, hex-encoded, and is called P1

    @nominal @pis-core
    Scenario: A different amount changes the hash
      Given the same payment with 12.51 EUR
      When the challenge is created
      Then the hash differs from P1

    @nominal @pis-core
    Scenario: A different payee changes the hash
      Given the same payment to another creditor IBAN
      When the challenge is created
      Then the hash differs from P1

    @nominal @pis-core
    Scenario: A different debtor account changes the hash
      Given the same payment from Savings
      When the challenge is created
      Then the hash differs from P1

    @edge @pis-core
    Scenario: The same payment always gives the same hash
      Given two challenges for pay001 after an expiry
      When their hashes are compared
      Then they are equal, while their nonces differ

  @rts-art-5
  Rule: What the device shows is what the hash covers

    @nominal @pis-core
    Scenario: The approval screen shows amount, payee and account
      Given the challenge for pay001
      When the app loads it
      Then the screen shows 'Pay EUR 12.50 to Payee X from Main Account' and the TPP name

    @nominal @pis-core
    Scenario: The summary stored with the challenge matches the screen
      Given the challenge's dynamic link
      When its summary is read
      Then it is 'TPP App: pay EUR 12.50 to Payee X from DE23 …7 89'

    @nominal @pis-core
    Scenario: A payment challenge is not an account-consent challenge
      Given the challenge for pay001
      When its subject is read
      Then the subject kind is PIS_PAYMENT and the subject id is pay001

  @security
  Rule: An approval of one payment cannot approve another

    @error @pis-core
    Scenario: A signature over another payment's hash is refused
      Given a valid device signature over the hash of pay002
      When it is posted for the challenge of pay001
      Then the SCA engine answers 400 'signature does not match challenge'
      And pay001 stays RCVD

    @error @pis-core
    Scenario: A signature over an account consent's hash is refused
      Given a valid signature over H1, the hash of consent 123cons456
      When it is posted for the payment challenge
      Then the answer is 400 and nothing is approved

    @edge @pis-core
    Scenario: Changing the payment after the challenge invalidates it
      Given a pending challenge for pay001
      When the payment amount is changed by any path
      Then the challenge is expired and a new one must be issued
