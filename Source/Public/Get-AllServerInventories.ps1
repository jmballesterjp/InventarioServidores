# Get-AllServerInventories.ps1
# Obtiene todos los inventarios almacenados

function Get-AllServerInventories {
    <#
    .SYNOPSIS
        Obtiene todos los inventarios almacenados
    
    .DESCRIPTION
        Lee todos los archivos .var.xml del directorio de inventarios
    
    .PARAMETER IncludeStale
        Incluir inventarios desactualizados
    
    .PARAMETER DaysThreshold
        Umbral de días para considerar desactualizado
    
    .EXAMPLE
        $allServers = Get-AllServerInventories
    
    .EXAMPLE
        Get-AllServerInventories | Where-Object { $_.Status.Result -eq 'Success' }
    #>
    [CmdletBinding()]
    [OutputType([ServerInventory[]])]
    param(
        [Parameter()]
        [switch]$IncludeStale,
        
        [Parameter()]
        [int]$DaysThreshold = 7
    )
    
    $inventoryPath = Join-Path $script:DataPath 'Inventory'
    
    if (-not (Test-Path $inventoryPath)) {
        Write-Warning "No existe el directorio de inventarios: $inventoryPath"
        return @()
    }
    
    $files = Get-ChildItem -Path $inventoryPath -Filter '*.var.xml'
    
    if ($files.Count -eq 0) {
        Write-Warning "No se encontraron inventarios en: $inventoryPath"
        return @()
    }
    
    Write-Verbose "Encontrados $($files.Count) inventarios"
    
    $inventories = @()
    
    foreach ($file in $files) {
        try {
            $inventory = Import-ServerInventory -Path $file.FullName
            
            if ($null -ne $inventory) {
                if ($IncludeStale -or -not $inventory.IsStale($DaysThreshold)) {
                    $inventories += $inventory
                }
                else {
                    Write-Verbose "Inventario desactualizado omitido: $($inventory.ServerName)"
                }
            }
        }
        catch {
            Write-Warning "Error al importar '$($file.Name)': $_"
        }
    }
    
    return $inventories
}
