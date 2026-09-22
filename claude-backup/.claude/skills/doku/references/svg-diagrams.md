# SVG-Diagramme

Erstelle ein Diagramm, wenn es die Leser eine Beziehung, einen Ablauf, eine
Grenze oder eine Zuständigkeit schneller verstehen lässt als Fließtext. Füge
keines für eine kurze Liste, eine offensichtliche lineare Abfolge oder als
Dekoration hinzu.

## Vor dem Zeichnen

1. Schreibe die eine Aussage auf, die das Diagramm vermitteln muss.
2. Wähle nur die Komponenten und Verbindungen aus, die diese Aussage braucht.
3. Bevorzuge ein lesbares Diagramm gegenüber einer dichten Karte des gesamten
   Systems.
4. Kopiere die im Haupt-Skill genannte SVG-Vorlage, wenn es keine
   Projektkonvention gibt.

## Gestaltung

- Nutze eine beschreibende `viewBox`, `role="img"`, `<title>` und `<desc>`.
- Nutze eine eigenständige SVG ohne externe Schriften, Skripte oder entfernte
  Ressourcen.
- Halte die Datei klein, wenn die Zielplattform sie inline einbettet. Entferne
  Kommentare und lege lange Beschreibungen in den Alt-Text der Plattform statt
  in `<desc>`.
- Nimm als Standard eine neutrale, einfarbige Fläche, die in hellen und dunklen
  Seitenthemen lesbar bleibt.
- Verwende verifizierte Projektfarben wieder, wenn sie ausreichenden Kontrast
  behalten.
- Kodiere Bedeutung nie allein über Farbe. Ergänze Beschriftungen, Formen oder
  Linienstile.
- Halte Beschriftungen kurz, nutze Satzschreibung und eine klare Leserichtung.
- Gestalte für die erwartete Einbettungsbreite. Text muss mit 12 Pixeln oder
  größer gerendert werden; staple den Ablauf vertikal oder teile das Diagramm,
  wenn horizontale Skalierung ihn kleiner machen würde.
- Vermeide sich kreuzende Verbinder, abgeschnittenen Text, winzige Schrift und
  unerklärte Abkürzungen.
- Zeige eine Legende nur, wenn Symbole nicht selbsterklärend sind.

## Platzierung

- Benenne die Datei nach ihrer Aussage, etwa `request-flow.svg`, nicht
  `diagram-1.svg`.
- Speichere sie gemäß der Referenz der Zielplattform.
- Führe das Diagramm im vorangehenden Text ein. Ergänze nützlichen Alt-Text und
  eine einsätzige Bildunterschrift, statt jeden Knoten im Fließtext zu
  wiederholen.

## Prüfung

- Parse die SVG als XML.
- Rendere sie in einem Browser oder SVG-Renderer und prüfe das Ergebnis, wenn
  die Werkzeuge das erlauben.
- Prüfe Textkontrast, Abstände, Pfeilrichtung, Beschriftungen, Beschneidung und
  Skalierung auf schmalen Bildschirmen.
- Bestätige, dass jeder Knoten und jede Kante durch das Quellmaterial gedeckt
  ist.
- Prüfe nach dem Veröffentlichen das exakt eingebettete Bild am Zielort.
