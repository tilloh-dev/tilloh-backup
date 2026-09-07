# AFFiNE Authoring und Wissenspflege

Diese Referenz enthält die bewährten Regeln der AFFiNE-Wissenspflege durch
Marie. Sie ergänzt `SKILL.md`; sie ersetzt weder einen Read-back noch die
aktuellen Rechte des eingeloggten Kontos.

## Vor jedem Write

1. Sitzung mit `current_user` prüfen.
2. Zielseite und ihre aktuelle Struktur mit `read_doc` lesen.
3. Bei Seitenersatz zusätzlich `analyze_doc_fidelity` ausführen und den
   bestehenden Inhalt exportieren.
4. Ermitteln, ob ein gezielter Block-Edit die Struktur besser erhält als ein
   Markdown-Ersatz.

Wenn die Sitzung abgelaufen ist, keine Zugangsdaten erfragen oder erfinden. Den
Authentifizierungsblocker klar melden. Ein erfolgreiches API-Ergebnis allein
beweist keine korrekte Wissenspflege.

## Sichere Schreibwege

- **Kleine Ergänzung in verschachteltem Inhalt:** Block hinzufügen oder gezielt
  ändern.
- **Neue, zusammenhängende Wissenseinheit:** Seite aus Markdown als Kindseite
  erstellen.
- **Flache Seite umfassend überarbeiten:** Gesamtersatz erst nach
  Fidelity-Analyse.
- **Unvermeidbarer Verlust nativer Blöcke:** Verlust erklären und vorher
  Bestätigung einholen.

Nach jeder Änderung Zielseite erneut lesen. Bei neu erstellten oder verlinkten
Kindseiten beide Ziele zurücklesen: die Parent-Seite und die Kindseite. Prüfen,
dass die Kindseite mit dem vorgesehenen Parent verknüpft ist.

## Hermes Gehirn

- Das „Hermes Gehirn“ ist die zentrale Übersicht für dauerhaftes gemeinsames
  Agentenwissen. Vor dem Anlegen per Titel oder bekannter ID live auflösen.
- Eine neue Wissenseinheit bekommt eine eigene, präzise benannte Kindseite.
  Die Übersicht bleibt kurz und navigierbar.
- Marie pflegt die gemeinsame Wissensstruktur. Dokumentiere verifizierte
  Entscheidungen dort, aber keine temporären Chat-Verläufe oder Rohdaten.
- Projektübersichten bleiben lesbar; Architektur-, Migrations-, Sicherheits-
  und Betriebsdetails gehören auf klar abgegrenzte Kindseiten.

## Stil und Grenzen

- Meta-Informationen als kurze Bulletpoints, nicht als Tabellen.
- Featurelisten als To-do-Checkboxen, wenn sie tatsächlich Arbeitsstand
  darstellen.
- Dokumentiere Messwerte mit Quelle und Zeitpunkt; Vermutungen als solche.
- Organize-Folder sind keine normalen Dokumente. Eine leere Suche beweist nicht,
  dass ein Ordner fehlt. Erzeuge deshalb niemals automatisch eine gleichnamige
  Root-Seite.
- Seitenersatz kann Listenhierarchien abflachen. Bei wichtigen Verschachtelungen
  den Blockweg bevorzugen.
- Keine Credentials, PATs, Auth-Cookies, privaten Session-Dumps oder Geheimnisse
  in AFFiNE speichern.
