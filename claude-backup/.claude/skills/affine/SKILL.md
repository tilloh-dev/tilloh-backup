---
name: affine
description: Finde, organisiere und pflege Wissen im AFFiNE-Workspace sicher. Nutze bei AFFiNE-Seiten oder -Notizen, beim Suchen oder Umhängen von Seiten, bei Tags, Ordnern und Sammlungen, beim "Hermes Gehirn" oder bei Wissenspflege. Wie eine einzelne Seite geschrieben wird, regelt der Skill doku; dieser Skill regelt, wo sie hingehört und was nicht hinein darf.
---

# AFFiNE

Dieser Skill kennt den Workspace: seine Struktur, seinen Hub und seine Grenzen.
Das Schreiben von Seiteninhalt (Blockmodell, Fidelity-Analyse, Read-back,
Markdown-Verluste) steht in `doku` unter `references/affine.md`; lade es vor
jedem Write und wiederhole es hier nicht.

## Ablauf

1. **Sitzung prüfen** — `current_user`. Ist die Sitzung abgelaufen, melde den
   Blocker und erfrage oder erfinde keine Zugangsdaten. Ein erfolgreiches
   API-Ergebnis allein beweist noch keine korrekte Wissenspflege.
2. **Ziel live auflösen** — suche die Seite per Titel oder bekannter ID und lies
   sie vollständig. Der Workspace-Baum dient nur der Orientierung: leere
   Organize-Folder sind dort nicht verlässlich sichtbar, und eine leere Suche
   beweist nicht, dass etwas fehlt. Lege deshalb nie automatisch eine
   gleichnamige Root-Seite an.
3. **Einordnen** — aktualisiere die angegebene Seite. Für neues, dauerhaftes
   Agentenwissen suche zuerst die bestehende Übersicht „Übersicht – Hermes
   Gehirn“ und lege die neue Seite als präzise benannte Kindseite unter diesem
   Hub an. Erstelle keine parallelen Hubs oder Ersatzseiten wegen einer leeren
   Suche.
4. **Schreiben** — nach `doku` (Dokumenttyp, Blöcke, Read-back). Bei
   erstellten oder verlinkten Kindseiten beide Ziele zurücklesen, Parent und
   Kind, und prüfen, dass die Kindseite am vorgesehenen Parent hängt.

## Struktur des Workspaces

- Das „Hermes Gehirn“ ist die zentrale Übersicht für dauerhaftes gemeinsames
  Agentenwissen. Marie pflegt diese Struktur; dokumentiere dort verifizierte
  Entscheidungen, keine Chat-Verläufe oder Rohdaten.
- Die Übersicht bleibt kurz und navigierbar. Architektur-, Migrations-,
  Sicherheits- und Betriebsdetails gehören auf klar abgegrenzte Kindseiten.
- Tags verknüpfen Themen quer; Kindseiten bilden die dauerhafte Navigation.
- Organize-Folder sind keine Dokumente. Behandle sie nicht wie Seiten und
  ersetze sie nicht durch Seiten.

## Grenzen

- Speichere keine Zugangsdaten, PATs, Auth-Cookies, Session-Werte oder rohen
  Agenten-Logs in AFFiNE.
- Dokumentiere Messwerte mit Quelle und Zeitpunkt; Vermutungen als solche.
- Bewahre verifizierte Fakten beim Umstrukturieren; markiere Widersprüche,
  statt sie still aufzulösen.
- Bei klarer Anweisung direkt schreiben und danach verifizieren. Bei unklarem
  Ziel oder drohendem Datenverlust vorher genau eine Frage stellen.
