#Requires -Version 3

Function Get-NovashellCleanerTargets {
    Process {
        ForEach ($Target in (Get-NovashellConfig -Path ".\Novashell\NovashellCleaner\NovashellCleaner.json").Targets) {
            Write-Host " <<< " -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Write-Host "$($Target.Path)" -NoNewline
            Write-Host " [$($Target.Days) days]" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Write-Host " ($($Target.GUID))" -ForegroundColor $env:NovashellConsoleColorHidden
        }
    }
    End {
        New-NovashellLog -Severity "info" -Message "get novashell cleaner targets"
    }
}

Function New-NovashellCleanerTarget {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateScript( { Test-Path -Path (Resolve-Path -Path $_).Path })]
        [System.String]$Path,

        [Parameter(Mandatory = $false)]
        [System.String]$Days
    )
    Begin {
        If ($Path -eq "" -or ($Path -eq " ")) {
            New-NovashellPrompt -Arrow ">>?"
            $Path = Read-Host " path"
        }
        If ($Days -eq "" -or ($Days -eq " ")) {
            New-NovashellPrompt -Arrow ">>?"
            $Days = Read-Host " days"
        }
    }
    Process {
        $Config = Get-NovashellConfig -Path ".\Novashell\NovashellCleaner\NovashellCleaner.json"
        $Config.Targets += [PSCustomObject] @{
            Path   = $Path
            Days   = $Days
            Author = $env:USERNAME
            GUID   = (New-Guid)
        }
        $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\NovashellCleaner\NovashellCleaner.json" 
    }
    End {
        New-NovashellLog -Severity "info" -Message "new novashell cleaner target"
    }
}

Function Clear-NovashellCleanerTarget {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [System.String]$GUID
    )
    Begin {
        If ($GUID -eq "" -or ($GUID -eq " ")) {
            $GUID = Read-Host " guid"
        }
    }
    Process {
        $Config = Get-NovashellConfig -Path ".\Novashell\NovashellCleaner\NovashellCleaner.json"
        [System.Collections.ArrayList]$Targets = @()
        ForEach ($Target in $Config.Targets) {
            If ($Target.GUID -ne $GUID) {
                $Targets += $Target
            }
        }
        $Config.Targets = $Targets
        $Config | ConvertTo-Json -Depth 20 | Set-Content -Path ".\Novashell\NovashellCleaner\NovashellCleaner.json" 
    }
    End {
        New-NovashellLog -Severity "info" -Message "clear novashell cleaner target"
    }
}

Function Invoke-NovashellCleaner {
    Begin {
        Try {
            New-Item -ItemType Directory -Path ".\Novashell\NovashellCleaner\Temp"
        }
        Catch [System.Exception] {
            New-NovashellLog -Severity "error" -Message "$($_.Exception.Message)"
        }
    }
    Process {
        ForEach ($Target in (Get-NovashellConfig -Path ".\Novashell\NovashellCleaner\NovashellCleaner.json").Targets) {
            $Days = "-" + $Target.Days
            $CleaningDate = (Get-Date).AddDays($Days)
            Get-ChildItem -Path $Target.Path | Where-Object { $_.LastWriteTime -lt $CleaningDate } | Move-Item -Destination ".\Novashell\NovashellCleaner\Temp" | Out-Null
        }
        $FileSystemObject = New-Object -ComObject scripting.filesystemobject
        $FileSystemObject.DeleteFolder(".\Novashell\NovashellCleaner\Temp") | Out-Null
    }
}