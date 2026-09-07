# XS2A specification

The specification the sandbox implements, vendored so that every section
reference in the design resolves against exactly the document the design was
written from.

| File | Document |
|---|---|
| `NextGenPSD2 XS2A Framework.pdf` | NextGenPSD2 XS2A Framework — Implementation Guidelines v1.3.16, 342 pages |

Published by the [Berlin Group](https://www.berlin-group.org/psd2-access-to-bank-accounts),
the joint initiative behind the NextGenPSD2 XS2A interface.

## How it is cited

Section numbers throughout the design refer to this document, and only to it:

- **In prose** — `§6.3.1`, as in
  [the system design document](../design/xs2a-sandbox-system-design.md).
- **In the models** — a `+"spec x.y"` tag, as in
  [`../design/eventstorming/`](../design/eventstorming/),
  [`../design/storymap/`](../design/storymap/) and
  [`../design/examplemap/`](../design/examplemap/).

Regulatory requirements that come from the law rather than from this
specification are tagged separately, `+"RTS art. n"`, referring to the EBA
Regulatory Technical Standards on strong customer authentication. OAuth 2.0 and
OpenID Connect behaviour is cited by RFC number.

The version matters: section numbering moves between releases, so a `+"spec 6.3.1"`
tag is only meaningful against v1.3.16. Replacing this PDF with another version
means re-checking every citation.
