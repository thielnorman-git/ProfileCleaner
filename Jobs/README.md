# ProfileCleaner - Job System Dokumentation

## 📋 Übersicht

Das ProfileCleaner Job-System verwendet JSON-Dateien um Bereinigungsaufgaben zu definieren. Alle `.json` Dateien im `Jobs/` Ordner werden automatisch geladen.

## 🎯 Job-Typen

### 1. **ProfileFolder** - Ordner in Benutzerprofilen bereinigen

Löscht oder simuliert das Löschen von spezifischen Unterordnern in Benutzerprofilen.

**Beispiel:**
```json
{
    "Label": "excluded-Downloads",
    "Type": "ProfileFolder",
    "SubFolder": "UPM_Profile\\Downloads",
    "RootPaths": [
        "CTX-Profiles\\ZDRS\\",
        "CTX-Profiles\\ZDRW\\"
    ],
    "Enabled": true
}
```

**Parameter:**
- `Label` (String, **pflicht**): Anzeigename in der GUI
- `Type` (String, **pflicht**): Muss `"ProfileFolder"` sein
- `SubFolder` (String, **pflicht**): Relativer Pfad zum Unterordner der gelöscht werden soll
- `RootPaths` (Array, **pflicht**): Liste von Basis-Pfaden (relativ zum eingegebenen Basisordner)
- `Enabled` (Boolean, optional): `true` = aktiv, `false` = deaktiviert (Standard: `true`)

**Funktionsweise:**
1. Für jeden `RootPath` wird der Pfad mit dem Basisordner kombiniert
2. In jedem gefundenen Profil wird der `SubFolder` gesucht
3. Gefundene Ordner werden gelöscht (oder simuliert bei Dry-Run)
4. CSV-Report wird erstellt

---

### 2. **UPMCleanup** - Alte UPM-Profile entfernen

Löscht Citrix UPM-Profile die älter als X Tage sind basierend auf dem `LastWriteTime`.

**Beispiel:**
```json
{
    "Label": "UPMProfileCleanup",
    "Type": "UPMCleanup",
    "DaysOld": 30,
    "Enabled": true,
    "Description": "Entfernt UPM-Profile die älter als 30 Tage sind"
}
```

**Parameter:**
- `Label` (String, **pflicht**): Anzeigename in der GUI
- `Type` (String, **pflicht**): Muss `"UPMCleanup"` sein
- `DaysOld` (Integer, **pflicht**): Alter in Tagen (Profile älter als dieser Wert werden gelöscht)
- `Enabled` (Boolean, optional): `true` = aktiv, `false` = deaktiviert (Standard: `true`)
- `Description` (String, optional): Beschreibung für Dokumentation

**Funktionsweise:**
1. Durchsucht den eingegebenen Basisordner nach Profil-Ordnern
2. Prüft das `LastWriteTime` jedes Profils
3. Löscht Profile die älter als `DaysOld` sind
4. CSV-Report wird mit Alter und Zeitstempel erstellt

---

## 📝 Job-Dateien erstellen

### Namenskonvention
- Dateiname: `Job-<Beschreibung>.json`
- Beispiel: `Job-excluded-Downloads.json`
- UTF-8 Encoding verwenden

### Validierung
```powershell
# Test-Script ausführen
.\Test-JobLoading.ps1
```

### Beispiele

#### ✅ **Gültiger Job**
```json
{
    "Label": "Firefox Cache",
    "Type": "ProfileFolder",
    "SubFolder": "UPM_Profile\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles",
    "RootPaths": [
        "CTX-Profiles\\ZDRS\\"
    ],
    "Enabled": true
}
```

#### ❌ **Ungültiger Job** (fehlende Pflichtfelder)
```json
{
    "Label": "Mein Job",
    "Type": "ProfileFolder"
    // FEHLER: SubFolder und RootPaths fehlen!
}
```

---

## 🔧 Job deaktivieren

Um einen Job temporär zu deaktivieren ohne die Datei zu löschen:

```json
{
    "Label": "MeinJob",
    "Type": "ProfileFolder",
    "SubFolder": "...",
    "RootPaths": ["..."],
    "Enabled": false  // ← Job wird übersprungen
}
```

---

## 📊 Aktuell konfigurierte Jobs

### ProfileFolder Jobs (15)
- DMSTempFolder
- excluded-BasisApp
- excluded-Downloads
- excluded-FirefoxProfiles
- excluded-LoyHutz-App
- excluded-MSEdgeApplicationCache
- excluded-MSEdgeCodeCacheJS
- excluded-MSEdgeDefaultCache
- excluded-EdgeRoamingProfileCache
- excluded-MSEdgeServiceWorkerCache
- excluded-MSEdgeSnapshots
- excluded-roaming-iMedOne Cache
- excluded-WindowsWebCache
- MicrosoftEdgeBackups
- NCHSoftwareFolder

### UPMCleanup Jobs (1)
- UPMProfileCleanup (30 Tage)

---

## 🚀 Verwendung

1. **GUI starten**: `.\GUI\Start-GUI.ps1`
2. **Basisordner** eingeben (z.B. `C:\Profiles`)
3. **Jobs auswählen** (Checkboxen)
4. **Dry-Run** aktivieren zum Testen
5. **Start** klicken

---

## 📈 Output

Für jeden Job wird ein CSV-Report erstellt:
- `Cleanup-<JobLabel>-<Timestamp>.csv` (bei ProfileFolder)
- `UPM_Cleanup-<Timestamp>.csv` (bei UPMCleanup)

Am Ende wird ein zusammengefasster HTML-Report generiert:
- `Merged_SessionData.html`

---

## ⚠️ Hinweise

- **Backups erstellen** vor der ersten Ausführung ohne Dry-Run!
- **Schreibrechte** werden automatisch geprüft
- **Logs** werden in `Logs/Session-<Timestamp>/` gespeichert
- Jobs können während der Ausführung mit **Cancel** abgebrochen werden
- Encoding ist UTF-8 (ohne BOM) für Excel-Kompatibilität

---

## 🔍 Fehlersuche

### Job wird nicht angezeigt
- Prüfe JSON-Syntax mit `Test-JobLoading.ps1`
- Stelle sicher dass `Enabled: true` gesetzt ist
- Prüfe ob alle Pflichtfelder vorhanden sind

### Job schlägt fehl
- Prüfe Log-Datei in `Logs/Session-<Timestamp>/ProfileCleaner.log`
- Aktiviere DEBUG-Filter in der GUI
- Teste mit **Dry-Run** aktiviert

### Pfade nicht gefunden
- Verwende **relative Pfade** in `RootPaths`
- Der Basisordner wird automatisch vorangestellt
- Beispiel: Basis=`C:\Profiles`, RootPath=`CTX-Profiles\ZDRS\` → `C:\Profiles\CTX-Profiles\ZDRS\`
