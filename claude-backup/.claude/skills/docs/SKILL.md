---
name: docs
description: Create or revise concise, structured documentation. Use for README files, Markdown, Confluence, AFFiNE, runbooks, architecture decisions, project docs, or /docs.
---

# Docs

Create the shortest complete document a reader can understand and use.

## Process

1. **Inspect** — read the destination, source material, related code and live
   state before writing. Infer the platform, document type, audience and reader
   task. Research what the available sources can answer instead of asking.
2. **Load only what applies** — read
   `${CLAUDE_SKILL_DIR}/references/document-types.md`, then `github.md`,
   `confluence.md` or `affine.md` from that directory. Do not load every
   platform reference.
3. **Resolve important gaps** — if missing information would materially affect
   correctness, completeness or the reader's ability to act, ask the one
   question that unlocks the most dependent decisions, then reassess. Ask only
   one question at a time. Do not draft around an unresolved gap or invent
   facts.
4. **Design** — put the reader's goal first, group one idea per section and move
   optional detail later. Use the destination's language and surrounding style.
5. **Write** — prefer short paragraphs and purposeful lists, links, code, tables
   or callouts over walls of text. Preserve verified facts when restructuring
   existing content and expose contradictions.
6. **Visualize flows** — create an SVG for a documented request, data or
   deployment flow with multiple known components or boundaries. Otherwise,
   create one when relationships or responsibilities are clearer visually. Read
   `${CLAUDE_SKILL_DIR}/references/svg-diagrams.md`. Start from
   `${CLAUDE_SKILL_DIR}/assets/diagram-template.svg` when no project style
   exists. Create an accessible SVG; never use Mermaid.
7. **Verify** — check facts, commands, required information, links, hierarchy
   and rendering. After an external write, read the page back and confirm the
   diagram node's position, size and alt text. You cannot see rendered output;
   when the render itself is in doubt, publish a throwaway draft with the
   candidate methods and ask the author what displays. No delete operation
   exists, so report the draft as a leftover to clean up.

## Rules

- Do not add an introduction that merely announces the document.
- Do not repeat the same information in prose, a table and a diagram.
- Every visual element must help the reader find, compare, execute or avoid
  something.
- Omit empty sections. Add no generic conclusion.
- A clear request to write or update a file or page authorizes the write;
  verify it instead of asking again.
