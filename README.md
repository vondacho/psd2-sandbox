# Why
The [Berlin Group NextGenPSD2](https://www.berlin-group.org/psd2-access-to-bank-accounts) is a joint initiative for a PSD2-compliant XS2A interface.

# What
The [NextGenPSD2 XS2A Framework](https://c2914bdb-1b7a-4d22-b792-c58ac5d6648e.usrfiles.com/ugd/c2914b_f7066c0ffa2e4242b8a25e7b31f1278a.pdf) that specify the XS2A interface in technical detail, including XML/JSON schemas

# How
This project should provide a sandbox based on the [NextGenPSD2 XS2A Framework](https://c2914bdb-1b7a-4d22-b792-c58ac5d6648e.usrfiles.com/ugd/c2914b_f7066c0ffa2e4242b8a25e7b31f1278a.pdf) specification to implement an PSD2-compliant ASPSP/AIS/PIS system.

# Design
- [PSU account-list journey — system design](docs/design/psu-account-list-journey.md): roles, decisions, flows, contracts, security controls and sandbox layout for a PSU reading accounts at the Bank through the TPP, with SCA by password and a QR code approved on a registered device, and an access token issued by an OpenID Connect provider.
- Models as code: [event storms](docs/design/eventstorming/) (`.eventstorm`, the account and payment journeys), [story maps](docs/design/storymap/) (`.storymap`, the account journey plus the Bank's payment services and interface conformance), [example maps](docs/design/examplemap/) (`.examplemap`, one per story: rules, examples, questions), [context map](docs/design/domain/psd2-access-to-account.ddd) (`.ddd`) and [domain models](docs/design/domain/) (`.ddm`).
- [ASPSP compliance increments](docs/design/psu-account-list-journey.md#17-aspsp-compliance-increments): the seven increments that make the sandbox compliant for account information and payment initiation, and what is deliberately out of scope.
- Diagrams: [LikeC4 C4 model](docs/design/likec4/) (`npx likec4 start docs/design/likec4`) and [PlantUML sources](docs/design/puml/).
