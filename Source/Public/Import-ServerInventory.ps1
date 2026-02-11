# Import-ServerInventory.ps1
# Importa un inventario desde archivo con validación y migración automática

function Import-ServerInventory {
    <#
    .SYNOPSIS
        Importa un inventario de servidor desde archivo
    
    .DESCRIPTION
        Lee un archivo .var.xml, valida el schema y ejecuta migraciones si es necesario
    
    .PARAMETER Path
        Ruta al archivo .var.xml
    
    .PARAMETER ServerName
        Nombre del servidor (alternativa a Path)
    
    .PARAMETER Strict
        Validación estricta del schema
    
    .PARAMETER NoMigration
        No ejecutar migraciones automáticas
    
    .EXAMPLE
        $inventory = Import-ServerInventory -ServerName "SRV01"
    
    .EXAMPLE
        $inventory = Import-ServerInventory -Path "C:\Data\Inventory\SRV01.var.xml"
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByServerName')]
    [OutputType([ServerInventory])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPath', Position = 0)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter(Mandatory, ParameterSetName = 'ByServerName', Position = 0)]
        [string]$ServerName,
        
        [Parameter()]
        [switch]$Strict,
        
        [Parameter()]
        [switch]$NoMigration
    )
    
    # Resolver path
    if ($PSCmdlet.ParameterSetName -eq 'ByServerName') {
        $Path = Join-Path $script:DataPath "Inventory/$ServerName.var.xml"
        
        if (-not (Test-Path $Path)) {
            Write-Error "No existe inventario para el servidor '$ServerName' en: $Path"
            return $null
        }
    }
    
    Write-InventoryLog -Message "Importando inventario desde: $Path" -Level Verbose
    
    try {
        # Importar XML
        # [ServerInventory]$inventory = Import-Clixml -Path $Path -ErrorAction Stop

        # Importar el objeto deserializado
        $deserializado = Import-CliXml -Path $Path -ErrorAction Stop
        # Rehidratar a objeto con métodos
        $inventory = [ServerInventory]::FromCliXml($deserializado)

        
        # Validar schema básico
        if (-not (Test-ServerInventorySchema -Inventory $inventory -Strict:$Strict)) {
            Write-Error "El inventario no pasó la validación de schema"
            return $null
        }
        
        # Migración automática si es necesario
        if (-not $NoMigration -and $inventory.SchemaVersion -lt [ServerInventory]::CurrentSchemaVersion) {
            Write-InventoryLog -Message "Inventario requiere migración (v$($inventory.SchemaVersion) -> v$([ServerInventory]::CurrentSchemaVersion))" -ServerName $inventory.ServerName -Level Info
            
            $inventory = Invoke-SchemaMigration -Inventory $inventory
            
            # Guardar versión migrada
            Export-ServerInventory -Inventory $inventory -Force
        }
        
        Write-InventoryLog -Message "Inventario importado correctamente: $($inventory.ServerName)" -ServerName $inventory.ServerName -Level Verbose
        
        return $inventory
    }
    catch {
        Write-Error "Error al importar inventario desde '$Path': $_"
        Write-InventoryLog -Message "Error al importar inventario: $_" -Level Error -ErrorLog
        return $null
    }
}
