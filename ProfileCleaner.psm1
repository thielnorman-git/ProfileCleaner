# ============================
# ProfileCleaner.psm1
# ============================

# Modulverzeichnis merken
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ModulesPath = Join-Path $ModuleRoot "Modules"
$script:GuiScript = Join-Path $ModuleRoot "GUI\Start-GUI.ps1"

# Alle Untermodule importieren
$subModules = @(
    "Write-Log.psm1",
    "Get-FolderSize.psm1",
    "Find-ProfileFolder.psm1",
    "Remove-OldUPMProfiles.psm1",
    "Merge-ProfileCleanerSessionCSVs.psm1"
)

foreach ($m in $subModules) {
    $path = Join-Path $ModulesPath $m
    if (Test-Path $path) {
        Import-Module $path -Force -ErrorAction SilentlyContinue
    } else {
        Write-Warning "Untermodule fehlt: $m"
    }
}

# Hauptfunktion
function Start-ProfileCleaner {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:GuiScript)) {
        Write-Error "GUI-Skript nicht gefunden: $script:GuiScript"
        return
    }

    Write-Host "Starte ProfileCleaner GUI..." -ForegroundColor Cyan
    & $script:GuiScript
}

# Alias für bequemen Aufruf
Set-Alias -Name Profile-Cleaner -Value Start-ProfileCleaner

Export-ModuleMember -Function Start-ProfileCleaner -Alias Profile-Cleaner
