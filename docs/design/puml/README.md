# PlantUML diagrams

The diagrams of
[the system design document](../xs2a-sandbox-system-design.md), one file per
diagram, in the order they appear there. The C4 diagrams use the PlantUML
standard library (`!include <C4/...>`), so rendering needs no network access.

| File | Diagram | Section |
|---|---|---|
| [`01-context.puml`](01-context.puml) | System context (C4 level 1) | 3 |
| [`02-containers.puml`](02-containers.puml) | Containers (C4 level 2) | 4 |
| [`03-seq-device-enrolment.puml`](03-seq-device-enrolment.puml) | Device enrolment | 6.1 |
| [`04-seq-consent-and-authorization-start.puml`](04-seq-consent-and-authorization-start.puml) | Consent creation and start of authorisation | 6.2 |
| [`05-seq-sca-at-bank.puml`](05-seq-sca-at-bank.puml) | Authentication and SCA at the Bank | 6.3 |
| [`06-seq-token-and-account-read.puml`](06-seq-token-and-account-read.puml) | Token exchange, confirmation, account list and details | 6.4 |
| [`07-seq-later-access.puml`](07-seq-later-access.puml) | Later access and token refresh | 6.5 |
| [`08-state-consent.puml`](08-state-consent.puml) | Consent status | 9.1 |
| [`09-state-authorisation.puml`](09-state-authorisation.puml) | Authorisation sub-resource status | 9.2 |
| [`10-state-sca-challenge.puml`](10-state-sca-challenge.puml) | SCA challenge | 9.3 |
| [`11-data-model.puml`](11-data-model.puml) | Data model | 8 |
| [`12-seq-payment-initiation.puml`](12-seq-payment-initiation.puml) | Payment initiation and approval | 12.1 |
| [`13-seq-payment-cancellation.puml`](13-seq-payment-cancellation.puml) | Payment cancellation with its own SCA | 12.2 |
| [`14-state-transaction-status.puml`](14-state-transaction-status.puml) | Transaction status | 9.4 |

## Rendering

```sh
java -jar plantuml.jar -tpng -o out docs/design/puml/*.puml
```

Rendered with PlantUML 1.2026.8. Images are not committed: the `.puml` sources
are, and the pictures are regenerated.

## Relation to the LikeC4 model

The C4 and sequence diagrams here overlap with the views in
[`../likec4/`](../likec4/), on purpose and with different jobs. These files are
the fixed pictures embedded in the document, one diagram per file, laid out for
the page. The LikeC4 model is one model with many views, browsable and
navigable, and it is the one to change when the architecture changes.

Sequence numbering is shared, so `03-seq-device-enrolment.puml` and the
`deviceEnrolment` view are the same journey. **Keeping them in step is manual** —
nothing generates one from the other, so a change to a flow has to be made in
both.
