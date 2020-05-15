@{
    ModuleToProcess   = "Novashell.psm1"
    ModuleVersion     = "0.0.0.0"
    GUID              = "81ad031d-aac6-42c0-88e5-d973973cb232"

    FunctionsToExport = @(
        "Get-NovashellConfig",
        "New-NovashellPrompt",
        "New-NovashellMenu",
        "New-NovashellMenuMember",
        "Clear-NovashellMenuMember",
        "Get-NovashellModuleFunction",
        "Get-NovashellModules",
        "Mount-NovashellModule",
        "Dismount-NovashellModule",
        "New-NovashellLog",
        "Get-NovashellLog",
        "Get-NovashellConsoleColor",
        "Set-NovashellConsoleColor",
        "Write-NovashellProgressBar"
        "Exit-Novashell",
        "Write-Novashell"
        "Get-NovashellCleanerTargets",
        "New-NovashellCleanerTarget",
        "Clear-NovashellCleanerTarget",
        "Invoke-NovashellCleaner",
        "Invoke-NovashellPingScanner",
        "Invoke-NovashellPortScanner"
    )

    VariablesToExport = 
    "NovashellConsoleColorPrimary",
    "NovashellConsoleColorSecondary",
    "NovashellConsoleColorTertiary",
    "NovashellConsoleColorHidden"

    ModuleList        = @(
        @{ ModuleName = "NovashellLauncher"; ModuleVersion = "0.0.0.0"; GUID = "71d14ab5-70a5-481f-823c-fa6d4cf53ae8" },
        @{ ModuleName = "NovashellCleaner"; ModuleVersion = "0.0.0.0"; GUID = "75701bab-21a0-4ca7-a7f0-7f0bb299de85" },
        @{ ModuleName = "NovashellScanner"; ModuleVersion = "0.0.0.0"; GUID = "c7e064ff-e0c3-4b4c-8b48-3cfa7b0c101d" }
    )
}