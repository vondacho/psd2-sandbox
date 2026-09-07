# Generated from docs/design/examplemap/4-complete-the-connection/validate-the-callback-state.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@tpp @security @spec-7.6.3 @walking-skeleton @ready
Feature: Validate the callback state
  As TPP operator
  I want the TPP to abort when the returned state does not match the session
  So that a fixated session never receives a token

  @spec-7.6.3
  Rule: The callback is accepted only if its state names a pending, unexpired attempt bound to the browser session that presents it

    @nominal @walking-skeleton
    Scenario: The nominal callback
      Given attempt att-1 with state S8NJ7… bound to session sess-anna, started 2 minutes ago
      When the browser with cookie sess-anna opens /xs2a/callback/bank?code=Splx…&state=S8NJ7…
      Then the attempt is matched and the code exchange starts

    @error @walking-skeleton
    Scenario: A state that no attempt knows
      Given no attempt with state XXXX
      When the callback arrives with state XXXX
      Then the TPP answers 400 'Unknown request' and sends nothing to the OIDC-provider

    @error @walking-skeleton
    Scenario: A valid state presented by another browser session
      Given attempt att-1 bound to sess-anna
      When a browser with cookie sess-mallory opens the callback with state S8NJ7… and a code
      Then the TPP answers 400 and sends nothing to the OIDC-provider
      And the event is logged as a possible session fixation with both session ids

    @error @mvp
    Scenario: A callback without a session cookie
      Given attempt att-1
      When a browser with no cookie opens the callback with state S8NJ7…
      Then the TPP answers 400 and sends nothing to the OIDC-provider

    @error @walking-skeleton
    Scenario: A state used a second time
      Given att-1 was already consumed
      When the same callback URL is opened again
      Then the TPP shows the current state of the connection and sends nothing to the OIDC-provider

    @error @mvp
    Scenario: A state older than ten minutes
      Given att-1 started 11 minutes ago
      When the callback arrives
      Then the TPP answers 'This request expired, please try again' and sends nothing to the OIDC-provider

    @error @walking-skeleton
    Scenario: A callback without state
      Given any attempt
      When the callback arrives with a code and no state
      Then the TPP answers 400

    @error @mvp
    Scenario: A callback with an empty code
      Given att-1 pending
      When the callback arrives with state S8NJ7… and code ''
      Then the TPP answers 400 and the attempt outcome is denied

  Rule: The state is consumed on first use, whatever happens afterwards

    @edge @mvp
    Scenario: A failed token exchange still consumes the state
      Given att-1 matched and the OIDC-provider answered invalid_grant
      When the callback is opened again
      Then the TPP does not retry the exchange and shows 'Connection failed'

    @edge @mvp
    Scenario: Two concurrent callbacks with the same state exchange once
      Given the callback URL opened twice within 100 ms
      When both requests are handled
      Then exactly one token request reaches the OIDC-provider

  Rule: Error callbacks are validated the same way

    @nominal @mvp
    Scenario: access_denied with a valid state fails the attempt
      Given att-1 pending
      When the callback arrives with error=access_denied&state=S8NJ7…
      Then the attempt outcome is denied and no token request is sent

    @error @mvp
    Scenario: access_denied with an unknown state is ignored
      Given no attempt with state XXXX
      When the callback arrives with error=access_denied&state=XXXX
      Then no connection changes

  @security
  Rule: Codes and states never reach logs or third parties

    @nominal @walking-skeleton
    Scenario: The code is not logged
      Given the nominal callback
      When the TPP's access log is inspected
      Then the query string is redacted to code=[redacted]&state=[redacted]

    @nominal @mvp
    Scenario: The callback page loads no third-party resources
      Given the callback response
      When its HTML is inspected
      Then it references no external script or image that would leak the URL in a referrer
