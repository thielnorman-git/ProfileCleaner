Import-Module (Join-Path $PSScriptRoot "Write-Log.psm1") -Force

function Find-ProfileFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$SubFolder,
        [Parameter(Mandatory = $true)][string]$Label,
        [switch]$DryRun
    )

    # --- Prüfen, ob Sessionpfad vorhanden ---
    if (-not $global:ProfileCleanerSessionPath) {
        Write-Log "ProfileCleanerSessionPath nicht initialisiert!" "ERROR"
        throw "Session-Path fehlt. Bitte über Start-GUI.ps1 starten."
    }

    $ExportPath = $global:ProfileCleanerSessionPath
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $csvPath = Join-Path $ExportPath "Cleanup-$($Label)-$timestamp.csv"

    Write-Log "Starte Profilprüfung: '$Label' in '$RootPath' (Subfolder: '$SubFolder')" "INFO"

    # --- RootPath validieren ---
    if (-not (Test-Path $RootPath)) {
        Write-Log "RootPath existiert nicht: '$RootPath'" "WARN"
        "Path`tSize(MB)`tAktion" | Out-File -FilePath $csvPath -Encoding UTF8 -Force
        "Keine Ziele gefunden (RootPath ungültig)" | Out-File -FilePath $csvPath -Append -Encoding UTF8
        Write-Log "Job '$Label' abgeschlossen (RootPath ungültig)." "INFO"
        return
    }

    # --- Profile auflisten ---
    $profiles = @()
    try {
        $profiles = Get-ChildItem -Path $RootPath -Directory -ErrorAction Stop
    }
    catch {
        Write-Log "Fehler beim Auflisten von '$RootPath': $($_.Exception.Message)" "ERROR"
        "Path`tSize(MB)`tAktion" | Out-File -FilePath $csvPath -Encoding UTF8 -Force
        "Keine Ziele gefunden (Fehler beim Auflisten)" | Out-File -FilePath $csvPath -Append -Encoding UTF8
        Write-Log "Job '$Label' abgeschlossen (Fehler beim Auflisten)." "INFO"
        return
    }

    # --- Zielordner finden ---
    $targets = @()
    foreach ($profile in $profiles) {
        if ($global:CancelRequested) {
            Write-Log "Abbruch erkannt – verbleibende Profile übersprungen (Job '$Label')." "WARN"
            break
        }

        $fullPath = Join-Path $profile.FullName $SubFolder
        if (Test-Path $fullPath) {
            $targets += $fullPath
        }
    }

    # --- CSV initialisieren ---
    "Path`tSize(MB)`tAktion" | Out-File -FilePath $csvPath -Encoding UTF8 -Force

    if (-not $targets -or $targets.Count -eq 0 -or $global:CancelRequested) {
        Write-Log "Keine gültigen Ziele für '$Label' gefunden oder Abbruch erkannt." "WARN"
        "Keine Ziele gefunden" | Out-File -FilePath $csvPath -Append -Encoding UTF8
        Write-Log "Job '$Label' abgeschlossen (0 Treffer)." "INFO"
        return
    }

    Write-Log "Gefunden: $($targets.Count) Zielordner für '$Label'." "INFO"

    $totalSize = 0
    $deletedCount = 0
    $errorCount = 0

    foreach ($path in $targets) {

        if ($global:CancelRequested) {
            Write-Log "Abbruch erkannt – Job '$Label' wird beendet." "WARN"
            break
        }

        Write-Log "Analysiere Pfad: $path" "DEBUG"

        # --- Größe berechnen ---
        $folderSizeMB = 0
        try {
            $size = Get-ChildItem -Path $path -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum
            if ($size.Sum) { $folderSizeMB = [math]::Round($size.Sum / 1MB, 2) }
        } catch {
            Write-Log "Fehler bei Größenberechnung für '$path': $($_.Exception.Message)" "ERROR"
        }

        if ($folderSizeMB -gt 0) {
            $totalSize += $folderSizeMB
            if ($DryRun) {
                Write-Log "Trockenlauf: würde löschen '$path' ($folderSizeMB MB)" "WARN"
                "$path`t$folderSizeMB`tSimulation" | Out-File -FilePath $csvPath -Append -Encoding UTF8
            } else {
                try {
                    Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Attributes = 'Normal' }

                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                    Write-Log "Gelöscht: '$path' ($folderSizeMB MB)" "INFO"
                    "$path`t$folderSizeMB`tGelöscht" | Out-File -FilePath $csvPath -Append -Encoding UTF8
                    $deletedCount++
                } catch {
                    Write-Log "Fehler beim Löschen von '$path': $($_.Exception.Message)" "ERROR"
                    "$path`t$folderSizeMB`tFehler" | Out-File -FilePath $csvPath -Append -Encoding UTF8
                    $errorCount++
                }
            }
        } else {
            Write-Log "Übersprungen (leer oder 0 MB): '$path'" "DEBUG"
            "$path`t0`tÜbersprungen" | Out-File -FilePath $csvPath -Append -Encoding UTF8
        }
    }

    # --- Zusammenfassung ---
    $summary = if ($DryRun) {
        "Simulation abgeschlossen: $($targets.Count) Ordner geprüft, gesamt $([math]::Round($totalSize,2)) MB"
    } else {
        "Bereinigung abgeschlossen: $deletedCount gelöscht, $errorCount Fehler, gesamt $([math]::Round($totalSize,2)) MB"
    }

    Write-Log "$summary" "INFO"
    Write-Log "CSV-Report: $csvPath" "INFO"
    Write-Log "Job '$Label' abgeschlossen." "INFO"
}

Export-ModuleMember -Function Find-ProfileFolder
