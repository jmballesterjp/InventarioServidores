using module ..\..\InventarioServidores.psd1 #(Join-Path $ScriptRoot "..\..\InventarioServidores.psd1")

# 02-UIBasicTest.ps1
# Prueba básica de la interfaz sin datos reales

#Requires -Version 5.1

Write-Host "🧪 Test básico de la interfaz WPF" -ForegroundColor Cyan
Write-Host "=" * 50
Write-Host ""

# Ruta raiz del proyecto
$rootFolderPath = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)

# Importar módulo
$modulePath = Join-Path $rootFolderPath "InventarioServidores.psm1"
Import-Module $modulePath -Force

# Cargar helpers
$helpersPath = Join-Path $rootFolderPath "UI\Helpers\XamlLoader.psm1"
Import-Module -Force $helpersPath

# Cargar XAML
$xamlPath = Join-Path $rootFolderPath "UI\Views\MainWindow.xaml"

Write-Host "📝 Cargando XAML desde: $xamlPath" -ForegroundColor Yellow

try {
    $window = Load-XamlWindow -XamlPath $xamlPath
    Write-Host "✓ XAML cargado correctamente" -ForegroundColor Green
}
catch {
    Write-Error "Error al cargar XAML: $_"
    exit 1
}

# Obtener controles
Write-Host "`n🔍 Buscando controles..." -ForegroundColor Yellow

$controlsToFind = @(
    'btnRefresh',
    'btnUpdateSelected',
    'btnUpdateAll',
    'dgServers',
    'txtStatus'
)

foreach ($controlName in $controlsToFind) {
    $control = Get-XamlControl -Window $window -ControlName $controlName
    if ($null -ne $control) {
        Write-Host "  ✓ $controlName - Tipo: $($control.GetType().Name)" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $controlName - NO ENCONTRADO" -ForegroundColor Red
    }
}

# Crear datos de prueba
Write-Host "`n📊 Creando datos de prueba..." -ForegroundColor Yellow

$testData = New-Object System.Collections.ObjectModel.ObservableCollection[PSCustomObject]

# Añadir servidores de prueba
$testData.Add([PSCustomObject]@{
    ServerName = "TEST-SRV01"
    IPAddressFormatted = "192.168.1.10"
    OSName = "Windows Server 2019 Datacenter"
    RAMFormatted = "32.00 GB"
    UptimeDays = 15
    LastInventoryFormatted = "2026-02-09 20:30"
    StatusText = "Success"
    StatusColor = "#4CAF50"
})

$testData.Add([PSCustomObject]@{
    ServerName = "TEST-SRV02"
    IPAddressFormatted = "192.168.1.11"
    OSName = "Windows Server 2022 Standard"
    RAMFormatted = "64.00 GB"
    UptimeDays = 3
    LastInventoryFormatted = "2026-02-09 18:15"
    StatusText = "Success"
    StatusColor = "#4CAF50"
})

$testData.Add([PSCustomObject]@{
    ServerName = "TEST-SRV03"
    IPAddressFormatted = "192.168.1.12"
    OSName = "Windows Server 2019 Standard"
    RAMFormatted = "16.00 GB"
    UptimeDays = 45
    LastInventoryFormatted = "2026-02-08 14:22"
    StatusText = "Partial"
    StatusColor = "#FF9800"
})

# Vincular datos al DataGrid
$dgServers = Get-XamlControl -Window $window -ControlName "dgServers"
$dgServers.ItemsSource = $testData

Write-Host "✓ Añadidos $($testData.Count) servidores de prueba" -ForegroundColor Green

# Actualizar status
$txtStatus = Get-XamlControl -Window $window -ControlName "txtStatus"
$txtStatus.Text = "Modo TEST - Datos de prueba cargados"

$txtServerCount = Get-XamlControl -Window $window -ControlName "txtServerCount"
$txtServerCount.Text = "Servidores: $($testData.Count)"

# Configurar evento de botón Refrescar
$btnRefresh = Get-XamlControl -Window $window -ControlName "btnRefresh"
$btnRefresh.Add_Click({
    [System.Windows.MessageBox]::Show(
        "Botón Refrescar funcional!`n`nEn producción esto recargará los inventarios.",
        "Test de botón",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

Write-Host "`n✅ Interfaz preparada con datos de prueba" -ForegroundColor Green
Write-Host "🚀 Mostrando ventana..." -ForegroundColor Cyan
Write-Host ""

# Mostrar ventana
[void]$window.ShowDialog()

Write-Host "`n👋 Test completado" -ForegroundColor Cyan
