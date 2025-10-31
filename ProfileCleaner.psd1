@{
    RootModule        = 'ProfileCleaner.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '2e7c2a9d-9944-44b8-8a7f-1b3f3ac1f22f'
    Author            = 'Dein Name'
    CompanyName       = 'IT Automation'
    Description       = 'PowerShell GUI zur Bereinigung von Citrix/UPM-Profilen mit Logging, Simulation und HTML-Report.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @('Start-ProfileCleaner')
    AliasesToExport   = @('Profile-Cleaner')
    CmdletsToExport   = @()
    VariablesToExport = @()
    PrivateData       = @{}
}
