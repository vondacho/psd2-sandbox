# Story maps

The backlog: what has to be built, ordered by the journey rather than by
component. Written in the story-mapping DSL documented at
[doc-sm.obya.ch/dsl](https://doc-sm.obya.ch/dsl); the practice is described at
[dev-portal.obya.ch/doc/practices/story-mapping](https://dev-portal.obya.ch/doc/practices/story-mapping/).

| File | Scope | Activities | Steps | Stories |
|---|---|---|---|---|
| [`obi_psu-account-list-journey.storymap`](obi_psu-account-list-journey.storymap) | Building the system behind the PSU account-list journey, end to end | 6 | 16 | 90 |
| [`obi-psu-payment-journey.storymap`](obi-psu-payment-journey.storymap) | The Bank's payment initiation service, PISP-facing (increments 4 and 5) | 4 | 7 | 20 |
| [`obi_aspsp-interface-conformance.storymap`](obi_aspsp-interface-conformance.storymap) | What the XS2A interface owes every TPP whatever the service (increments 3 and 7) | 2 | 5 | 16 |

## Structure

**Activity → step → story.** Activities run left to right in journey order and
form the backbone; steps are the columns under an activity; stories hang under a
step, ordered by priority, highest first.

The first two maps take their backbone from the event storms in
[`../eventstorming/`](../eventstorming/): each activity is a phase between two
pivotal events, each step is one timeline column, tagged `+"ES column n"`. The
conformance map has no backbone — its journey is a TPP operator integrating with
the interface, not a PSU using it, so its activities follow the integration
instead of a timeline.

**Deliveries slice the map horizontally.** A delivery is a release band; a story
ships in the band its `@` names. Stories with no `@` are known and not
committed.

| Map | Deliveries |
|---|---|
| Account list | `Walking skeleton`, `MVP`, `Hardening`, then `AIS reads`, `Consent models`, `Access rules` |
| Payment | `PIS core`, `PIS cancellation` |
| Conformance | `Authorisation resources`, `Conformance` |

The first three are the thinnest end-to-end path, the complete journey, and what
production needs. The rest are the compliance increments of
[the system design document](../xs2a-sandbox-system-design.md#17-aspsp-compliance-increments);
their declaration order is timeline order.

**Tickets are not invented here.** A `#` is issued by the tracker. The story
maps carry none until the tracker does.

## What depends on this

Every story has exactly one example map in [`../examplemap/`](../examplemap/),
named after it in kebab-case and filed under its activity. The example map
copies the story's `as`/`want`/`so`, its delivery and its tags verbatim, so the
two stay checkable against each other.
