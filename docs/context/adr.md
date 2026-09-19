# Architecture Decision Record (ADR)

## Bank IDP
[Ping Federate](https://www.pingidentity.com/en/products/ping-federate.html) is our commercial identity server that provides secure authentication and authorization services. 
It supports various protocols such as SAML, OAuth, and OpenID Connect, making it suitable for enterprise-level applications.

## Bank CIAM
[Transmit](https://developer.transmitsecurity.com/guides/journeys_intro) is our chosen CIAM (Customer Identity and Access Management) solution. 
It offers features like user registration, authentication, and profile management, ensuring a seamless user experience for our customers.
It adds device management capabilities, allowing us to manage and secure access to our applications from different devices.

## Bank ASPSP
We develop our own ASPSP (Account Servicing Payment Service Provider) gateway.
It provides secure access to banking services and APIs.
It must comply with PSD2 (Payment Services Directive 2) regulatory requirements.

## Bank Mobile App
We develop our own mobile banking application that allows customers to access their accounts, perform transactions, and manage their finances on the go. 
The app integrates with our ASPSP gateway and CIAM solution to provide a secure and user-friendly experience.
The app must comply with PSD2 regulatory requirements and support strong customer authentication (SCA) methods.

## SCA (Strong Customer Authentication)
We implement SCA methods in our mobile banking application to ensure secure access to customer accounts and transactions.
SCA methods include multi-factor authentication (MFA), biometric authentication, and one-time passwords (OTP).
These methods help protect customer data and prevent unauthorized access to banking services.

### In house solution
We implement SCA methods in our mobile banking application using our own IDP and CIAM solutions.

## PSD2 gateway
[Finologee](https://finologee.com/psd-psd2-module/) is our PSD2 gateway provider.
It acts as an intermediary between our ASPSP and third-party providers (TPPs), ensuring secure and compliant access to banking services.
It implements OIDC (OpenID Connect) and OAuth 2.0 protocols for authentication and authorization, enabling TPPs to access customer accounts with proper consent.

## PSU consent lifecycle management
Not decided yet.
The consent lifecycle management includes features such as consent expiration, revocation, and auditing, ensuring compliance with PSD2 requirements and enhancing customer trust in our banking services.

### In house solution
Our current IDP and CIAM solutions should provide a built-in user consent lifecycle management feature, which is essential for managing customer consents in compliance with PSD2 regulations.

### Third-party solution
We are considering using Finologee's user consent lifecycle management feature to handle customer consents for TPPs.

Finologee provides a user consent lifecycle management feature that allows customers to grant and revoke access to their accounts for TPPs.
This feature ensures that customers have control over their data and can manage their consents in a secure manner.
