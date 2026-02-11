# Update-SchemaFrom1To2.ps1
# Migración de schema v1 a v2 (añade soporte IIS)

function Update-SchemaFrom1To2 {
    <#
    .SYNOPSIS
        Migra inventario de schema v1 a v2
    
    .DESCRIPTION
        Schema v2 añade:
        - Propiedad IIS para información de IIS
        - Información extendida de servicios
    
    .PARAMETER Inventory
        Inventario en schema v1
    
    .EXAMPLE
        $v2 = Update-SchemaFrom1To2 -Inventory $v1Inventory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Inventory
    )
    
    Write-InventoryLog -Message "Iniciando migración 1 -> 2" -ServerName $Inventory.ServerName -Level Info
    
    try {
        # Añadir propiedad IIS (vacía inicialmente)
        if (-not $Inventory.PSObject.Properties['IIS']) {
            Add-Member -InputObject $Inventory -MemberType NoteProperty -Name 'IIS' -Value $null -Force
            Write-InventoryLog -Message "Añadida propiedad IIS" -ServerName $Inventory.ServerName -Level Verbose
        }
        
        # Actualizar SchemaVersion
        $Inventory.SchemaVersion = 2
        
        # Marcar que requiere actualización completa para poblar IIS
        if ($Inventory.Status) {
            if (-not $Inventory.Status.Details) {
                $Inventory.Status.Details = @{}
            }
            $Inventory.Status.Details['RequiresFullRefresh'] = $true
            $Inventory.Status.AddWarning("Schema migrado a v2. Se recomienda ejecutar inventario completo para poblar datos IIS.")
        }
        
        Write-InventoryLog -Message "Migración 1 -> 2 completada" -ServerName $Inventory.ServerName -Level Info
        
        return $Inventory
    }
    catch {
        Write-InventoryLog -Message "Error en migración 1 -> 2: $_" -ServerName $Inventory.ServerName -Level Error -ErrorLog
        throw
    }
}
