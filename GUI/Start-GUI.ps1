# ============================
# Start-GUI.ps1 – ProfileCleaner GUI (STA Runspace, Auto-Open fix)
# ============================

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location -Path $PSScriptRoot

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# --- Modulpfade ---
$moduleRoot = Join-Path $PSScriptRoot "..\Modules"
$jobsFolder = Join-Path $PSScriptRoot "..\Jobs"

# --- Module importieren ---
Import-Module (Join-Path $moduleRoot "Write-Log.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "Find-ProfileFolder.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "Remove-OldUPMProfiles.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "Merge-ProfileCleanerSessionCSVs.psm1") -Force -Global

# --- Logs vorbereiten ---
$logsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "Logs"
if (-not (Test-Path $logsRoot)) { New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null }

$sessionName = "Session-{0}" -f (Get-Date -Format "yyyy-MM-dd_HH-mm")
$global:ProfileCleanerSessionPath = Join-Path $logsRoot $sessionName
New-Item -ItemType Directory -Force -Path $global:ProfileCleanerSessionPath | Out-Null
$global:LogFile = Join-Path $global:ProfileCleanerSessionPath "ProfileCleaner.log"





function Invoke-ProfileCleanerDiagnostics {
    param (
        [string]$OutputPath = (Join-Path $PSScriptRoot "ProfileCleaner-Diagnostics.txt")
    )

    try {
        Write-Host "Erstelle Diagnosebericht: $OutputPath" -ForegroundColor Cyan

        $lines = @()
        $lines += "=== ProfileCleaner Diagnosebericht ==="
        $lines += "Zeitpunkt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $lines += ""
        $lines += "## Globale Variablen"
        $lines += "ProfileCleanerSessionPath: $global:ProfileCleanerSessionPath"
        $lines += "ScriptRoot:                $PSScriptRoot"
        $lines += "Aktuelles Verzeichnis:     $(Get-Location)"
        $lines += ""

        # Falls Jobs geladen wurden:
        if ($global:LoadedJobs) {
            $lines += "## Geladene Jobs:"
            foreach ($job in $global:LoadedJobs) {
                $lines += "  Label: $($job.Label)"
                $lines += "  Type: $($job.Type)"
                $lines += "  RootPath: $($job.RootPath)"
                $lines += "  SubFolder: $($job.SubFolder)"
                $lines += "  DaysOld: $($job.DaysOld)"
                $lines += "  Enabled: $($job.Enabled)"
                $lines += ""

                # Teste Pfad-Kombination (Root + Benutzer + SubFolder)
                if (Test-Path $job.RootPath) {
                    $userProfiles = Get-ChildItem -Path $job.RootPath -Directory -ErrorAction SilentlyContinue
                    foreach ($userprof in $userProfiles) {
                        $combined = Join-Path $userprof.FullName $job.SubFolder
                        $exists = Test-Path $combined
                        $lines += "   -> $combined  [$(if ($exists) {'OK'} else {'FEHLT'})]"
                    }
                    $lines += ""
                } else {
                    $lines += "   ! RootPath nicht gefunden: $($job.RootPath)"
                }
                $lines += ""
            }
        } else {
            $lines += "Keine Jobs geladen oder $global:LoadedJobs ist leer."
        }

        $lines += ""
        $lines += "## Session-Verzeichnisprüfung"
        if (Test-Path $global:ProfileCleanerSessionPath) {
            $lines += "  OK: $global:ProfileCleanerSessionPath"
        } else {
            $lines += "  FEHLT: $global:ProfileCleanerSessionPath"
        }

        $lines += ""
        $lines += "=== Ende Diagnose ==="

        $lines | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-Host "Diagnosebericht gespeichert unter: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Fehler bei Diagnose: $($_.Exception.Message)" -ForegroundColor Red
    }
}

















# --- GUI-XAML ---
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Profile Cleaner"
        Height="860" Width="700"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0">
            <TextBlock FontSize="18" FontWeight="Bold" Margin="0,0,0,10">Profile Cleaner</TextBlock>

            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <TextBlock Text="Basisordner Benutzerprofile:" Width="200" VerticalAlignment="Center"/>
                <TextBox x:Name="ProfileBasePath" Width="340"/>
                <Button Content="..." Width="35" Margin="5,0,0,0" x:Name="BrowseBasePath"/>
            </StackPanel>

            <TextBlock x:Name="BasePathWarning" Text="Bitte gültigen Basisordner auswählen."
                       Foreground="Red" Visibility="Collapsed" Margin="0,0,0,10"/>

            <ScrollViewer Height="220" Margin="0,5,0,5">
                <StackPanel x:Name="JobList"/>
            </ScrollViewer>

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,5,0,5">
                <Button Content="Alle abwählen" Width="130" Margin="0,0,10,0" x:Name="ToggleAllButton"/>
            </StackPanel>

            <CheckBox x:Name="DryRunCheckBox" Content="Nur Simulation (keine Dateien löschen)" Margin="0,5,0,5"/>
            <CheckBox x:Name="AutoOpenCheckBox" Content="Report nach Abschluss automatisch öffnen" Margin="0,5,0,5" IsChecked="True"/>

            <TextBlock x:Name="ProgressText" FontSize="14" FontStyle="Italic"
                       Margin="0,10,0,5" Foreground="#444" Text="Bereit."/>

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,5,0,5">
                <Button Content="Starte Bereinigung" Height="35" Width="160" x:Name="StartButton" Margin="0,0,10,0"/>
                <Button Content="Abbrechen" Height="35" Width="100" x:Name="CancelButton" IsEnabled="False"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,5,0,5">
                <Button Content="Öffne Logverzeichnis" Width="160" x:Name="OpenLogDirButton"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal" Margin="0,10,0,5">
                <TextBlock Text="Log-Filter:" Width="70" VerticalAlignment="Center"/>
                <CheckBox x:Name="FilterInfo"  Content="INFO"  IsChecked="True" Margin="5,0"/>
                <CheckBox x:Name="FilterWarn"  Content="WARN"  IsChecked="True" Margin="5,0"/>
                <CheckBox x:Name="FilterDebug" Content="DEBUG" IsChecked="True" Margin="5,0"/>
                <CheckBox x:Name="FilterError" Content="ERROR" IsChecked="True" Margin="5,0"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,0,5">
                <Button Content="Log löschen" Width="120" x:Name="ClearLogButton"/>
            </StackPanel>
        </StackPanel>

        <Grid Grid.Row="1" Margin="0,10,0,0">
            <Border BorderThickness="1" BorderBrush="#CCC" Padding="3">
    <!-- Autoscroll-fähig: kein externer ScrollViewer -->
    <RichTextBox x:Name="LogBox"
                 IsReadOnly="True"
                 FontFamily="Consolas"
                 FontSize="12"
                 VerticalScrollBarVisibility="Auto"
                 Margin="0"
                 AcceptsReturn="True"/>
</Border>

        </Grid>
    </Grid>
</Window>
'@

# --- GUI laden ---
$xml = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $xaml))
$window = [Windows.Markup.XamlReader]::Load($xml)

# --- Controls ---
$profileBasePath = $window.FindName("ProfileBasePath")
$browseBasePath  = $window.FindName("BrowseBasePath")
$basePathWarning = $window.FindName("BasePathWarning")
$jobList         = $window.FindName("JobList")
$toggleAllButton = $window.FindName("ToggleAllButton")
$dryRunCheck     = $window.FindName("DryRunCheckBox")
$autoOpenCheck   = $window.FindName("AutoOpenCheckBox")
$progressText    = $window.FindName("ProgressText")
$startButton     = $window.FindName("StartButton")
$cancelButton    = $window.FindName("CancelButton")
$openLogButton   = $window.FindName("OpenLogDirButton")
$filterInfo      = $window.FindName("FilterInfo")
$filterWarn      = $window.FindName("FilterWarn")
$filterDebug     = $window.FindName("FilterDebug")
$filterError     = $window.FindName("FilterError")
$clearLogButton  = $window.FindName("ClearLogButton")
$logBox          = $window.FindName("LogBox")

$logFilter = @{
    "INFO"  = $filterInfo
    "WARN"  = $filterWarn
    "DEBUG" = $filterDebug
    "ERROR" = $filterError
}

# --- Jobs laden ---
$jobs = @()
foreach ($f in (Get-ChildItem -Path $jobsFolder -Filter *.json -ErrorAction SilentlyContinue)) {
    try {
        $jobObj = (Get-Content $f.FullName -Raw -Encoding UTF8) | ConvertFrom-Json
        if (-not $jobObj.Label -or -not $jobObj.Type) { continue }
        if ($jobObj.PSObject.Properties.Name -contains 'Enabled' -and -not $jobObj.Enabled) { continue }
        $jobs += $jobObj
        Write-Host "✓ Job geladen: $($jobObj.Label) [$($jobObj.Type)]" -ForegroundColor Green
    } catch {
        Write-Host "Fehler beim Laden von $($f.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($jobs.Count -eq 0) {
    [System.Windows.MessageBox]::Show("Keine gültigen Jobs gefunden in: $jobsFolder", "Warnung", "OK", "Warning")
}

$checkboxes = @{}
foreach ($job in $jobs) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $job.Label
    $cb.IsChecked = $true
    $cb.Margin = '2,2,2,2'
    [void]$jobList.Children.Add($cb)
    $checkboxes[$job.Label] = $cb
}

$toggleAllButton.Add_Click({
    $allChecked = ($checkboxes.Values | Where-Object { -not $_.IsChecked }).Count -eq 0
    foreach ($cb in $checkboxes.Values) { $cb.IsChecked = -not $allChecked }
    $toggleAllButton.Content = if ($allChecked) { "Alle auswählen" } else { "Alle abwählen" }
})
$clearLogButton.Add_Click({ $logBox.Document.Blocks.Clear() })
$browseBasePath.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $profileBasePath.Text = $dlg.SelectedPath
        $basePathWarning.Visibility = 'Collapsed'
    }
})
$openLogButton.Add_Click({
    if (Test-Path $global:ProfileCleanerSessionPath) {
        Start-Process explorer.exe $global:ProfileCleanerSessionPath
    } else {
        Start-Process explorer.exe $logsRoot
    }
})

$script:activeRunspace = $null
$cancelButton.Add_Click({
    $global:CancelRequested = $true
    if ($script:activeRunspace) {
        try {
            $script:activeRunspace.SessionStateProxy.SetVariable('global:CancelRequested', $true)
        } catch {}
    }
    $progressText.Text = "Abbruch angefordert..."
})

# --- Startbutton ---
$startButton.Add_Click({
    $base = $profileBasePath.Text
    if ([string]::IsNullOrWhiteSpace($base) -or -not (Test-Path $base)) {
        $basePathWarning.Text = "Pfad existiert nicht oder ungültig."
        $basePathWarning.Visibility = 'Visible'
        return
    }
    $basePathWarning.Visibility = 'Collapsed'
    $startButton.IsEnabled = $false
    $cancelButton.IsEnabled = $true
    $global:CancelRequested = $false

    $activeJobs = foreach ($j in $jobs) { if ($checkboxes[$j.Label].IsChecked) { $j } }
    if ($activeJobs.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Keine Jobs ausgewählt.","Hinweis")
        $startButton.IsEnabled = $true
        $cancelButton.IsEnabled = $false
        return
    }

    $iss = [runspacefactory]::CreateRunspace()
    $iss.ApartmentState = "STA"
    $iss.ThreadOptions  = "ReuseThread"
    $iss.Open()

    $iss.SessionStateProxy.SetVariable('global:GuiDispatcher', $window.Dispatcher)
    $iss.SessionStateProxy.SetVariable('global:GuiLogBox', $logBox)
    $iss.SessionStateProxy.SetVariable('global:GuiLogFilter', $logFilter)
    $iss.SessionStateProxy.SetVariable('global:ProfileCleanerSessionPath', $global:ProfileCleanerSessionPath)
    $iss.SessionStateProxy.SetVariable('global:LogFile', $global:LogFile)
    $iss.SessionStateProxy.SetVariable('global:LogsRoot', $logsRoot)
    $iss.SessionStateProxy.SetVariable('global:CancelRequested', $false)
    $iss.SessionStateProxy.SetVariable('ModuleRoot', $moduleRoot)

    $ps = [powershell]::Create()
    $ps.Runspace = $iss
    $script:activeRunspace = $iss

    $ps.AddScript({
        param($activeJobs,$base,$dryRun,$autoOpen,$progressText,$cancelButton,$startButton,$window)

        Import-Module (Join-Path $ModuleRoot "Write-Log.psm1") -Force
        Import-Module (Join-Path $ModuleRoot "Find-ProfileFolder.psm1") -Force
        Import-Module (Join-Path $ModuleRoot "Remove-OldUPMProfiles.psm1") -Force
        Import-Module (Join-Path $ModuleRoot "Merge-ProfileCleanerSessionCSVs.psm1") -Force

        Write-Log "[INFO] Runspace gestartet." "INFO"

        $total = $activeJobs.Count
        $i = 0
        foreach ($job in $activeJobs) {
            $i++
            $window.Dispatcher.Invoke({ $progressText.Text = "Laufender Job ${i}/${total}: $($job.Label)" })
            if ($global:CancelRequested) { break }

            Write-Log "[INFO] Starte Job '$($job.Label)'" "INFO"

            switch ($job.Type) {
                "ProfileFolder" {
                    foreach ($root in $job.RootPaths) {
                        try {
                            if ($global:CancelRequested) { break }
                            $resolved = Join-Path $base $root
                            if (-not (Test-Path $resolved)) {
                                Write-Log "[WARN] RootPath nicht gefunden: $resolved" "WARN"
                                continue
                            }
                            Find-ProfileFolder -RootPath $resolved -SubFolder $job.SubFolder -Label $job.Label -DryRun:$dryRun
                            Write-Log "[INFO] ✔ Abgeschlossen: $($job.Label) für RootPath '$root'"
                        } catch {
                            Write-Log "[ERROR] Job '$($job.Label)' fehlgeschlagen: $_" "ERROR"
                        }
                    }
                }
                "UPMCleanup" {
                    try {
                        Remove-OldUPMProfiles -ProfileRoot $base -DaysOld $job.DaysOld -SubFolder $job.SubFolder -DryRun:$dryRun

                        Write-Log "[INFO] ✔ UPM Cleanup abgeschlossen: $($job.Label)"
                    } catch {
                        Write-Log "[ERROR] UPM Cleanup fehlgeschlagen: $_" "ERROR"
                    }
                }
            }
        }

        if (-not $global:CancelRequested) {
            $reportPath = Merge-ProfileCleanerSessionCSVs
            Write-Log "[INFO] Alle Jobs abgeschlossen." "INFO"

            # --- AUTO OPEN robust ---
            if ($autoOpen -and $reportPath) {
                if (Test-Path $reportPath) {
                    Write-Log ("[INFO] Öffne HTML-Report: {0}" -f $reportPath) "INFO"
                    try {
                        $null = $window.Dispatcher.BeginInvoke([action]{
                            try {
                                Start-Process $using:reportPath
                            } catch {
                                try { Invoke-Item $using:reportPath } catch {
                                    Start-Process explorer.exe $using:reportPath
                                }
                            }
                        })
                    } catch {
                        Write-Log ("[WARN] Auto-Open fehlgeschlagen: {0}" -f $_.Exception.Message) "WARN"
                    }
                } else {
                    Write-Log ("[WARN] Report-Pfad existiert nicht: {0}" -f $reportPath) "WARN"
                }
            }

            $window.Dispatcher.Invoke({ $progressText.Text = "✔ Bereinigung abgeschlossen." })
        } else {
            Write-Log "[WARN] Bereinigung abgebrochen." "WARN"
            $window.Dispatcher.Invoke({ $progressText.Text = "❌ Bereinigung abgebrochen." })
        }

        $window.Dispatcher.Invoke({
            $cancelButton.IsEnabled = $false
            $startButton.IsEnabled = $true
        })
    }).AddArgument($activeJobs).AddArgument($base.Trim()).
       AddArgument($dryRunCheck.IsChecked).
       AddArgument($autoOpenCheck.IsChecked).
       AddArgument($progressText).
       AddArgument($cancelButton).
       AddArgument($startButton).
       AddArgument($window)

    $handle = $ps.BeginInvoke()

    # Cleanup-Timer
    $cleanupTimer = New-Object System.Windows.Threading.DispatcherTimer
    $cleanupTimer.Interval = [TimeSpan]::FromSeconds(1)
    $cleanupTimer.Tag = @{ Handle = $handle; PowerShell = $ps; Timer = $cleanupTimer }
    $cleanupTimer.Add_Tick({
        param($sender, $e)
        $data = $sender.Tag
        if ($data.Handle.IsCompleted) {
            try {
                $data.PowerShell.EndInvoke($data.Handle)
                $data.PowerShell.Dispose()
                $script:activeRunspace = $null
                Write-Host "✓ Runspace sauber beendet"
            } catch {}
            finally { $data.Timer.Stop() }
        }
    })
    $cleanupTimer.Start()
})

[void]$window.ShowDialog()
