# AFFiNE

Use native blocks when the available AFFiNE tools support them. Treat Markdown
import and export as potentially lossy for richer blocks.

## Structure

- Use H2 and H3 for the normal page hierarchy beneath the page title.
- Prefer short paragraphs and simple bullet lists for metadata and summaries.
- Use tables only for true comparisons with stable columns; do not turn
  label/value information into a table.
- Use to-do blocks only for actionable work.
- Do not generate an embedded table of contents or depend on portable
  heading-anchor slugs.

## Highlights

- Use a callout sparingly for a critical note, warning or decision.
- Use blockquotes for quotations, not as generic decoration.
- Use code blocks with a language when the content is code or a command.
- Use internal links, block references or synced content only when the
  referenced identity is verified in the same workspace.

## Links and diagrams

- Upload SVGs to workspace storage, create an image block and place it directly
  after the text that introduces it.
- Add descriptive alt text and a short caption when the available block model
  supports them. Otherwise add the caption as the following paragraph.
- Confirm that the uploaded blob resolves and the image appears on the page.
- Do not use Mermaid.

## Writes

A clear create or update request authorizes the change. Read the page back after
writing and verify its title, hierarchy, links, callouts, list nesting and image
blocks.

Avoid replacing an entire page through Markdown when a targeted block edit can
preserve nested lists and native blocks. Before replacement, export the current
content and run `analyze_doc_fidelity`. If unsupported blocks could be lost,
prefer block edits; when preservation is impossible, explain the loss and ask
before replacing. Read back and verify the resulting structure.

References:

- [AFFiNE blocks][blocks]
- [AFFiNE docs][docs]
- [BlockSuite transformer and adapter][adapters]

[blocks]: https://docs.affine.pro/core-concepts/elements-of-affine/blocks
[docs]: https://docs.affine.pro/core-concepts/elements-of-affine/docs
[adapters]: https://docs.affine.pro/blocksuite-wip/store/transformer-and-adapter
