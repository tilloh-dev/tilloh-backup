# Confluence Cloud

Nutze native Elemente des Cloud-Editors, statt sie mit eingefügtem Markdown
nachzuahmen. Erhalte Sprache und Konventionen des umgebenden Bereichs, solange
sie die Lesbarkeit nicht beeinträchtigen.

## Struktur

- Nutze H1–H6 in Reihenfolge; innerhalb einer betitelten Seite reichen
  normalerweise H2 und H3.
- Füge das Inhaltsverzeichnis-Element nur längeren Seiten hinzu, die von
  direkter Abschnittsnavigation profitieren.
- Nutze native Code-Snippets mit korrekter Sprache, Zeilenumbruch- und
  Zeilennummern-Einstellung.
- Nutze Tabellen für Vergleiche, nicht für Seitenlayout.
- Nutze Aktionselemente nur für Arbeit mit Verantwortlichen; ergänze Zuständige
  oder Datum, wenn bekannt.

## Hervorhebungen

- Nutze `info`-, `note`-, `success`-, `warning`- oder `error`-Panels nur für
  Informationen, die eine Unterbrechung verdienen.
- Nutze Status-Elemente für echte Zustände wie Entwurf, Aktiv oder Veraltet,
  nicht als farbige Etiketten.
- Stelle Logs, lange Beispiele und optionale Details in Expand-Abschnitte.
- Bevorzuge die aktuellen Panel-, Status- und Code-Snippet-Elemente gegenüber
  Legacy-Makros.

## Links und Diagramme

- Verlinke die konkrete Seite oder Überschrift, die die Leser brauchen. Nutze
  explizite Anker nur, wenn stabile Deep-Links nötig sind.
- `id`-Attribute an Überschriften überleben nicht. Schreibe keine Ankerlinks
  innerhalb derselben Seite.
- Die verfügbare API kann keine Anhänge erstellen. Plane ein Diagramm nie um
  einen Upload herum.
- Binde eine SVG als Base64-Data-URI ein:
  `<img width="760" alt="..." src="data:image/svg+xml;base64,...">`.
  Confluence speichert sie als `<ac:image><ri:url/></ac:image>` und rendert sie
  ohne Anhang und ohne externen Request.
- Setze `width` und `height` an der SVG-Wurzel für die intrinsische Größe und
  `width` am `<img>` für die Layoutgröße. Bette eine minimierte Kopie ein,
  behalte eine lesbare Quelldatei und nenne, wo diese Quelle liegt.
- Base64 ist etwa 1,34-mal so groß wie die Datei. Halte die SVG so klein, dass
  sie den Seitenkörper nicht dominiert.
- Drei Methoden funktionieren nicht: inline `<svg>` weist das Format ab; ein
  externes `src` rendert nur von einem öffentlich erreichbaren Host, die
  Raw-URL eines privaten Repositorys zeigt deshalb „preview not available“;
  Mermaid braucht eine Marketplace-App, und selbst wo eine installiert ist,
  kann sie beim Laden scheitern und einen Fehlerblock auf der Seite
  hinterlassen.
- `<img>` hat keine native Bildunterschrift. Setze eine einsätzige
  Bildunterschrift in einen `<em>`-Absatz direkt darunter.
- Alt-Text wird als `ac:alt` gespeichert, erscheint aber nicht beim Zurücklesen
  als Markdown. Prüfe ihn im `html`-Format.

## Schreibvorgänge

Eine klare Aufforderung zum Erstellen oder Aktualisieren autorisiert die
direkte Veröffentlichung. Lies unmittelbar vor einem API-Update die aktuelle
Seitenversion. Führt eine gleichzeitige Bearbeitung zu einem Konflikt, lies neu
und gleiche ab, statt blind erneut zu versuchen. Öffne die Seite nach dem
Schreiben erneut und prüfe Titel, Hierarchie, Panels, Links, Code-Snippets,
eingebettete Bilder und Diagrammplatzierung.

Kann die verfügbare API ein benötigtes natives Element nicht abbilden, nutze
den nächstliegenden semantischen Rückfall und benenne die Einschränkung.
Behaupte nicht, dass eingefügtes Markdown in Confluence verlustfrei hin und
zurück konvertiert wird.

Referenzen:

- [Elemente in eine Seite einfügen][elements]
- [Inhaltsverzeichnis-Makro einfügen][toc]
- [Aus dem Cloud-Editor entfernte Makros][legacy-macros]
- [Expand-Makro einfügen][expand]

[elements]: https://support.atlassian.com/confluence-cloud/docs/insert-elements-into-a-page
[toc]: https://support.atlassian.com/confluence-cloud/docs/insert-the-table-of-contents-macro
[legacy-macros]: https://support.atlassian.com/confluence-cloud/docs/learn-which-macros-are-being-removed
[expand]: https://support.atlassian.com/confluence-cloud/docs/insert-the-expand-macro
