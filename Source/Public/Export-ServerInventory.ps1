# Export-ServerInventory.ps1
# Exporta un inventario a archivo

function Export-ServerInventory {
    <#
    .SYNOPSIS
        Exporta un inventario de servidor a archivo
    
    .DESCRIPTION
        Guarda un inventario como .var.xml y opcionalmente como .json
    
    .PARAMETER Inventory
        Objeto de inventario a exportar
    
    .PARAMETER Path
        Ruta de destino (opcional, usa convención por defecto)
    
    .PARAMETER Force
        Sobrescribir si ya existe
    
    .PARAMETER AlsoExportJSON
        También exportar versión JSON para lectura humana
    
    .EXAMPLE
        Export-ServerInventory -Inventory $inv -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ServerInventory]$Inventory,
        
        [Parameter()]
        [string]$Path,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$AlsoExportJSON
    )
    
    process {
        # Path por defecto
        if (-not $Path) {
            $Path = Join-Path $script:DataPath "Inventory/$($Inventory.ServerName).var.xml" #TODO: Fix them all
        }
        
        $directory = Split-Path $Path -Parent
        if (-not (Test-Path $directory)) {
            [void](New-Item -Path $directory -ItemType Directory -Force)
        }
        
        # Verificar sobrescritura
        if ((Test-Path $Path) -and -not $Force) {
            Write-Error "El archivo ya existe. Use -Force para sobrescribir: $Path"
            return
        }
        
        try {
            # Exportar XML
            Export-Clixml -InputObject $Inventory -Path $Path -Depth 10 -Force
            Write-InventoryLog -Message "Inventario exportado a: $Path" -ServerName $Inventory.ServerName -Level Info
            
            # Export JSON opcional
            try { #Falla si el inventario tiene objetos complejos no serializables o null-valued, por eso va en try separado
                if ($AlsoExportJSON) {
                    $jsonPath = $Path -replace '\.var\.xml$', '.json'
                    
                    # Crear objeto simplificado para JSON
                    $jsonObject = [ordered]@{
                        ServerName = $Inventory.ServerName
                        FQDN = $Inventory.FQDN
                        IPAddress = $Inventory.IPAddress
                        LastInventory = $Inventory.LastInventory.ToString('yyyy-MM-dd HH:mm:ss')
                        SchemaVersion = $Inventory.SchemaVersion
                        OS = [ordered]@{
                            Name = $Inventory.OS.Name
                            Version = $Inventory.OS.Version
                            Build = $Inventory.OS.Build
                            Architecture = $Inventory.OS.Architecture
                            UptimeDays = $Inventory.OS.UptimeDays
                        }
                        Hardware = [ordered]@{
                            Manufacturer = $Inventory.Hardware.Manufacturer
                            Model = $Inventory.Hardware.Model
                            CPU = $Inventory.Hardware.CPUName
                            CPUCores = $Inventory.Hardware.CPUCores
                            RAM = $Inventory.Hardware.GetRAMFormatted()
                            Disks = @($Inventory.Hardware.Disks | ForEach-Object {
                                [ordered]@{
                                    Device = $_.DeviceID
                                    Size = $_.GetSizeFormatted()
                                    Free = $_.GetFreeFormatted()
                                    PercentFree = $_.PercentFree
                                }
                            })
                        }
                        Network = @($Inventory.Network | ForEach-Object {
                            [ordered]@{
                                Adapter = $_.AdapterName
                                IP = $_.IPAddress -join ', '
                                MAC = $_.MACAddress
                                Speed = $_.GetSpeedFormatted()
                            }
                        })
                        Status = [ordered]@{
                            Result = $Inventory.Status.Result.ToString()
                            Message = $Inventory.Status.Message
                            Errors = $Inventory.Status.Errors
                            Warnings = $Inventory.Status.Warnings
                        }
                    }
                    
                    $jsonObject | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Force
                    Write-InventoryLog -Message "JSON exportado a: $jsonPath" -ServerName $Inventory.ServerName -Level Verbose
                }
            }
            catch {
                Write-Warning "Error al exportar inventario, en formato JSON: $_"
                Write-InventoryLog -Message "Error al exportar inventario, en formato JSON: $_" -ServerName $Inventory.ServerName -Level Error -ErrorLog
            }
            
            return $Path
        }
        catch {
            Write-Error "Error al exportar inventario: $_"
            Write-InventoryLog -Message "Error al exportar inventario: $_" -ServerName $Inventory.ServerName -Level Error -ErrorLog
        }
    }
}
