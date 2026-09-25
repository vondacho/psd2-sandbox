# Terminology

## Actors

- PSU - Payment Service User
- TPP - Third-Party Provider
- Bank X2SA — XS2A API that makes the Bank an ASPSP — Account Servicing Payment Service Provider
- Bank CIAM — Customer Identity and Access Management
- Bank SCA — Strong Customer Authentication
- Bank IDP — Identity Provider
- Bank Core Banking System — DCP
- Bank Mobile App
- OIDC/OAuth provider
- PSD2 X2SA Gateway
- PSD2 Authenticator — TPP authentication
- PSD2 Consent Manager — PSU consent lifecycle management

## Screens

- Login screen — where the PSU authenticates against the CIAM, in the web browser
- Consent screen — where the PSU grants or revokes a given TPP's access to his accounts, in the web browser
- SCA screen — displayed on demand by the CIAM, where the PSU completes Strong Customer Authentication on the Bank Mobile App.

## Protocols

- OIDC — OpenID Connect
- OAuth 2.0 — Open Authorization

## Concepts

- PSUCLM — PSU Consent Lifecycle Management
- SCA — Strong Customer Authentication
- Device enrolment — registering a device with the CIAM so it can be used for SCA

## Glossary

- **SCA** — Strong Customer Authentication
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
