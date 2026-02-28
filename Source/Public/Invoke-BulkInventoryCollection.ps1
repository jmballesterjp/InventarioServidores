# Invoke-BulkInventoryCollection.ps1
# Ejecuta inventario masivo con control de concurrencia

function Invoke-BulkInventoryCollection {
    <#
    .SYNOPSIS
        Ejecuta recopilación de inventario en múltiples servidores con control de concurrencia
    
    .DESCRIPTION
        Usa PowerShell Jobs para ejecutar recopilaciones en paralelo con límite configurable
    
    .PARAMETER ServerName
        Array de nombres de servidores
    
    .PARAMETER ThrottleLimit
        Número máximo de jobs paralelos (default: 10)
    
    .PARAMETER Credential
        Credencial para conexiones remotas
    
    .PARAMETER Force
        Actualizar inventarios recientes
    
    .EXAMPLE
        Invoke-BulkInventoryCollection -ServerName @("SRV01","SRV02","SRV03") -ThrottleLimit 5
    
    .EXAMPLE
        Get-Content servers.txt | Invoke-BulkInventoryCollection -ThrottleLimit 20
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$ServerName,
        
        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$ThrottleLimit = 10,
        
        [Parameter()]
        [PSCredential]$Credential,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        $allServers = @()
    }
    
    process {
        $allServers += $ServerName
    }
    
    end {
        Write-InventoryLog -Message "=== INICIO INVENTARIO MASIVO ===" -Level Info
        Write-InventoryLog -Message "Servidores: $($allServers.Count) | Concurrencia: $ThrottleLimit" -Level Info
        
        Write-Host "`n=== Inventario Masivo ===" -ForegroundColor Cyan
        Write-Host "Servidores: $($allServers.Count)" -ForegroundColor Cyan
        Write-Host "Concurrencia máxima: $ThrottleLimit" -ForegroundColor Cyan
        Write-Host ""
        
        $jobs = @()
        $completed = 0
        $successful = 0
        $failed = 0
        $total = $allServers.Count
        
        $startTime = Get-Date
        
        # Ruta al manifest .psd1 (no al .psm1 que devuelve .Path).
        # Import-Module con el .psd1 garantiza que las clases se cargan correctamente
        # en el runspace del job antes de que se parseen los archivos de funciones.
        $moduleManifestPath = Join-Path (Get-Module 'InventarioServidores').ModuleBase 'InventarioServidores.psd1'

        foreach ($server in $allServers) {
            # Control de concurrencia
            while ((Get-Job -State Running | Where-Object Name -like "Inventory_*").Count -ge $ThrottleLimit) {
                Start-Sleep -Milliseconds 500
                
                # Procesar jobs completados
                $finished = Get-Job -State Completed | Where-Object Name -like "Inventory_*"
                foreach ($job in $finished) {
                    $completed++
                    
                    $result = Receive-Job -Job $job
                    
                    if ($result.Success) {
                        $successful++
                        Write-Host "  ✓ " -ForegroundColor Green -NoNewline
                        Write-Host "$($result.ServerName) " -NoNewline
                        Write-Host "[$($result.Inventory.Status.Result)]" -ForegroundColor $(
                            switch($result.Inventory.Status.Result) {
                                'Success' { 'Green' }
                                'Partial' { 'Yellow' }
                                default { 'Red' }
                            }
                        )
                    }
                    else {
                        $failed++
                        Write-Host "  ✗ " -ForegroundColor Red -NoNewline
                        Write-Host "$($result.ServerName) " -NoNewline
                        Write-Host "- $($result.Error)" -ForegroundColor Red
                    }
                    
                    Remove-Job -Job $job
                }
                
                # Actualizar progreso
                Write-Progress -Activity "Inventario masivo" `
                               -Status "Completados: $completed/$total (Exitosos: $successful, Fallos: $failed)" `
                               -PercentComplete (($completed / $total) * 100)
            }
            
            # Lanzar nuevo job. Las clases están en el scope del módulo (.psm1),
            # así que Import-Module del .psd1 las carga correctamente en el runspace del job.
            $job = Start-Job -Name "Inventory_$server" -ScriptBlock { 
                #TODO: Refactorizar para evitar duplicación de lógica con Update-ServerInventory (sugerencia)
                # cambiar parametro credential a psCredential nativo y reconstruir dentro del job para evitar problemas de serialización
                param($srv, $manifestPath, $credentialXml, $forceUpdate)
                
                # Importar módulo en el runspace del job
                Import-Module $manifestPath
                
                try {
                    $params = @{
                        ServerName = $srv
                        Force = $forceUpdate
                        PassThru = $true
                    }
                    
                    # Reconstruir credential si fue proporcionado
                    if ($credentialXml) {
                        $params.Credential = $credentialXml | ConvertTo-SecureString | ConvertFrom-SecureString | ConvertTo-SecureString -AsPlainText -Force
                    }
                    
                    $inventory = Update-ServerInventory @params -ErrorAction Stop
                    
                    return @{
                        Success = $true
                        ServerName = $srv
                        Inventory = $inventory
                    }
                }
                catch {
                    return @{
                        Success = $false
                        ServerName = $srv
                        Error = $_.Exception.Message
                    }
                }
            } -ArgumentList $server, $moduleManifestPath, $Credential, $Force.IsPresent
            
            $jobs += $job
        }
        
        # Esperar jobs restantes
        Write-Host "`nEsperando finalización de jobs restantes..." -ForegroundColor Yellow
        Wait-Job -Job $jobs | Out-Null
        
        # Procesar últimos resultados
        foreach ($job in (Get-Job | Where-Object Name -like "Inventory_*")) {
            $completed++
            
            $result = Receive-Job -Job $job
            
            if ($result.Success) {
                $successful++
                Write-Host "  ✓ " -ForegroundColor Green -NoNewline
                Write-Host "$($result.ServerName) " -NoNewline
                Write-Host "[$($result.Inventory.Status.Result)]" -ForegroundColor Green
            }
            else {
                $failed++
                Write-Host "  ✗ " -ForegroundColor Red -NoNewline
                Write-Host "$($result.ServerName) " -NoNewline
                Write-Host "- $($result.Error)" -ForegroundColor Red
            }
            
            Remove-Job -Job $job
        }
        
        Write-Progress -Activity "Inventario masivo" -Completed
        
        $duration = (Get-Date) - $startTime
        
        # Resumen final
        Write-Host "`n=== Resumen ===" -ForegroundColor Cyan
        Write-Host "Total: $total servidores" -ForegroundColor White
        Write-Host "Exitosos: $successful" -ForegroundColor Green
        Write-Host "Fallidos: $failed" -ForegroundColor Red
        Write-Host "Duración: $($duration.ToString('mm\:ss'))" -ForegroundColor White
        Write-Host ""
        
        Write-InventoryLog -Message "=== FIN INVENTARIO MASIVO === Total: $total | Exitosos: $successful | Fallidos: $failed | Duración: $($duration.TotalSeconds)s" -Level Info
        
        # Retornar objeto de resumen
        return [PSCustomObject]@{
            TotalServers = $total
            Successful = $successful
            Failed = $failed
            Duration = $duration
            SuccessRate = [Math]::Round(($successful / $total) * 100, 2)
        }
    }
}
