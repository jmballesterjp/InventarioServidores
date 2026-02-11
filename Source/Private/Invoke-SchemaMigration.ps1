# Invoke-SchemaMigration.ps1
# Migra un inventario de una versión de schema a otra

function Invoke-SchemaMigration {
    <#
    .SYNOPSIS
        Migra un inventario entre versiones de schema
    
    .DESCRIPTION
        Ejecuta una cadena de migraciones secuenciales para llevar un inventario
        desde su versión actual hasta la versión más reciente del schema
    
    .PARAMETER Inventory
        Inventario a migrar
    
    .EXAMPLE
        $updated = Invoke-SchemaMigration -Inventory $oldInventory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Inventory
    )
    
    $originalVersion = $Inventory.SchemaVersion
    $targetVersion = [ServerInventory]::CurrentSchemaVersion
    
    if ($originalVersion -eq $targetVersion) {
        Write-InventoryLog -Message "Schema ya está en la versión actual ($targetVersion)" -ServerName $Inventory.ServerName -Level Verbose
        return $Inventory
    }
    
    Write-InventoryLog -Message "Migrando schema de v$originalVersion a v$targetVersion" -ServerName $Inventory.ServerName -Level Info
    
    # Migración secuencial
    while ($Inventory.SchemaVersion -lt $targetVersion) {
        $currentVersion = $Inventory.SchemaVersion
        
        switch ($currentVersion) {
            1 { 
                Write-InventoryLog -Message "Ejecutando migración 1 -> 2" -ServerName $Inventory.ServerName -Level Info
                $Inventory = Update-SchemaFrom1To2 -Inventory $Inventory 
            }
            # Futuras migraciones aquí
            # 2 { $Inventory = Update-SchemaFrom2To3 -Inventory $Inventory }
            # 3 { $Inventory = Update-SchemaFrom3To4 -Inventory $Inventory }
            
            default {
                Write-InventoryLog -Message "No existe migración desde versión $currentVersion" -ServerName $Inventory.ServerName -Level Error
                throw "No se encontró función de migración para schema v$currentVersion"
            }
        }
        
        # Prevenir bucles infinitos
        if ($Inventory.SchemaVersion -eq $currentVersion) {
            Write-InventoryLog -Message "La migración no actualizó la versión del schema" -ServerName $Inventory.ServerName -Level Error
            throw "Error en migración: SchemaVersion no cambió de v$currentVersion"
        }
    }
    
    Write-InventoryLog -Message "Migración completada: v$originalVersion -> v$($Inventory.SchemaVersion)" -ServerName $Inventory.ServerName -Level Info
    
    return $Inventory
}
