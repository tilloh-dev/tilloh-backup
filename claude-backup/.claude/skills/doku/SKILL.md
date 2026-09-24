---
name: doku
description: Erstellt oder überarbeitet knappe, strukturierte Dokumentation. Nutze den Skill für README-Dateien, Markdown, Confluence, AFFiNE, Runbooks, Architekturentscheidungen, Projektdokumentation oder bei /doku.
---

# Doku

Erstelle das kürzeste vollständige Dokument, das eine Leserin oder ein Leser
verstehen und benutzen kann.

## Ablauf

1. **Sichten** — lies vor dem Schreiben das Ziel, das Quellmaterial, den
   zugehörigen Code und den Live-Zustand. Leite Plattform, Dokumenttyp,
   Zielgruppe und Leseraufgabe daraus ab. Recherchiere, was die verfügbaren
   Quellen beantworten können, statt zu fragen.
2. **Nur laden, was zutrifft** — lies
   `${CLAUDE_SKILL_DIR}/references/document-types.md`, danach `github.md`,
   `confluence.md` oder `affine.md` aus demselben Verzeichnis. Lade nicht jede
   Plattform-Referenz.
3. **Immer `leserfreundlich` laden** — rufe den Skill `leserfreundlich` über das
   Skill-Werkzeug auf, bevor du entwirfst oder schreibst. Er ist kein Zusatz,
   sondern die Gestaltungsregel für jeden Text dieses Skills: Lead-Satz,
   Überschriften nach Leserfrage, Listen, Tabellen, Codeblöcke, Hinweisboxen.
   Steht das Skill-Werkzeug nicht zur Verfügung, lies
   `${CLAUDE_SKILL_DIR}/../leserfreundlich/SKILL.md` direkt. Überspringe den
   Schritt nicht, weil das Dokument kurz wirkt; genau dort wird Struktur am
   häufigsten weggelassen.
4. **Wichtige Lücken klären** — würde eine fehlende Information Korrektheit,
   Vollständigkeit oder die Handlungsfähigkeit der Leser wesentlich
   beeinflussen, stelle die eine Frage, die die meisten abhängigen
   Entscheidungen freischaltet, und bewerte dann neu. Stelle immer nur eine
   Frage auf einmal. Schreibe nicht um eine ungeklärte Lücke herum und erfinde
   keine Fakten.
5. **Entwerfen** — stelle das Ziel der Leser an den Anfang, gruppiere einen
   Gedanken pro Abschnitt und verschiebe optionale Details nach hinten.
   Verwende die Sprache und den umgebenden Stil des Ziels.
6. **Schreiben** — bevorzuge kurze Absätze und zweckmäßige Listen, Links,
   Code, Tabellen oder Hinweisboxen gegenüber Textwänden. Erhalte verifizierte
   Fakten beim Umstrukturieren bestehender Inhalte und lege Widersprüche offen.
7. **Abläufe visualisieren** — erstelle eine SVG für einen dokumentierten
   Request-, Daten- oder Deployment-Ablauf mit mehreren bekannten Komponenten
   oder Grenzen. Erstelle sonst eine, wenn Beziehungen oder Zuständigkeiten
   visuell klarer werden. Lies `${CLAUDE_SKILL_DIR}/references/svg-diagrams.md`.
   Starte von `${CLAUDE_SKILL_DIR}/assets/diagram-template.svg`, wenn es keinen
   Projektstil gibt. Erstelle eine barrierefreie SVG; nutze niemals Mermaid.
8. **Prüfen** — kontrolliere Fakten, Kommandos, Pflichtinformationen, Links,
   Hierarchie und Darstellung. Lies nach einem externen Schreibvorgang die Seite
   zurück und bestätige Position, Größe und Alt-Text des Diagrammknotens. Du
   kannst gerenderte Ausgabe nicht sehen; ist die Darstellung selbst unsicher,
   veröffentliche einen Wegwerf-Entwurf mit den Kandidatenmethoden und frage die
   Autorin oder den Autor, was angezeigt wird. Es gibt keine Löschoperation,
   melde den Entwurf deshalb als aufzuräumenden Rest.

## Regeln

- Füge keine Einleitung hinzu, die das Dokument nur ankündigt.
- Wiederhole dieselbe Information nicht in Fließtext, Tabelle und Diagramm.
- Jedes visuelle Element muss den Lesern helfen, etwas zu finden, zu
  vergleichen, auszuführen oder zu vermeiden.
- Lasse leere Abschnitte weg. Füge kein generisches Fazit an.
- Eine klare Aufforderung, eine Datei oder Seite zu schreiben oder zu
  aktualisieren, autorisiert den Schreibvorgang; prüfe ihn, statt erneut zu
  fragen.
- Kein Text verlässt diesen Skill ohne den Skim-Test aus `leserfreundlich`:
  Überschriften, erste Zeile und fette Einstiege allein müssen sagen, was
  passiert ist, was zu tun ist und wo das Risiko liegt.
