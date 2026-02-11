# Update-ServerInventory.ps1
# Actualiza el inventario de uno o más servidores

function Update-ServerInventory {
    <#
    .SYNOPSIS
        Actualiza el inventario de un servidor
    
    .DESCRIPTION
        Ejecuta recopilación remota de información y guarda el inventario actualizado
    
    .PARAMETER ServerName
        Nombre(s) del servidor a actualizar
    
    .PARAMETER Credential
        Credencial para conexión remota
    
    .PARAMETER Force
        Actualizar aunque el inventario sea reciente
    
    .PARAMETER PassThru
        Retornar el objeto de inventario actualizado
    
    .EXAMPLE
        Update-ServerInventory -ServerName "SRV01"
    
    .EXAMPLE
        "SRV01","SRV02","SRV03" | Update-ServerInventory -PassThru
    
    .EXAMPLE
        Update-ServerInventory -ServerName "SRV01" -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    [OutputType([ServerInventory])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ServerName,
        
        [Parameter()]
        [PSCredential]$Credential,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    process {
        foreach ($server in $ServerName) {
            Write-InventoryLog -Message "Iniciando actualización de inventario" -ServerName $server -Level Info
            
            # Verificar si ya existe y está actualizado
            $existingPath = Join-Path $script:DataPath "Inventory" "$server.var.xml"
            if ((Test-Path $existingPath) -and -not $Force) {
                try {
                    $existing = Import-ServerInventory -ServerName $server
                    if ($null -ne $existing -and -not $existing.IsStale(1)) {
                        Write-Warning "El inventario de '$server' fue actualizado hace menos de 1 día. Use -Force para actualizar de todas formas."
                        if ($PassThru) { Write-Output $existing }
                        continue
                    }
                }
                catch {
                    Write-Verbose "No se pudo verificar inventario existente, procediendo con actualización"
                }
            }
            
            # Recopilar inventario
            $params = @{
                ServerName = $server
            }
            
            if ($Credential) {
                $params.Credential = $Credential
            }
            
            try {
                $inventory = Get-RemoteServerInventory @params
                
                if ($null -eq $inventory) {
                    Write-Error "No se pudo obtener inventario de '$server'"
                    Write-InventoryLog -Message "Fallo al obtener inventario" -ServerName $server -Level Error -ErrorLog
                    continue
                }
                
                # Guardar inventario
                $exportParams = @{
                    Inventory = $inventory
                    Force = $true
                }
                
                # Leer configuración para JSON
                $settingsFile = Join-Path $script:ConfigPath 'Settings.psd1'
                if (Test-Path $settingsFile) {
                    $settings = Import-PowerShellDataFile -Path $settingsFile
                    if ($settings.AlsoExportJSON) {
                        $exportParams.AlsoExportJSON = $true
                    }
                }
                
                Export-ServerInventory @exportParams
                
                Write-Host "✓ Inventario actualizado: $server [$($inventory.Status.Result)]" -ForegroundColor Green
                
                if ($PassThru) {
                    Write-Output $inventory
                }
            }
            catch {
                Write-Error "Error al actualizar inventario de '$server': $_"
                Write-InventoryLog -Message "Error crítico: $_" -ServerName $server -Level Error -ErrorLog
            }
        }
    }
}
