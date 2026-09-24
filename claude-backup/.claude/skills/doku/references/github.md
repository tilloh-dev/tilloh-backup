# GitHub Markdown

Verwende GitHub Flavored Markdown und Repository-relative Links. Folge
etablierten Schreibkonventionen des Repositorys, wenn sie klarer sind als
dieser Rückfall. Behalte das von der Person gewählte SVG-Diagrammformat bei,
solange sie es nicht ausdrücklich ändert.

## Struktur

- Nutze eine H1 für ein eigenständiges Dokument, danach H2 und H3 in
  Reihenfolge.
- GitHub blendet bei mehreren Überschriften eine Gliederung ein. Füge ein
  manuelles Inhaltsverzeichnis nur hinzu, wenn das Dokument lang ist und
  direkte Navigation hilft.
- Halte Absätze kurz. Nutze Aufzählungen für parallele Fakten und nummerierte
  Listen für Abfolgen.
- Nutze umzäunte Codeblöcke mit Sprachkennung. Trenne Kommandos von
  repräsentativer Ausgabe.
- Nutze Tabellen nur für kompakte Vergleiche mit stabilen Spalten.
- Nutze Aufgabenlisten nur für umsetzbare Arbeit mit aussagekräftigem
  Erledigt-Zustand.

## Hervorhebungen

Verwende in einem normalen Dokument höchstens ein oder zwei GitHub-Alerts:

```markdown
> [!NOTE]
> Kontext, den die Leser sonst übersehen könnten.
```

Wähle `NOTE`, `TIP`, `IMPORTANT`, `WARNING` oder `CAUTION` nach Bedeutung.
Nutze einen Alert nie als Dekoration und stelle keinen gewöhnlichen Inhalt
hinein.

## Links und Diagramme

- Bevorzuge relative Links für Dateien im selben Repository und prüfe jeden
  Pfad.
- Nutze beschreibenden Linktext statt roher URLs, wenn das Ziel stabil ist.
- Lege SVG-Dateien neben der Dokumentation nach einer bestehenden
  Asset-Konvention ab. Rückfall: `<dokument-verzeichnis>/assets/<dokument-name>/`.
- Binde sie mit beschreibendem Alt-Text ein und ergänze eine einsätzige
  kursive Bildunterschrift, wenn das Diagramm Interpretation braucht:

```markdown
![Request-Pfad vom Client bis zum Speicher](assets/architecture/request-flow.svg)

*Die API validiert jeden Request, bevor sie in den Speicher schreibt.*
```

## Prüfung

Kontrolliere das gerenderte Markdown, wenn Browserzugriff möglich ist. Parse
mindestens Links und SVG-XML, prüfe Überschriftenebenen und bestätige, dass
referenzierte Dateien existieren.

Referenzen:

- [GitHub-Syntax für Schreiben und Formatierung][github-syntax]
- [GitHub-Dokumentation zu Diagrammen][github-diagrams]

[github-syntax]: https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax
[github-diagrams]: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams
