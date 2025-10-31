# 🧹 ProfileCleaner

PowerShell-basiertes Tool zur automatisierten Bereinigung von Citrix UPM-Profilen mit WPF-GUI.

## ✨ Features

- ✅ **WPF-GUI** mit Live-Logging und Filterung
- ✅ **Job-System** - Flexible JSON-basierte Konfiguration
- ✅ **Dry-Run Modus** - Sichere Simulation vor der Ausführung
- ✅ **Parallel Execution** - Runspace-basierte Ausführung
- ✅ **HTML-Reports** - Sortierbare Tabellen für Analyse
- ✅ **CSV-Export** - Excel-kompatible Berichte
- ✅ **Cancel-Funktion** - Abbruch während der Ausführung
- ✅ **Memory-Safe** - Runspace Disposal implementiert

---

## 🚀 Quick Start

```powershell
# 1. In Projekt-Verzeichnis wechseln
cd C:\tmp\ProfileCleaner\ProfileCleaner

# 2. GUI starten
.\GUI\Start-GUI.ps1

# 3. Basisordner eingeben (z.B. C:\Profiles)
# 4. Jobs auswählen
# 5. Dry-Run aktivieren (empfohlen für ersten Test)
# 6. Start klicken
```

---

## 📂 Projektstruktur

```
ProfileCleaner\
│
├── ProfileCleaner.psd1          # Modul-Manifest
├── ProfileCleaner.psm1          # Haupt-Modul
├── Test-JobLoading.ps1          # Job-Validierungs-Test
│
├── GUI\
│   └── Start-GUI.ps1            # WPF-GUI Hauptdatei
│
├── Jobs\                        # Job-Definitionen (JSON)
│   ├── README.md                # Job-System Dokumentation
│   ├── Job-DMS_Temp.json
│   ├── Job-excluded-Downloads.json
│   ├── Job-remove-oldUPMProfiles.json
│   └── ... (15 ProfileFolder + 1 UPMCleanup)
│
├── Logs\                        # Auto-generierte Session-Logs
│   └── Session-2025-10-30_14-30\
│       ├── ProfileCleaner.log
│       ├── Cleanup-*.csv
│       ├── UPM_Cleanup-*.csv
│       ├── Merged_SessionData.csv
│       └── Merged_SessionData.html
│
└── Modules\                     # PowerShell Module
    ├── Write-Log.psm1
    ├── Get-FolderSize.psm1
    ├── Find-ProfileFolder.psm1
    ├── Remove-OldUPMProfiles.psm1
    └── Merge-ProfileCleanerSessionCSVs.psm1
```

---

## 🎯 Job-Typen

### 1️⃣ ProfileFolder
Bereinigt spezifische Unterordner in Benutzerprofilen.

**Beispiel:** Downloads, Browser-Caches, Temp-Ordner

```json
{
    "Label": "excluded-Downloads",
    "Type": "ProfileFolder",
    "SubFolder": "UPM_Profile\\Downloads",
    "RootPaths": ["CTX-Profiles\\ZDRS\\"],
    "Enabled": true
}
```

### 2️⃣ UPMCleanup
Entfernt alte UPM-Profile basierend auf LastWriteTime.

**Beispiel:** Profile älter als 30 Tage

```json
{
    "Label": "UPMProfileCleanup",
    "Type": "UPMCleanup",
    "DaysOld": 30,
    "Enabled": true
}
```

📖 **Detaillierte Job-Dokumentation:** `Jobs\README.md`

---

## 🔧 Module

### Write-Log.psm1
- Zentrale Logging-Funktion
- GUI-Integration (Live-Updates)
- Konsolen-Ausgabe mit Farben
- Level: INFO, WARN, ERROR, DEBUG

### Find-ProfileFolder.psm1
- Durchsucht Profile nach Unterordnern
- Berechnet Größen
- Löscht/Simuliert Löschung
- CSV-Report-Generierung
- Schreibschutz-Entfernung

### Remove-OldUPMProfiles.psm1
- Entfernt alte UPM-Profile
- Age-basiertes Filtering
- Statistik-Tracking
- CSV-Report mit Zeitstempel

### Merge-ProfileCleanerSessionCSVs.psm1
- Zusammenführung aller CSV-Reports
- HTML-Report mit sortierbaren Spalten
- Auto-Open nach Fertigstellung

### Get-FolderSize.psm1
- Rekursive Größenberechnung
- Unterstützt KB, MB, GB
- Error-Handling bei Berechtigungsproblemen

---

## 📊 Aktuell konfigurierte Jobs

### ProfileFolder Jobs (15)
- DMSTempFolder
- excluded-BasisApp
- excluded-Downloads
- excluded-FirefoxProfiles
- excluded-LoyHutz-App
- Microsoft Edge Caches (6 verschiedene)
- excluded-roaming-iMedOne Cache
- excluded-WindowsWebCache
- MicrosoftEdgeBackups
- NCHSoftwareFolder

### UPMCleanup Jobs (1)
- UPMProfileCleanup (30 Tage Schwellenwert)

**Test:** `.\Test-JobLoading.ps1`

---

## 🛡️ Sicherheit

### ✅ Implementierte Sicherheitsmaßnahmen
- **Pfad-Validierung** - Existenz und Schreibrechte werden geprüft
- **Dry-Run Modus** - Simulation vor echten Änderungen
- **Try/Catch** - Fehlerbehandlung in allen kritischen Bereichen
- **Cancel-Funktion** - Sofortiger Abbruch möglich
- **Detailed Logging** - Vollständige Nachvollziehbarkeit
- **CSV-Reports** - Dokumentation aller Aktionen

### ⚠️ Empfehlungen
1. **Backup erstellen** vor dem ersten Produktiv-Einsatz
2. **Dry-Run testen** mit echten Daten
3. **Logs prüfen** nach jedem Durchlauf
4. **Schrittweise aktivieren** - Nicht alle Jobs auf einmal

---

## 🐛 Behobene Probleme (Oktober 2025)

### Kritische Fixes
- ✅ **Runspace Memory Leak** - DispatcherTimer für Disposal
- ✅ **$PSScriptRoot Override** - Verwendung der eingebauten Variable
- ✅ **Fehlende Fehlerbehandlung** - Try/Catch in allen Job-Ausführungen
- ✅ **UTF8-BOM Encoding** - Excel-Kompatibilität für CSV
- ✅ **Parameter-Inkonsistenz** - UPMCleanup DaysOld statt DaysThreshold
- ✅ **Schreibschutz-Probleme** - Attribute werden vor Löschung entfernt

### Verbesserungen
- ✅ **Job-Validierung** - Detaillierte Prüfung beim Laden
- ✅ **Pfad-Prüfung** - Schreibrechte-Test vor Start
- ✅ **Statistik-Tracking** - Gelöscht/Fehler/Übersprungen Counter
- ✅ **Besseres Logging** - Detaillierte Zusammenfassungen
- ✅ **Session-Path Redundanz entfernt** - GUI initialisiert zentral

---

## 📝 Verwendung

### GUI-Modus (empfohlen)
```powershell
.\GUI\Start-GUI.ps1
```

1. **Basisordner** eingeben (z.B. `C:\Profiles` oder `\\Server\Profiles$`)
2. **Jobs auswählen** über Checkboxen
3. **Optionen setzen:**
   - ☑️ Dry-Run (Simulation)
   - ☑️ Auto-Open HTML (Report nach Fertigstellung)
4. **Log-Filter** anpassen (INFO, WARN, ERROR, DEBUG)
5. **Start** klicken
6. **Live-Logs** beobachten
7. **Cancel** bei Bedarf

### Output
- **Log:** `Logs\Session-<Timestamp>\ProfileCleaner.log`
- **CSV:** `Logs\Session-<Timestamp>\Cleanup-*.csv`
- **HTML:** `Logs\Session-<Timestamp>\Merged_SessionData.html`

---

## 🔍 Fehlersuche

### Job wird nicht angezeigt
```powershell
# Validiere alle Jobs
.\Test-JobLoading.ps1
```

### Job schlägt fehl
1. Log-Datei prüfen: `Logs\Session-<Timestamp>\ProfileCleaner.log`
2. DEBUG-Filter in GUI aktivieren
3. Dry-Run Mode testen
4. Pfade manuell validieren

### Pfade nicht gefunden
- Basisordner muss **absolute Pfad** sein
- RootPaths sind **relativ** zum Basisordner
- Beispiel: 
  - Basis: `C:\Profiles`
  - RootPath: `CTX-Profiles\ZDRS\`
  - Ergebnis: `C:\Profiles\CTX-Profiles\ZDRS\`

---

## 🧪 Testing

### Job-Validierung
```powershell
.\Test-JobLoading.ps1
```

### Dry-Run Test
1. GUI starten
2. Basisordner mit echten Daten eingeben
3. ☑️ **Dry-Run** aktivieren
4. Start klicken
5. CSV-Report prüfen (Aktion = "Simulation")

---

## 📈 Performance

- **Runspace-basiert** - GUI bleibt reaktiv
- **Parallele CSV-Generierung** - Ein Report pro Job
- **Optimierte Größenberechnung** - SilentlyContinue bei Berechtigungsfehlern
- **Memory-Safe** - Automatisches Runspace Disposal

---

## 🔄 Wartung

### Neuen Job hinzufügen
1. JSON-Datei in `Jobs\` erstellen
2. Validieren mit `.\Test-JobLoading.ps1`
3. GUI neu starten
4. Dry-Run testen

### Job deaktivieren
```json
{
    "Label": "MeinJob",
    "Type": "ProfileFolder",
    "SubFolder": "...",
    "RootPaths": ["..."],
    "Enabled": false  // ← Deaktiviert
}
```

### Logs aufräumen
```powershell
# Alte Sessions löschen (älter als 30 Tage)
Get-ChildItem Logs\Session-* | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item -Recurse -Force
```

---

## 📜 Lizenz

Internes Tool - Keine externe Lizenz

---

## 👨‍💻 Autor

ProfileCleaner Team - Oktober 2025

---

## 📞 Support

Bei Fragen oder Problemen:
1. Log-Datei prüfen
2. `Test-JobLoading.ps1` ausführen
3. Dry-Run Mode verwenden
4. `Jobs\README.md` konsultieren
