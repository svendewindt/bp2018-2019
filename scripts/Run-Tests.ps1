
$DiskSpdCommand = "D:\scripts\diskspd.exe" 

$Duration = '-d720'
$WaitBeforeStart = '-W60'
$SecondsToSleepAfterRun = '300'

$Random = '-r'                             
$WritePercentage = '-w30'
$BlockSize = '-b8k'
$Threads = '-t8'
$OutstandingIO = '-o15'
$DisableOSCaching = '-h'
$CaptureLatency= '-L'
$RandomBuffers = '-Z1M'
$FileSize = '-c30G'
#$FileName = 'I:\test\test.dat'
$Logs = "c:\Logs"
$Volumes = Get-Volume | ? {$_.FileSystemLabel -in ("SimpleWB", "SimpleWT", "MirrorWB", "MirrorWT", "ParityWB", "ParityWT")}
$volumes = $Volumes | Sort-Object DriveLetter

foreach($Volume in $Volumes){
    if (-not(Test-Path "$($Volume.DriveLetter):\test")){
        New-Item -ItemType Directory "$($Volume.DriveLetter):\test"
    }
    if (-not(Test-Path $Logs)){
        New-Item -ItemType Directory $Logs
    }
    $FileName = "$($Volume.DriveLetter):\test\$($Volume.FileSystemLabel).dat"
    $Log = "$($Logs)\$($Volume.FileSystemLabel).log"
    Write-Host "Running on $($fileName)" -ForegroundColor Green
    & $DiskSpdCommand $random $WritePercentage $Duration $WaitBeforeStart $BlockSize $Threads $OutstandingIO $DisableOSCaching $CaptureLatency $RandomBuffers $FileSize $FileName > $Log
    Start-Sleep -s $SecondsToSleepAfterRun
}

