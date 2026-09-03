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
- Before uploading, verify that the author may add attachments and that the SVG
  fits the tenant's current attachment-size limit.
- Upload SVGs as page attachments and embed them next to the text they clarify.
- Set descriptive alt text and a short caption. Confirm both the attachment and
  rendered image after publishing.
- Do not assume Mermaid support. It normally requires a Marketplace app.

## Writes

A clear create or update request authorizes direct publication. Read the current
page version immediately before an API update. If a concurrent edit causes a
conflict, reread and reconcile instead of blindly retrying. After writing,
reopen the page and verify its title, hierarchy, panels, links, code snippets,
attachments and diagram placement.

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
