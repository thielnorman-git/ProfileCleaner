🧭 Projektübersicht
🔩 Verzeichnisstruktur
ProfileCleaner\
│
├── ProfileCleaner.psd1
├── ProfileCleaner.psm1
│
├─ GUI\
│   ├─ Start-GUI.ps1
│
├─ Jobs\
│   ├─ Cleanup-DMSTempFolder.json
│   ├─ Cleanup-Downloads.json
│   └─ (weitere Jobdefinitionen)
│
├─ Logs\
│   └─ (automatisch erzeugt)
│       └─ Session-2025-10-29_19-00\
│           ├─ ProfileCleaner.log
│           ├─ Cleanup-*.csv
│           ├─ UPM_Cleanup-*.csv
│           ├─ Merged_SessionData.csv
│           └─ Merged_SessionData.html
│
└─ Modules\
    ├─ Write-Log.psm1
    ├─ Get-FolderSize.psm1
    ├─ Find-ProfileFolder.psm1
    ├─ Remove-OldUPMProfiles.psm1
    └─ Merge-ProfileCleanerSessionCSVs.psm1

🧠 Funktionslogik
1️⃣ Start-GUI.ps1

Das Hauptskript mit XAML-GUI.

Liest Job-Definitionen aus \Jobs.

Kombiniert Basisordner mit Pfadangaben aus den Jobs → ergibt die effektiven Arbeitsverzeichnisse.

Steuert den Ablauf:

GUI startet Jobs.

Jeder Job ruft ein Modul auf (z. B. Find-ProfileFolder).

Während der Laufzeit schreibt das GUI Live-Logs in die Oberfläche.

Nach Abschluss wird die Zusammenfassung mit Merge-ProfileCleanerSessionCSVs erzeugt.

Abbrechen-Button setzt $global:CancelRequested = $true, was sofort von allen Modulen respektiert wird.

Globale Variablen:

$global:ProfileCleanerSessionPath   # Session-Verzeichnis (z. B. Logs\Session-2025-10-29_19-00)
$global:LogFile                     # zentrales Logfile (ProfileCleaner.log)
$global:CancelRequested             # steuert Abbruch

2️⃣ Write-Log.psm1

Einheitliche Logging-Funktion.
Schreibt Zeitstempel, Level (INFO, WARN, DEBUG, ERROR)
in die Datei $global:LogFile.
Bei Konsolenstart zusätzlich farbig nach Level.

3️⃣ Get-FolderSize.psm1

Hilfsmodul, das die Größe eines Ordners rekursiv ermittelt und als [PSCustomObject] zurückgibt.
Verwendet wahlweise MB, KB oder GB.

4️⃣ Find-ProfileFolder.psm1

Wird für „normale“ Bereinigungsjobs genutzt.

Erwartet:

RootPath (Basisverzeichnis),

SubFolder (z. B. AppData\Roaming\Temp),

Label (Jobname),

optional -DryRun.

Ermittelt alle Benutzerprofile, deren Zielordner existiert,
misst deren Größe, schreibt pro Job ein CSV ins Sessionverzeichnis,
löscht Ordner oder führt Simulation durch.

5️⃣ Remove-OldUPMProfiles.psm1

Wird für Cleanup-Jobs vom Typ "UPMCleanup" genutzt.

Durchläuft eine oder mehrere Wurzeln (RootPaths[]),
vergleicht LastWriteTime mit DaysOld,
löscht alte UPM-Profile oder simuliert bei -DryRun.

Exportiert Ergebnisse als UPM_Cleanup-*.csv ins Sessionverzeichnis.

6️⃣ Merge-ProfileCleanerSessionCSVs.psm1

Sammelt alle CSVs im aktuellen Sessionordner.

Führt sie in einer Datei Merged_SessionData.csv zusammen.

Baut daraus einen sortierbaren HTML-Bericht (Merged_SessionData.html)
mit interaktiven Spalten und numerischer Sortierung.

Gibt den Pfad zur HTML-Datei zurück, damit die GUI sie anzeigen oder loggen kann.

🧩 Datenfluss
GUI → Job → Modul → CSV + Log → Merge → HTML-Report


Jede Session ist vollständig isoliert:
Sämtliche temporären CSVs und Logs liegen unterhalb eines Session-Unterordners.
Das bedeutet, du kannst vergangene Durchläufe jederzeit nachvollziehen.

🧰 Fehlerbehandlung

Alle Module verwenden try/catch mit Write-Log auf [ERROR].

GUI zeigt dieselben Zeilen im Logfenster farbig an.

Fehlende Pfade, unlesbare Jobs oder Modulfehler bremsen nicht den gesamten Durchlauf.

✅ Zusammenfassung

Eine GUI, die interaktiv Joblisten steuert und Logs farbig anzeigt.

Module, die voneinander unabhängig, aber konsistent loggen.

Einen Report-Generator, der übersichtliche HTML-Berichte erzeugt.

Eine saubere Trennung von GUI-Logik, Business-Logik und Reporting.