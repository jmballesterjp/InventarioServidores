using module ..\..\InventarioServidores.psd1 #Importación de clases

# 03-UIWithData.ps1
# Ejemplo de interfaz con datos reales del módulo

#Requires -Version 5.1

Write-Host "🧪 Interfaz WPF con datos reales" -ForegroundColor Cyan
Write-Host "=" * 50
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
    Write-Warning "No hay inventarios creados."
    Write-Host ""
    Write-Host "Opciones:" -ForegroundColor Yellow
    Write-Host "  1. Crear inventario de localhost:" -ForegroundColor White
    Write-Host "     Update-ServerInventory -ServerName 'localhost' -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Lanzar interfaz con datos de prueba:" -ForegroundColor White
    Write-Host "     .\Scripts\Examples\02-UIBasicTest.ps1" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "¿Crear inventario de localhost ahora? (S/N)"
    
    if ($response -eq 'S' -or $response -eq 's') {
        Write-Host "`n📊 Creando inventario de localhost..." -ForegroundColor Cyan
        
        try {
            $inv = Update-ServerInventory -ServerName "localhost" -Force -PassThru
            
            if ($null -ne $inv) {
                Write-Host "✓ Inventario creado exitosamente" -ForegroundColor Green
                Write-Host "  Servidor: $($inv.ServerName)" -ForegroundColor White
                Write-Host "  OS: $($inv.OS.Name)" -ForegroundColor White
                Write-Host "  RAM: $($inv.Hardware.GetRAMFormatted())" -ForegroundColor White
                Write-Host ""
                
                # Recargar inventarios
                $inventories = Get-AllServerInventories -IncludeStale
            }
        }
        catch {
            Write-Error "Error al crear inventario: $_"
            exit 1
        }
    }
    else {
        Write-Host "❌ No se puede continuar sin inventarios" -ForegroundColor Red
        exit 0
    }
}

Write-Host "✓ Encontrados $($inventories.Count) inventarios" -ForegroundColor Green
Write-Host ""

# === LANZAR INTERFAZ ===
$uiLauncher = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "UI\Start-InventoryUI.ps1"

if (-not (Test-Path $uiLauncher)) {
    Write-Error "No se encuentra el launcher de UI en: $uiLauncher"
    exit 1
}

Write-Host "🚀 Lanzando interfaz..." -ForegroundColor Cyan
Write-Host ""

# Ejecutar launcher
& $uiLauncher

Write-Host "`n👋 Interfaz cerrada" -ForegroundColor Cyan
