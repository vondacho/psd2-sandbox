# AI-Driven SDLC Review and Delivery Policy

## Purpose

These instructions govern validation, human review, delivery-pack generation, and Git integration for AI-generated software-intent artefacts.

## AI authority boundary

AI may analyse, propose, transform, validate, and explain impact.

AI must not silently decide:

- Domain facts that the supplied evidence does not establish
- Product priorities or release commitments
- Answers to open behavioural questions
- Bounded-context ownership or organisational responsibility
- Consequential architecture trade-offs
- Whether a generated proposal represents accepted intent

Mark every uncertain statement as a hypothesis, assumption, question, or recommendation.

## Walking-skeleton delivery pack

The walking skeleton is the smallest end-to-end implementation that proves the technical delivery path.

The pack should include:

- Technical learning objective
- Minimal end-to-end scenario
- Relevant stories and accepted examples
- Components and interfaces involved
- Deployment path
- Contract-validation approach
- Automated test path
- Observability and production evidence
- Risks, dependencies, and open questions
- Clear completion evidence

The walking skeleton may deliver limited business value. Its purpose is to prove architecture, integration, deployment, and feedback before the team expands the solution.

## MVP delivery pack

The MVP is the smallest coherent Story Map slice that delivers a meaningful user outcome and tests an important business or product hypothesis.

The pack should include:

- User outcome and learning hypothesis
- Included stories and excluded scope
- Pivotal events and journey coverage
- Accepted rules and examples
- Affected bounded contexts
- Components and interfaces
- Compatibility considerations
- Required tests
- UX and accessibility evidence, including the UX-sketch deck slides for every screen in the slice
- Operational measures
- Risks, dependencies, and unanswered questions

Do not define the MVP as a collection of high-priority tickets. Preserve a coherent journey slice and measurable outcome.

## Validation

Validate every generated file against its DSL or applicable schema.

Also check:

- Identifier uniqueness
- Referential integrity
- Vocabulary consistency within bounded contexts
- Compatibility of changed technical contracts
- Traceability from delivery scope to source intent
- Examples and tests connected to the correct source revision
- Architecture relationships against agreed policies
- Required production evidence

For the mindmap and wiremd sources and their decks, also check:

- Every use case map renders with Mermaid, has exactly one root, and uses the branch names that the artefact contract defines. Its `Scenarios` branch has the four kinds, `Normal`, `Related`, `Edge`, and `Error`, and exactly one `Normal` scenario. Every scenario identifier is unique across all use cases.
- Every wireframe renders with `wiremd --style clean` and produces no warnings: no unsupported node, and no missing include.
- Every identifier shown in a deck (use case, story, journey, screen) resolves to a source artefact.
- Every deck names the source revision that it was generated from, and that revision matches its sources.
- Every open question in the sources appears on the deck's closing slide.
- Every deck opens from disk and can be navigated and printed without a server.

Produce a validation report containing errors, warnings, assumptions, open questions, and decisions that require human authority.

## Human review gates

Route each decision to the appropriate reviewers:

- Product and UX review the problem, journey, outcomes, slices, and research interpretation.
- Product, domain experts, and compliance review the use cases through the use-case deck.
- Product, UX, and accessibility review the screens through the UX-sketch deck, together with the owners of the systems that present them.
- Domain experts review events, policies, language, boundaries, and invariants.
- Product, QA, and development review rules and examples.
- Architects and engineers review components, interfaces, compatibility, security, and operability.
- Delivery and operations review deployment, observability, and completion evidence.

Human reviewers may correct the generated visual models. The synchronized as-code files must capture those edits.

## Git proposal

Write generated and updated artefacts to a branch. Do not overwrite accepted intent without review.

The pull request should include:

- Problem and outcome summary
- Generated or changed artefacts
- Instruction files and versions used
- Links to the use-case deck and the UX-sketch deck, as the reviewers' entry points
- Traceability and impact summary
- Walking-skeleton and MVP proposals
- Validation results
- Assumptions and unresolved questions
- Required reviewers

After approval, merge records the accepted intent in Git.

## GitOps projections

Automation may use the accepted revision to generate or reconcile:

- Contextualised tickets
- Executable scenarios and test data
- Architecture views and documentation portals
- The use-case deck and the UX-sketch deck, whenever their sources change
- Interface mocks and compatibility tests
- Delivery configuration and policy checks
- Links to runtime signals and production evidence

Every projection should record its source revision. Detect drift and route meaningful differences back through review.
