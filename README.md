# Why
The [Berlin Group NextGenPSD2](https://www.berlin-group.org/psd2-access-to-bank-accounts) is a joint initiative for a PSD2-compliant XS2A interface.

# What
The [NextGenPSD2 XS2A Framework](https://c2914bdb-1b7a-4d22-b792-c58ac5d6648e.usrfiles.com/ugd/c2914b_f7066c0ffa2e4242b8a25e7b31f1278a.pdf) that specify the XS2A interface in technical detail, including XML/JSON schemas

# How
This project should provide a sandbox based on the [NextGenPSD2 XS2A Framework](https://c2914bdb-1b7a-4d22-b792-c58ac5d6648e.usrfiles.com/ugd/c2914b_f7066c0ffa2e4242b8a25e7b31f1278a.pdf) specification to implement an AISP/PISP system.

# Design
- [PSU account-list journey — system design](docs/design/psu-account-list-journey.md): roles, decisions, flows, contracts, security controls and sandbox layout for a PSU reading accounts at Bank B through TPP application A, with SCA by password and a QR code approved on a registered device, and an access token issued by an OpenID Connect provider.
- Models as code: [event storm](docs/design/eventstorming/psu-account-list-journey.eventstorm) (`.eventstorm`), [story map](docs/design/storymap/psu-account-list-journey.storymap) (`.storymap`), [context map](docs/design/domain/psd2-access-to-account.ddd) (`.ddd`) and [domain models](docs/design/domain/) (`.ddm`).
- Diagrams: [LikeC4 C4 model](docs/design/likec4/) (`npx likec4 start docs/design/likec4`) and [PlantUML sources](docs/design/puml/).
