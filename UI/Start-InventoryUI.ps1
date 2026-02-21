# Start-InventoryUI.ps1
# Launcher principal de la interfaz de inventario

#Requires -Version 5.1

[CmdletBinding()]
param()

# Add-Type -AssemblyName System.Windows.Forms
# Solucion 1 (descartada por usar WPF>WinForms): Agregar referencia a Windows Forms para usar [System.Windows.Forms.Application]::DoEvents()

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
Import-Module -Force $helpersPath -DisableNameChecking # Disable Warnings por funciones sin verbos aprobados (Load-*), pero es un módulo de helpers
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
    'btnViewDetails',
    'btnUpdateAll',
    'btnSearch',
    'btnAddServer',
    'btnDeleteServer',
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

# === LEER CONFIGURACIÓN ===
$settingsPath = Join-Path $moduleRoot "Config\Settings.psd1"
$script:StaleThresholdDays = 7  # valor por defecto
if (Test-Path $settingsPath) {
    try {
        $settings = Import-PowerShellDataFile $settingsPath
        if ($settings.ContainsKey('StaleThresholdDays')) {
            $script:StaleThresholdDays = [int]$settings.StaleThresholdDays
        }
    }
    catch {
        Write-Warning "No se pudo leer la configuración: $_. Usando umbral Stale por defecto ($($script:StaleThresholdDays) días)."
    }
}
Write-Verbose "Umbral de inventario anticuado (Stale): $($script:StaleThresholdDays) días"

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
                "No se encontraron inventarios.`n`nEjecuta Update-ServerInventory desde PowerShell para crear inventarios.`n`nO mediante el botón 'Inventariar Seleccionado' después de agregar un servidor.",
                "Sin inventarios",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            return
        }
        
        # Actualizar ViewModel
        Update-ServersInViewModel -ViewModel $viewModel -Inventories $inventories -StaleThresholdDays $script:StaleThresholdDays

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

# === FUNCIÓN: ACTUALIZAR/INVENTARIAR SERVIDOR SELECCIONADO ===
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
        "¿Inventariar '$serverName'?`n`nEsto puede tardar unos segundos.",
        "Confirmar inventario",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar -Message "Inventariando $serverName..." -ShowTime:$false
        
        try {
            # Deshabilitar botón mientras actualiza
            $controls['btnUpdateSelected'].IsEnabled = $false
            
            # Forzar actualización de la UI
            # [System.Windows.Forms.Application]::DoEvents()
            # En lugar de la anterior, usar esta línea para procesar eventos pendientes y evitar que la UI se congele:
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
            
            # Actualizar inventario (esto puede tardar)
            $newInventory = Update-ServerInventory -ServerName $serverName -Force -PassThru -ErrorAction Stop
            
            if ($null -ne $newInventory) {
                # Recargar todos los inventarios para reflejar cambios
                Load-Inventories
                
                [System.Windows.MessageBox]::Show(
                    "Inventario de '$serverName' completado correctamente.`n`nEstado: $($newInventory.Status.Result)",
                    "Inventario exitoso",
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

# === FUNCIÓN: ACTUALIZAR/INVENTARIAR TODOS LOS SERVIDORES ===
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
        "¿Inventariar TODOS los servidores ($($viewModel.Servers.Count))?`n`nEsto puede tardar varios minutos.",
        "Confirmar inventario masivo",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar -Message "Iniciando inventario masivo..." -ShowTime:$false
        
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
Inventario masivo completado.

Total: $($summary.TotalServers) servidores
Exitosos: $($summary.Successful)
Fallidos: $($summary.Failed)
Tasa de éxito: $($summary.SuccessRate)%
Duración: $($summary.Duration.ToString('mm\:ss'))
"@

            [System.Windows.MessageBox]::Show(
                $message,
                "Inventario completado",
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
            Update-ServersInViewModel -ViewModel $viewModel -Inventories $filtered -StaleThresholdDays $script:StaleThresholdDays
            Update-StatusBar -Message "Encontrados $($filtered.Count) resultados para '$searchText'"
        }
    }
    catch {
        $errorMsg = "Error al buscar: $($_.Exception.Message)"
        Update-StatusBar -Message $errorMsg -ShowTime:$false
        Write-Error $errorMsg
    }
}

# === FUNCIÓN: FORMATEAR INVENTARIO A TEXTO ===
function Format-InventoryAsText {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Inventory
    )

    try {
        $json = $Inventory | ConvertTo-Json -Depth 10
    }
    catch {
        $json = $Inventory.ToString()
    }

    $header = "Servidor: $($Inventory.ServerName)`nFecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
    return $header + $json
}

# === FUNCIÓN: ELIMINAR SERVIDOR SELECCIONADO ===
function Remove-SelectedServer {
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
        "¿Estás seguro de que deseas eliminar el servidor '$serverName'?`n`nEsta acción no se puede deshacer.",
        "Confirmar eliminación",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Update-StatusBar -Message "Eliminando servidor '$serverName'..." -ShowTime:$false
            
            # Obtener la ruta del archivo del inventario
            $dataPath = Join-Path $moduleRoot "Data\Inventory"
            $inventoryFiles = Get-ChildItem -Path $dataPath -Recurse -Include "$serverName.var.xml","$serverName.json" -ErrorAction SilentlyContinue
            
            if ($inventoryFiles.Count -eq 0) {
                Write-Warning "No se encontraron archivos para el servidor '$serverName'"
                Update-StatusBar -Message "Error: No se encontró el archivo del servidor" -ShowTime:$false
                return
            }
            
            # Eliminar los archivos del servidor
            foreach ($file in $inventoryFiles) {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Write-Verbose "Archivo eliminado: $($file.Name)"
            }
            
            # Remover la entrada de memoria
            $viewModel.Servers.Remove($selectedItem) | Out-Null
            
            # Recargar inventarios desde disco para sincronizar
            Load-Inventories
            
            Update-StatusBar -Message "Servidor '$serverName' eliminado correctamente"
            
            [System.Windows.MessageBox]::Show(
                "Servidor '$serverName' eliminado correctamente.",
                "Eliminación completada",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
        catch {
            $errorMsg = "Error al eliminar servidor: $($_.Exception.Message)"
            Update-StatusBar -Message $errorMsg -ShowTime:$false
            
            Write-Error $errorMsg
            [System.Windows.MessageBox]::Show(
                $errorMsg,
                "Error de eliminación",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }
}

# === FUNCIÓN: MOSTRAR DETALLES DE UN SERVIDOR ===
function Show-ServerDetails {
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

    # Obtener inventario original si existe
    try {
        $inventory = $null
        if ($selectedItem -is [object] -and $selectedItem.PSObject.Methods.Name -contains 'GetInventory') {
            $inventory = $selectedItem.GetInventory()
        }
        else {
            $inventory = $selectedItem
        }
    }
    catch {
        $inventory = $selectedItem
    }

    $detailsXaml = Join-Path $scriptPath "Views\ServerDetailsWindow.xaml"

    try {
        $detailsWindow = Load-XamlWindow -XamlPath $detailsXaml
        $detailControls = Get-AllXamlControls -Window $detailsWindow -ControlNames @('txtDetails','btnClose','tvJson','btnExpandAll','btnCollapseAll')

        $detailText = Format-InventoryAsText -Inventory $inventory
        if ($detailControls.ContainsKey('txtDetails')) {
            $detailControls['txtDetails'].Text = $detailText
        }

        if ($detailControls.ContainsKey('tvJson')) {
            $jsonHelpersPath = Join-Path $scriptPath "Helpers\JsonTreeHelpers.psm1"
            if (Test-Path $jsonHelpersPath) {
                try {
                    Import-Module $jsonHelpersPath -Force -ErrorAction Stop
                }
                catch {
                    Write-Verbose "No se pudo importar JsonTreeHelpers: $($_.Exception.Message)"
                }
            }

            try {
                if (Get-Command -Name Populate-TreeViewFromObject -ErrorAction SilentlyContinue) {
                    Populate-TreeViewFromObject -TreeView $detailControls['tvJson'] -Object $inventory
                }
                else {
                    $json = $null
                    try { $json = $inventory | ConvertTo-Json -Depth 10 }
                    catch { $json = $inventory.ToString() }
                    if ($json -and (Get-Command -Name Populate-TreeViewFromJson -ErrorAction SilentlyContinue)) {
                        Populate-TreeViewFromJson -TreeView $detailControls['tvJson'] -JsonText $json
                    }
                }
            }
            catch {
                Write-Verbose "Error al popular TreeView: $($_.Exception.Message)"
            }
        }

        if ($detailControls.ContainsKey('btnExpandAll')) {
            $detailControls['btnExpandAll'].Add_Click({
                try {
                    if (-not $detailControls.ContainsKey('tvJson')) { return }
                    $tv = $detailControls['tvJson']
                    if ($null -eq $tv) { return }

                    function _SetRecExpansion([System.Windows.Controls.ItemsControl]$parent, [bool]$expanded) {
                        foreach ($item in $parent.Items) {
                            if ($item -is [System.Windows.Controls.TreeViewItem]) {
                                $item.IsExpanded = $expanded
                                if ($item.Items.Count -gt 0) { _SetRecExpansion $item $expanded }
                            }
                        }
                    }

                    _SetRecExpansion $tv $true
                }
                catch { }
            })
        }

        if ($detailControls.ContainsKey('btnCollapseAll')) {
            $detailControls['btnCollapseAll'].Add_Click({
                try {
                    if (-not $detailControls.ContainsKey('tvJson')) { return }
                    $tv = $detailControls['tvJson']
                    if ($null -eq $tv) { return }

                    function _SetRecExpansion([System.Windows.Controls.ItemsControl]$parent, [bool]$expanded) {
                        foreach ($item in $parent.Items) {
                            if ($item -is [System.Windows.Controls.TreeViewItem]) {
                                $item.IsExpanded = $expanded
                                if ($item.Items.Count -gt 0) { _SetRecExpansion $item $expanded }
                            }
                        }
                    }

                    _SetRecExpansion $tv $false
                }
                catch { }
            })
        }

        if ($detailControls.ContainsKey('btnClose')) {
            $detailControls['btnClose'].Add_Click({ $detailsWindow.Close() })
        }

        $detailsWindow.Title = "Detalles - $($inventory.ServerName)"
        [void]$detailsWindow.ShowDialog()
    }
    catch {
        $err = "No se pudo abrir la ventana de detalles: $($_.Exception.Message)"
        Write-Error $err
        [System.Windows.MessageBox]::Show(
            $err,
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# === FUNCIÓN: AGREGAR NUEVO SERVIDOR ===
function Add-NewServer {
    [CmdletBinding()]
    param()

    # Crear un diálogo de entrada para el nombre del servidor
    $xamlInputDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Agregar Nuevo Servidor"
        Height="220" 
        Width="500"
        WindowStartupLocation="CenterScreen"
        Background="#F5F5F5"
        ResizeMode="NoResize">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" 
                   Text="Nombre del servidor:" 
                   FontSize="13"
                   Margin="0,0,0,10"
                   Foreground="#333333"/>
        
        <TextBox Grid.Row="1" 
                 Name="txtServerName" 
                 Height="40"
                 Padding="10"
                 FontSize="13"
                 Margin="0,0,0,15"/>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="btnOK" 
                    Content="Aceptar" 
                    Width="100" 
                    Height="35"
                    Margin="0,0,10,0"
                    Background="#4CAF50"
                    Foreground="White"
                    BorderThickness="0"
                    FontSize="12"
                    Cursor="Hand"/>
            <Button Name="btnCancel" 
                    Content="Cancelar" 
                    Width="100" 
                    Height="35"
                    Background="#F44336"
                    Foreground="White"
                    BorderThickness="0"
                    FontSize="12"
                    Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        # Cargar el diálogo
        $inputDialog = [xml]$xamlInputDialog
        $reader = (New-Object System.Xml.XmlNodeReader $inputDialog)
        $dialog = [System.Windows.Markup.XamlReader]::Load($reader)
        
        # Obtener controles
        $txtServerName = $dialog.FindName('txtServerName')
        $btnOK = $dialog.FindName('btnOK')
        $btnCancel = $dialog.FindName('btnCancel')
        
        # Variables para el resultado
        $result = @{ ServerName = $null; Accepted = $false }
        
        # Evento del botón Aceptar
        $btnOK.Add_Click({
            $trimmedName = $txtServerName.Text.Trim()
            if ([string]::IsNullOrEmpty($trimmedName)) {
                [System.Windows.MessageBox]::Show(
                    "Por favor, ingresa el nombre del servidor.",
                    "Nombre vacío",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                )
                return
            }
            
            $result['ServerName'] = $trimmedName
            $result['Accepted'] = $true
            $dialog.Close()
        })
        
        # Evento del botón Cancelar
        $btnCancel.Add_Click({
            $dialog.Close()
        })
        
        # Foco en el textbox
        $txtServerName.Focus()
        
        # Mostrar el diálogo
        [void]$dialog.ShowDialog()
        
        if (-not $result['Accepted']) {
            return
        }
        
        $serverName = $result['ServerName']
        
        # Crear nuevo ServerInventory
        try {
            Update-StatusBar -Message "Creando nuevo inventario para '$serverName'..." -ShowTime:$false

            # Crear la instancia de ServerInventory
            $newInventory = [ServerInventory]::new($serverName)

            # Establecer el estado inicial como "Pendiente"
            $newInventory.Status.Message = "Pendiente de inventariar"

            # Guardar el inventario a disco para que persista
            Export-ServerInventory -Inventory $newInventory -Force

            # Recargar todos los inventarios desde disco
            Load-Inventories

            Update-StatusBar -Message "Nuevo servidor '$serverName' agregado"

            [System.Windows.MessageBox]::Show(
                "Servidor '$serverName' agregado correctamente.`n`nEstado: Pendiente de inventariar`n`nPuedes actualizar su información usando el botón 'Inventariar Seleccionado'.",
                "Servidor agregado",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
        catch {
            $errorMsg = "Error al crear el servidor: $($_.Exception.Message)"
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
    catch {
        $errorMsg = "Error al crear el diálogo: $($_.Exception.Message)"
        Write-Error $errorMsg
        [System.Windows.MessageBox]::Show(
            $errorMsg,
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# === EVENTOS DE CONTROLES ===

# Botón Refrescar
$controls['btnRefresh'].Add_Click({
    Load-Inventories
})

# Botón Actualizar/Inventariar Seleccionado
$controls['btnUpdateSelected'].Add_Click({
    Update-SelectedServer
})

# Botón Actualizar/Inventariar Todos
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
    # Habilitar botones cuando haya selección
    if ($controls.ContainsKey('btnViewDetails')) {
        $controls['btnViewDetails'].IsEnabled = $isSelected
    }
    if ($controls.ContainsKey('btnDeleteServer')) {
        $controls['btnDeleteServer'].IsEnabled = $isSelected
    }
})

# Botón Ver detalles
if ($controls.ContainsKey('btnViewDetails')) {
    $controls['btnViewDetails'].Add_Click({
        Show-ServerDetails
    })
}

# DataGrid - doble click en fila -> ver detalles
$controls['dgServers'].Add_MouseDoubleClick({
    $sel = $controls['dgServers'].SelectedItem
    if ($null -ne $sel) {
        Show-ServerDetails
    }
})

# Botón Eliminar Servidor
if ($controls.ContainsKey('btnDeleteServer')) {
    $controls['btnDeleteServer'].Add_Click({
        Remove-SelectedServer
    })
}

# Botón Agregar Nuevo Servidor
if ($controls.ContainsKey('btnAddServer')) {
    $controls['btnAddServer'].Add_Click({
        Add-NewServer
    })
}

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
