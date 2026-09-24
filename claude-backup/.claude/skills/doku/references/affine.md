# AFFiNE

Nutze native Blöcke, wenn die verfügbaren AFFiNE-Werkzeuge sie unterstützen.
Behandle Markdown-Import und -Export bei reicheren Blöcken als potenziell
verlustbehaftet. Wo eine Seite im Workspace hingehört (Hub „Hermes Gehirn“,
Kindseiten, Tags, Organize-Folder) und was nicht hinein darf, regelt der Skill
`affine`; diese Referenz regelt nur, wie die Seite selbst geschrieben wird.

## Struktur

- Nutze H2 und H3 für die normale Seitenhierarchie unter dem Seitentitel.
- Bevorzuge kurze Absätze und einfache Aufzählungen für Metadaten und
  Zusammenfassungen.
- Nutze Tabellen nur für echte Vergleiche mit stabilen Spalten; mache aus
  Label/Wert-Informationen keine Tabelle.
- Nutze To-do-Blöcke nur für umsetzbare Arbeit.
- Erzeuge kein eingebettetes Inhaltsverzeichnis und verlasse dich nicht auf
  portable Überschriften-Anker.

## Hervorhebungen

- Nutze ein Callout sparsam für einen kritischen Hinweis, eine Warnung oder
  eine Entscheidung.
- Nutze Blockzitate für Zitate, nicht als allgemeine Dekoration.
- Nutze Codeblöcke mit Sprache, wenn der Inhalt Code oder ein Kommando ist.
- Nutze interne Links, Blockreferenzen oder synchronisierte Inhalte nur, wenn
  die referenzierte Identität im selben Workspace verifiziert ist.

## Links und Diagramme

- Lade SVGs in den Workspace-Speicher, erstelle einen Bildblock und platziere
  ihn direkt nach dem Text, der ihn einführt.
- Ergänze beschreibenden Alt-Text und eine kurze Bildunterschrift, wenn das
  verfügbare Blockmodell sie unterstützt. Andernfalls setze die
  Bildunterschrift als folgenden Absatz.
- Bestätige, dass der hochgeladene Blob auflöst und das Bild auf der Seite
  erscheint.
- Nutze kein Mermaid.

## Schreibvorgänge

Eine klare Aufforderung zum Erstellen oder Aktualisieren autorisiert die
Änderung. Lies die Seite nach dem Schreiben zurück und prüfe Titel,
Hierarchie, Links, Callouts, Listenverschachtelung und Bildblöcke.

Vermeide es, eine ganze Seite per Markdown zu ersetzen, wenn eine gezielte
Blockbearbeitung verschachtelte Listen und native Blöcke erhalten kann.
Exportiere vor einem Ersetzen den aktuellen Inhalt und führe
`analyze_doc_fidelity` aus. Könnten nicht unterstützte Blöcke verloren gehen,
bevorzuge Blockbearbeitungen; ist Erhalt unmöglich, erkläre den Verlust und
frage vor dem Ersetzen. Lies zurück und prüfe die entstandene Struktur.

Referenzen:

- [AFFiNE-Blöcke][blocks]
- [AFFiNE-Dokumente][docs]
- [BlockSuite Transformer und Adapter][adapters]

[blocks]: https://docs.affine.pro/core-concepts/elements-of-affine/blocks
[docs]: https://docs.affine.pro/core-concepts/elements-of-affine/docs
[adapters]: https://docs.affine.pro/blocksuite-wip/store/transformer-and-adapter
