Param(
    [Parameter(Mandatory = $false)]
    [Switch]$ShowMenu
)

Function Set-NovashellModulePath {
    Process {
        $Path = Resolve-Path -Path $PSScriptRoot
        $ModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath")
        $ModPath = "$ModulePath;$Path"
        [System.Environment]::SetEnvironmentVariable("PSModulePath", $ModPath)
    }
}

Function Invoke-Novashell {
    Begin {
        Set-NovashellModulePath
    }
    Process {
        Import-Module Novashell
    }
    End {
        Do {
            If ($ShowMenu) {
                New-NovashellMenu
            }
            Else {
                Write-Host " "
            }
            New-NovashellPrompt
            $NovashellInput = Read-Host " "
            Invoke-Expression (Get-NovashellModuleFunction $NovashellInput)
        }
        Until ($NovashellInput -eq "exit")
    }
}

Invoke-Novashell