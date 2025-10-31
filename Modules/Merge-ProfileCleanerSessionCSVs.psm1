Import-Module (Join-Path $PSScriptRoot "Write-Log.psm1") -Force

function Merge-ProfileCleanerSessionCSVs {
    [CmdletBinding()]
    param()

    $sessionPath = $global:ProfileCleanerSessionPath
    if (-not (Test-Path $sessionPath)) {
        Write-Log "Session-Pfad nicht gefunden: $sessionPath" "ERROR"
        return $null
    }

    $mergedCsv  = Join-Path $sessionPath "Merged_SessionData.csv"
    $mergedHtml = Join-Path $sessionPath "ProfileCleaner_Report.html"

    Write-Log "Starte CSV-Zusammenführung in: $sessionPath" "INFO"

    $csvFiles = Get-ChildItem -Path $sessionPath -Filter '*.csv' -File -ErrorAction SilentlyContinue
    if (-not $csvFiles) {
        Set-Content -Path $mergedHtml -Value "<html><body><h2>Keine CSV-Dateien vorhanden</h2></body></html>" -Encoding utf8
        return $mergedHtml
    }

    $allRows = @()
    foreach ($csv in $csvFiles) {
        try {
            $rows = Import-Csv -Path $csv.FullName -Delimiter "`t" -ErrorAction Stop
            foreach ($row in $rows) {
                if ($row.PSObject.Properties.Name -notcontains 'SourceFile') {
                    $row | Add-Member -NotePropertyName 'SourceFile' -NotePropertyValue $csv.Name -Force
                }
                $allRows += $row
            }
        } catch {
            Write-Log "Fehler beim Lesen von $($csv.Name): $($_.Exception.Message)" "ERROR"
        }
    }

    if (-not $allRows) {
        Write-Log "Keine Daten gefunden." "WARN"
        return
    }

    # Status bestimmen
    foreach ($r in $allRows) {
        $path = $r.Path
        $aktion = [string]$r.Aktion
        $size = [double]($r.'Size(MB)' -replace ',', '.')
        $r | Add-Member -NotePropertyName 'SizeMB' -NotePropertyValue $size -Force

        if ($path -eq 'Keine Ziele gefunden') {
            $status = 'Leer'
        }
        elseif ($aktion -match 'Simulation' -or $aktion -match 'DryRun') {
            $status = 'Simulation'
        }
        elseif ($aktion -match 'Gelöscht' -or $aktion -match 'würde löschen') {
            $status = 'Gefunden'
        }
        else {
            $status = 'Übersprungen'
        }
        $r | Add-Member -NotePropertyName 'Status' -NotePropertyValue $status -Force
    }

    # Zusammenfassungen
    $entriesTotal = $allRows.Count
    $foundTotal   = ($allRows | Where-Object { $_.Status -eq 'Gefunden' -or $_.Status -eq 'Simulation' }).Count
    $emptyTotal   = ($allRows | Where-Object { $_.Status -eq 'Leer' }).Count
    $totalMB      = [math]::Round(($allRows | Measure-Object -Property SizeMB -Sum).Sum, 2)

    function Get-RowStyle($status) {
        switch ($status) {
            'Gefunden'     { "style='background-color:#ccffcc;'" }
            'Simulation'   { "style='background-color:#b3e6ff;'" }
            'Übersprungen' { "style='background-color:#fff0b3;'" }
            'Leer'         { "style='background-color:#ffcccc;'" }
            default        { "" }
        }
    }

    # Haupttabelle
    $tbody = foreach ($r in $allRows) {
        $style = Get-RowStyle $r.Status
        $size  = if ($r.SizeMB -gt 0) { "{0:N2}" -f $r.SizeMB } else { "0" }
        "<tr $style><td>$($r.Path)</td><td>$size</td><td>$($r.Status)</td><td>$($r.SourceFile)</td></tr>"
    }

    # Summen je CSV
    $summaryRows =
        $allRows |
        Group-Object -Property SourceFile |
        ForEach-Object {
            $sf = $_.Name
            $items = $_.Count
            $found = ($_.Group | Where-Object { $_.Status -eq 'Gefunden' -or $_.Status -eq 'Simulation' }).Count
            $sumMB = [math]::Round( ($_.Group | Measure-Object -Property SizeMB -Sum).Sum, 2)
            "<tr><td>$sf</td><td>$items</td><td>$found</td><td>$sumMB</td></tr>"
        }

    # HTML mit Sortierung
    $html = @"
<html>
<head>
<meta charset='UTF-8'>
<title>ProfileCleaner Session Report</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background-color: #f9f9f9; }
h2 { color: #004578; }
h3 { margin-top: 30px; color: #004578; }
table { border-collapse: collapse; width: 100%; box-shadow: 0 2px 6px rgba(0,0,0,0.1); margin-top: 10px; }
th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
th { background-color: #0078D7; color: white; cursor: pointer; user-select: none; }
tr:nth-child(even) { background-color: #f2f2f2; }
tr:hover { background-color: #eaf2ff; }
.sort-asc::after { content: " ▲"; }
.sort-desc::after { content: " ▼"; }
.summary { margin-bottom: 15px; padding: 10px; background-color: #eef2f7; border-radius: 8px; }
.legend span { padding: 2px 8px; margin-right: 10px; border-radius: 4px; }
</style>
<script>
function sortTable(header) {
  var table = header.closest('table');
  var index = Array.prototype.indexOf.call(header.parentNode.children, header);
  var asc = header.asc = !header.asc;
  Array.from(header.parentNode.children).forEach(th => th.classList.remove('sort-asc', 'sort-desc'));
  header.classList.add(asc ? 'sort-asc' : 'sort-desc');
  var rows = Array.from(table.rows).slice(1);
  rows.sort(function(a, b) {
    var A = a.cells[index].innerText.trim();
    var B = b.cells[index].innerText.trim();
    var numA = parseFloat(A.replace(',', '.'));
    var numB = parseFloat(B.replace(',', '.'));
    if (!isNaN(numA) && !isNaN(numB)) { return asc ? numA - numB : numB - numA; }
    return asc ? A.localeCompare(B, 'de') : B.localeCompare(A, 'de');
  });
  rows.forEach(r => table.tBodies[0].appendChild(r));
}
</script>
</head>
<body>
<h2>ProfileCleaner Session Report – $(Get-Date -Format 'yyyy-MM-dd HH:mm')</h2>
<div class='summary'>
<b>Quelle:</b> $sessionPath<br/>
<b>Einträge:</b> $entriesTotal &nbsp;&nbsp;|&nbsp;&nbsp;
<b>Gefunden:</b> $foundTotal &nbsp;&nbsp;|&nbsp;&nbsp;
<b>Leer:</b> $emptyTotal &nbsp;&nbsp;|&nbsp;&nbsp;
<b>Gesamtspeicher:</b> $totalMB MB
<div class='legend'>
<span style='background:#ccffcc;'>Gefunden</span>
<span style='background:#b3e6ff;'>Simulation</span>
<span style='background:#fff0b3;'>Übersprungen</span>
<span style='background:#ffcccc;'>Leer/Keine Ziele</span>
</div>
</div>

<table id='reportTable'>
<thead><tr>
<th onclick='sortTable(this)'>Path</th>
<th onclick='sortTable(this)'>SizeMB</th>
<th onclick='sortTable(this)'>Status</th>
<th onclick='sortTable(this)'>SourceFile</th>
</tr></thead>
<tbody>
$($tbody -join "`n")
</tbody>
</table>

<h3>Gesamtspeicher je Job</h3>
<table id='summaryTable'>
<thead><tr><th onclick='sortTable(this)'>SourceFile</th><th onclick='sortTable(this)'>TotalItems</th><th onclick='sortTable(this)'>FoundItems</th><th onclick='sortTable(this)'>TotalMB</th></tr></thead>
<tbody>
$($summaryRows -join "`n")
</tbody>
</table>
</body>
</html>
"@

    Set-Content -Path $mergedHtml -Value $html -Encoding utf8
    Write-Log "HTML-Report erstellt: $mergedHtml" "INFO"
    return $mergedHtml
}

Export-ModuleMember -Function Merge-ProfileCleanerSessionCSVs
