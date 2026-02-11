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
