# Domain models

Where the design stops being a journey and becomes a set of boundaries. Written
in the context-mapping DSL documented at
[ba-cm.obya.ch/dsl](https://ba-cm.obya.ch/dsl) (`.ddd` for the map,
[`.ddm`](https://ba-cm.obya.ch/dsl#ddm) for the inside of one context).

Everything sits under
[`psd2-access-to-account/`](psd2-access-to-account/), one folder per bounded
context plus the map itself:

```
psd2-access-to-account/
  psd2-access-to-account.ddd        the context map: domains, subdomains,
  psd2-access-to-account.dddview    contexts and the relationships between them
  consent-management/
    consent-management.ddm          the inside of that one context
    consent-management.ddmview
  ... one folder per context
```

A `.dddview` / `.ddmview` file is the editor's layout for its model: node
positions as JSON. It carries no meaning — the model is entirely in the `.ddd`
or `.ddm` — but keeping it next to the model means the diagram opens the way it
was left.

## The map

Three domains: the Bank (ASPSP), the OIDC-provider and the TPP.

| Bounded context | Subdomain | Aggregates | Status |
|---|---|---|---|
| [Consent management](psd2-access-to-account/consent-management/consent-management.ddm) | core — consent and account access | `Consent`, `Authorisation` | modelled |
| [Account information](psd2-access-to-account/account-information/account-information.ddm) | core — consent and account access | `AccountResource`, `TransactionReport`, `DeltaCursor` | modelled |
| [Payment initiation](psd2-access-to-account/payment-initiation/payment-initiation.ddm) | core — consent and account access | `Payment`, `PaymentAuthorisation`, `PaymentCancellation` | modelled |
| [Customer identity and SCA](psd2-access-to-account/customer-identity-and-sca/customer-identity-and-sca.ddm) | core — identity and SCA | `PsuIdentity`, `RegisteredDevice`, `ScaChallenge`, `AuthenticationSession` | modelled |
| [TPP identification](psd2-access-to-account/tpp-identification/tpp-identification.ddm) | supporting | `TppIdentity` | modelled |
| [Token issuance](psd2-access-to-account/token-issuance/token-issuance.ddm) | supporting — authorization server | `ClientRegistration`, `AuthorizationRequest`, `TokenGrant` | modelled |
| [Bank connection](psd2-access-to-account/bank-connection/bank-connection.ddm) | supporting — bank connections (the TPP) | `BankConnection`, `BankRegistryEntry`, `AuthorizationAttempt` | modelled |
| [Accounts ledger](psd2-access-to-account/accounts-ledger/accounts-ledger.ddm) | generic — core banking | — | **unmodelled** |

**Direction is about the model, not the network.** Upstream is whoever's model
the other has to accommodate. The map records each relationship with the pattern
that governs it — `published-language`, `open-host-service`, `customer-supplier`,
`shared-kernel`, `conformist`, `anticorruption-layer` — and, for each, what is
exchanged and why that pattern and not another.

Two of those choices carry most of the design. The NextGenPSD2 XS2A interface is
a **published language**: it is read by every TPP in the market, so the
interchange format is the asset and neither side's internal model may leak into
it. And consent management and payment initiation share the authorisation
sub-resource as a **shared kernel**, because the specification defines one
authorisation process for both — two copies would drift.

## Conventions

- **One context per `.ddm`, named after it.** The `context` title matches the
  `.ddd` entry and the folder name.
- **Aggregates match the map.** The aggregates a `.ddm` declares are exactly the
  ones its `.ddd` context lists.
- **Spec primitives are used bare.** Types such as `IBAN`, `Max35Text`,
  `CurrencyCode`, `ConsentId` and `PsuId` come from ISO 20022 and NextGenPSD2 and
  are not redeclared. Structured types a context owns are declared in it.
- **`unmodelled` means wrapped, not missing.** The accounts ledger is an existing
  system; the account information context translates it through an
  anticorruption layer, so nothing inside that boundary is our model.

## Known gap

`accounts-ledger/accounts-ledger.ddm` is an **unfilled editor stub** — it still
carries the template's `"New aggregate"` placeholder. The `.ddd` marks that
context `unmodelled` deliberately, so the stub is consistent with the intent but
contradicts it in form: an `unmodelled` context should have no `.ddm` at all, or
the file should say in a comment that it is a deliberate placeholder. Every other
context here is genuinely modelled.
