# Architecture Decision Record (ADR):

## Bank ASPSP

The bank is building its own ASPSP (Account Servicing Payment Service Provider) gateway.

This provides secure access to the bank's services and APIs and must comply with the PSD2 (Payment Services Directive 2) regulatory requirements.

## Bank Core Banking System

The bank's in-house solution, DCP (Digital Client Platform), runs the core banking system.

The DCP must manage the PSU's accounts, balances, transactions, and payment services.

## Bank CIAM

[Transmit](https://developer.transmitsecurity.com/guides/journeys_intro) is the bank's in-house CIAM (Customer Identity and Access Management) solution.

It provides device management and enrolment, Auth-N and Auth-Z.

### Device enrolment

The PSU must register a device with the Bank CIAM so that it can be used for SCA (Strong Customer Authentication) in the Bank Mobile App.

## Bank Mobile App

The Bank has its own mobile banking app.

PSU must install it on the enrolled mobile device.

This must integrate with the Bank CIAM, and implements SCA methods which include user facing, QR code scanning,
biometric authentication, or one-time passwords.

## TPP application

The TPP application runs in a web browser.

## PSD2 gateway

[Finologee](https://finologee.com/psd-psd2-module/) is the PSD2/X2SA gateway provider and the OIDC/OAuth provider.

It must sit between the bank's ASPSP and the third-party provider (TPP), keeping access to
banking services secure and compliant. It implements OIDC (OpenID Connect) and OAuth 2.0 to
authenticate and authorise the TPP, so that a TPP can reach customer accounts with the PSU's
consent.

## PSU consent lifecycle management

This covers consent expiry, frequency, revocation, and auditing.

This helps the bank to remain compliant with PSD2 and to strengthen customer trust in its services.

### Login screen

The login screen is where the PSU authenticates against the IDP.

It must be presented to the PSU in a web browser.

### Consent screen

The consent screen is where the PSU grants or revokes a given TPP access to his accounts.

It must comply with PSD2 rules on consent management.

It must be presented to the PSU in a web browser.

### SCA screen

The SCA screen is where the PSU confirms his identity using the final authentication method,
completing Strong Customer Authentication.

The Bank Mobile App manages it. It must be presented to the PSU on the enrolled mobile device
at the request of the Bank CIAM.
