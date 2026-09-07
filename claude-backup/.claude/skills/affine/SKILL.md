---
name: affine
description: Finde, erstelle und organisiere AFFiNE-Wissen sicher. Nutze bei AFFiNE-Seiten oder -Notizen, Hermes Gehirn oder Wissenspflege.
---

# AFFiNE

Arbeite mit AFFiNE als lebendiger Wissensbasis: kurz, strukturiert und anhand
verifizierter Quellen. Lies vor dem Schreiben; bestätige externe Änderungen
immer durch einen Read-back.

## Ablauf

1. **Sitzung und Kontext prüfen** — verwende `current_user`, suche die Zielseite
   per Titel oder ID und lies sie vollständig. Nutze den Workspace-Baum nur zur
   Orientierung; leere Organize-Folder sind dort nicht verlässlich sichtbar.
2. **Ziel sauber wählen** — aktualisiere die angegebene Seite. Für neues,
   dauerhaftes Agentenwissen suche zuerst die bestehende Übersicht „Übersicht –
   Hermes Gehirn“ und lege die neue Seite als präzise benannte Kindseite mit
   diesem bestehenden Hub als Parent an. Erstelle keine parallelen Hubs oder
   Ersatzseiten allein wegen einer leeren Suche.
3. **Wissenslücken auflösen** — recherchiere verfügbare Quellen selbst. Wenn
   eine fehlende Information Inhalt, Zielseite oder Sicherheit wesentlich
   verändert, stelle genau eine Frage mit dem größten Klärungswert und erfinde
   nichts.
4. **Passend schreiben** — verwende die Sprache der Zielseite. Halte Meta- und
   Infobereiche kurz: Stichpunkte mit `**Label:** Wert`, keine Tabellen.
   Gliedere umfangreiche Themen als klar benannte Kindseiten.
5. **Strukturerhalt priorisieren** — ergänze einzelne Inhalte als Block. Ersetze
   eine ganze Seite nur, wenn die Struktur flach ist oder der Gewinn die
   möglichen Formatverluste rechtfertigt.
6. **Verifizieren** — lies nach jedem Write den exakten Zielinhalt zurück und
   prüfe Titel, Hierarchie und die wichtigen Fakten. Berichte Verluste,
   Konflikte oder nicht auflösbare Berechtigungsprobleme klar.

## Regeln

- Speichere keine Zugangsdaten, Tokens, Session-Werte oder rohen Agenten-Logs.
- Bewahre verifizierte Fakten beim Umstrukturieren; markiere Widersprüche statt
  sie still aufzulösen.
- Tags verknüpfen Themen; Kindseiten bilden die dauerhafte Navigation ab.
- Bei klarer Erstellungs- oder Änderungsanweisung direkt schreiben und danach
  verifizieren. Bei unklarem Ziel oder drohendem Datenverlust vorher fragen.
- Lade `${CLAUDE_SKILL_DIR}/references/authoring.md` vor jeder AFFiNE-Änderung
  mit struktureller oder potenziell verlustreicher Wirkung.
