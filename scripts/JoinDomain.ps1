
<#
.SYNOPSIS
  Script to join an existing domain

.DESCRIPTION
  This script will install a domain controller with the given parameters

.PARAMETER Username
  The username used to join the domain

.PARAMETER Password
  The password used to join the domain

.PARAMETER DnsServer1
  The primary dns server

.PARAMETER DnsServer 2
  The secondary dns server

.PARAMETER domain
  The name of the domain to join

.PARAMETER NewName
  Specifies the new name of the computer

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        0.1
  Author:         Sven de Windt
  Creation Date:  31/03/2018
  Purpose/Change: Initial script development
  Version:        0.2
  Author:         Sven de Windt
  Creation Date:  27/04/2019
  Purpose/Change: Added functionality NewName
  
.EXAMPLE
  .\JoinDomain.ps1 -Username vagrant -Password vagrant -DomainName "test.local" -DnsServer "192.168.38.2" -verbose

.EXAMPLE
  .\JoinDomain.ps1 -Username vagrant -Password vagrant -DomainName "test.local" -DnsServer "192.168.38.2" -NewName WSW10 -verbose

.EXAMPLE
  .\JoinDomain.ps1 -Username vagrant -Password vagrant -DomainName "svedew.gent" -DnsServer1 "192.168.1.1" -DnsServer2 "192.168.1.2" -verbose

.EXAMPLE
  .\JoinDomain.ps1 -Username vagrant -Password vagrant -DomainName "svedew.gent" -DnsServer1 "192.168.1.1" -DnsServer2 "192.168.1.2" -Gateway "192.168.1.254" -verbose
#>

#requires -version 3.0

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------
param(
  [CmdletBinding()]
    [parameter(mandatory=$false)][string]$Username = "vagrant",
    [parameter(mandatory=$false)][string]$Password = "vagrant",
    [parameter(mandatory=$false)][string]$DnsServer1,
    [parameter(mandatory=$false)][string]$DnsServer2,
    [parameter(mandatory=$false)][string]$Gateway,
    [parameter(mandatory=$false)][string]$NewName,
    [parameter(mandatory=$true)][string]$DomainName

)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Set-StrictMode -Version Latest

#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

$Nummer = Get-Date -UFormat "%Y-%m-%d@%H-%M-%S"
$Log = "$($env:TEMP)\$($MyInvocation.MyCommand.Name) $($Nummer).log"

#Dot Source required Function Libraries
#. "C:\Scripts\Functions\Logging_Functions.ps1"

$Username = $DomainName + "\" + $Username

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$ScriptVersion = "0.1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------



#-----------------------------------------------------------[Execution]------------------------------------------------------------
#Clear-Host
Start-Transcript -Path $Log -NoClobber
$StopWatch = New-Object System.Diagnostics.Stopwatch
$StopWatch.Start()
#Clear-Host
Write-Output "Start script $($MyInvocation.MyCommand.Name) - version $($ScriptVersion)"

if ($DnsServer1){
  Write-Verbose "Setting DNS server(s)"
  $DnsServers = $DnsServer1 |out-null
  if ($DnsServer2){
      Write-Host "$($DnsServers)"
      $DnsServers = $DnsServer1, $DnsServer2
  }
  
  # Find network ID
  $NetworkOctets = $DnsServer1.Split(".")
  $NetworkID = ""
  for($i= 0 ; $i -le 2; $i++){
      $NetworkID = $NetworkID + $NetworkOctets[$i] + "."
  }
  # Select network adapter matching the network ID
  $Adapter = Get-WmiObject win32_NetworkAdapterConfiguration | Where-Object {$_.IPaddress -match $NetworkID}
  $Adapter.SetDNSServerSearchOrder($DnsServers)

  if($Gateway){
    $Adapter.SetGateways($Gateway)
  }
}

Write-Verbose "Join the domain $($DomainName)"
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$DomainCredentials = New-Object System.Management.Automation.PSCredential $Username,$SecurePassword

try {
    if ($NewName){
        Add-Computer -DomainName $DomainName -Credential $DomainCredentials -NewName $NewName -PassThru -Verbose 
    } else {
        Add-Computer -DomainName $DomainName -Credential $DomainCredentials -PassThru -Verbose 
    }
  Register-DnsClient
  #Restart-Computer
}
catch {
  Write-Output "Error occured:"
  Write-Output $_.Exception.Message  
}

Write-Output "Time taken $($StopWatch.Elapsed)"

$StopWatch.Stop()
Write-Output "Finished $($MyInvocation.MyCommand.Name)"
Stop-Transcript