Import-Module (Join-Path $PSScriptRoot "Write-Log.psm1") -Force

function Remove-OldUPMProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$ProfileRoot,
        [Parameter(Mandatory = $true)][string]$SubFolder,
        [Parameter(Mandatory = $true)][int]$DaysOld,
        [switch]$DryRun
    )

    if (-not (Test-Path $ProfileRoot)) {
        Write-Log "Pfad nicht gefunden: $ProfileRoot" "WARN"
        return
    }

    if (-not $global:ProfileCleanerSessionPath) {
        Write-Log "ProfileCleanerSessionPath nicht initialisiert!" "ERROR"
        throw "Session-Path fehlt. Bitte über Start-GUI.ps1 starten."
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $outputFile = Join-Path $global:ProfileCleanerSessionPath ("Cleanup-OldUPMProfiles-{0}.csv" -f $timestamp)
    Write-Log "Starte UPM Cleanup unter '$ProfileRoot' (Grenze: $DaysOld Tage) – DryRun=$($DryRun.IsPresent)" "INFO"

    "Path`tSizeMB`tAgeDays`tLastWriteTime`tAktion`tGrund" | Out-File -FilePath $outputFile -Encoding UTF8 -Force

    $now = Get-Date
    $deletedCount = 0
    $skippedCount = 0
    $errorCount   = 0

    # --- Benutzerprofile ermitteln ---
    $userProfiles = Get-ChildItem -Path $ProfileRoot -Directory -ErrorAction SilentlyContinue
    Write-Log "$($userProfiles.Count) Benutzerprofile unter '$ProfileRoot' gefunden." "INFO"

    foreach ($userprof in $userProfiles) {
        Write-Log "Prüfe Benutzerprofil: $($userprof.FullName)" "DEBUG"

        $upmFolder = Join-Path $userprof.FullName $SubFolder
        if (-not (Test-Path $upmFolder)) {
            Write-Log "Übersprungen (kein $SubFolder): $($userprof.FullName)" "DEBUG"
            continue
        }

        # Prüfe Alter
        $iniPath = Join-Path $upmFolder "UPMSettings.ini"
        $dateSource = if (Test-Path $iniPath) {
            "UPMSettings.ini"
        } elseif (Test-Path $upmFolder) {
            "$SubFolder Ordner"
        } else {
            "Profilordner"
        }

        $lastWrite = if (Test-Path $iniPath) {
            (Get-Item $iniPath -Force).LastWriteTime
        } elseif (Test-Path $upmFolder) {
            (Get-Item $upmFolder -Force).LastWriteTime
        } else {
            (Get-Item $userprof.FullName -Force).LastWriteTime
        }

        $ageDays = ($now - $lastWrite).Days
        $lastWriteDisplay = $lastWrite.ToString("dd.MM.yyyy HH:mm")

        # Größe messen
        $folderSizeMB = 0
        try {
            $size = Get-ChildItem -Path $userprof.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
            if ($size.Sum) { $folderSizeMB = [math]::Round($size.Sum / 1MB, 2) }
        } catch {
            Write-Log "Fehler bei Größenmessung für '$($userprof.FullName)': $($_.Exception.Message)" "ERROR"
        }

        $action = ""
        $reason = ""

        if ($ageDays -ge $DaysOld) {
            $reason = "Alt (> $DaysOld Tage)"
            if ($DryRun) {
                $action = "Simulation: würde löschen"
                Write-Log "Simulation: würde löschen '$userprof.FullName' ($folderSizeMB MB, $ageDays Tage alt)" "WARN"
            } else {
                try {
                    Get-ChildItem -Path $userprof.FullName -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Attributes = 'Normal' }
                    Remove-Item -Path $userprof.FullName -Recurse -Force -ErrorAction Stop
                    $action = "Gelöscht"
                    $deletedCount++
                    Write-Log "Gelöscht: $($userprof.FullName) ($folderSizeMB MB, $ageDays Tage alt)" "INFO"
                } catch {
                    $action = "Fehler"
                    $errorCount++
                    Write-Log "Fehler beim Löschen '$($userprof.FullName)': $($_.Exception.Message)" "ERROR"
                }
            }
        } else {
            $action = "Übersprungen"
            $reason = "Zu jung – letzte Änderung vor $ageDays Tagen"
            $skippedCount++
            Write-Log "Übersprungen (zu jung): $($userprof.FullName) ($ageDays Tage)" "DEBUG"
        }

        "$($userprof.FullName)`t$folderSizeMB`t$ageDays`t$lastWriteDisplay`t$action`t$reason" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    }

    $summary = if ($DryRun) {
        "UPM Simulation: Würde $deletedCount Profile löschen, $skippedCount übersprungen, $errorCount Fehler"
    } else {
        "UPM Cleanup: $deletedCount gelöscht, $skippedCount übersprungen, $errorCount Fehler"
    }

    Write-Log $summary "INFO"
    Write-Log "CSV-Report: $outputFile" "INFO"
}

Export-ModuleMember -Function Remove-OldUPMProfiles
