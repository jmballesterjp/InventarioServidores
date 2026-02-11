# ServerInventory.ps1
# Clase principal que representa el inventario de un servidor

class ServerInventory {
    # === Schema Version ===
    [int]$SchemaVersion = 1
    hidden static [int]$CurrentSchemaVersion = 1
    hidden static [int]$OldestSupportedVersion = 1
    
    # === Identificación ===
    [string]$ServerName
    [string]$FQDN
    [string[]]$IPAddress
    
    # === Metadata ===
    [datetime]$LastInventory
    [datetime]$CreatedDate
    [string]$CollectedBy
    
    # === Información del Sistema ===
    [OSInfo]$OS
    [HardwareInfo]$Hardware
    [NetworkInfo[]]$Network
    
    # === Información de Aplicaciones (para futuras versiones) ===
    # [IISInfo]$IIS  # Schema v2+
    
    # === Estado de la Recopilación ===
    [CollectionStatus]$Status
    
    # === Extensibility ===
    [hashtable]$CustomProperties = @{}
    
    # === Constructores ===
    ServerInventory() {
        $this.SchemaVersion = [ServerInventory]::CurrentSchemaVersion
        $this.CreatedDate = Get-Date
        $this.LastInventory = Get-Date
        $this.CollectedBy = $env:USERNAME
        $this.Status = [CollectionStatus]::new()
    }
    
    ServerInventory([string]$serverName) {
        $this.ServerName = $serverName
        $this.SchemaVersion = [ServerInventory]::CurrentSchemaVersion
        $this.CreatedDate = Get-Date
        $this.LastInventory = Get-Date
        $this.CollectedBy = $env:USERNAME
        $this.Status = [CollectionStatus]::new()
    }
    
# <#
    static [ServerInventory] FromCliXml([PSObject]$deserializedObject) {
        $inventory = [ServerInventory]::new($deserializedObject.ServerName)
        
        # === Basic Properties ===
        $inventory.FQDN = $deserializedObject.FQDN
        $inventory.IPAddress = $deserializedObject.IPAddress
        $inventory.LastInventory = $deserializedObject.LastInventory
        $inventory.CreatedDate = $deserializedObject.CreatedDate
        $inventory.CollectedBy = $deserializedObject.CollectedBy
        $inventory.SchemaVersion = $deserializedObject.SchemaVersion
        
        # === Nested Object: OSInfo ===
        if ($deserializedObject.OS) {
            $osInfo = [OSInfo]::new()
            $osInfo.Name = $deserializedObject.OS.Name
            $osInfo.Version = $deserializedObject.OS.Version
            $osInfo.Build = $deserializedObject.OS.Build
            $osInfo.Architecture = $deserializedObject.OS.Architecture
            $osInfo.InstallDate = $deserializedObject.OS.InstallDate
            $osInfo.LastBootTime = $deserializedObject.OS.LastBootTime
            $osInfo.UptimeDays = $deserializedObject.OS.UptimeDays
            $osInfo.SerialNumber = $deserializedObject.OS.SerialNumber
            $osInfo.RegisteredUser = $deserializedObject.OS.RegisteredUser
            $osInfo.Organization = $deserializedObject.OS.Organization
            $inventory.OS = $osInfo
        }
        
        # === Nested Object: HardwareInfo ===
        if ($deserializedObject.Hardware) {
            $hw = [HardwareInfo]::new()
            $hw.Manufacturer = $deserializedObject.Hardware.Manufacturer
            $hw.Model = $deserializedObject.Hardware.Model
            $hw.SerialNumber = $deserializedObject.Hardware.SerialNumber
            $hw.CPUName = $deserializedObject.Hardware.CPUName
            $hw.CPUCores = $deserializedObject.Hardware.CPUCores
            $hw.CPULogicalProcessors = $deserializedObject.Hardware.CPULogicalProcessors
            $hw.CPUMaxClockSpeed = $deserializedObject.Hardware.CPUMaxClockSpeed
            $hw.RAMBytes = $deserializedObject.Hardware.RAMBytes
            $hw.RAMSlots = $deserializedObject.Hardware.RAMSlots
            $hw.RAMSlotsUsed = $deserializedObject.Hardware.RAMSlotsUsed
            
            # Reconstruct Disks array
            if ($deserializedObject.Hardware.Disks) {
                $hw.Disks = @()
                foreach ($diskObj in $deserializedObject.Hardware.Disks) {
                    $disk = [DiskInfo]::new()
                    $disk.DeviceID = $diskObj.DeviceID
                    $disk.VolumeName = $diskObj.VolumeName
                    $disk.FileSystem = $diskObj.FileSystem
                    $disk.SizeBytes = $diskObj.SizeBytes
                    $disk.FreeBytes = $diskObj.FreeBytes
                    $disk.PercentFree = $diskObj.PercentFree
                    $disk.DriveType = $diskObj.DriveType
                    $hw.Disks += $disk
                }
            }
            $inventory.Hardware = $hw
        }
        
        # === Nested Array: NetworkInfo ===
        if ($deserializedObject.Network) {
            $inventory.Network = @()
            foreach ($netObj in $deserializedObject.Network) {
                $net = [NetworkInfo]::new()
                $net.AdapterName = $netObj.AdapterName
                $net.Description = $netObj.Description
                $net.MACAddress = $netObj.MACAddress
                $net.IPAddress = $netObj.IPAddress
                $net.SubnetMask = $netObj.SubnetMask
                $net.DefaultGateway = $netObj.DefaultGateway
                $net.DNSServers = $netObj.DNSServers
                $net.DHCPEnabled = $netObj.DHCPEnabled
                $net.DHCPServer = $netObj.DHCPServer
                $net.Status = $netObj.Status
                $net.Speed = $netObj.Speed
                $inventory.Network += $net
            }
        }
        
        # === Nested Object: CollectionStatus ===
        if ($deserializedObject.Status) {
            $collectionStatus = [CollectionStatus]::new()
            $collectionStatus.Result = $deserializedObject.Status.Result
            $collectionStatus.Message = $deserializedObject.Status.Message
            $collectionStatus.Timestamp = $deserializedObject.Status.Timestamp
            $collectionStatus.Details = $deserializedObject.Status.Details
            $collectionStatus.Errors = $deserializedObject.Status.Errors
            $collectionStatus.Warnings = $deserializedObject.Status.Warnings
            $inventory.Status = $collectionStatus
        }
        
        # === Custom Properties ===
        if ($deserializedObject.CustomProperties) {
            $inventory.CustomProperties = $deserializedObject.CustomProperties
        }
        
        return $inventory
    }
#>
    # === Métodos Útiles ===
    [string] ToString() {
        return "$($this.ServerName) - $($this.OS.Name) - Last: $($this.LastInventory.ToString('yyyy-MM-dd HH:mm'))"
    }
    
    [bool] IsStale([int]$daysThreshold = 7) {
        return ((Get-Date) - $this.LastInventory).TotalDays -gt $daysThreshold
    }
    
    [string] GetInventoryFilePath([string]$basePath) {
        return Join-Path $basePath "$($this.ServerName).var.xml"
    }
}
