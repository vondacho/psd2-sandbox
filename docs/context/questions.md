# Questions

## PSU consent lifecycle management
Where will the consent management be located? Will it be in the IDP, CIAM, or PSD2 gateway?

### In house solution
Our current IDP and CIAM solutions should provide a built-in user consent lifecycle management feature, which is essential for managing customer consents in compliance with PSD2 regulations.

### Third-party solution
We are considering using Finologee's user consent lifecycle management feature to handle customer consents for TPPs.

## Token management
Ping Feredate is our current IDP solution and access token issuer inside the bank. 
We are considering using Finologee's token management feature to handle TPP tokens.
Finologee's token issued for the TPP must allow access to the bank's ASPSP APIs.
Should Finologee's token be exchanged for a bank-issued token before accessing the ASPSP APIs? 
Or should the TPP token be used directly to access the ASPSP APIs?
