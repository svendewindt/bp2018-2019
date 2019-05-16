<#
.SYNOPSIS
  Script to setup the environment
.DESCRIPTION
  This script setup the DC
.PARAMETER Cleanup
    Removes the DC
.OUTPUTS
  A transcript to the temp folder
.EXAMPLE
  ./Setup-Environment
.EXAMPLE
  ./Setup-Environment -Cleanup
#>

#Requires -RunAsAdministrator
#Requires -Version 3

param(
  [CmdletBinding()]
  [switch]$Cleanup
)

#Set Error Action to Stop on error
$ErrorActionPreference = "Stop"

$Nummer = Get-Date -UFormat "%Y-%m-%d@%H-%M-%S"
$Log = "$($env:TEMP)\$($MyInvocation.MyCommand.Name) $($Nummer).log"

#Script Version
$ScriptVersion = "0.1"
$TemplateVHDX = "C:\BP\resources\Template2019.vhdx"
$AutoUnattendPath = 'C:\BP\resources\autounattend2019.xml'
$AutoUnattendDestination = 'D:\Windows\Panther\unattend.xml'
$VMSPath = "C:\BP\resources\vms"
$DC1Name = "DC1"
$DC1IP = "192.168.1.10"
$TestVMName = "TestVM"
$TestVMIP = "192.168.1.20"
$Gateway = "192.168.1.254"
$SecondsToSleep = 1
$Prefix = 24
$NicName = "Lan"
$LocalAdminUserName = "administrator"
$DomainName = "bp.local"
$DomainAdminUserName = "bp\administrator"
#$Password = ConvertTo-SecureString "YourPasswordHere" -AsPlainText -Force | ConvertFrom-SecureString | Out-File "C:\BP\resources\password.enc"  
$Password = Get-Content "C:\BP\resources\password.enc" | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$LocalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocalAdminUserName, $Password
$DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainAdminUserName, $Password

function Find-VHDPath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$VMName  
  )
  $VMPath = Join-Path $VMSPath $VMName 
  $VMPath = $VMPath + ".vhdx"
  return $VMPath
}

function Copy-Server {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$VMName
  )
  Write-Host "Start copy for $($VMName)"
  $VMPath = Find-VHDPath -VMName $VMName
  Copy-Item $TemplateVHDX $VMPath
  Mount-VHD -Path $VMPath
  Copy-Item $AutoUnattendPath -Destination $AutoUnattendDestination
  Dismount-VHD $VMPath
}

function Remove-Server {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$VMName
  )
  Write-Host "Remove $($VMName)"
  $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
  if ($VM){
    stop-vm $VM -Force -TurnOff
    Start-Sleep -Seconds 3
    $VM | Remove-VMSnapshot 
    Start-Sleep -Seconds 3
    $Disks = Get-VHD -VMId $vm.VMId
    $Disks | Remove-Item -Force
    Start-Sleep -Seconds 3 
    $VM | Remove-VM -Force
  }
}

function Start-Server {
  [CmdletBinding()]
  param (
    # Name of the vm
    [Parameter(Mandatory=$true)][string]$VMName,
    [Parameter(Mandatory=$false)][string]$SwitchName
  )
  Copy-Server -VMName $VMName
  Write-Output "Start $($VMName) on path $($VMPath) on switch $($SwitchName)"
  $VMPath = Find-VHDPath -VMName $VMName
  New-VM -Name $VMName -MemoryStartupBytes 4GB -VHDPath $VMPath -Generation 2 -SwitchName $SwitchName #-WhatIf
  Set-VMProcessor -VMName $VMName -Count 2 # -Reserve 10 -Maximum 75 -RelativeWeight 200
  Write-output "VM Creation Completed. Starting VM $($VMName)" -Verbose
  Start-VM $VMName
}

function Cleanup{
  Write-Host "Removing vm's"
  $VMs = @($DC1Name, $TestVMName )
  foreach($VM in $VMs){
    Remove-Server -VMName $VM
  }
  Exit-Script
}

function Exit-Script{
  Write-Output "Time taken $($StopWatch.Elapsed)"

  $StopWatch.Stop()
  Write-Output "Finished $($MyInvocation.MyCommand.Name)"
  Stop-Transcript
  exit
}
function Wait-PowershellDirect{
  [CmdletBinding()]
  param (
    # Name of the vm
    [Parameter(Mandatory=$true)][string]$VMName,
    [Parameter(Mandatory=$true)][pscredential]$Credential
  )
  Write-Host "Wait for PowerShell Direct to start on VM $($VMName)"
  while ((Invoke-Command -VMName $VMName -Credential $Credential {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "No respons, sleeping for $($SecondsToSleep)"
    Start-Sleep -Seconds $SecondsToSleep
  }
  Write-Host "PowerShell Direct responds on $($VMName)"
}

function Start-Script {
  param(
    [parameter(mandatory=$True)][string]$Script,
    [parameter(mandatory=$True)][Hashtable]$Parameters,
    [parameter(mandatory=$False)][System.Management.Automation.Runspaces.PSSession]$Session,
    [parameter(mandatory=$False)][string]$VMName,
    [parameter(mandatory=$False)][pscredential]$Credential
  )
  if (-not($Credential)){
    $Credential = $DomainCredential
  }
  # Get the absolute path of the script
  $Script = Join-Path -Path $PSScriptRoot -ChildPath $Script
  Write-Host "Get script $($script)"
  # Magic happens here. We create a new scriptblock from a passed file and pass the hashtable as parameters to the scriptblock.
  $ScriptBlock = [scriptblock]::create(".{$(get-content -Path $Script -Raw)} $(&{$args} @Parameters)")

  if (-not($Session)){
    if (-not($VMName)){Throw "No VMName passed. If no session is passed as parameter, we need a VMName to create a session"}
    Write-host "Creating session to $($VMName)"
    $Session = New-PSSession -VMName $VMName -Credential $Credential
  }
  Invoke-Command -ScriptBlock $ScriptBlock -Session $Session
  $Session | Remove-PSSession
}

Clear-Host
Start-Transcript -Path $Log -NoClobber
$StopWatch = New-Object System.Diagnostics.Stopwatch
$StopWatch.Start()
Write-Output "Start script $($MyInvocation.MyCommand.Name) - version $($ScriptVersion)"

if ($Cleanup){
  Cleanup
} else {
$DefaultSwitch = Get-VMSwitch -Name "Default Switch"
  # Install server DC1
  Write-Host "Start on $($DC1Name)" -ForegroundColor Green
  Start-Server -VMName $DC1Name -SwitchName $DefaultSwitch.Name
  Wait-PowershellDirect -VMName $DC1Name -Credential $LocalCredential
  # Set the ip address
  $Adapter = Get-VMNetworkAdapter -VMName $DC1Name
  Write-host "Set IP address"
  $Parameters = @{
    MacAddress = $Adapter.MacAddress
    IPAddress = $DC1IP
    PrefixLength = $Prefix
    DefaultGateway = $Gateway
  }
  Start-Script -Script "SetIP.ps1" -Parameters $Parameters -VMName $DC1Name 
  # Configure RDP
  Write-Host "Configure RDP"
  Invoke-Command -VMName $DC1Name -Credential $LocalCredential {
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name "UserAuthentication" -Value 1
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
  }
  # Set computername
  Write-Host "Set computername to $($DC1Name)"
  Invoke-Command -VMName $DC1Name -Credential $LocalCredential {param($DC1Name) Rename-Computer -NewName $DC1Name} -ArgumentList $DC1Name
  write-host "Rebooting" 
  Restart-VM $DC1Name -Wait -Force
  # Install Domain
  Wait-PowershellDirect -VMName $DC1Name -Credential $LocalCredential
  $Parameters = @{
    DomainName = $DomainName
    Username = $LocalAdminUserName
    Password = $UnsecurePassword
    SetDNSForwarder = "CloudFlare"
    verbose = '$True'
  }
  Start-Script -Script "InstallDomain.ps1" -Parameters $Parameters -VMName $DC1Name
Exit-Script
}

