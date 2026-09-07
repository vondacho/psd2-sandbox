# Generated from docs/design/examplemap/2-connect-the-bank-from-the-tpp/enforce-redirect-uris-in-the-qwac-domain.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.
# 1 open question(s) in the map are not exported; the scenarios below assume an answer.

@oidc-provider @security @spec-4.10 @mvp @analysing
Feature: Enforce redirect URIs in the QWAC domain
  As Bank security officer
  I want redirect URIs outside the certificate's domain refused
  So that codes are never sent to a third party

  @spec-4.10
  Rule: At registration, the host of every redirect URI must be a domain named in the QWAC

    @nominal @mvp
    Scenario: A callback under tpp.sandbox is accepted
      Given the TPP's QWAC has SAN dNSName tpp.sandbox
      When https://tpp.sandbox/xs2a/callback/bank is registered
      Then the registration is accepted

    @error @mvp
    Scenario: A callback on another domain is refused
      Given the TPP's QWAC has SAN dNSName tpp.sandbox
      When https://evil.example/cb is registered
      Then the registration is refused with 'redirect URI not in certificate domain'

    @edge @mvp
    Scenario: A subdomain is accepted only with a wildcard SAN
      Given the TPP's QWAC has SAN dNSName tpp.sandbox only
      When https://callback.tpp.sandbox/cb is registered
      Then the registration is refused

    @edge @mvp
    Scenario: A wildcard SAN covers one level of subdomain
      Given a QWAC with SAN *.tpp.sandbox
      When https://callback.tpp.sandbox/cb is registered
      Then the registration is accepted
      When https://x.y.tpp.sandbox/cb is registered
      Then the registration is refused

    @error @mvp
    Scenario: An http URI is refused
      Given the TPP's QWAC
      When http://tpp.sandbox/cb is registered
      Then the registration is refused with 'redirect URI must use https'

    @error @mvp
    Scenario: A URI with a userinfo part is refused
      Given the TPP's QWAC
      When https://tpp.sandbox@evil.example/cb is registered
      Then the registration is refused

    @error @mvp
    Scenario: A URI with a fragment is refused
      Given the TPP's QWAC
      When https://tpp.sandbox/cb#x is registered
      Then the registration is refused

  Rule: At /authorize the redirect_uri must be one of the registered URIs, and an error is shown rather than redirected

    @nominal @mvp
    Scenario: A registered URI passes
      Given https://tpp.sandbox/xs2a/callback/bank is registered
      When /authorize is called with it
      Then the OIDC-provider proceeds

    @error @mvp
    Scenario: An unregistered URI on the right domain is still refused
      Given only https://tpp.sandbox/xs2a/callback/bank is registered
      When /authorize is called with https://tpp.sandbox/xs2a/callback/bank-c
      Then the OIDC-provider shows an error page and does not redirect

    @error @mvp
    Scenario: An error for a bad redirect_uri never goes to that URI
      Given redirect_uri https://evil.example/cb
      When /authorize is called
      Then no request reaches evil.example

  @spec-4.10
  Rule: The Bank applies the same domain check to TPP-Redirect-URI and TPP-Nok-Redirect-URI on the XS2A interface

    @nominal @mvp
    Scenario: A TPP-Redirect-URI in the QWAC domain is accepted
      Given the TPP's QWAC and TPP-Redirect-URI https://tpp.sandbox/xs2a/callback/bank
      When POST /v1/consents is called
      Then the answer is 201

    @error @mvp
    Scenario: A TPP-Nok-Redirect-URI outside the domain is refused
      Given TPP-Nok-Redirect-URI https://evil.example/nok
      When POST /v1/consents is called
      Then the answer is 400 FORMAT_ERROR with path TPP-Nok-Redirect-URI

  Rule: A certificate rotation re-validates the registered URIs

    @edge @mvp
    Scenario: A new certificate without the domain disables the URIs
      Given the TPP client registered with https://tpp.sandbox/xs2a/callback/bank
      When the operator binds a new QWAC whose SAN is only app-a.example
      Then the OIDC-provider refuses the binding with 'registered redirect URIs would leave the certificate domain'

    @nominal @mvp
    Scenario: A new certificate with the domain is accepted
      Given the same client
      When the operator binds a new QWAC with SAN tpp.sandbox
      Then the binding is accepted and the URIs stay registered
