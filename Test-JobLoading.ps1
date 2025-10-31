# ============================
# Test-JobLoading.ps1
# Testet das Laden und Validieren aller Job-Dateien
# ============================

$jobsFolder = Join-Path $PSScriptRoot "Jobs"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Job-Validierungs-Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$jobs = @()
$errors = @()
$warnings = @()

foreach ($f in (Get-ChildItem -Path $jobsFolder -Filter *.json -ErrorAction SilentlyContinue)) {
    Write-Host "Prüfe: $($f.Name)" -NoNewline
    
    try {
        $jobObj = (Get-Content $f.FullName -Raw -Encoding UTF8) | ConvertFrom-Json
        
        # Validierung
        $isValid = $true
        $issues = @()
        
        if (-not $jobObj.Label) {
            $issues += "Kein Label"
            $isValid = $false
        }
        if (-not $jobObj.Type) {
            $issues += "Kein Type"
            $isValid = $false
        }
        
        # Enabled-Check
        if ($jobObj.PSObject.Properties.Name -contains 'Enabled' -and -not $jobObj.Enabled) {
            Write-Host " [DEAKTIVIERT]" -ForegroundColor DarkGray
            $warnings += "$($f.Name): Job ist deaktiviert"
            continue
        }
        
        # Type-spezifische Validierung
        if ($jobObj.Type -eq 'ProfileFolder') {
            if (-not $jobObj.RootPaths -or $jobObj.RootPaths.Count -eq 0) {
                $issues += "Keine RootPaths"
                $isValid = $false
            }
            if (-not $jobObj.SubFolder) {
                $issues += "Kein SubFolder"
                $isValid = $false
            }
        }
        elseif ($jobObj.Type -eq 'UPMCleanup') {
            if (-not $jobObj.DaysOld -or $jobObj.DaysOld -lt 1) {
                $issues += "DaysOld fehlt oder ungültig"
                $isValid = $false
            }
        }
        else {
            $issues += "Unbekannter Type '$($jobObj.Type)'"
            $isValid = $false
        }
        
        if ($isValid) {
            Write-Host " ✓" -ForegroundColor Green
            $jobs += $jobObj
        } else {
            Write-Host " ✗ $($issues -join ', ')" -ForegroundColor Red
            $errors += "$($f.Name): $($issues -join ', ')"
        }
        
    } catch {
        Write-Host " ✗ JSON-Fehler" -ForegroundColor Red
        $errors += "$($f.Name): $($_.Exception.Message)"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Ergebnis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Gültige Jobs:     $($jobs.Count)" -ForegroundColor Green
Write-Host "⚠ Warnungen:        $($warnings.Count)" -ForegroundColor Yellow
Write-Host "✗ Fehler:           $($errors.Count)" -ForegroundColor Red

if ($warnings.Count -gt 0) {
    Write-Host "`nWarnungen:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host "`nFehler:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Job-Details" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$jobsByType = $jobs | Group-Object -Property Type

foreach ($group in $jobsByType) {
    Write-Host "$($group.Name) Jobs: $($group.Count)" -ForegroundColor Cyan
    foreach ($job in $group.Group) {
        Write-Host "  • $($job.Label)" -ForegroundColor Gray
        if ($job.Type -eq 'ProfileFolder') {
            Write-Host "    SubFolder: $($job.SubFolder)" -ForegroundColor DarkGray
            Write-Host "    RootPaths: $($job.RootPaths.Count) Pfade" -ForegroundColor DarkGray
        }
        if ($job.Type -eq 'UPMCleanup') {
            Write-Host "    DaysOld: $($job.DaysOld) Tage" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($jobs.Count -gt 0) {
    Write-Host "✓ Alle Jobs können geladen werden!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Keine gültigen Jobs gefunden!" -ForegroundColor Red
    exit 1
}
