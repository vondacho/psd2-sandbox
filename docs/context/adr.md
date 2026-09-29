# Architecture Decision Record (ADR):

## Flows

### AIS

TPP : wants to present the list of all accounts or information (balances, transactions) on some accounts
TPP > PRETA ledger : to get URL of Bank ASPSP
TPP > PSD2/XS2A gateway : to ask for one AIS Consent; 
PSD2/XS2A gateway > Bank CIAM : to authenticate the PSU
PSU > Bank CIAM : Login screen: to type the username
Bank CIAM > PSU : Challenge screen: to show QR-code and wait
PSU > Bank ASPSP App : to scan the shown QR-code on the enrolled device
Bank ASPSP App > Bank CIAM : to confirm identity
PSU > Bank ASPSP App : Challenge screen: to type the passcode defined at device enrollment
Bank CIAM > Bank XS2A : to retrieve consent
Bank XS2A > Finologee gateway : to retrieve consent
Bank XS2A > Core Banking : to check that the asked accounts belong to PSU
Bank XS2A > Bank CIAM : to return consent payload
PSU > Bank CIAM : Option A) Consent confirmation screen: to confirm consent
PSU > Bank ASPSP App : Option B) Consent confirmation screen: to confirm consent
Bank CIAM > PSD2/XS2A gateway : to return an access code
Bank CIAM > Bank IDP : to exchange access token
PSD2/XS2A gateway > Bank CIAM : to exchange the access code against an ID-token and an access token
PSD2/XS2A gateway > TPP : to return an access code
TPP > PSD2/XS2A gateway : to exchange the access code against an access token
TPP > PSD2/XS2A gateway : to access list of all accounts or information (balances, transactions) on some accounts
TPP > PSD2/XS2A gateway > Bank XS2A > Core Banking : fetch all accounts or information (balances, transactions) on some accounts

### PIS

TPP : wants to initiate a payment
TPP > PSD2/XS2A gateway : to ask for one PIS Consent
PSD2/XS2A gateway > Bank CIAM : to authenticate the PSU
PSU > Bank CIAM : Login screen: to type the username
Bank CIAM > PSU : Challenge screen: to show QR-code and wait
PSU > Bank ASPSP App : to scan the shown QR-code on the enrolled device
Bank ASPSP App > Bank CIAM : to confirm identity
PSU > Bank ASPSP App : Challenge screen: to type the passcode defined at device enrollment
Bank CIAM > Bank XS2A : to retrieve consent
Bank XS2A > Finologee gateway : to retrieve consent
Bank XS2A > Core Banking : to check that the account belongs to PSU
Bank XS2A > Bank CIAM : to return consent payload
PSU > Bank CIAM : Option A) Consent confirmation screen: to confirm consent
PSU > Bank ASPSP App : Option B) Consent confirmation screen: to confirm consent
Bank CIAM > PSD2/XS2A gateway : to return an access code
Bank CIAM > Bank IDP : to exchange access token
PSD2/XS2A gateway > Bank CIAM : to exchange the access code against an ID-token and an access token
PSD2/XS2A gateway > TPP : to return an access code
TPP > PSD2/XS2A gateway : to exchange the access code against an access token
TPP > PSD2/XS2A gateway : to execute payment > Bank XS2A : to execute payment
Bank XS2A > Core Banking : to execute the payment

## Bank ASPSP

The Bank ASPSP delegates the PSD2 compliance with the consent management to [Finologee](https://finologee.com/psd-psd2-module/)
an external partner in charge to implement a PS2D/XS2A gateway.

### PSD2/XS2A gateway

A REST API for consent issuance, account information querying and payment initiation.
It delegates to an OIDC provider, based on Keycloak, which orchestrates the OAuth authorisation protocol.
It manages the consent lifecycle, and delegates SCA to the Bank CIAM.

### Finologee gateway

An internal REST API which exposes the managed Consent resources.

### Bank XS2A

An internal REST API for account information querying and payment initiation.

## Bank CIAM

The Bank in-house CIAM solution is [Transmit](https://developer.transmitsecurity.com/guides/journeys_intro).
Option A) It supports the Consent confirmation screen.

### Bank IDP

The Bank in-house IDP solution is [PingFederate](https://developer.pingidentity.com/pingfederate.html).

The solution architecture in place requires a token exchange to consume the Core Banking Services,
because the access control only supports tokens issued by the Bank IDP.

### Bank SCA

The Bank SCA involves [Transmit](https://developer.transmitsecurity.com/guides/journeys_intro) to support SCA, involving QR-code scanning by the Bank Mobile App installed 
on PSU's enrolled mobile device.

## Bank ASPSP App

It supports Bank SCA with QR-code scanning. It integrates with Bank CIAM for QR-code sending.
Option B) It supports the Consent confirmation screen.

## Core Banking or DCP Services

The Digital Client Platform is the Bank's platform solution to manage the PSU accounts, balances, transactions, and payment services.
Token-based access control is applied to protect the Core Banking Services, and the solution architecture in place requires token issuance by the Bank IDP.

## OIDC / OAuth provider

[Finologee](https://finologee.com/psd-psd2-module/) is the OIDC/OAuth provider.

## PSD2 Authenticator

[Finologee](https://finologee.com/psd-psd2-module/) is the PSD2 Authenticator.

## PSD2 Consent Manager

[Finologee](https://finologee.com/psd-psd2-module/) is the PSD2 Consent Manager.
Consent resources are partially mirrored inside the Bank ASPSP.

## Screens

- Bank selection screen — It is managed by the TPP.
- Consent revocation screen - It is managed by the Bank ASPSP
- Login screen — It is managed by the CIAM.
- Challenge screen — It is managed by the both the CIAM and the Bank Mobile App.
  - A waiting screen managed by the CIAM in the web browser; it contains the QR code to be scanned with the enrolled device.
- Consent confirmation screen
  - Option A) It is managed by the Bank CIAM.
  - Option B) It is managed by the Bank ASPSP App.
- Journey confirmation screen — It is managed by TPP.
