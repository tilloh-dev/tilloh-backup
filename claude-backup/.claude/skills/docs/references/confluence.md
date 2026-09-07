# Confluence Cloud

Use native Cloud Editor elements instead of imitating them with pasted
Markdown. Preserve the surrounding space's language and conventions unless they
harm readability.

## Structure

- Use H1–H6 in order; normally H2 and H3 are enough inside a titled page.
- Add the table-of-contents element only to longer pages that benefit from
  direct section navigation.
- Use native code snippets with the correct language, wrapping and line-number
  settings.
- Use tables for comparison, not page layout.
- Use action items only for owned work; include an assignee or date when known.

## Highlights

- Use `info`, `note`, `success`, `warning` or `error` panels only for information
  that deserves interruption.
- Use status elements for real states such as Draft, Active or Deprecated, not
  as colored labels.
- Put logs, long examples and optional detail in Expand sections.
- Prefer current Panel, Status and Code snippet elements over legacy macros.

## Links and diagrams

- Link the specific page or heading a reader needs. Use explicit anchors only
  when stable deep links are required.
- Heading `id` attributes do not survive. Do not write same-page anchor links.
- The available API cannot create attachments. Never plan a diagram around
  uploading one.
- Embed an SVG as a base64 data URI:
  `<img width="760" alt="..." src="data:image/svg+xml;base64,...">`.
  Confluence stores it as `<ac:image><ri:url/></ac:image>` and renders it with
  no attachment and no external request.
- Set `width` and `height` on the SVG root for the intrinsic size, and `width`
  on the `<img>` for the layout size. Inline a minified copy, keep a readable
  source file, and name where that source lives.
- Base64 is about 1.34x the file size. Keep the SVG small enough that it does
  not dominate the page body.
- Three methods do not work: inline `<svg>` is rejected by the format; an
  external `src` renders only from a publicly reachable host, so a private
  repository's raw URL shows "preview not available"; Mermaid needs a
  Marketplace app, and where one is installed it may still fail to load and
  leave an error block in the page.
- `<img>` has no native caption. Put a one-sentence caption in an `<em>`
  paragraph directly below it.
- Alt text is stored as `ac:alt` but does not appear in a markdown read-back.
  Verify it in `html` format.

## Writes

A clear create or update request authorizes direct publication. Read the current
page version immediately before an API update. If a concurrent edit causes a
conflict, reread and reconcile instead of blindly retrying. After writing,
reopen the page and verify its title, hierarchy, panels, links, code snippets,
embedded images and diagram placement.

If the available API cannot represent a required native element, use the
closest semantic fallback and state the limitation. Do not claim that pasted
Markdown is round-trip safe in Confluence.

References:

- [Insert elements into a page][elements]
- [Insert the table of contents macro][toc]
- [Macros removed from the Cloud Editor][legacy-macros]
- [Insert the Expand macro][expand]

[elements]: https://support.atlassian.com/confluence-cloud/docs/insert-elements-into-a-page
[toc]: https://support.atlassian.com/confluence-cloud/docs/insert-the-table-of-contents-macro
[legacy-macros]: https://support.atlassian.com/confluence-cloud/docs/learn-which-macros-are-being-removed
[expand]: https://support.atlassian.com/confluence-cloud/docs/insert-the-expand-macro
