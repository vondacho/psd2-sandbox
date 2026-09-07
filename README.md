# Why
The [Berlin Group NextGenPSD2](https://www.berlin-group.org/psd2-access-to-bank-accounts) is a joint initiative for a PSD2-compliant XS2A interface.

# What
The [NextGenPSD2 XS2A Framework](https://c2914bdb-1b7a-4d22-b792-c58ac5d6648e.usrfiles.com/ugd/c2914b_f7066c0ffa2e4242b8a25e7b31f1278a.pdf) that specify the XS2A interface in technical detail, including XML/JSON schemas

# How
This project should provide a sandbox based on the [NextGenPSD2 XS2A Framework](https://c2914bdb-1b7a-4d22-b792-c58ac5d6648e.usrfiles.com/ugd/c2914b_f7066c0ffa2e4242b8a25e7b31f1278a.pdf) specification to implement an PSD2-compliant ASPSP/AIS/PIS system.

# Design
- [XS2A sandbox — system design](docs/design/xs2a-sandbox-system-design.md): roles, decisions, flows, contracts, security controls and sandbox layout for the PSU journeys the sandbox serves. A PSU reads the accounts held at the Bank through the TPP, and pays from one of them, both with SCA by password and a QR code approved on a registered device, and with access tokens issued by an OpenID Connect provider.
- Models as code: [event storms](docs/design/eventstorming/) (`.eventstorm`, the account and payment journeys), [story maps](docs/design/storymap/) (`.storymap`, the account journey plus the Bank's payment services and interface conformance), [example maps](docs/design/examplemap/) (`.examplemap`, one per story: rules, examples, questions), [context map](docs/design/domain/psd2-access-to-account/psd2-access-to-account.ddd) (`.ddd`) and [domain models](docs/design/domain/) (`.ddm`).
- [ASPSP compliance increments](docs/design/xs2a-sandbox-system-design.md#17-aspsp-compliance-increments): the seven increments that make the sandbox compliant for account information and payment initiation, and what is deliberately out of scope.
- Diagrams: [LikeC4 C4 model](docs/design/likec4/) (`npx likec4 start docs/design/likec4`) and [PlantUML sources](docs/design/puml/).

Every folder under [`docs/`](docs/) and [`tools/`](tools/) carries a README that
says what its files are and how they relate to the rest.

# Tools
- [`tools/emcheck.py`](tools/README.md): structural checker for the 126 example maps. `python3 tools/emcheck.py docs/design/examplemap/*/*.examplemap`.
- [`tools/emgherkin.py`](tools/README.md#emgherkinpy): generates a Gherkin [`.feature`](docs/design/features/) from every example map. `python3 tools/emgherkin.py`.
