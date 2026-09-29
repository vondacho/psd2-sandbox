# Terminology

## Glossary

- **CIAM** — Customer Identity and Access Management
- **SCA** — Strong Customer Authentication
- **IDP** — Identity Provider
- **eIDAS** — Electronic Identification, Authentication and Trust Services
- **PSD2** — Payment Services Directive 2
- **PSU** — Payment Service User
- **TPP** — Third-Party Provider
- **ASPSP** — Account Servicing Payment Service Provider
- **AISP** — One TPP may be an Account Information Service Provider
- **PISP** — One TPP may be a Payment Initiation Service Provider
- **PIISP** — One TPP may be a Payment Instrument Issuer Service Provider
- **XS2A** — PSD2 compliant API contract for accessing and operating bank accounts
- **DCP** — Digital Client Platform, the bank's in-house core banking solution
- **OAUTH** — Consent-based authorization protocol
- **OIDC** — OpenID Connect protocol based on OAUTH that includes user Identity.

## Actors

- PSU
- TPP
- Bank ASPSP
- Bank XS2A
- Bank CIAM
- Bank SCA
- Bank IDP
- Bank ASPSP App
- Bank e-Bankink
- Core Banking Services
- OIDC-OAuth provider
- PSD2 Authenticator
- PSD2 Consent Manager

## PSU

An end-user who owns one or more accounts at one or more banks. 
A web user or another system with a PSU as web user.

## TPP

A certified third-party aggregation solution, used by a PSU to access his account information and initiate payments from ones of his banks.

It must own an eIDAS certificate issued by a recognised certification authority, to be registered at the Bank ASPSP, 
in order to access PSU's account information and initiate payments.

A web application runnning in a web browser.

## Bank ASPSP

The Bank wants to provide TPP the access to PSU's account information and payment initation in a secure and PSD2-compliant way.

It must be registered in the PRETA ledger and must provide an XS2A interface for account information and payment initiation.

The PSD2 specification introduces the concept of consent; PSU's consent is mandatory for one TPP to access
PSU's accounts and initiate payments.

### OIDC / OAuth provider

The Bank ASPSP must orchestrates OIDC / OAuth authorization protocol. 
It coordinates PSU authentication, TPP authorization through PSU's consent retrieval, and access token issuance.

### PSD2 Authenticator

The Bank ASPSP must authenticate a registered TPP in a PSD2-compliant way, based on eIDAS certificate,
before it can ask any consent.

### PSD2 Consent Manager

The Bank ASPSP must manage the lifecycle of each consent in a PSD2-compliant way.

### Bank XS2A

The Bank ASPSP must expose a public REST/JSON API that implements the PSD2-XS2A specification. 
It integrates with the Core Banking Services to deliver account information and initiate payments.

## Bank CIAM

It provides device management, device enrollment, Auth-N, Auth-Z, and access token issuance.

## Bank SCA

It implements multi-factor authentication of one PSU — Something You Know, Have, or Are; it includes Dynamic Linking, 
letting PSU confirm the given consent for the selected accounts (AIS) or the payment details (PIS).

SCA journey contains the following steps:

- Login screen: the PSU gives his username.
- Challenge screen: the PSU confirms his identity using an SCA method.
  - 1) Scanning QR-code
  - 2) Passcode or Biometric method (fingerprint, face recognition).
- Consent confirmation screen: the PSU confirms the items of the consent he is giving.

## Bank ASPSP App

The Bank's mobile-facing solution for PSU to manage his accounts and to order payments in a secure way from his enrolled mobile device.
It integrates with the Bank CIAM, and implements SCA methods, i.e QR code scanning and biometry.

## Bank e-Bankink

The Bank's web-facing solution for PSU to manage his accounts and to order payments in a secure way from his web browser.

## Core Banking Services

The Bank's platform solution to manage the PSU accounts, balances, transactions, and payment services.

## Screens

- Bank selection screen — where the PSU selects the banks the TPP has to connect with, in the web browser.
- Consent screen — where the PSU grants the access by one TPP to all or some of his accounts, in the web browser.
- Consent revocation screen - where the PSU revokes the access by one TPP to all or some of his accounts, in the web browser.
- Login screen — where the PSU authenticates against the CIAM, in the web browser.
- Challenge screen — where the PSU completes Strong Customer Authentication using the SCA method of his choice, on the Bank Mobile App, on the enrolled device.
- Consent confirmation screen — where the PSU is displayed a summary of the consent he is giving to the TPP, Dynamic Linking, on the Bank Mobile App, on the enrolled device.
- Journey confirmation screen — where the PSU is displayed the confirmation and completion of his journey, in the web browser.

## Concepts

- Device enrollment — registering a device with the CIAM so it can be used for SCA
- Consent — Time-bounded authorisation given by a PSU to a TPP for accessing PSU's account information and initiate payments from PSU's accounts.
