# AI-Driven SDLC Artefact Contract

## Purpose

These instructions define the expected content and relationships of artefacts generated during an AI-driven software-development journey.

Generate an artefact only when it answers a useful question. Every generated file must have a clear source, owner, purpose, and relationship to the other models.

## Problem and journey material

Preserve the original narrative or specification as an authoritative input. Record UX research findings, evidence, assumptions, pain points, desired outcomes, and accessibility needs without converting hypotheses into facts.

Journey Mapping supplies the outside-in experience view. Use stable identifiers for actors, journey stages, touchpoints, outcomes, and research evidence.

## Event Storming

Generate `.eventstorm` files under `docs/journeys/` when domain behaviour needs exploration.

Use:

- Big Picture to explore the domain landscape, time, pivotal events, hotspots, actors, and external systems
- Process Modelling to develop commands, events, policies, alternate paths, and exceptions around an outcome
- System Design to assign software responsibility where the team needs implementation-level clarity

Do not resolve hotspots, remove meaningful disagreement, or invent domain facts.

## Story Mapping

Generate `.storymap` files under `docs/stories/`.

The Story Map should contain personas, activities, user steps, stories, alternatives, release objectives, coherent slices, and unscheduled work. Connect its backbone to the journey and pivotal events.

The Story Map owns product and release meaning. Ticketing owns operational workflow data. Generated tickets should retain the story identifier, journey position, release objective, source revision, and connected examples or contexts.

## Example Mapping

Generate `.examplemap` files under `docs/stories/` for stories requiring behavioural clarification.

Record the story, rules, concrete examples, boundary cases, and unanswered questions. Keep the `.examplemap` file as the discovery source. Treat executable scenarios and tests as downstream projections and evidence.

Do not answer open questions without evidence or invent accepted examples.

## Context Mapping and Domain Modelling

Generate strategic `.ddd` files and tactical `.ddm` files under `docs/domain/`.

The strategic model should describe domains, subdomains, bounded contexts, ownership, context relationships, and language seams. Tactical models should describe aggregates, entities, value objects, domain events, policies, and invariants where that detail supports delivery.

Represent relationship power honestly. Do not create tidy boundaries for symmetry. Do not define an aggregate without a meaningful invariant or transactional reason.

## Architecture and technical contracts

Place architecture artefacts under `docs/system/`:

```text
docs/system/
├── c4/
│   └── *.likec4
├── uml/
│   └── **/*.puml
└── api/
    ├── openapi/
    │   └── *.yaml
    ├── asyncapi/
    │   └── *.yaml
    ├── graphql/
    │   └── **/*
    └── wsdl/
        └── *
```

Use C4 or LikeC4 for structural views. Use PlantUML for focused dynamic, state, class, component, or deployment views. Generate interface contracts only where the proposed design requires them.

Connect each architecture element to its bounded context and to the stories, examples, or events that justify it.

## Stable identifiers and traceability

Preserve stable identifiers across transformations. Generate a traceability manifest under `docs/traceability/`.

The manifest should support navigation across this chain:

```text
Objective
  → Journey and evidence
  → Pivotal event
  → Story and release slice
  → Rule and example
  → Bounded context and invariant
  → Component and interface
  → Implementation and test
  → Production evidence
```

An entry may use a structure such as:

```yaml
objective: OBJ-01
journey: JRN-ONBOARDING
pivotal_event: EVT-APPLICATION-SUBMITTED
story: STORY-SUBMIT-APPLICATION
example_map: EXMAP-SUBMISSION
bounded_context: CTX-APPLICATION
component: CMP-SUBMISSION-API
delivery_pack: MVP-01
evidence: EVIDENCE-SUBMISSION-SLO
```

## Consistency

Consistency means that relationships are explicit and unexplained contradictions receive attention. Different disciplines may express different views of the same system.

Report:

- Missing or broken references
- Conflicting vocabulary
- Stories without journey context
- Rules without concrete examples
- Components without context ownership
- Interfaces without behavioural justification
- Delivery items without expected evidence
- Facts that lack a source
