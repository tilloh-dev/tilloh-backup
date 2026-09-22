---
name: leserfreundlich
description: Reminder to shape any text written for human readers with textual and structural formatting so it can be scanned, understood and acted on. Use it every time a text artefact is created or revised, whatever the platform or length — Confluence pages, Markdown and README files, Jira tickets and comments, AFFiNE docs, PR descriptions, release notes, handover notes, meeting notes, e-mails, chat posts, commit bodies, code comments longer than a line. Trigger also on German phrasing ("Doku schreiben", "Ticket anlegen", "Seite erstellen", "Notiz verfassen", "Text formulieren", "beschreib das mal", "schreib das auf") and even when the user only asks for "a short text", "a few lines" or "just a description" — short texts are where formatting is skipped most often.
---

# leserfreundlich

A text is finished when a human reader finds what they need without reading all of it.
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
- **Cut the framing.** No "This document describes …", no "In summary …", no closing offer.
  The heading already says what the document is.
- **Write in the destination's language and register.** German page, German text;
  match the tone of the surrounding pages, tickets or threads.

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
reader what happened, what to do and where the risk is, publish. If not, restructure
before polishing sentences.
