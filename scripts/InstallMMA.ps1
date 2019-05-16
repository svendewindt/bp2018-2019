<#
.SYNOPSIS
  Script to Install the Microsoft Monitoring Agent (MMA)

.DESCRIPTION
  This script will download the MMA in a resources folder and install it

.PARAMETER WorkspaceID
  Specivies the ID of the workspace

.PARAMETER WorkspaceKey
  Specivies the Key of the workspace

.OUTPUTS
  A log file in the temp directory

.NOTES
  Version:        0.1
  Author:         Sven de Windt
  Creation Date:  28/04/2019
  Purpose/Change: Initial script development

.EXAMPLE
  .\InstallMMA -WorkspaceID <id> -WorkspaceKey <key> -Verbose
#>

#requires -version 3.0

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------

param(
    [CmdletBinding()]
        [parameter(mandatory = $true)][String]$WorkspaceID,
        [parameter(mandatory = $true)][String]$WorkspaceKey
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



#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Clear-Host
Start-Transcript -Path $Log -NoClobber
$StopWatch = New-Object System.Diagnostics.Stopwatch
$StopWatch.Start()
Write-Output "Start script - version $($ScriptVersion)"

$MMA64bitURL = "http://download.microsoft.com/download/1/5/E/15E274B9-F9E2-42AE-86EC-AC988F7631A0/MMASetup-AMD64.exe"
$ResourcesFolder = new-item -ItemType Directory -Path "c:\" -Name "Resources"

$Destination = Join-Path $ResourcesFolder.FullName  "MMASetup-AMD64.exe"

$null = Invoke-WebRequest -uri $MMA64bitURL -OutFile $Destination 
$null = Unblock-File $Destination 

Write-Verbose "Installing Microsoft Monitoring Agent"
$Command = "$Destination /C:setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID=$WorkspaceID" + " OPINSIGHTS_WORKSPACE_KEY=$WorkspaceKey " + " AcceptEndUserLicenseAgreement=1" 

Invoke-Expression -Command $Command

#-----------------------------------------------------------[Finish up]------------------------------------------------------------
Write-Output $StopWatch.Elapsed

$StopWatch.Stop()
Write-Output "Finished $($MyInvocation.MyCommand.Name)"
Stop-Transcript
