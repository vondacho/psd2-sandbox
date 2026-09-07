# Event storms

The two PSU journeys as they happen in time. Written in the event-storming DSL
documented at [doc-es.obya.ch/dsl](https://doc-es.obya.ch/dsl); the practice is
described at
[dev-portal.obya.ch/doc/practices/event-storming](https://dev-portal.obya.ch/doc/practices/event-storming/).

| File | Journey | Cards |
|---|---|---|
| [`obi-psu-account-list-journey.eventstorm`](obi-psu-account-list-journey.eventstorm) | A PSU reads the accounts held at the Bank, through the TPP | 111 |
| [`obi-psu-payment-journey.eventstorm`](obi-psu-payment-journey.eventstorm) | A PSU pays from one of those accounts | 81 |

Both are at the **software design** level, which is cumulative: big picture
(events, actors), plus process modelling (commands, policies, read models), plus
software design (aggregates, bounded contexts, user interfaces).

## How to read one

**Lanes are parties, columns are moments.** Every lane shares one timeline, and
a column is one moment of the journey, written `@n`. Reading a column across all
lanes tells you what every party is doing at that instant; reading a lane down
the file tells you one party's whole story.

Both journeys use 14 columns, mapped in the comment at the top of each file.
The parties are the same in both, with the ledger joining for payments:

`PSU` · `TPP` · `OIDC` · `Bank CIAM` · `Bank mobile app` · `Bank XS2A`
(· `Bank core banking`, payment journey only)

**Tags carry the meaning that the shape cannot.**

| Tag | Means |
|---|---|
| `+pivotal` | The event that closes a phase. The story map turns each phase into an activity. |
| `+alternative` | A branch: the journey can end here, or go another way. |
| `+"spec x.y"` | A citation to the NextGenPSD2 XS2A Implementation Guidelines v1.3.16. |

A `hotspot` card is a question nobody could answer during the session. It stays
in the file rather than being resolved silently, and is tagged with who can
answer it (`+"ask bank"` and so on).

## What depends on this

The story maps in [`../storymap/`](../storymap/) use these files as their
backbone: each phase between two pivotal events becomes an activity, and each
timeline column becomes a step, tagged `+"ES column n"`. A step's column tag
must name a column that exists here — that is what keeps the backlog anchored
to the journey rather than drifting into a wish list.

The mapping is tabulated in
[the system design document](../xs2a-sandbox-system-design.md), under
"How the story map follows the event storm".
