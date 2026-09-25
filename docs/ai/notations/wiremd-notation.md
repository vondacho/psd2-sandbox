# Working with wiremd wireframes

You are being asked to read, write or change a wireframe — a low-fidelity
sketch of one screen, kept as text, in a Markdown dialect called **wiremd**.
This document is the whole of that notation as this repository uses it. Follow
it exactly: wiremd renders almost anything, so a mistake here does not fail —
it renders as the wrong control, which is worse.

## The notation: wiremd

A wiremd file is a Markdown file (`.md`). Everything standard Markdown does
still works; wiremd adds controls, containers and attributes on top.

```markdown
> **Screen:** SCR-CONSENT · **Story:** STORY-GRANT-CONSENT · **Owner:** Bank ASPSP
> **Presented in:** web browser, redirected from the TPP

![[_header.md]]

::: card

## :shield: Allow Acme Budget to access your accounts?

Acme Budget (TPP, licensed by BaFin) asks for:

- [x] Account list
- [x] Balances
- [ ] Transactions of the last 90 days

Accounts
[Select accounts______________v]

- CH93 0076 2011 6238 5295 7 — Private
- CH56 0483 5012 3456 7800 9 — Savings

Access valid until: |2026-12-24|{.warning} · Up to 4 reads a day

::: alert info
You can revoke this access at any time in the Bank Mobile App.
:::

[Allow]* [Deny]{.secondary}

:::

> **Question** (ask legal): must the 90-day transaction window be
> pre-selected, or is that a nudge the consent rules forbid?

> **Error state:** consent expired while the page was open →
> `::: alert error` + [Start again]*
```

**One file is one screen.** Controls are what the text *looks like*: a bracket
with underscores is a field, a bracket with words is a button, a bracket with a
URL is a link. The container a control sits in says where it sits on the
screen. A blockquote is never part of the screen — it is a note to the reader
about it.

### Controls

| Written as                               | Renders as                                |
|------------------------------------------|-------------------------------------------|
| `[Allow]`                                | button                                    |
| `[Allow]*` or `[Allow]{.primary}`        | primary button                            |
| `[Deny]{.secondary}` / `{.outline}`      | secondary / outline button                |
| `[Revoke]{variant:danger}`               | danger button                             |
| `[Sending...]{state:loading}`            | button in a state (`loading`, `disabled`) |
| `[Save]* [Cancel]`                       | button group — buttons on one line        |
| `[______________]`                       | text input; the underscores are the width |
| `[IBAN__________]`                       | text input with placeholder `IBAN`        |
| `[**************]`                       | password input                            |
| `[Your message...]{rows:4}`              | textarea                                  |
| `[Choose_______v]` + list right below    | dropdown; the list items are its options  |
| `- [ ] Label` / `- [x] Label`            | checkbox, unchecked / checked             |
| `- ( ) Label` / `- (*) Label`            | radio, unselected / selected              |
| `[[ Home \| *Accounts* \| [Sign in] ]]`  | navigation bar; `*…*` is the active item  |
| `[[ Home > Accounts > Consent ]]`        | breadcrumbs                               |
| `[[Back](./login.md)]`                   | a button that links to another screen     |
| `\|Active\|{.success}`                   | badge (`success` `warning` `error` `primary`) |
| `[#########_________] 45%`               | progress bar; `#` filled, `_` empty       |
| `:shield:`                               | icon, anywhere text goes                  |
| `![[_header.md]]`                        | include another file, before parsing      |

**The disambiguation rules** are the heart of the notation, because every
control is a pair of square brackets:

```text
[Text](url)      → link           (has a URL)
[Text]           → button         (no URL, no underscores)
[Text___v]       → dropdown       (underscores, ends in v)
[___] [Text___]  → text input     (underscores, no trailing v)
[***]            → password input (asterisks)
```

**A field's label is the line directly above it, with no blank line between.**
A blank line makes the label a paragraph of its own and the field unlabelled —
which renders, and is wrong.

### Attributes

A `{…}` directly after a control, a container opener or a heading, holding
space-separated parts:

- `.name` — a class: `.primary`, `.secondary`, `.outline`, `.right`,
  `.col-span-2`, and the badge variants.
- `key:value` — a property: `type:email`, `type:tel`, `type:number`,
  `type:date`, `type:search`, `type:password`, `rows:5`, `min:18`, `max:120`,
  `state:error`, `state:disabled`, `state:loading`, `variant:danger`.
- `word` — a flag: `required`.

Values cannot contain spaces: the attribute string is split on whitespace, and
nothing quotes.

### Containers

A container opens with `:::` and a single-word type on a line of its own, and
closes with a line holding only `:::`. Containers nest.

| Opener                        | Is                                                  |
|-------------------------------|-----------------------------------------------------|
| `::: card`                    | a bordered panel                                    |
| `::: hero`                    | a headline block                                    |
| `::: modal`                   | a dialog; put it at the end of the file             |
| `::: alert info`              | a message: `info`, `success`, `warning`, `error`    |
| `::: grid-3` / `::: grid-3 card` | 2–5 columns; each `###` heading starts a cell; `card` gives each cell card chrome |
| `::: row` / `::: row {.right}`   | children laid out on one line                    |
| `::: tabs` + `::: tab Label`  | a tabbed panel and its panels                       |
| `::: layout {.sidebar-main}`  | a fixed sidebar and a fluid main area, holding `::: sidebar` and `::: main` |
| `::: sidebar`, `::: footer`   | the regions they name                               |

An empty `###` (or `### {.right}`) is a legal empty grid cell, and the usual
way to push an action to the right of a section title.

### Formally

wiremd has no published grammar. It is Markdown (CommonMark, GFM tables)
parsed by remark, and then *recognised*: the transformer looks at the text of
each node and decides which control it is. The shape of a file, as far as this
repository relies on it:

```ebnf
File        = { Block } ;
Block       = Container | Annotation | Include | ? any Markdown block ? ;
Container   = ':::' , Type , [ Attributes ] , [ Words ] , Newline ,
              { Block } ,
              ':::' , Newline ;
Type        = ? one word: card | hero | modal | alert | grid-2 … grid-5 | row
                | tabs | tab | layout | sidebar | main | footer | … ? ;
Annotation  = '>' , ? Markdown ? ;           (* never part of the screen *)
Include     = '![[' , Path , ']]' ;          (* resolved relative to this file *)
Attributes  = '{' , Part , { ' ' , Part } , '}' ;
Part        = '.' , Name | Name , ':' , Value | Name ;
```

Reading it:

- **Unknown container types are not an error.** `::: panel` renders a generic
  container called `panel`. Use the types in the table above; a new one is a
  styling hole, not a new control.
- **Recognition is by shape, so a typo changes the control.** `[Select___]`
  without the trailing `v` is a text input; `[Allow] *` with a space is a button
  and a stray asterisk. Read a rendered preview after every change you cannot
  check by eye.
- **`|Label|` inside a table cell is a table column**, not a badge. Say the
  status in words there.
- **When the last line in a container has bold, code or a link, put a blank
  line before the closing `:::`** — otherwise the parser can take the closer as
  part of the paragraph.
- **Includes are spliced in before parsing.** A missing file renders as a
  warning blockquote rather than failing, so check the path.

## Conventions in this repository

The notation above is wiremd's. What follows is how this repository uses it,
so that a wireframe connects to the rest of the artefacts.

- **Where they live.** `docs/ux/wireframes/<journey>/<screen>.md`, one screen per
  file. Files starting with `_` are partials — a header, a footer — included
  with `![[…]]`, never screens of their own.
- **The first block is the screen header**, a blockquote carrying the stable
  identifiers the traceability manifest points at: `**Screen:** SCR-…`,
  `**Story:**` the story it serves, `**Owner:**` the system that presents it
  (see `docs/context/adr.md` — the login and consent screens are presented in a
  web browser, the SCA screen on the enrolled device by the Bank Mobile App),
  and `**Presented in:**`. wiremd has no id syntax; the header is how a screen
  is named.
- **States are annotations, not extra screens.** `> **Loading state:** …`,
  `> **Empty state:** …`, `> **Error state:** …`. Give a state its own file
  only when it is a different screen to the user, not a different paint of the
  same one.
- **Questions stay questions.** `> **Question** (ask <team>): …` — the same
  *ask* spelling used on the event storm, story map and example map, so a
  question raised on a wireframe is findable next to the ones raised in a
  workshop. A wireframe that looks finished while its question is open is how
  an assumption becomes a requirement.
- **Real words, fake data.** Use the vocabulary in `docs/context/terminology.md`
  for every label a PSU reads. Use obviously fictional values: `Acme Budget`,
  test IBANs, dates in the future. Never a real customer, account or TPP.
- **Render with `--style clean`.** It is this repository's default, for every
  wireframe and every audience — pass it explicitly, because wiremd's own
  default is `sketch`:

  ```bash
  wiremd consent.md --style clean -o consent.html
  ```

  Use another style only when somebody asks for it, and only for that
  rendering. Style is a rendering choice, not content: nothing in a wireframe
  file names or depends on it. Never commit rendered HTML next to the source;
  it is a projection. The one rendering that is committed is the UX-sketch deck,
  generated from these files as `10-artifact-contract.md` describes.

## Changing somebody's wireframe

- **The whole file**, not a fragment. It replaces the file.
- **Change only what was asked for.** Everything else comes back
  byte-identical — blank lines matter to this notation more than to most.
- **Keep the annotations.** A blockquote is somebody's reasoning or somebody's
  unanswered question. Never delete a `**Question**` because the screen now
  seems to answer it; the room answers it, and the answer goes in the header or
  a note.
- **Never change a screen identifier.** Other artefacts point at it.
- **A wireframe is not a design.** Do not add colour, spacing or brand. The
  question a wireframe answers is *what is on the screen and in what order*;
  anything more makes a reviewer argue about the wrong thing.

---

*Written against wiremd 0.1.7 (akonan/wiremd, commit `85fe43e`): the syntax is
taken from its own reference, `skills/wireframe/references/syntax.md`, and
checked against `src/parser/`. Where a file and this document disagree, the
parser is right and this file is old. Nested containers, `::: row`, `::: tabs`
and hrefs inside `[[ ]]` need 0.1.7 or later.*
