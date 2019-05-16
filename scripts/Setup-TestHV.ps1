<#
.SYNOPSIS
  Configure a host for WCF with Hyper-V.

.DESCRIPTION
  This script will configure a host with an IP address, a hostname and the roles required for Hyper-V.

.NOTES
  Version:        0.1
  Author:         Sven de Windt
  Creation Date:  27/04/2018
  Purpose/Change: Initial script development

.EXAMPLE
  .\SetupHV1.ps1
#>

#requires -version 3.0

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------
#param(
#    [CmdletBinding()]
#        [parameter(mandatory = $true)][String][ValidateSet('TestHV1','TestHV2')]$HV
#)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

Set-StrictMode -Version Latest

#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

#----------------------------------------------------------[Declarations]----------------------------------------------------------



Write-Host "Set up host" -ForegroundColor Green
$MacAddressTestHV1 = "90-1B-0E-C4-9A-13"
$MacAddressTestHV2 = "90-1B-0E-C4-97-9B"
$ScriptVersion = "0.1"

$ScriptVersion = $null
$Hostname = $null
$ManagementIP = $null
$ManagementMac = $null
$SubnetPrefix = $null
$Gateway = $null
$DNSServer = $null
$StorageIP = $null
$StorageMac = $null

$WorkspaceId = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$WorkspaceKey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$MMA64bitURL = "http://download.microsoft.com/download/1/5/E/15E274B9-F9E2-42AE-86EC-AC988F7631A0/MMASetup-AMD64.exe"


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Enable-RDP (){
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$MacObjects = Get-NetAdapter | select MacAddress
$Macaddresses = [System.Collections.ArrayList]::new()
foreach($Mac in $MacObjects){
    $Macaddresses.Add($Mac.MacAddress) | Out-Null
}

if ($Macaddresses.Contains($MacAddressTestHV1)){
    $Hostname = "TestHV1"
    $ManagementIP = "192.168.1.11"
    $ManagementMac = "90-1B-0E-C4-9A-13"
    $SubnetPrefix = "24"
    $Gateway = "192.168.1.254"
    $DNSServer = "192.168.1.10"
    $StorageIP = "172.16.0.11"
    $StorageMac = "A0-36-9F-D6-54-9C"
}

if ($Macaddresses.Contains($MacAddressTestHV2)){
    $Hostname = "TestHV2"
    $ManagementIP = "192.168.1.12"
    $ManagementMac = "90-1B-0E-C4-97-9B"
    $SubnetPrefix = "24"
    $Gateway = "192.168.1.254"
    $DNSServer = "192.168.1.10"
    $StorageIP = "172.16.0.12"
    $StorageMac = "A0-36-9F-D6-56-04"
}

if ($Hostname -eq $null){
    throw "Script is not running on expected server, quiting"
}

# Set Management IP
Write-Host "Set management IP to $($ManagementIP)" -ForegroundColor Green
Invoke-Expression -Command "$($PSScriptRoot)\SetIP.ps1 -MacAddress $ManagementMac -IPAddress $ManagementIP -PrefixLength $SubnetPrefix -DefaultGateway $Gateway -DnsServer1 $DNSServer -verbose"

# Set Storage IP
Write-Host "Set storage IP to $($StorageIP)" -ForegroundColor Green
Invoke-Expression -Command "$($PSScriptRoot)\SetIP.ps1 -MacAddress $StorageMac -IPAddress $StorageIP -PrefixLength $SubnetPrefix -verbose"

# Enable RDP
Write-Host "Enable RDP" -ForegroundColor Green
Enable-RDP
start-sleep -Seconds 10

# Install MMA
Write-Host "Install Microsoft Monitoring Agent" -ForegroundColor Green
$ResourcesFolder = new-item -ItemType Directory -Path "c:\" -Name "Resources" -Force
$Destination = Join-Path $ResourcesFolder.FullName  "MMASetup-AMD64.exe"
$null = Invoke-WebRequest -uri $MMA64bitURL -OutFile $Destination 
$null = Unblock-File $Destination 

Write-Verbose "Installing Microsoft Monitoring Agent"
$Command = "$Destination"
$Param = '/C:"setup.exe /qn NOAPM=1 ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID=' + $WorkspaceID + ' OPINSIGHTS_WORKSPACE_KEY=' + $WorkspaceKey + ' AcceptEndUserLicenseAgreement=1"'

& $Command $Param

# Install & configure MPIO
Write-Host "Install & configure Multipath IO" -ForegroundColor Green
Install-WindowsFeature MultiPath-IO
New-MSDSMSupportedHW -VendorId MSFT2005 -ProductId iSCSIBusType_0x9

# Install Hyper-V
Write-Host "Install Hyper-V" -ForegroundColor Green
Install-WindowsFeature -Name hyper-v -IncludeManagementTools

# Install WCF
Write-Host "Install Windows Failover Clustering" -ForegroundColor Green
Install-WindowsFeature –Name Failover-Clustering –IncludeManagementTools

# Join Domain
Write-Host "Join Domain" -ForegroundColor Green
Invoke-Expression -Command "$($PSScriptRoot)\JoinDomain.ps1 -Username administrator -Password Hogent123 -DomainName 'bp.local' -NewName $($Hostname) -verbose"

Restart-Computer

