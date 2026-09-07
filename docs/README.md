# Documentation

Two folders: the specification the sandbox implements, and the design that
says how.

| Folder | Holds |
|---|---|
| [`design/`](design/) | The system design document and every model behind it: event storms, story maps, example maps, the context map and domain models, and the C4 and PlantUML diagrams. |
| [`xs2a/`](xs2a/) | The NextGenPSD2 XS2A Framework specification the sandbox implements. |

Nothing here is generated. Every model is text under version control, written
in a grammar that diffs and reviews like code, so a change to the design shows
up as a reviewable diff rather than as a redrawn picture.

## Where to start

Read [`design/xs2a-sandbox-system-design.md`](design/xs2a-sandbox-system-design.md)
first: it carries the roles, the key decisions, the flows, the contracts and the
compliance increments, and it links to every model. The other folders are the
sources it is built from.
