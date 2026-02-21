using module ..\..\InventarioServidores.psd1 #Importación de clases

# 03-UIWithData.ps1
# Ejemplo de interfaz con datos reales del módulo

#Requires -Version 5.1

Write-Host "🧪 Interfaz WPF con datos reales" -ForegroundColor Cyan
Write-Host ("=" * 50)
Write-Host ""

# === VERIFICAR INVENTARIOS EXISTENTES ===
$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "InventarioServidores.psm1"

if (-not (Test-Path $modulePath)) {
    Write-Error "No se encuentra el módulo en: $modulePath"
    exit 1
}

Import-Module $modulePath -Force
Write-Host "✓ Módulo cargado" -ForegroundColor Green

# Verificar si hay inventarios
$inventories = Get-AllServerInventories -IncludeStale

if ($inventories.Count -eq 0) {
    Write-Warning "No hay inventarios creados todavía."
    Write-Host ""
    Write-Host "Puedes inventariar servidores de las siguientes formas:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Desde CLI:" -ForegroundColor White
    Write-Host "     Update-ServerInventory -ServerName 'localhost' -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Desde la interfaz:" -ForegroundColor White
    Write-Host "     1. Pulsa '➕ Añadir nuevo servidor'" -ForegroundColor Gray
    Write-Host "     2. Selecciona el servidor en la lista" -ForegroundColor Gray
    Write-Host "     3. Pulsa '⚡ Inventariar Seleccionado'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "La interfaz se abrirá igualmente. Puedes añadir servidores desde ella." -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "✓ Encontrados $($inventories.Count) inventarios" -ForegroundColor Green
    Write-Host ""
}

# === LANZAR INTERFAZ ===
$uiLauncher = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "UI\Start-InventoryUI.ps1"

if (-not (Test-Path $uiLauncher)) {
    Write-Error "No se encuentra el launcher de UI en: $uiLauncher"
    exit 1
}

Write-Host "🚀 Lanzando interfaz..." -ForegroundColor Cyan
Write-Host ""

# Ejecutar launcher
& $uiLauncher #-Verbose

Write-Host "`n👋 Interfaz cerrada" -ForegroundColor Cyan
