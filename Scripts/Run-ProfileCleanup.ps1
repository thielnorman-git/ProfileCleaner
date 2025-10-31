param(
    [string]$JobFolder = "$PSScriptRoot\..\Jobs",
    [string]$ModulePath = "$PSScriptRoot\..\Modules",
    [string]$ExportPath = "C:\Temp"
)

. "$ModulePath\Find-ProfileFolder.ps1"

$jobs = Get-ChildItem -Path $JobFolder -Filter *.json | ForEach-Object {
    Get-Content $_.FullName | ConvertFrom-Json
}

foreach ($job in $jobs) {
    if ($job.Enabled -eq $true) {
        Write-Host "Starte Bereinigung: $($job.Label)" -ForegroundColor Cyan
        Find-ProfileFolder -RootPath $job.RootPath -SubFolder $job.SubFolder -Label $job.Label -ExportPath $ExportPath
    } else {
        Write-Host "Übersprungen (deaktiviert): $($job.Label)" -ForegroundColor Yellow
    }
}
