# Test-ServerInventorySchema.ps1
# Valida el schema de un inventario

function Test-ServerInventorySchema {
    <#
    .SYNOPSIS
        Valida que un inventario cumpla con el schema esperado
    
    .PARAMETER Inventory
        Objeto de inventario a validar
    
    .PARAMETER Strict
        Validación estricta (todos los campos requeridos)
    
    .EXAMPLE
        Test-ServerInventorySchema -Inventory $inv -Strict
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Inventory,
        
        [Parameter()]
        [switch]$Strict
    )
    
    # Propiedades mínimas requeridas
    $requiredProperties = @('ServerName', 'SchemaVersion', 'LastInventory')
    
    foreach ($prop in $requiredProperties) {
        if (-not $Inventory.PSObject.Properties[$prop]) {
            Write-InventoryLog -Message "Validación fallida: falta propiedad '$prop'" -Level Error
            return $false
        }
    }
    
    # Validar versión de schema
    if ($Inventory.SchemaVersion -lt [ServerInventory]::OldestSupportedVersion) {
        Write-InventoryLog -Message "Schema version $($Inventory.SchemaVersion) no soportada (mínimo: $([ServerInventory]::OldestSupportedVersion))" -Level Error
        return $false
    }
    
    if ($Inventory.SchemaVersion -gt [ServerInventory]::CurrentSchemaVersion) {
        Write-InventoryLog -Message "Schema version $($Inventory.SchemaVersion) es más nueva que la soportada ($([ServerInventory]::CurrentSchemaVersion))" -Level Warning
    }
    
    if ($Strict) {
        # Validación estricta: verificar tipos
        if ($Inventory.OS -and $Inventory.OS -isnot [OSInfo]) {
            Write-InventoryLog -Message "Propiedad OS no es del tipo [OSInfo]" -Level Error
            return $false
        }
        
        if ($Inventory.Hardware -and $Inventory.Hardware -isnot [HardwareInfo]) {
            Write-InventoryLog -Message "Propiedad Hardware no es del tipo [HardwareInfo]" -Level Error
            return $false
        }
    }
    
    return $true
}
