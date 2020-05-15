#Requires -Version 3

Get-ChildItem $PSScriptRoot | Where-Object { $_.PSIsContainer } | ForEach-Object { Import-Module $_.FullName -DisableNameChecking }

[System.ConsoleColor]$env:NovashellConsoleColorPrimary = [System.String](Get-NovashellConsoleColor -Color "Primary")
[System.ConsoleColor]$env:NovashellConsoleColorSecondary = [System.String](Get-NovashellConsoleColor -Color "Secondary")
[System.ConsoleColor]$env:NovashellConsoleColorTertiary = [System.String](Get-NovashellConsoleColor -Color "Tertiary")
[System.ConsoleColor]$env:NovashellConsoleColorHidden = [System.String](Get-NovashellConsoleColor -Color "Hidden")

Function Get-NovashellConfig {
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path (Resolve-Path -Path $_).Path })]
        [System.String]$Path
    )
    Process {
        $Config = Get-Content -Path (Resolve-Path -Path $Path).Path | Out-String | ConvertFrom-Json
        Return $Config
    }
}

Function New-NovashellPrompt {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [System.String]$Name = "nsl",

        [Parameter()]
        [System.String]$Scope,

        [Parameter()]
        [System.String]$Arrow = ">>>"
    )
    Process {
        Write-Host " $Arrow" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
        Write-Host " $Name" -NoNewline
        If ($Scope) {
            Write-Host "($($Scope.ToLower()))" -NoNewline
        }
    }
}

Function New-NovashellMenu {
    Process {
        ForEach ($Module in (Get-NovashellConfig ".\Novashell\Novashell.json").Modules) {
            Write-Host " "
            ForEach ($MenuMember in (Get-NovashellConfig ".\Novashell\Novashell$Module\Novashell$Module.json").Menu) {
                Write-Novashell -Block $MenuMember.Alias -Suffix $MenuMember.Command -Paranthes $MenuMember.Description
            }
        }
        Write-Host " "
    }
}

Function New-NovashellMenuMember {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [ValidateScript( { Test-Path -Path (Resolve-Path -Path ".\Novashell\Novashell$_\Novashell$_.json").Path })]
        [System.String]$Module,

        [Parameter()]
        [System.String]$Alias,

        [Parameter()]
        [System.String]$Command,

        [Parameter()]
        [System.String]$Function,

        [Parameter()]
        [System.String]$Description
    )
    Begin {
        If (-not($Module)) {
            New-NovashellPrompt -Arrow ">>?"
            $Module = Read-Host " module"
        }
        If (-not($Alias)) {
            New-NovashellPrompt -Arrow ">>?"
            $Alias = Read-Host " alias"
        }
        If (-not($Command)) {
            New-NovashellPrompt -Arrow ">>?"
            $Command = Read-Host " command"
        }
        If (-not($Function)) {
            New-NovashellPrompt -Arrow ">>?"
            $Function = Read-Host " function"
        }
        If (-not($Description)) {
            New-NovashellPrompt -Arrow ">>?"
            $Description = Read-Host " description"
        }
    }
    Process {
        $Config = Get-NovashellConfig -Path ".\Novashell\Novashell$Module\Novashell$Module.json"
        $Config.Menu += [PSCustomObject] @{
            Alias       = $Alias
            Command     = $Command
            Function    = $Function
            Description = $Description
            GUID        = (New-Guid)
        }
        $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\Novashell$Module\Novashell$Module.json"
    }
    End {
        New-NovashellLog -Severity "info" -Message "new novashell menu member"
    }
}

Function Clear-NovashellMenuMember {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [ValidateScript( { Test-Path -Path (Resolve-Path -Path ".\Novashell\Novashell$_\Novashell$_.json").Path })]
        [System.String]$Module,

        [Parameter()]
        [System.String]$Alias
    )
    Begin {
        If (-not($Module)) {
            $Module = Read-Host "module"
        }
        If (-not($Alias)) {
            $Alias = Read-Host "alias"
        }
    }
    Process {
        $Config = Get-NovashellConfig ".\Novashell\Novashell$Module\Novashell$Module.json"
        [System.Collections.ArrayList]$MenuMembers = @()
        ForEach ($MenuMember in $Config.Menu) { 
            If ($MenuMember.Alias -ne $Alias -and ($Alias -ne "nmm" -and ($Alias -ne "cmm"))) {
                $MenuMembers += $MenuMember
            }
        }
        $Config.Menu = $MenuMembers
        $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\Novashell$Module\Novashell$Module.json"
    }
    End {
        New-NovashellLog -Severity "info" -Message "clear novashell menu member"
    }
}

Function Get-NovashellModuleFunction {
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Scope
    )
    ForEach ($Module in (Get-NovashellConfig -Path ".\Novashell\Novashell.json").Modules) {
        $ModuleConfig = Get-NovashellConfig -Path ".\Novashell\Novashell$Module\Novashell$Module.json"
        $ModuleArgument = $ModuleConfig.Menu | Where-Object { $_.Alias -eq $Scope -or ($_.Command -eq $Scope -or ($_.GUID -eq $Scope)) } | Select-Object Function
        If ($ModuleConfig.Menu.Function -eq $ModuleArgument.Function) {
            Return $ModuleArgument.Function
        }
    }
}

Function Get-NovashellModules {
    Process {
        ForEach ($Module in (Get-NovashellConfig -Path ".\Novashell\Novashell.json").Modules) {
            Write-Host " <<<" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary 
            Write-Host "$Module"
        }
    }
    End {
        New-NovashellLog -Severity "info" -Message "get novashell modules"
    }
}

Function Mount-NovashellModule {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [System.String]$Name
    )
    Begin {
        If (-not($Name)) {
            New-NovashellPrompt -Arrow ">>?"
            $Name = Read-Host " module"
        }
    }
    Process {
        $Config = (Get-NovashellConfig -Path ".\Novashell\Novashell.json")
        If ($Config.Modules -notcontains $Name) {
            $Config.Modules += $Name
            $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\Novashell.json"
        }
    }
    End {
        New-NovashellLog -Severity "info" -Message "mount novashell module"
    }
}

Function Dismount-NovashellModule {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [System.String]$Name
    )
    Begin {
        If (-not($Name)) {
            New-NovashellPrompt -Arrow ">>?"
            $Name = Read-Host " module"
        }
    }
    Process {
        $Config = (Get-NovashellConfig -Path ".\Novashell\Novashell.json")
        If ($Config.Modules -contains $Name) {
            [System.Collections.ArrayList]$Modules = @()
            ForEach ($Module in $Config.Modules) {
                If ($Module -ne $Name) {
                    $Modules += $Module
                }
            }
            $Config.Modules = $Modules
            $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\Novashell.json"
        }
    }
    End {
        New-NovashellLog -Severity "info" -Message "dismount novashell module"
    }
}

Function New-NovashellLog {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [System.String]$Severity = "info",

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Message
    )
    Process {
        $Config = (Get-NovashellConfig -Path ".\Novashell\Novashell.json")
        $Config.Logs += [PSCustomObject] @{
            Date     = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")
            Severity = $Severity
            Message  = $Message
            Author   = $env:USERNAME
            GUID     = (New-Guid)
        }
        $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\Novashell.json"
    }
}

Function Get-NovashellLog {
    Process {
        Write-Host " "
        ForEach ($Log in (Get-NovashellConfig -Path ".\Novashell\Novashell.json").Logs) {
            Write-Novashell "<<<" $Log.Date $Log.Severity.ToUpper() $Log.Message $Log.Author
        }
    }
    End {
        New-NovashellLog -Severity "info" -Message "get novashell logs"
    }
}

Function Set-NovashellConsoleColor {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [System.String]$Primary,

        [Parameter(Mandatory = $false)]
        [System.String]$Secondary,

        [Parameter(Mandatory = $false)]
        [System.String]$Tertiary,

        [Parameter(Mandatory = $false)]
        [System.String]$Hidden
    )
    Begin {
        If ($Primary -eq " " -or ($Primary -eq "")) {
            New-NovashellPrompt -Arrow ">>?"
            $Primary = Read-Host " primary"
        }
        If ($Secondary -eq " " -or ($Secondary -eq "")) {
            New-NovashellPrompt -Arrow ">>?"
            $Secondary = Read-Host " secondary"
        }
        If ($Tertiary -eq " " -or ($Tertiary -eq "")) {
            New-NovashellPrompt -Arrow ">>?"
            $Tertiary = Read-Host " tertiary"
        }
        If ($Hidden -eq " " -or ($Hidden -eq "")) {
            New-NovashellPrompt -Arrow ">>?"
            $Hidden = Read-Host " hidden"
        }
    }
    Process {
        $Config = Get-NovashellConfig ".\Novashell\Novashell.json"
        If ($Config.Configs.Colors.Primary -ne $Primary -and ("" -ne $Primary -and (" " -ne $Primary))) {
            $Config.Configs.Colors.Primary = $Primary
            $env:NovashellConsoleColorPrimary = $Primary
        }
        If ($Config.Configs.Colors.Secondary -ne $Secondary -and ("" -ne $Secondary -and (" " -ne $Secondary))) {
            $Config.Configs.Colors.Secondary = $Secondary
            $env:NovashellConsoleColorSecondary = $Secondary
        }
        If ($Config.Configs.Colors.Tertiary -ne $Tertiary -and ("" -ne $Tertiary -and (" " -ne $Tertiary))) {
            $Config.Configs.Colors.Tertiary = $Tertiary
            $env:NovashellConsoleColorTertiary = $Tertiary
        }
        If ($Config.Configs.Colors.Hidden -ne $Hidden -and ("" -ne $Hidden -and (" " -ne $Hidden))) {
            $Config.Configs.Colors.Hidden = $Hidden
            $env:NovashellConsoleColorHidden = $Hidden
        }
        $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\Novashell.json"
    }
}

Function Get-NovashellConsoleColor {
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Color
    )
    Begin {
        $Config = Get-NovashellConfig ".\Novashell\Novashell.json"
    }
    Process {
        Switch ($Color) {
            "Primary" {
                Return $Config.Configs.Colors.Primary
            }
            "1" {
                Return $Config.Configs.Colors.Primary
            }
            "Secondary" {
                Return $Config.Configs.Colors.Secondary
            }
            "2" {
                Return $Config.Configs.Colors.Secondary
            }
            "Tertiary" {
                Return $Config.Configs.Colors.Tertiary
            }
            "3" {
                Return $Config.Configs.Colors.Tertiary
            }
            "Hidden" {
                Return $Config.Configs.Colors.Hidden
            }
            "4" {
                Return $Config.Configs.Colors.Hidden
            }
            Default {
                Return $Config.Configs.Colors.Primary
            }
        }
    }
}

Function Write-Novashell {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [System.String]$Arrow,

        [Parameter(Mandatory = $false)]
        [System.String]$Prefix,

        [Parameter(Mandatory = $false)]
        [System.String]$Block,

        [Parameter(Mandatory = $false)]
        [System.String]$Suffix,

        [Parameter(Mandatory = $false)]
        [System.String]$Paranthes
    )
    Process {
        If ($Arrow) {
            Write-Host " $Arrow" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
        }
        If ($Prefix) {
            Write-Host " $Prefix" -NoNewline
        }
        If ($Block) {
            Write-Host " [" -NoNewline -ForegroundColor $env:NovashellConsoleColorHidden
            Write-Host "$Block" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Write-Host "]" -NoNewline -ForegroundColor $env:NovashellConsoleColorHidden
        }
        If ($Suffix) {
            Write-Host " $Suffix" -NoNewline
        }
        If ($Paranthes) {
            Write-Host " ($Paranthes)" -ForegroundColor $env:NovashellConsoleColorHidden
        }
    }
}

Function Write-NovashellProgressBar {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.String]$Arrow,

        [Parameter(Mandatory = $true)]
        $Argument
    )
    Process {
        Write-Host " "
        Write-Host " $Arrow$Arrow$Arrow" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
        Do {
            Write-Host "$Arrow" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Start-Sleep -Milliseconds (Get-Random -Minimum 1 -Maximum 100)
        }
        While ($Argument -contains $false)
        Write-Host "$Arrow$Arrow$Arrow" -ForegroundColor $env:NovashellConsoleColorSecondary
        Write-Host " "
    }
}

Function Exit-Novashell {
    Begin {
        [System.Collections.Generic.List[System.String]]$ExitMessages = @()
        ForEach ($ExitMessage in (Get-NovashellConfig ".\Novashell\Novashell.json").Configs.Messages.Exit) {
            $ExitMessages += $ExitMessage
        }
    }
    Process {
        1..$ExitMessages.Count | ForEach-Object {
            $RandomExitMessage = Get-Random $ExitMessages.ToArray()
            Write-Host " "
            Write-Host " <<<" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Write-Host " $RandomExitMessage"
            Start-Sleep -Milliseconds 1500
            Exit
        }
    }
}

Export-ModuleMember -Variable $env:NovashellConsoleColorPrimary, $env:NovashellConsoleColorSecondary, $env:NovashellConsoleColorTertiary, $env:NovashellConsoleColorHidden