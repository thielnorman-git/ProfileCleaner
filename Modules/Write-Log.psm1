function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','WARN','DEBUG','ERROR')][string]$Level = 'INFO',
        [string]$LogFile = $global:LogFile
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[{0}][{1}] {2}" -f $timestamp, $Level.ToUpper(), $Message

    # --- Logfilter prüfen (bools, kein WPF!) ---
    if ($global:GuiLogFilterState -and $global:GuiLogFilterState.ContainsKey($Level)) {
        if (-not [bool]$global:GuiLogFilterState[$Level]) { return }
    }

    # --- Logdatei ---
    try {
        if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent))) {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        }
    } catch {}

    # --- GUI ---
    if ($global:GuiLogBox -and $global:GuiDispatcher) {
        try {
            $invoke = {
                param($msg,$lvl)
                $color = switch ($lvl) {
                    'INFO' {'DarkGreen'}
                    'WARN' {'DarkOrange'}
                    'DEBUG'{'Gray'}
                    'ERROR'{'Red'}
                    default {'Black'}
                }

                $run = New-Object Windows.Documents.Run
                $run.Text = $msg + "`n"

                try {
                    $run.Foreground = New-Object Windows.Media.SolidColorBrush(
                        [Windows.Media.ColorConverter]::ConvertFromString($color))
                } catch {
                    $run.Foreground = New-Object Windows.Media.SolidColorBrush([Windows.Media.Colors]::Black)
                }

                $p = New-Object Windows.Documents.Paragraph
                $p.Inlines.Add($run)
                $global:GuiLogBox.Document.Blocks.Add($p)

                # --- Autoscroll zuverlässig ---
                $global:GuiLogBox.UpdateLayout()
                $global:GuiLogBox.CaretPosition = $global:GuiLogBox.Document.ContentEnd
                $global:GuiLogBox.ScrollToEnd()
            }

            $global:GuiDispatcher.Invoke([action[string,string]]$invoke, $line, $Level)
        } catch {}
    }
    elseif ($Host.Name -match 'ConsoleHost') {
        $fg = switch ($Level) {
            'INFO'{'Green'} 'WARN'{'Yellow'} 'DEBUG'{'Gray'} 'ERROR'{'Red'} default{'White'}
        }
        Write-Host $line -ForegroundColor $fg
    }
}

Export-ModuleMember -Function Write-Log
