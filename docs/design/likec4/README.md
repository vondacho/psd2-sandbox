# C4 model (LikeC4)

One model of the sandbox, many views. Written in the
[LikeC4 DSL](https://likec4.dev/dsl): elements and relationships are declared
once in `model.c4`, and each view in `views.c4` selects a slice of them, so a
container added once appears correctly everywhere it belongs.

| File | Holds |
|---|---|
| [`specs.c4`](specs.c4) | Notation: element kinds (`actor`, `softwareSystem`, `container`, `component`, `webApp`, `mobileApp`, `database`, `apiGateway`), relationship kinds (`https`, `mtls`, `redirect`, `internal`, `push`) and tags. |
| [`model.c4`](model.c4) | The model: the PSU, the TPP, the OIDC-provider, the Bank and the Bank mobile app, with their containers, components and relationships. |
| [`views.c4`](views.c4) | The 14 views listed below. |

The viewer writes layout snapshots to a local `.likec4/` folder as you arrange
views. It is gitignored: the three files above are the whole source of truth, and
a snapshot is only a cache that can be regenerated.

## Views

Static views — the C4 levels:

| View | Shows |
|---|---|
| `index` | Landscape: the whole system context |
| `tpp`, `oidcProvider`, `bank` | Containers of each system |
| `tppBackend`, `bankCiam`, `bankPayments` | Components of the TPP back end, the Bank CIAM and payment initiation |

Dynamic views — the journeys, numbered as in
[the system design document](../xs2a-sandbox-system-design.md) and matching the
PlantUML sequences in [`../puml/`](../puml/):

| View | Section |
|---|---|
| `deviceEnrolment` | 6.1 Device enrolment |
| `consentAndAuthorizationStart` | 6.2 Consent creation and start of the authorization-code flow |
| `scaAtBank` | 6.3 Authentication and SCA at the Bank |
| `tokenAndAccountRead` | 6.4 Token exchange, confirmation, account list and details |
| `laterAccess` | 6.5 Later access and token refresh |
| `paymentInitiation` | 12.1 Payment initiation and approval |
| `paymentCancellation` | 12.2 Payment cancellation with its own SCA |

Open a dynamic view in the viewer's **sequence variant** to read it as a
sequence diagram.

## Working with it

LikeC4 needs a current Node. With `nvm`:

```sh
nvm use --lts
```

```sh
npx likec4 start    docs/design/likec4   # browse at localhost, live reload
npx likec4 validate docs/design/likec4   # parse and check every reference
npx likec4 build    docs/design/likec4 --output out
```

`validate` parses; `build` additionally lays every view out, so it is the one
that catches a view referencing an element that does not exist. Run `build`
before committing a change to `views.c4`.
