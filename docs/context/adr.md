# Architecture Decision Record (ADR)

## Bank ASPSP

The bank builds its own ASPSP (Account Servicing Payment Service Provider) gateway.

It gives secure access to the bank's services and APIs, and it must meet the regulatory
requirements of PSD2 (Payment Services Directive 2).

## Bank Core Banking System

Core banking runs on **DCP (Digital Client Platform)**, the bank's in-house solution.

DCP must manage the PSU's accounts, transactions and payment services.

## Bank IDP

[Ping Federate](https://www.pingidentity.com/en/products/ping-federate.html) is the bank's
in-house IDP (Identity Provider).

It must authenticate the PSU and manage the PSU's identity information.

### Login screen

The login screen is where the PSU authenticates against the IDP.

The IDP manages it in house, and it must be presented to the PSU in the web browser.

## Bank CIAM

[Transmit](https://developer.transmitsecurity.com/guides/journeys_intro) is the bank's in-house
CIAM (Customer Identity and Access Management) solution.

It provides device management and device enrolment.

### Device enrolment

Device enrolment is how the PSU registers a device with the CIAM, so that the device can be used
for SCA (Strong Customer Authentication) in the Bank Mobile App.

## Bank Mobile App

The bank has its own mobile banking application.

It must integrate with the CIAM solution and implement SCA methods, so that access to the PSU's
accounts and transactions stays secure. These methods include multi-factor authentication (MFA),
biometric authentication and one-time passwords (OTP).

### SCA screen

The SCA screen is where the PSU completes Strong Customer Authentication.

The Bank Mobile App manages it, and it must be presented to the PSU on demand from the CIAM
solution. On that screen the PSU confirms identity and consent, as the final step of the
authentication process.

## PSD2 gateway

[Finologee](https://finologee.com/psd-psd2-module/) is the PSD2 gateway provider.

It must sit between the bank's ASPSP and the third-party provider (TPP), keeping access to
banking services secure and compliant. It implements OIDC (OpenID Connect) and OAuth 2.0 to
authenticate and authorise the TPP, so that a TPP can reach customer accounts with the PSU's
consent.

## PSU consent lifecycle management

Consent lifecycle management covers consent expiry, revocation and auditing.

It keeps the bank compliant with PSD2 and strengthens customer trust in the bank's services.

## Consent screen

The consent screen is where the PSU grants or revokes a given TPP's access to their accounts,
securely and understandably.

It must comply with the PSD2 rules on consent management, and it must be presented to the PSU in
the web browser.
