<#
.SYNOPSIS
  Script to assign an IP configuration to an interface specified by a mac address

.DESCRIPTION
  This script will look for an interface where the specified mac address matches the mac address of the interface and assign the IP configuration

.PARAMETER MacAddress
  The name mac address of the interface, where to assign the IP configuration to

.PARAMETER IPAddress
  The IP address to assign

.PARAMETER PrefixLength
  The subnet mask in prefix format. IE 24 for 255.255.255.0

.PARAMETER DefaultGateway
  The default gateway to assign/

.PARAMETER DnsServer1
  The dns server (1) to assign

.PARAMETER DnsServer2
  The dns server (2) to assign

.OUTPUTS
  A log file in the temp directory

.NOTES
  Version:        0.1
  Author:         Sven de Windt
  Creation Date:  10/3/2019
  Purpose/Change: Initial script development

.EXAMPLE
  .\SetIP.ps1 -MacAddress 00-15-5D-02-65-33 -IPAddress 192.168.0.100 -PrefixLength 24 -DefaultGateway 192.168.0.254 -DnsServer1 8.8.8.8
#>

#requires -version 3.0

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------

param(
    [CmdletBinding()]
        [parameter(mandatory = $true)][String]$MacAddress,
        [parameter(mandatory = $true)][String]$IPAddress,
        [parameter(mandatory = $true)][String]$PrefixLength,
        [parameter(mandatory = $false)][String]$DefaultGateway,
        [parameter(mandatory = $false)][String]$DnsServer1,
        [parameter(mandatory = $false)][String]$DnsServer2
)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Set-StrictMode -Version Latest

#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

$Nummer = Get-Date -UFormat "%Y-%m-%d@%H-%M-%S"
$Log = "$($env:TEMP)\$($MyInvocation.MyCommand.Name) $($Nummer).log"

#Dot Source required Function Libraries
#. "C:\Scripts\Functions\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$ScriptVersion = "0.1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Find-InterfaceName {
    Write-Host "Look for interface with mac address $($MacAddress)"
    $Interfaces = Get-NetAdapter
    foreach ($Interface in $Interfaces){
        if ((Clean-MacAddress -MacAddress $Interface.MacAddress) -eq $MacAddress){
            Write-host "Interface found"
            return $Interface.Name
        }
    }
    Write-Host "No matching interface found"
}

Function Clean-MacAddress{
    param(
        [parameter(mandatory = $true)][String]$MacAddress
    )
    # $MacAddress = 'aa-bb-cc-dd-ee-ff'
    # $MacAddress = 'aa:bb:cc:dd:ee:ff'
    $MacAddress = $MacAddress -replace '[-|:]'
    return $MacAddress
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Clear-Host
Start-Transcript -Path $Log
$StopWatch = New-Object System.Diagnostics.Stopwatch
$StopWatch.Start()
Write-Output "Start script $($MyInvocation.MyCommand.Name) - version $($ScriptVersion)"

# 00-15-5D-02-65-33
Write-Output "Clean Mac Address"
$MacAddress = Clean-MacAddress -MacAddress $MacAddress
Write-Output "Find Interface"
$InterfaceName = Find-InterfaceName

if ($InterfaceName){
    Write-Output "Create DNS server array"
    $DnsServers = $DnsServer1
    if ($DnsServer2){
        Write-Output "$($DnsServers)"
        $DnsServers = $DnsServer1, $DnsServer2
    }

    Write-Output "Set IP config on interface $($InterfaceName)"
    if ($DefaultGateway) {
      Write-Host "Set IP adress and gateway"
      New-NetIPAddress -InterfaceAlias $InterfaceName -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
    } else {
      Write-Host "Set IP adress without gateway"
      New-NetIPAddress -InterfaceAlias $InterfaceName -IPAddress $IPAddress -PrefixLength $PrefixLength
    }

    if ($DnsServers){
        Write-Output "Set DNS to $($DnsServers)"
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses $DnsServers
    }
}

#-----------------------------------------------------------[Finish up]------------------------------------------------------------
Write-Output $StopWatch.Elapsed

$StopWatch.Stop()
Write-Output "Finished $($MyInvocation.MyCommand.Name)"
Stop-Transcript



