# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/log-in-with-psu-id-and-password.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 2 open question(s) in the map are not exported; the scenarios below assume an answer.

@bank-ciam @walking-skeleton @analysing
Feature: Log in with PSU-ID and password
  As PSU
  I want to enter my bank customer id and password on the Bank's page
  So that the Bank knows who is consenting

  @rts-art-4
  Rule: A correct PSU-ID and password verify the first factor and record amr pwd

    @nominal @walking-skeleton
    Scenario: Anna logs in
      Given an authentication session started by the OIDC-provider for consent 123cons456
      And identity anna.mueller is active with the password 'correct-horse-battery'
      When Anna submits PSU-ID anna.mueller and that password
      Then the session step is firstFactorVerified, the session references anna.mueller and amr contains pwd
      And the page moves on to account selection

    @edge @mvp
    Scenario: Leading and trailing spaces in the PSU-ID are ignored
      Given identity anna.mueller
      When Anna submits ' anna.mueller '
      Then the first factor is verified

    @edge @mvp
    Scenario: Spaces inside the password are significant
      Given the password 'correct-horse-battery'
      When Anna submits 'correct-horse-battery '
      Then the login is refused

  @security
  Rule: A failed login says only that the credentials are invalid, counts the failure and locks after five

    @error @walking-skeleton
    Scenario: A wrong password
      Given identity anna.mueller
      When Anna submits the password 'wrong'
      Then the page shows 'Customer id or password is incorrect'
      And the session step stays identified
      And failedTries of the password credential is 1

    @error @walking-skeleton
    Scenario: An unknown PSU-ID gives the same message
      Given no identity nobody.here
      When nobody.here and any password are submitted
      Then the page shows 'Customer id or password is incorrect'
      And the response time is within 50 ms of the wrong-password case

    @error @mvp
    Scenario: The fifth failure locks the credential
      Given four failed tries for anna.mueller
      When a fifth wrong password is submitted
      Then the identity status is locked
      And the page shows 'Your access is locked. Contact the Bank.'

    @edge @mvp
    Scenario: A correct password after four failures resets the counter
      Given four failed tries for anna.mueller
      When the correct password is submitted
      Then the first factor is verified and failedTries is 0

    @error @mvp
    Scenario: A locked identity cannot log in with the correct password
      Given anna.mueller is locked
      When the correct password is submitted
      Then the page shows 'Your access is locked. Contact the Bank.' and the authorisation scaStatus becomes failed

    @error @mvp
    Scenario: A closed identity cannot log in
      Given the identity of a former customer is closed
      When the correct former password is submitted
      Then the page shows 'Customer id or password is incorrect'

  Rule: The login page belongs to a brokered session and shows who is asking

    @nominal @walking-skeleton
    Scenario: The page names the TPP and the purpose
      Given the session for consent 123cons456 created by the TPP (brand 'TPP App')
      When the login page renders
      Then it says 'TPP App asks to access your accounts. Log in to continue.'
      And the address bar shows ciam.bank.sandbox

    @error @mvp
    Scenario: Opening the login URL without a brokered request is refused
      Given no session
      When the browser opens https://ciam.bank.sandbox/login directly
      Then the page shows 'Start from your app' and no form

    @edge @mvp
    Scenario: The session times out after ten minutes of inactivity
      Given the login page was opened at 09:00 and nothing happened
      When Anna submits the form at 09:11
      Then the page shows 'Your session expired, start again from TPP App' with a link to the TPP's nok URI

    @nominal @walking-skeleton
    Scenario: The password is posted over TLS and never appears in a URL or a log
      Given a login
      When the CIAM access log is inspected
      Then the password is absent from URLs and log lines

  @rts-art-4
  Rule: A successful first factor alone grants nothing

    @nominal @walking-skeleton
    Scenario: No ID token exists after the first factor
      Given Anna verified her password
      When the session is inspected
      Then no ID token was issued and the consent is still received

    @edge @mvp
    Scenario: A first factor for the wrong PSU cannot approve a consent pre-bound to another
      Given consent 123cons456 was created with PSU-ID anna.mueller
      When Ben logs in with his own credentials in that session
      Then the page shows 'This request is for another customer' and the authorisation is failed
