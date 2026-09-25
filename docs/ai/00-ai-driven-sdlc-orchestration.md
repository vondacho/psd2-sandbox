# AI-Driven SDLC Orchestration Instructions

## Purpose

Use these instructions when a user asks AI to study a problem narrative or specification and propose a connected software solution.

The AI must produce reviewable software-intent artefacts rather than an unqualified final design. Human participants retain authority over domain facts, product priorities, behavioural decisions, boundaries, and consequential architecture choices.

## Minimal invocation

The user prompt may be as short as:

> Study the supplied problem narrative or specification. Follow the AI-driven SDLC instructions in `docs/ai/`. Produce a connected solution-design proposal, including the appropriate as-code artefacts, a use-case deck, a UX-sketch deck, a walking-skeleton pack, an MVP pack, a validation report, and a pull-request description. Preserve assumptions and open questions.

## Required inputs

Use all relevant sources supplied with the request:

- Problem narrative or specification
- Business objectives and expected outcomes
- UX research, journey maps, service blueprints, or accessibility constraints
- Existing domain and architecture models
- Technical contracts and repository context
- Policies, constraints, and production evidence

Do not infer that a missing detail is an accepted fact.

## Initial analysis

Before generating artefacts:

1. Summarise the problem and desired outcomes.
2. Identify actors, current journeys, constraints, systems, and available evidence.
3. Establish a shared vocabulary.
4. Separate facts, stakeholder claims, hypotheses, decisions, and open questions.
5. Identify contradictions and hotspots.
6. Propose stable identifiers that can connect the generated artefacts.
7. State which artefacts are justified and which are unnecessary for the current scope.

## Practice instruction sets

Load the doctrine, notation, and DSL for every practice used.

### Event Storming

- Doctrine: https://doc-es.obya.ch/doctrine
- Notation: https://doc-es.obya.ch/notation
- DSL: https://doc-es.obya.ch/dsl

### Story Mapping

- Doctrine: https://doc-sm.obya.ch/doctrine
- Notation: https://doc-sm.obya.ch/notation
- DSL: https://doc-sm.obya.ch/dsl

### Example Mapping

- Doctrine: https://doc-em.obya.ch/doctrine
- Notation: https://doc-em.obya.ch/notation
- DSL: https://doc-em.obya.ch/dsl

### Context Mapping and Domain Modelling

- Doctrine: https://ba-cm.obya.ch/doctrine
- Notation: https://ba-cm.obya.ch/notation
- DSL: https://ba-cm.obya.ch/dsl

### Use Case Mapping

- Notation and DSL: `docs/ai/notations/mindmap-notation.md` (Mermaid `mindmap`)
- Package: an HTML deck, as defined in `10-artifact-contract.md`

### UX Sketching

- Notation and DSL: `docs/ai/notations/wiremd-notation.md` (wiremd, rendered with `--style clean`)
- Package: an HTML deck, as defined in `10-artifact-contract.md`

These two practices have no separate doctrine. Their notation files state what each artefact is for and what it must not be used for; treat those sections as the doctrine.

Doctrine governs the meaning and quality of the model. Notation explains the modelling concepts and visual semantics. The DSL defines the exact generated file format.

Notation protects syntax. Doctrine protects the practice.

## Generation sequence

Generate only the artefacts justified by the problem, in this general order:

1. Problem analysis and journey mapping
2. Use case maps and the use-case deck
3. Event Storming Big Picture
4. Focused Process Modelling and System Design where required
5. Story Map and proposed release slices
6. Example Maps for stories requiring behavioural clarification
7. UX sketches for stories with a user-facing screen, and the UX-sketch deck
8. Context Map and domain models
9. Architecture models and technical contracts
10. Walking-skeleton and MVP delivery packs
11. Traceability manifest
12. Validation report and unresolved-question ledger

Use case maps come before Event Storming: they lay out who wants what from the system, and the storm then puts it in time. UX sketches come after Example Mapping: a screen should show the rules and examples the room agreed, not anticipate them.

Decks are packaging. Generate a deck from its source files after they change; never write content into a deck that its sources do not hold.

Treat every generated artefact as a proposal. Record its source inputs and the instructions used to produce it.

## General generation rules

- Preserve uncertainty and disagreement.
- Prefer the smallest useful artefact set.
- Do not duplicate the same meaning across several manually maintained sources.
- Keep stable identifiers when transforming or projecting information.
- Link every downstream artefact to its originating intent.
- Distinguish the current state from a proposed future state.
- Explain consequential inferences.
- Request human decisions when the evidence cannot establish the answer.

Read `10-artifact-contract.md` for required artefact content and traceability. Read `20-review-and-delivery-policy.md` for validation, delivery-pack, Git, and human-review rules.
