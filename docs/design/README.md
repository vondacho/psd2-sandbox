# Design

[`xs2a-sandbox-system-design.md`](xs2a-sandbox-system-design.md) is the document:
roles, key decisions, flows, contracts, security controls, state machines, the
sandbox layout and the seven ASPSP compliance increments. Everything else in
this folder is a model it is built from, kept as text so it diffs and reviews
like code.

| Folder | Grammar | Holds |
|---|---|---|
| [`eventstorming/`](eventstorming/) | `.eventstorm`, [doc-es.obya.ch/dsl](https://doc-es.obya.ch/dsl) | The two PSU journeys as a timeline of events, one lane per party. |
| [`storymap/`](storymap/) | `.storymap`, [doc-sm.obya.ch/dsl](https://doc-sm.obya.ch/dsl) | The backlog: activities, steps and stories, sliced into deliveries. |
| [`examplemap/`](examplemap/) | `.examplemap`, [doc-em.obya.ch/dsl](https://doc-em.obya.ch/dsl) | One map per story: business rules, worked examples, open questions. |
| [`domain/`](domain/) | `.ddd` / `.ddm`, [ba-cm.obya.ch/dsl](https://ba-cm.obya.ch/dsl) | The context map and the inside of each bounded context. |
| [`likec4/`](likec4/) | LikeC4, [likec4.dev/dsl](https://likec4.dev/dsl) | The C4 model: one source, many views, browsable in a viewer. |
| [`puml/`](puml/) | PlantUML | The rendered diagrams of the document: C4, sequences, state machines. |
| [`features/`](features/) | Gherkin | **Generated** from the example maps: one `.feature` per story, ready for a runner. |

## How the models chain

The models are not parallel views of the same thing. Each one is derived from
the one before it, and the link is mechanical enough to check:

```
eventstorming/  the journey as it happens, one column per moment
      |         each phase between two pivotal events becomes an activity,
      v         each timeline column becomes a step  (+"ES column n")
storymap/       activities > steps > stories, sliced into deliveries
      |         one story becomes one file, named after it; the story's
      v         as/want/so, delivery and tags are copied verbatim
examplemap/     rules, examples with Given/When/Then, open questions
      |         story > Feature, rule > Rule, example > Scenario;
      v         questions are not exported  (tools/emgherkin.py)
features/       executable specifications, one .feature per story

domain/         .ddd names the bounded contexts; one .ddm per context
                opens it up into aggregates, entities, values and enums

likec4/ puml/   the same systems and containers drawn as C4 and sequences
```

Because the derivation is mechanical, drift is detectable: a story map step
tagged `+"ES column 7"` must match a column that exists in the event storm, and
an example map's story title, `as`/`want`/`so`, delivery and tags must match the
story map entry it names.

## Numbers

| Model | Files | Contents |
|---|---|---|
| Event storms | 2 | 111 and 81 cards, 14 timeline columns each |
| Story maps | 3 | 12 activities, 28 steps, 126 stories |
| Example maps | 126 | 426 rules, 1594 examples, 5052 Given/When/Then steps, 100 open questions |
| Domain models | 1 `.ddd` + 8 `.ddm` | 8 bounded contexts, 19 aggregates, plus one unfilled stub (see [`domain/`](domain/)) |
| Feature files | 126 | 426 rules, 1594 scenarios, 5052 steps — generated, not hand-written |
| Diagrams | 3 `.c4` + 14 `.puml` | 14 LikeC4 views, 14 PlantUML diagrams |

Regenerate the example-map figures with
[`tools/emcheck.py`](../../tools/README.md), which also validates the files.
