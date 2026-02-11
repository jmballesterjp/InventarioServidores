# Get-ServerInventory.ps1
# Obtiene el inventario de un servidor (lee desde cache)

function Get-ServerInventory {
    <#
    .SYNOPSIS
        Obtiene el inventario de un servidor desde cache
    
    .DESCRIPTION
        Lee el inventario almacenado en archivo. No ejecuta recopilación nueva.
        Use Update-ServerInventory para actualizar.
    
    .PARAMETER ServerName
        Nombre del servidor
    
    .PARAMETER IncludeStale
        Incluir inventarios desactualizados
    
    .PARAMETER DaysThreshold
        Umbral de días para considerar un inventario desactualizado
    
    .EXAMPLE
        $inv = Get-ServerInventory -ServerName "SRV01"
    
    .EXAMPLE
        Get-ServerInventory -ServerName "SRV01" | Format-Table ServerName, LastInventory, @{N='OS';E={$_.OS.Name}}
    #>
    [CmdletBinding()]
    [OutputType([ServerInventory])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ServerName,
        
        [Parameter()]
        [switch]$IncludeStale,
        
        [Parameter()]
        [int]$DaysThreshold = 7
    )
    
    process {
        foreach ($server in $ServerName) {
            $inventory = Import-ServerInventory -ServerName $server
            
            if ($null -eq $inventory) {
                Write-Warning "No se encontró inventario para: $server"
                continue
            }
            
            # Verificar si está desactualizado
            if (-not $IncludeStale -and $inventory.IsStale($DaysThreshold)) {
                Write-Warning "Inventario de '$server' está desactualizado (última actualización: $($inventory.LastInventory)). Use -IncludeStale o ejecute Update-ServerInventory."
                continue
            }
            
            Write-Output $inventory
        }
    }
}
