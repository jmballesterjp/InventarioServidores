using module ..\..\InventarioServidores.psd1 #(Join-Path $ScriptRoot "..\..\InventarioServidores.psd1")

# 01-BasicUsage.ps1
# Ejemplos básicos de uso del módulo

# Importar módulo
# $PSScriptRoot
# $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptRoot = $PSScriptRoot
# Importar módulo #Reemplazado por using module para evitar problemas de ClassNotFound
# Import-Module (Join-Path $ScriptRoot "..\..\InventarioServidores.psm1") -Force

#Servidor por defecto
if ($null -eq $serverToInventory) {
    $serverToInventory="localhost"
}

# === EJEMPLO 1: Inventariar un servidor ===
Write-Host "`n=== EJEMPLO 1: Inventario básico ===" -ForegroundColor Cyan
Update-ServerInventory -ServerName $serverToInventory -Force -PassThru

# === EJEMPLO 2: Consultar inventario ===
Write-Host "`n=== EJEMPLO 2: Consultar inventario ===" -ForegroundColor Cyan
$inv = Get-ServerInventory -ServerName $serverToInventory
Write-Host "Servidor: $($inv.ServerName)"
Write-Host "OS: $($inv.OS.Name)"
Write-Host "RAM: $($inv.Hardware.GetRAMFormatted())"
Write-Host "Uptime: $($inv.OS.GetUptimeFormatted())"

# === EJEMPLO 3: Listar discos ===
Write-Host "`n=== EJEMPLO 3: Discos ===" -ForegroundColor Cyan
$inv.Hardware.Disks | Format-Table DeviceID, @{N='Tamaño';E={$_.GetSizeFormatted()}}, @{N='Libre';E={$_.GetFreeFormatted()}}, PercentFree

# === EJEMPLO 4: Red ===
Write-Host "`n=== EJEMPLO 4: Adaptadores de red ===" -ForegroundColor Cyan
$inv.Network | Format-Table AdapterName, @{N='IP';E={$_.IPAddress -join ', '}}, MACAddress, @{N='Velocidad';E={$_.GetSpeedFormatted()}}

# === EJEMPLO 5: Todos los inventarios ===
Write-Host "`n=== EJEMPLO 5: Todos los servidores ===" -ForegroundColor Cyan
Get-AllServerInventories | Format-Table ServerName, @{N='OS';E={$_.OS.Name}}, @{N='RAM';E={$_.Hardware.GetRAMFormatted()}}, LastInventory, @{N='Estado';E={$_.Status.Result}}
