---
name: leserfreundlich
description: Reminder to shape any text written for human readers with textual and structural formatting so it can be scanned, understood and acted on, and to keep only the information the reader needs — little prose, no history lessons, no meta-commentary. When an existing text is revised, the touched passages are trimmed as well. Use it every time a text artefact is created or revised, whatever the platform or length — Confluence pages, Markdown and README files, Jira tickets and comments, AFFiNE docs, PR descriptions, release notes, handover notes, meeting notes, e-mails, chat posts, commit bodies, code comments longer than a line. Trigger also on German phrasing ("Doku schreiben", "Ticket anlegen", "Seite erstellen", "Notiz verfassen", "Text formulieren", "beschreib das mal", "schreib das auf") and even when the user only asks for "a short text", "a few lines" or "just a description" — short texts are where formatting is skipped most often. Trigger also on requests to shorten or tighten a text ("kürzen", "straffen", "zu lang", "weniger Prosa", "überarbeite diese Seite/Doku").
---

# leserfreundlich

A text is finished when a human reader finds what they need without reading all of it,
and nothing is left in it that the reader does not need.
Plain prose blocks are the default output of a language model; a person skimming a ticket
between two meetings needs the opposite: structure that carries the meaning before the words do.

Apply this to every text artefact, not only to "documentation". A three-line Jira comment,
a PR body or a handover note is read under the same time pressure as a Confluence page.

## Before writing

Answer three questions in your head:

1. **Who reads this, and in which situation?** On-call at 3 a.m., a reviewer with ten PRs,
   a colleague who joins the project next month. The situation sets the depth and the order.
2. **What does the reader want to do afterwards?** Decide, execute, verify, understand.
   The first lines serve that action; background comes later or not at all.
3. **What does the destination render?** Use the strongest elements the platform supports
   instead of the plain-text lowest common denominator (see the table below).

## Structural levers

Pick the elements that let the reader skip, compare or execute. Every element earns its
place by doing one of those; decoration does not.

| Reader needs to … | Use |
|---|---|
| find the section for their question | headings that name the reader's question, not the topic ("How to roll back", not "Rollback") |
| grasp the outcome in five seconds | a one- or two-sentence lead (TL;DR, status, verdict) at the top |
| execute in order | numbered list, one action per step, copyable command per step |
| pick from options or scan facts | bulleted list, one idea per bullet, parallel wording |
| compare things along dimensions | table; rows are the things, columns the dimensions |
| copy something exactly | code block, never inline prose for commands, paths, error text |
| notice a risk or precondition | callout / panel / bold lead-in, placed *before* the step it guards |
| go deeper only if they want to | collapsible section, linked sub-page, appendix at the end |
| jump to the source | link on the noun, not "click here" |
| spot the key term while skimming | bold on the first few words of a bullet or paragraph, sparingly |

Order sections by the reader's task, not by how you found things out. Keep paragraphs to
three or four sentences; a paragraph break is the cheapest structural element there is.

## Textual levers

- **Answer first.** The conclusion, decision or status opens the text. The reasoning follows.
- **One idea per sentence**, about 20 words, with a verb. Split at "and", "but", "which".
- **Concrete over abstract.** Name the command, the file, the number, the person's role.
  "Some tests fail" tells nothing; "3 of 42 tests fail, all in `auth.spec.ts`" tells everything.
- **Active voice and a named actor.** "The cron job deletes …" instead of "… is deleted".
- **One term per thing.** Choose "cluster" or "environment" and keep it. Expand an acronym
  the first time.
- **Write in the destination's language and register.** German page, German text;
  match the tone of the surrounding pages, tickets or threads.

## Cut the prose

Every sentence has to pass these tests. Each is a yes/no question; a sentence that is merely
long is not a finding. Apply them while writing, so the prose never appears.

| Cut | The test |
|---|---|
| History lesson | Does it say what something **used to** be? |
| Route to the decision | Does it narrate how the decision was reached instead of stating it? |
| Meta-commentary | Is the subject the text itself ("This page describes …", "In summary …", a closing offer) rather than the thing it describes? |
| The obvious | Does the sentence before it, the heading or the code beside it already say so — including counts and lists the reader can see for themselves? |
| Second copy | Does this content already have an authoritative home? Replace it with a link to that home, never delete it outright. |

History is the content, and the first test does not apply, in release notes, changelogs,
handover and meeting notes.

**Keep** — cutting these is the failure mode of trimming:

- **The failure a rule prevents.** "`fit = on` silently offloads experts, ~30 % slower" is the
  reason the rule exists; the reader cannot re-derive it.
- **A measured number**, with its unit and what was measured.
- **A constraint from outside** the reader's control: a platform quirk, a vendor limit, a
  policy.
- **The one authoritative statement** of a rationale, at its home, however long it has to be.
- **Dead-end history.** A past state stays, condensed to one sentence, when it stops someone
  from re-entering a dead end or "correcting" something that is deliberate.
- **Certainty markers.** "unmeasured", "not verified", "tested on one machine only" look like
  filler and are the first words a trim removes. Without them a guess reads as fact.

## Revising an existing text

- **Scope:** trim the passages you touch and the section around them, not the whole text.
  Other sections may be someone else's work, and a reader who asked for one change cannot
  review a rewritten document.
- **Offer the rest:** if untouched sections fail the cut tests, ask once in one line whether
  the whole text should be trimmed too. If nothing else fails, don't ask.
- **Whole text on request:** "revise / shorten / tighten this page" means the whole text.
- **Report what went:** after trimming an existing text, give one line per cut category with
  one struck phrase as example, e.g. "History lesson: 2 sentences (›used to run via …‹)".
  No report for a newly written text — nothing was cut.

## Platform notes

| Destination | Use its strengths |
|---|---|
| Confluence | info/warning/note panels, expand macro for detail, status lozenges, page tree instead of one long page, table of contents on long pages |
| Jira ticket / comment | headings inside the description, checklists for acceptance criteria, `{code}` for logs and commands, panels for the blocker or decision |
| Markdown (README, PR, release notes) | headings, tables, fenced code with language tag, `<details>` for long output, task lists in PRs, relative links to files |
| AFFiNE | callout blocks, `**Label:** Wert` bullets for meta information, child pages for large topics, database blocks for lists with attributes |
| E-mail, chat post | first line = the ask or the answer, bullets for more than two items, one link per line |
| Commit body, code comment | why, not what; wrap at ~72 columns; a blank line between reasoning and references |

## Anti-patterns

- A wall of prose where a list or table would let the reader skip.
- Headings that mirror your investigation ("Analysis", "Findings", "Next steps") when the
  reader's questions are "Is it broken?", "What do I do?", "Who decides?".
- Formatting as decoration: every bullet bolded, tables with one column, emoji as bullets,
  three levels of nesting.
- Repeating the same fact in prose, a table and a diagram.
- Skipping structure because the text is "just a comment". Short texts get a lead sentence
  and a list too; they just get a smaller one.

## Together with other skills

- For a full document (README, runbook, architecture record, Confluence page) also load
  `doku`, which owns document types, platform references and diagrams. This skill is the
  reminder that applies even when `doku` does not fire.
- For AFFiNE writes, `affine` owns the page hierarchy and read-back rules.
- `klartext` shapes chat answers to the user; this skill shapes artefacts other people read.

## Check before publishing

Read only the headings, the first line and every bold lead-in. If that skim already tells the
reader what happened, what to do and where the risk is, go on; if not, restructure before
polishing sentences. Then read every remaining sentence against *Cut the prose*: one that
fails a test and is not on the keep list goes.
