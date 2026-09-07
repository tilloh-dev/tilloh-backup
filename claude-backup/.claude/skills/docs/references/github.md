# GitHub Markdown

Use GitHub Flavored Markdown and repository-relative links. Follow established
repository writing conventions when they are clearer than this fallback. Keep
the user-selected SVG diagram format unless the user explicitly overrides it.

## Structure

- Use one H1 for a standalone document, then H2 and H3 in order.
- GitHub provides an outline when a file has multiple headings. Add a manual
  table of contents only when the document is long and direct navigation helps.
- Keep paragraphs short. Use bullets for parallel facts and numbered lists for
  sequences.
- Use fenced code blocks with a language identifier. Separate commands from
  representative output.
- Use tables only for compact comparisons with stable columns.
- Use task lists only for actionable work with meaningful completion states.

## Highlights

Use at most one or two GitHub alerts in a normal document:

```markdown
> [!NOTE]
> Context the reader may otherwise miss.
```

Choose `NOTE`, `TIP`, `IMPORTANT`, `WARNING` or `CAUTION` by meaning. Never use
an alert as decoration or place ordinary content inside one.

## Links and diagrams

- Prefer relative links for files in the same repository and verify every path.
- Use descriptive link text instead of raw URLs when the destination is stable.
- Place SVG files beside the documentation under an existing asset convention.
  Fallback: `<document-directory>/assets/<document-name>/`.
- Embed with descriptive alt text and add a one-sentence italic caption when
  the diagram needs interpretation:

```markdown
![Request path from client to storage](assets/architecture/request-flow.svg)

*The API validates each request before writing to storage.*
```

## Verification

Check the rendered Markdown when browser access is available. At minimum, parse
links and SVG XML, inspect heading levels and confirm referenced files exist.

References:

- [GitHub writing and formatting syntax][github-syntax]
- [GitHub diagrams documentation][github-diagrams]

[github-syntax]: https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax
[github-diagrams]: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams
