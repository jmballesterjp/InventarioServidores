# Start-InventoryUI.ps1
# Launcher principal de la interfaz de inventario

#Requires -Version 5.1

[CmdletBinding()]
param()

Write-Host "🚀 Iniciando interfaz de Inventario de Servidores..." -ForegroundColor Cyan

# === RUTAS ===
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent $scriptPath
$xamlPath = Join-Path $scriptPath "Views\MainWindow.xaml"
$helpersPath = Join-Path $scriptPath "Helpers\XamlLoader.psm1"
$viewModelPath = Join-Path $scriptPath "ViewModels\MainViewModel.psm1"

Write-Verbose "Ruta del módulo: $moduleRoot"
Write-Verbose "Ruta XAML: $xamlPath"

# === CARGAR MÓDULO DE INVENTARIO ===
$modulePath = Join-Path $moduleRoot "InventarioServidores.psm1"

if (-not (Test-Path $modulePath)) {
    Write-Error "No se encontró el módulo de inventario en: $modulePath"
    Write-Error "Asegúrate de ejecutar este script desde la carpeta UI/ del proyecto"
    exit 1
}

try {
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "✓ Módulo de inventario cargado" -ForegroundColor Green
}
catch {
    Write-Error "Error al cargar módulo de inventario: $_"
    exit 1
}

# === CARGAR HELPERS Y VIEWMODEL ===
Import-Module -Force $helpersPath
Import-Module -Force $viewModelPath

# === CARGAR VENTANA XAML ===
Write-Host "📝 Cargando interfaz..." -ForegroundColor Cyan

try {
    $window = Load-XamlWindow -XamlPath $xamlPath
    Write-Host "✓ Interfaz cargada correctamente" -ForegroundColor Green
}
catch {
    Write-Error "Error al cargar la interfaz: $_"
    exit 1
}

# === OBTENER CONTROLES ===
$controlNames = @(
    'btnRefresh',
    'btnUpdateSelected',
    'btnUpdateAll',
    'btnSearch',
    'txtSearch',
    'dgServers',
    'txtStatus',
    'txtServerCount',
    'txtLastUpdate'
)

$controls = Get-AllXamlControls -Window $window -ControlNames $controlNames

# Verificar que se obtuvieron todos los controles
$missingControls = $controlNames | Where-Object { -not $controls.ContainsKey($_) }
if ($missingControls.Count -gt 0) {
    Write-Warning "No se encontraron los siguientes controles: $($missingControls -join ', ')"
}

# === CREAR VIEWMODEL ===
$viewModel = New-MainViewModel
Write-Verbose "ViewModel creado"

# === VINCULAR DATAGRID AL VIEWMODEL ===
$controls['dgServers'].ItemsSource = $viewModel.Servers

# === FUNCIÓN: ACTUALIZAR STATUS BAR ===
function Update-StatusBar {
    param(
        [string]$Message = "Listo",
        [switch]$ShowTime = $true
    )
    
    $controls['txtStatus'].Text = $Message
    $controls['txtServerCount'].Text = "Servidores: $($viewModel.Servers.Count)"
    
    if ($ShowTime) {
        $controls['txtLastUpdate'].Text = "Última actualización: $(Get-Date -Format 'HH:mm:ss')"
    }
}

# === FUNCIÓN: CARGAR INVENTARIOS ===
function Load-Inventories {
    [CmdletBinding()]
    param()
    
    try {
        Update-StatusBar -Message "Cargando inventarios..." -ShowTime:$false
        
        # Obtener todos los inventarios
        $inventories = Get-AllServerInventories -IncludeStale
        
        if ($inventories.Count -eq 0) {
            Update-StatusBar -Message "No hay inventarios disponibles. Usa Update-ServerInventory para crear uno."
            [System.Windows.MessageBox]::Show(
                "No se encontraron inventarios.`n`nEjecuta Update-ServerInventory desde PowerShell para crear inventarios.",
                "Sin inventarios",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            return
        }
        
        # Actualizar ViewModel
        Update-ServersInViewModel -ViewModel $viewModel -Inventories $inventories
        
        Update-StatusBar -Message "Inventarios cargados correctamente"
        
        Write-Host "✓ Cargados $($inventories.Count) servidores" -ForegroundColor Green
    }
    catch {
        $errorMsg = "Error al cargar inventarios: $($_.Exception.Message)"
        Update-StatusBar -Message $errorMsg -ShowTime:$false
        Write-Error $errorMsg
        
        [System.Windows.MessageBox]::Show(
            $errorMsg,
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# === FUNCIÓN: ACTUALIZAR SERVIDOR SELECCIONADO ===
function Update-SelectedServer {
    [CmdletBinding()]
    param()
    
    $selectedItem = $controls['dgServers'].SelectedItem
    
    if ($null -eq $selectedItem) {
        [System.Windows.MessageBox]::Show(
            "Por favor, selecciona un servidor de la lista.",
            "Sin selección",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }
    
    $serverName = $selectedItem.ServerName
    
    $result = [System.Windows.MessageBox]::Show(
        "¿Actualizar el inventario de '$serverName'?`n`nEsto puede tardar unos segundos.",
        "Confirmar actualización",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar -Message "Actualizando $serverName..." -ShowTime:$false
        
        try {
            # Deshabilitar botón mientras actualiza
            $controls['btnUpdateSelected'].IsEnabled = $false
            
            # Forzar actualización de la UI
            [System.Windows.Forms.Application]::DoEvents()
            
            # Actualizar inventario (esto puede tardar)
            $newInventory = Update-ServerInventory -ServerName $serverName -Force -PassThru -ErrorAction Stop
            
            if ($null -ne $newInventory) {
                # Recargar todos los inventarios para reflejar cambios
                Load-Inventories
                
                [System.Windows.MessageBox]::Show(
                    "Inventario de '$serverName' actualizado correctamente.`n`nEstado: $($newInventory.Status.Result)",
                    "Actualización exitosa",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
            }
        }
        catch {
            $errorMsg = "Error al actualizar '$serverName': $($_.Exception.Message)"
            Update-StatusBar -Message $errorMsg -ShowTime:$false
            
            [System.Windows.MessageBox]::Show(
                $errorMsg,
                "Error de actualización",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
        finally {
            $controls['btnUpdateSelected'].IsEnabled = $true
        }
    }
}

# === FUNCIÓN: ACTUALIZAR TODOS LOS SERVIDORES ===
function Update-AllServers {
    [CmdletBinding()]
    param()
    
    if ($viewModel.Servers.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "No hay servidores en la lista para actualizar.",
            "Sin servidores",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }
    
    $result = [System.Windows.MessageBox]::Show(
        "¿Actualizar el inventario de TODOS los servidores ($($viewModel.Servers.Count))?`n`nEsto puede tardar varios minutos.",
        "Confirmar actualización masiva",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar -Message "Iniciando actualización masiva..." -ShowTime:$false
        
        try {
            # Deshabilitar botones
            $controls['btnUpdateAll'].IsEnabled = $false
            $controls['btnUpdateSelected'].IsEnabled = $false
            $controls['btnRefresh'].IsEnabled = $false
            
            # Obtener nombres de servidores
            $serverNames = $viewModel.Servers | ForEach-Object { $_.ServerName }
            
            # Lanzar actualización masiva (esto ejecutará jobs en paralelo)
            $summary = Invoke-BulkInventoryCollection -ServerName $serverNames -ThrottleLimit 10 -Force
            
            # Recargar inventarios
            Load-Inventories
            
            # Mostrar resumen
            $message = @"
Actualización masiva completada.

Total: $($summary.TotalServers) servidores
Exitosos: $($summary.Successful)
Fallidos: $($summary.Failed)
Tasa de éxito: $($summary.SuccessRate)%
Duración: $($summary.Duration.ToString('mm\:ss'))
"@
            
            [System.Windows.MessageBox]::Show(
                $message,
                "Actualización completada",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
        catch {
            $errorMsg = "Error en actualización masiva: $($_.Exception.Message)"
            Update-StatusBar -Message $errorMsg -ShowTime:$false
            
            [System.Windows.MessageBox]::Show(
                $errorMsg,
                "Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
        finally {
            $controls['btnUpdateAll'].IsEnabled = $true
            $controls['btnRefresh'].IsEnabled = $true
        }
    }
}

# === FUNCIÓN: BUSCAR SERVIDORES ===
function Search-Servers {
    [CmdletBinding()]
    param()
    
    $searchText = $controls['txtSearch'].Text.Trim()
    
    if ([string]::IsNullOrEmpty($searchText)) {
        # Si está vacío, recargar todos
        Load-Inventories
        return
    }
    
    try {
        Update-StatusBar -Message "Buscando '$searchText'..." -ShowTime:$false
        
        # Obtener todos los inventarios
        $allInventories = Get-AllServerInventories -IncludeStale
        
        # Filtrar por nombre de servidor o IP
        $filtered = $allInventories | Where-Object {
            $_.ServerName -like "*$searchText*" -or
            $_.FQDN -like "*$searchText*" -or
            ($_.IPAddress -and ($_.IPAddress -join ',') -like "*$searchText*")
        }
        
        if ($filtered.Count -eq 0) {
            Update-StatusBar -Message "No se encontraron resultados para '$searchText'" -ShowTime:$false
            $viewModel.Servers.Clear()
        }
        else {
            Update-ServersInViewModel -ViewModel $viewModel -Inventories $filtered
            Update-StatusBar -Message "Encontrados $($filtered.Count) resultados para '$searchText'"
        }
    }
    catch {
        $errorMsg = "Error al buscar: $($_.Exception.Message)"
        Update-StatusBar -Message $errorMsg -ShowTime:$false
        Write-Error $errorMsg
    }
}

# === EVENTOS DE CONTROLES ===

# Botón Refrescar
$controls['btnRefresh'].Add_Click({
    Load-Inventories
})

# Botón Actualizar Seleccionado
$controls['btnUpdateSelected'].Add_Click({
    Update-SelectedServer
})

# Botón Actualizar Todos
$controls['btnUpdateAll'].Add_Click({
    Update-AllServers
})

# Botón Buscar
$controls['btnSearch'].Add_Click({
    Search-Servers
})

# TextBox Search - Enter key
$controls['txtSearch'].Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        Search-Servers
    }
})

# DataGrid - Selección cambiada
$controls['dgServers'].Add_SelectionChanged({
    $isSelected = $null -ne $controls['dgServers'].SelectedItem
    $controls['btnUpdateSelected'].IsEnabled = $isSelected
})

# Evento al cerrar ventana
$window.Add_Closing({
    Write-Host "`n👋 Cerrando interfaz de inventario" -ForegroundColor Cyan
})

# === CARGAR DATOS INICIALES ===
Load-Inventories

# === MOSTRAR VENTANA ===
Write-Host "✅ Interfaz lista. Mostrando ventana..." -ForegroundColor Green
Write-Host ""

[void]$window.ShowDialog()
