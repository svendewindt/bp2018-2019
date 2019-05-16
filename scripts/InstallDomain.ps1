
<#
.SYNOPSIS
  Script to install a domain controller

.DESCRIPTION
  This script will install a domain controller with the given parameters

.PARAMETER DomainName
  The name of the domain to install. This is the actual domain name, not the NetBIOS name.

.PARAMETER Username
  The username, by default this is "vagrant".

.PARAMETER Password
  The password, by default this is "vagrant".

.PARAMETER RecoveryPassword
  The is the Active Directory recovery password.

.PARAMETER JoinExistingDomain
  A switch to add a domain controller to an existing domain. If this switch is not added a new domain will be created.

.PARAMETER SetDNSForwarder
  If specified, configures a server wide dns forwarder. These could point to Google, OpenDNS, CloudFlare, Norton ConnectSafe, Comodo

.NOTES
  Version:        0.1
  Author:         Sven de Windt
  Creation Date:  17/03/2018
  Purpose/Change: Initial script development

  Version:        0.2
  Author:         Sven de Windt
  Creation Date:  3/11/2018
  Purpose/Change: Added functionality to add a domain controller to an existing domain

  Version:        0.3
  Author:         Sven de Windt
  Creation Date:  4/11/2018
  Purpose/Change: Added functionality to set DNS forwarders
  
.EXAMPLE
  ./installDomain -DomainName "test.local" -verbose

.EXAMPLE
  ./installDomain -DomainName "svedew.gent" -Password "RecoveryPassword" -JoinExistingDomain
#>

#requires -version 3.0

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------

param(
    [CmdletBinding()]
    [parameter(mandatory=$true)][string]$Domainname,
    [parameter(mandatory=$false)][string]$Username = "vagrant",
    [parameter(mandatory=$false)][string]$Password = "vagrant",
    [parameter(mandatory=$false)][string]$RecoveryPassword = "RecoveryPassword123!",
    [parameter(mandatory=$false)][ValidateSet("Google", "OpenDNS", "CloudFlare", "NortonConnectSafe", "Comodo")][string]$SetDNSForwarder,
    [switch]$JoinExistingDomain
)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Set-StrictMode -Version Latest
Write-Output $env:COMPUTERNAME
Import-Module ServerManager
#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

#Dot Source required Function Libraries
#. "C:\Scripts\Functions\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$ScriptVersion = "0.1"
$GoogleDNS = @("8.8.8.8", "8.8.4.4")                
$OpenDNS = @("208.67.222.222", "208.67.220.220")
$CloudFlareDNS = @("1.1.1.1", "1.0.0.1")            # Fastest DNS around, unsecured
$NortonConnectSafeDNS = @("199.85.126.10", "199.85.127.10")
$ComodoDNS = @("8.26.56.26", "8.20.247.20")

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function TestDomainName(){
    [parameter(mandatory=$true)][string]$DomainName
    Write-Verbose "Checking DomainName"
    if (([regex]::Matches($Domainname, "\.")).count -ne 1){
        Write-Error "Domain name consists of a top level domainname and a second level domain name"
    }
    $Split = $DomainName.Split(".")
    $TLD = $Split[1]
    $SLD = $Split[0]
    if ($TLD.Length -lt 2){
        Write-Error "Top level domain should at least be 2 characters long"
    }
    #should not start with a digit...
    Write-verbose "OK - DomainName"
}

function SetForwarder(){
    
    Write-Verbose "Set DNS forwarders"
    $Forwarders = @()
    switch ($SetDNSForwarder){
        "Google" {$Forwarders = $GoogleDNS}
        "OpenDNS" {$Forwarders = $OpenDNS}
        "CloudFlare" {$Forwarders = $CloudFlareDNS}
        "NortonConnectSafe" {$Forwarders = $NortonConnectSafeDNS}
        "Comodo" {$Forwarders = $ComodoDNS}
    }
    foreach ($Forwarder in $Forwarders){
        Add-DnsServerForwarder -IPAddress $Forwarder -PassThru
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Clear-Host
Write-Host "Start script $($MyInvocation.MyCommand.Name) - version $($ScriptVersion)"

Write-Verbose "Is this server a DC already?"
if (Test-Path "C:\Windows\sysvol") {
    Write-Verbose "This server is already a domain controller, exiting..."
    exit
} else {
    Write-Verbose "C:\Windows\sysvol not found, continuing"
}

Write-Verbose "Checking parameters"
TestDomainName -DomainName $Domainname | Out-Null

Write-Verbose "Install AD binaries"
Import-Module ServerManager
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

$SecurePassword = convertTo-SecureString $Password -AsPlainText -Force
$SecureRecoveryPassword = convertTo-SecureString $RecoveryPassword -AsPlainText -Force
if ($JoinExistingDomain){
    $Split = $DomainName.Split(".")
    $Username = "$($Split[0])\$($Username)"
    Write-Verbose "Adding domaincontroller to domain $($Domainname) with useraccount $($Username)"
    $Cred = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
   Install-ADDSDomainController -DomainName $Domainname -SafeModeAdministratorPassword $SecureRecoveryPassword -Credential $Cred -Force 
   if ($SetDNSForwarder){
      SetForwarder 
   }

} else {
    Write-Verbose "Install AD"
    $Split = $DomainName.Split(".")
    Install-Addsforest -DomainName $Domainname -DomainNetBIOSName $Split[0] -installdns -SafeModeAdministratorPassword $SecureRecoveryPassword  -force
    if ($SetDNSForwarder){
      SetForwarder 
   }
}
