# Architecture Decision Record (ADR)

## Bank ASPSP
We must develop our own ASPSP (Account Servicing Payment Service Provider) gateway.
It provides secure access to banking services and APIs.
It must comply with PSD2 (Payment Services Directive 2) regulatory requirements.

## Bank Core Banking System
The DCP Digital Client Platform is the in-house solution for the Bank Core Banking System.
It must manage PSU's accounts, transactions, and payment services.

## Bank IDP
[Ping Federate](https://www.pingidentity.com/en/products/ping-federate.html) is the in-house IDP (Identity provider) solution.
It must authenticate PSU and manage PSU's identity information.

### Login screen
The login screen allows PSU to authenticate agains the IDP. It is managed in-house by the IDP solution.
It must be presented to PSU in the web browser.

## Bank CIAM
[Transmit](https://developer.transmitsecurity.com/guides/journeys_intro) is the in-house CIAM (Customer Identity and Access Management) solution. 
It provide device management and device enrollement.

### Device enrollment
The device enrollment process allows PSU to register their device with the CIAM solution,
to use it for SCA (Strong Customer Authentication) in the Bank Mobile App.

## Bank Mobile App
We have our own mobile banking application.
It must integrate with our CIAM solutions to and implement SCA methods to ensure secure access to PSU's accounts and transactions.
SCA methods include multi-factor authentication (MFA), biometric authentication, and one-time passwords (OTP).

### SCA screen
The SCA screen allows PSU to complete the Strong Customer Authentication process.
It is managed by the Bank Mobile App, and must be presented to PSU on demand by the CIAM solution.
PSU confirms his identity and his consent as a final step in the authentication process.

## PSD2 gateway
[Finologee](https://finologee.com/psd-psd2-module/) is the PSD2 gateway provider.
It must act as an intermediary between our ASPSP and the third-party provider (TPP), ensuring secure and compliant access to banking services.
It implements OIDC (OpenID Connect) and OAuth 2.0 protocols for authentication and authorization, enabling TPP to access customer accounts with PSU consent.

## PSU consent lifecycle management
The consent lifecycle management includes features such as consent expiration, revocation, and auditing, 
ensuring compliance with PSD2 requirements and enhancing customer trust in our banking services.

## Consent screen
The consent screen allows PSU to grant or revoke access to their accounts for a given TPP in a secure and user-friendly manner.
It must comply with PSD2 regulations regarding consent management.
It must be presented to PSU in the web browser.
