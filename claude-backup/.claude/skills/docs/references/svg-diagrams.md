# SVG diagrams

Create a diagram when it lets the reader understand a relationship, flow,
boundary or responsibility faster than prose. Do not add one for a short list,
an obvious linear sequence or decoration.

## Before drawing

1. Write the single message the diagram must communicate.
2. Select only the components and connections needed for that message.
3. Prefer one readable diagram over a dense map of the entire system.
4. Copy the SVG template named by the main skill when no project convention
   exists.

## Design

- Use a descriptive `viewBox`, `role="img"`, `<title>` and `<desc>`.
- Use a self-contained SVG with no external fonts, scripts or remote assets.
- Keep the file small when the target platform inlines it. Strip comments, and
  put long descriptions in the platform's alt text rather than in `<desc>`.
- Default to a neutral solid canvas that remains legible in light and dark page
  themes.
- Reuse verified project colors when they retain sufficient contrast.
- Never encode meaning by color alone. Add labels, shapes or line styles.
- Keep labels short, use sentence case and maintain a clear reading direction.
- Design for the expected embed width. Text must render at 12 pixels or larger;
  stack the flow vertically or split the diagram when horizontal scaling would
  make it smaller.
- Avoid crossing connectors, clipped text, tiny type and unexplained
  abbreviations.
- Show a legend only when symbols are not self-explanatory.

## Placement

- Name the file for its message, for example `request-flow.svg`, not
  `diagram-1.svg`.
- Store it according to the target platform reference.
- Introduce the diagram in the preceding text. Add useful alt text and a
  one-sentence caption rather than repeating every node in prose.

## Verification

- Parse the SVG as XML.
- Render it in a browser or SVG renderer and inspect the result when tools allow.
- Check text contrast, spacing, arrow direction, labels, clipping and
  narrow-screen scaling.
- Confirm every node and edge is supported by the source material.
- After publishing, verify the exact embedded image at the destination.
