# Document types

Choose the closest type from the reader's task. Sections are adaptive: keep
required information, rename or merge headings when that improves the reading
flow, and omit optional sections with no useful content.

## How-to guide

The reader wants to complete a known task.

Required information:

- outcome and scope
- prerequisites, access and starting state
- ordered steps with copyable commands or concrete actions
- a way to verify success

Add troubleshooting only for known failure modes. Keep explanations beside the
step they clarify.

## Runbook

The reader needs to diagnose or recover an operational system.

Required information:

- trigger or symptom and affected scope
- prerequisites, access and safety constraints
- diagnosis steps that separate likely causes
- recovery procedure
- verification of service health
- rollback or escalation boundary when recovery can fail

Lead with the first safe diagnostic or containment action. Put permissions,
backups and destructive-action warnings before any mutating command. Move
background and long logs to optional or expandable sections.

## Architecture or decision record

The reader needs to understand a system or why a choice was made.

Required information:

- current context and problem
- decision or architecture boundary
- relevant components and relationships
- consequences, risks and operational effects
- status and date when the source provides them

Include alternatives only if they were genuinely considered. Use an SVG when
it clarifies boundaries, flows or ownership.

## Project, feature or overview

The reader needs orientation and a path to the next action.

Required information:

- purpose and current state
- user-visible scope and explicit exclusions
- usage, setup or entry points relevant to the audience
- important dependencies, limits or risks
- links to deeper sources instead of duplicating them

For active work, distinguish current behavior from planned work. Use task lists
only for work someone can actually complete.

## Final check

A reader should be able to answer, without guessing:

1. What is this?
2. Why or when do I need it?
3. What must I know or do?
4. How do I know it worked or what follows from it?
