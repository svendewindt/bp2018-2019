
#get-storagepool

 #Get-StoragePool -IsPrimordial $true | Get-PhysicalDisk | Where-Object CanPool -eq $True

$StoragePoolName = "StoragePoolBP"
if (Get-storagepool –FriendlyName $StoragePoolName){
    Write-Host "Existing storagepool found, removing..."
    Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false
    Get-storagepool –FriendlyName $StoragePoolName| Remove-StoragePool -Confirm:$false
}

Write-host "Create storage pool with all available disks"
New-StoragePool –FriendlyName $StoragePoolName –StorageSubsystemFriendlyName "Windows Storage*" –PhysicalDisks (Get-PhysicalDisk –CanPool $True)
$Pool = get-storagepool –FriendlyName $StoragePoolName

[System.UInt64]$DiskSize = (100GB)
$SimpleDiskNameFixed = "Simple"     # Stripe
$MirrorDiskNameFixed = "Mirror"     # Mirror
$ParityDiskNameFixed = "Parity"     # Parity

Write-host "Create virtual disk $($SimpleDiskNameFixed)"
New-VirtualDisk –StoragePoolFriendlyName $pool.FriendlyName –FriendlyName $SimpleDiskNameFixed -ResiliencySettingName  simple –Size $DiskSize -ProvisioningType Fixed | Out-Null
Write-host "Create virtual disk $($MirrorDiskNameFixed)"
New-VirtualDisk –StoragePoolFriendlyName $pool.FriendlyName –FriendlyName $MirrorDiskNameFixed -ResiliencySettingName  mirror –Size $DiskSize -ProvisioningType Fixed | Out-Null
Write-host "Create virtual disk $($ParityDiskNameFixed)"
New-VirtualDisk –StoragePoolFriendlyName $pool.FriendlyName –FriendlyName $ParityDiskNameFixed -ResiliencySettingName  parity –Size $DiskSize -ProvisioningType Fixed | Out-Null

Write-host "Create a volume on each disk"
$VirtualDisks = Get-VirtualDisk
foreach ($VirtualDisk in $VirtualDisks){
    $Disk = Initialize-Disk -VirtualDisk $VirtualDisk -PartitionStyle GPT -PassThru #-FriendlyName  #$vd.FriendlyName 
    $Volume = $Disk | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -NewFileSystemLabel $VirtualDisk.FriendlyName
    #Write-Host "Creating folder " -ForegroundColor Green
    new-item -ItemType Directory -Name $($VirtualDisk.FriendlyName + "_WT") -Path "$($Volume.DriveLetter):\" | Out-Null
    new-item -ItemType Directory -Name $($VirtualDisk.FriendlyName + "_WB") -Path "$($Volume.DriveLetter):\" | Out-Null
}
