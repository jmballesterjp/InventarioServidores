# HardwareInfo.ps1
# Información del Hardware

class HardwareInfo {
    [string]$Manufacturer
    [string]$Model
    [string]$SerialNumber
    
    # CPU
    [string]$CPUName
    [int]$CPUCores
    [int]$CPULogicalProcessors
    [int]$CPUMaxClockSpeed
    
    # Memoria
    [long]$RAMBytes
    [int]$RAMSlots
    [int]$RAMSlotsUsed
    
    # Discos
    [DiskInfo[]]$Disks
    
    HardwareInfo() {}
    
    [string] GetRAMFormatted() {
        $gb = [Math]::Round($this.RAMBytes / 1GB, 2)
        return "$gb GB"
    }
    
    [string] GetTotalDiskSpace() {
        $totalBytes = ($this.Disks | Measure-Object -Property SizeBytes -Sum).Sum
        $totalGB = [Math]::Round($totalBytes / 1GB, 2)
        return "$totalGB GB"
    }
    
    [string] ToString() {
        return "$($this.Manufacturer) $($this.Model) - $($this.GetRAMFormatted()) RAM"
    }
}

class DiskInfo {
    [string]$DeviceID
    [string]$VolumeName
    [string]$FileSystem
    [long]$SizeBytes
    [long]$FreeBytes
    [int]$PercentFree
    [string]$DriveType
    
    DiskInfo() {}
    
    [string] GetSizeFormatted() {
        $gb = [Math]::Round($this.SizeBytes / 1GB, 2)
        return "$gb GB"
    }
    
    [string] GetFreeFormatted() {
        $gb = [Math]::Round($this.FreeBytes / 1GB, 2)
        return "$gb GB"
    }
    
    [string] ToString() {
        return "$($this.DeviceID) - $($this.GetSizeFormatted()) ($($this.PercentFree)% libre)"
    }
}
