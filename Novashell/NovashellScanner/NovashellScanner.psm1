#Requires -Version 3

Function Invoke-NovashellPingScanner {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [System.String]$Network,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 254)]
        [System.Int16]$FirstAddress,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 254)]
        [System.Int16]$LastAddress
    )
    Begin {
        If ([System.String]::IsNullOrEmpty($Network)) {
            New-NovashellPrompt -Scope "ping"
            $Network = Read-Host " network"
            If ([System.String]::IsNullOrEmpty($Network) -or ([System.String]::IsNullOrWhiteSpace($Network))) {
                $CurrentNetwork = (Get-WmiObject -Class Win32_IP4RouteTable | Where-Object { '0.0.0.0' -in ($_.Destination, $_.Mask) }).NextHop
                $Network = ($CurrentNetwork -Split "\.")[0..2] -Join "."
            }
        }
        If (-not($FirstAddress)) {
            New-NovashellPrompt -Scope "ping"
            $FirstAddress = Read-Host " first address"
        }
        If (-not($LastAddress)) {
            New-NovashellPrompt -Scope "ping"
            $LastAddress = Read-Host " last address"
        }
        If ($LastAddress -le $FirstAddress) {
            Return
        }
        [System.Collections.ArrayList]$Addresses = @()
        $FirstAddress..$LastAddress | ForEach-Object {
            $Addresses += $_
        }
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            [CmdletBinding()]
            [OutputType([PSCustomObject])]
            Param(
                [Parameter(Mandatory = $true)]
                [System.String]$ScriptBlockNetwork,

                [Parameter(Mandatory = $true)]
                [System.Int16]$ScriptBlockAddress
            )
            Process {
                Try {
                    $ScriptBlockConnectionTest = Test-Connection "$($ScriptBlockNetwork).$($ScriptBlockAddress)" -Count 1 -Quiet
                    If (-not($ScriptBlockConnectionTest)) {
                        $ScriptBlockConnectionStatus = "offline"
                    }
                    Else {
                        $ScriptBlockConnectionStatus = "online"
                    }
                }
                Catch {
                    $ScriptBlockConnectionStatus = "failed"
                }
                $ScriptBlockIpv4Address = "$ScriptBlockNetwork.$ScriptBlockAddress"
                $ScriptBlockHostName = [System.Net.Dns]::GetHostByAddress($ScriptBlockIpv4Address).Hostname
                If (-not([System.String]::IsNullOrWhiteSpace($ScriptBlockHostName))) {
                    $ScriptBlockResult = New-Object PSCustomObject -Property @{
                        IPv4Address = $ScriptBlockIpv4Address
                        Hostname    = $ScriptBlockHostName
                        Status      = $ScriptBlockConnectionStatus
                    }
                    Return $ScriptBlockResult
                }
            }
        }
    }
    Process {
        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $Addresses.Count)
        $Runspace.Open()
        [System.Collections.ArrayList]$Jobs = @()
        ForEach ($Address in $Addresses) {
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddArgument($Network).AddArgument($Address)
            $Job.RunspacePool = $Runspace
            $Jobs += New-Object PSCustomObject -Property @{
                Address = $_
                Pipe    = $Job
                Result  = $Job.BeginInvoke()
            }
        }
        Write-Host " "
        Write-Host " >>>" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
        Do {
            Write-Host ">" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Start-Sleep -Milliseconds (Get-Random -Minimum 1 -Maximum 100)
        }
        While ($Jobs.Result.IsCompleted -contains $false)
        Write-Host "$Arrow$Arrow$Arrow" -ForegroundColor $env:NovashellConsoleColorSecondary
        [System.Collections.ArrayList]$Results = @()
        ForEach ($Job in $Jobs) {
            $Results += $Job.Pipe.EndInvoke($Job.Result)
        }
        If ($Results) {
            Write-Host " "
            ForEach ($Result in $Results) {
                $Ipv4Address = $Result | Select-Object -ExpandProperty IPv4Address
                $Hostname = $Result | Select-Object -ExpandProperty HostName
                $Status = $Result | Select-Object -ExpandProperty Status
                If ($Status -eq "online") {
                    Write-Host " <<< " -NoNewline -ForegroundColor $env:NovashellConsoleColorSecondary
                }
                Else {
                    Write-Host " <<< " -NoNewline -ForegroundColor $env:NovashellConsoleColorTertiary
                }
                Write-Host "$Ipv4Address" -NoNewline
                Write-Host " ($Hostname)" -ForegroundColor $env:NovashellConsoleColorHidden
            }
        }
        Else {
            Write-Novashell "<<!" "no computers are online"
        }
    }
    End {
        Try {
            $Runspace.Close()
        }
        Catch [System.Exception] {
            New-NovashellLog -Severity "error" -Message "cannot close runspace: $($_.Exception.Message)"
        }
        Try {
            $Runspace.Dispose()
        }
        Catch [System.Exception] {
            New-NovashellLog -Severity "error" -Message "cannot dispose runspace: $($_.Exception.Message)"
        }
        Finally {
            New-NovashellLog -Severity "info" -Message "invoke novashell ping scanner"
        }
    }
}

Function Invoke-NovashellPortScanner {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [System.String]$Computername,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 65535)]
        [System.Int16]$FirstPort,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 65535)]
        [System.Int16]$LastPort
    )
    Begin {
        If ([System.String]::IsNullOrEmpty($Computername) -or ([System.String]::IsNullOrWhiteSpace($Computername))) {
            New-NovashellPrompt -Arrow ">>?" -Scope "scanner/port"
            $Computername = Read-Host " computername"
        }
        If (-not($FirstPort)) {
            New-NovashellPrompt -Arrow ">>?" -Scope "scanner/port"
            $FirstPort = Read-Host " first port"
        }
        If (-not($LastPort)) {
            New-NovashellPrompt -Arrow ">>?" -Scope "scanner/port"
            $LastPort = Read-Host " last port"
        }
        [System.Collections.ArrayList]$Ports = @()
        $FirstPort..$LastPort | ForEach-Object {
            $Ports += $_
        }
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            [CmdletBinding()]
            [OutputType([PSCustomObject])]
            Param(
                [Parameter(Mandatory = $true)]
                [System.Int32]$ScriptBlockPort,

                [Parameter(Mandatory = $true)]
                [System.String]$ScriptBlockComputername
            )
            $ScriptBlockIPv4Address = [System.String]::Empty
            If ([System.Boolean]($ScriptBlockComputername -as [IPAddress])) {
                $ScriptBlockIPv4Address = $ScriptBlockComputername
            } 
            Else {
                Try {
                    $ScriptBlockIPv4AddressList = @(([System.Net.Dns]::GetHostEntry($ScriptBlockComputername)).AddressList)
                    ForEach ($Address in $ScriptBlockIPv4AddressList) {
                        If ($Address.AddressFamily -eq "InterNetwork") {
                            $ScriptBlockIPv4Address = Address.IPAddressToString
                            Break
                        }
                    }
                }
                Catch { } Finally { }
            }
            If ([System.String]::IsNullOrEmpty($ScriptBlockIPv4Address)) {
                Write-Host " <<< could not get ip address for $ScriptBlockComputername."
            }
            Try {
                [System.Net.Sockets.TcpClient]$ScriptBlockTcpClient = New-Object -TypeName System.Net.Sockets.TcpClient
                $ScriptBlockTcpClientConnector = $ScriptBlockTcpClient.BeginConnect(
                    $ScriptBlockIPv4Address, $ScriptBlockPort, $Null, $Null
                )
                $ScriptBlockTcpClientConnectorWaiter = $ScriptBlockTcpClientConnector.AsyncWaitHandle.WaitOne(1000, $False)
                If (-not($ScriptBlockTcpClientConnectorWaiter)) {
                    $ScriptBlockStatus = "closed"
                }
                Else {
                    $Null = $ScriptBlockTcpClient.EndConnect($ScriptBlockTcpClientConnector)
                    $ScriptBlockTcpClient.Close()
                    $ScriptBlockStatus = "open"
                }
            }
            Catch {
                $ScriptBlockStatus = "failed"
            }
            If ($ScriptBlockStatus -eq "open") {
                $Config = Get-NovashellConfig -Path ".\Novashell\NovashellScanner\Ports.json"
                ForEach ($Item in $Config.Ports) {
                    If ($Item.Port -eq $ScriptBlockPort) {
                        $ScriptBlockProtocol = $Item.Protocol
                        $ScriptBlockServiceName = $Item.ServiceName
                        $ScriptBlockServiceDescription = $Item.ServiceDescription
                    }
                }
                # Create a new powershell custom object
                [PSCustomObject]$ScriptBlockResult = New-Object PSCustomObject -Property @{
                    Port               = $ScriptBlockPort
                    Protocol           = $ScriptBlockProtocol
                    ServiceName        = $ScriptBlockServiceName
                    ServiceDescription = $ScriptBlockServiceDescription
                    Status             = $ScriptBlockStatus
                    ComputerName       = $ScriptBlockComputername
                    IPv4Address        = $ScriptBlockIPv4Address
                }
                Return $ScriptBlockResult
            }
        }
    }
    Process {
        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $Ports.Count)
        $Runspace.Open()
        [System.Collections.ArrayList]$Jobs = @()
        ForEach ($Port in $Ports) {
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddArgument($Port).AddArgument($Computername)
            $Job.RunspacePool = $Runspace
            [PSCustomObject]$Jobs += New-Object PSCustomObject -Property @{
                Port   = $_
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }
        }
        Write-Host " "
        Write-Host " >>>" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
        Do {
            Write-Host ">" -NoNewline -ForegroundColor $env:NovashellConsoleColorPrimary
            Start-Sleep -Milliseconds (Get-Random -Minimum 1 -Maximum 100)
        }
        While ($Jobs.Result.IsCompleted -contains $false)
        Write-Host "$Arrow$Arrow$Arrow" -ForegroundColor $env:NovashellConsoleColorSecondary
        [System.Collections.ArrayList]$Results = @()
        ForEach ($Job in $Jobs) {
            $Results += $Job.Pipe.EndInvoke($Job.Result)
        }
        $ResultsCollection = $Results | Where-Object { $_.Status -eq "open" }
        If ($Null -ne $ResultsCollection) {
            Write-Host " "
            ForEach ($Result in $ResultsCollection) {
                $ResultPort = $Result | Select-Object -ExpandProperty Port
                $ResultProtocol = $Result | Select-Object -ExpandProperty Protocol
                $ResultServiceName = $Result | Select-Object -ExpandProperty ServiceName
                $ResultServiceDescription = $Result | Select-Object -ExpandProperty ServiceDescription
                Write-Novashell "<<<" "port $ResultPort" $ResultProtocol $ResultServiceName $ResultServiceDescription
            }
        }
        Else {
            Write-Novashell "<<!" "all ports are closed"
        }
    }
    End {
        Try {
            $Runspace.Close()
        }
        Catch [System.Exception] {
            New-NovashellLog -Severity "error" -Message "cannot close runspace: $($_.Exception.Message)"
        }
        Try {
            $Runspace.Dispose()
        }
        Catch [System.Exception] {
            New-NovashellLog -Severity "error" -Message "cannot dispose runspace: $($_.Exception.Message)"
        }
        Finally {
            New-NovashellLog -Severity "info" -Message "invoke novashell port scanner"
        }
    }
}