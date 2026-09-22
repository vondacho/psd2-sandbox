# Architecture Decision Record (ADR):

## Bank ASPSP

The bank is building its own ASPSP (Account Servicing Payment Service Provider) XS2A gateway.

This provides secure access to the bank's services and APIs and must comply with the PSD2 (Payment Services Directive 2) regulatory requirements.

## Bank Core Banking System

The bank's in-house solution, DCP (Digital Client Platform), runs the core banking system.

The DCP must manage the PSU's accounts, transactions, and payment services.

## Bank CIAM

Transmit is the bank's in-house CIAM (Customer Identity and Access Management) solution.

It provides device management, enrolment, Auth-N, Auth-Z, and SCA (Strong Customer Authentication) methods.

Transmit is a token issuer.

## Bank IDP

PingFederate (https://www.pingidentity.com/en/products/ping-federate.html) is the bank's in-house IDP (Identity Provider).

PingFederate is a token issuer. The DCP services require a PingFederate token to be consumed.

A token exchange is required to convert a Transmit token into a PingFederate one.

### SCA journey

The SCA journey is the process of authenticating the PSU (Payment Service User). It contains the following steps:

- Login screen: the PSU authenticates against the CIAM in the web browser.
- OTP screen: the PSU confirms his identity using a one-time password (OTP) on the enrolled mobile device.
- or QR code screen: the PSU confirms his identity by scanning a QR code with the enrolled mobile device.
- or Biometric screen: the PSU confirms his identity using a biometric method (fingerprint, face recognition, etc.) on the enrolled mobile device.
- Consent confirmation panel: the PSU confirms the items of the consent on the enrolled mobile device.

The Bank Mobile App manages it. It must be presented to the PSU on the enrolled mobile device at the request of the Bank CIAM.

## Device enrolment

Device enrolment is how the PSU registers a device with the Bank CIAM so that it can be used for SCA (Strong Customer Authentication) in the Bank Mobile App.

## Bank Mobile App

The bank has its own mobile banking app. PSU must install it on the enrolled mobile device.

This must integrate with the Bank CIAM, and SCA methods must be implemented to secure access to PSU accounts and transactions. These methods include multi-factor authentication (MFA), biometric authentication and one-time passwords (OTPs).

## PSD2 gateway

[Finologee](https://finologee.com/psd-psd2-module/) is the PSD2 gateway provider.

It must sit between the bank's ASPSP and the third-party provider (TPP), keeping access to banking services secure and compliant. 
It implements OIDC (OpenID Connect) and OAuth 2.0 to authenticate and authorise the TPP, so that a TPP can reach PSU's accounts information, 
balances, transactions, and make payments, with the PSU's consent.

## Consent lifecycle management

This covers consent expiry, revocation and auditing.

This helps the bank to remain compliant with PSD2 and to strengthen customer trust in its services.

Finologee manages the consent state.

### Consent screen

The consent screen is where the PSU securely and understandably grants or revokes a given TPP access to their accounts.

It must comply with PSD2 rules on consent management.

The TPP manages it. It is presented to the PSU in the web browser.