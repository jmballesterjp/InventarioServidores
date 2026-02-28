
# InventarioServidores

Sistema de inventario automatizado para servidores Windows con soporte para recopilación remota, versionado de schema y arquitectura modular.

## 🚀 Características

- **Recopilación Remota**: Usa PowerShell Remoting (WinRM) para inventariar servidores
- **Schema Versionado**: Sistema de migración automática entre versiones
- **Exportación Múltiple**: XML (Export-Clixml) + JSON opcional
- **Inventario Masivo**: Recopilación paralela con control de concurrencia
- **Logging Thread-Safe**: Logs separados por servidor y tipo
- **Extensible**: Arquitectura modular con clases PowerShell

## 📋 Requisitos

- PowerShell 5.1 o superior
- WinRM habilitado en servidores target
- Active Directory (opcional, facilita autenticación)
- Permisos de administrador remoto en servidores

## 📦 Instalación

```powershell
# Clonar o copiar el módulo
Copy-Item -Path "InventarioServidores" -Destination "$env:PSModulePath\InventarioServidores" -Recurse

# Importar módulo
Import-Module InventarioServidores

# Verificar funciones disponibles
Get-Command -Module InventarioServidores
```


## 🎯 Uso Rápido

### Actualizar inventario de un servidor

```powershell
# Inventario básico
Update-ServerInventory -ServerName "SRV01"

# Con credenciales específicas
$cred = Get-Credential
Update-ServerInventory -ServerName "SRV01" -Credential $cred

# Forzar actualización aunque sea reciente
Update-ServerInventory -ServerName "SRV01" -Force -PassThru
```


### Inventario masivo

```powershell
# Desde array
$servers = @("SRV01", "SRV02", "SRV03", "SRV04")
Invoke-BulkInventoryCollection -ServerName $servers -ThrottleLimit 10

# Desde archivo
Get-Content servers.txt | Invoke-BulkInventoryCollection -ThrottleLimit 5

# Resultado:
# === Inventario Masivo ===
# Servidores: 150
# Concurrencia máxima: 10
# ✓ SRV01 [Success]
#   ✓ SRV02 [Success]
#   ✗ SRV03 - No se pudo conectar
#   ...
```


### Consultar inventarios

```powershell
# Un servidor específico
$inv = Get-ServerInventory -ServerName "SRV01"
$inv.OS.Name
$inv.Hardware.GetRAMFormatted()

# Todos los servidores
$all = Get-AllServerInventories
$all | Where-Object { $_.OS.UptimeDays -gt 30 } | Select-Object ServerName, @{N='Uptime';E={$_.OS.UptimeDays}}

# Filtrar por estado
Get-AllServerInventories | Where-Object { $_.Status.Result -eq 'Success' }
```


### Exportar/Importar manualmente

```powershell
# Importar
$inv = Import-ServerInventory -ServerName "SRV01"

# Exportar con JSON adicional
Export-ServerInventory -Inventory $inv -AlsoExportJSON -Force
```


## 📁 Estructura del Proyecto

```
InventarioServidores/
├── Source/
│   ├── Classes/           # Clases PowerShell
│   ├── Public/            # Cmdlets exportados
│   └── Private/           # Funciones internas
├── Config/
│   ├── Credentials/       # Credenciales guardadas
│   └── Settings.psd1      # Configuración
├── Data/
│   └── Inventory/         # Archivos .var.xml y .json
├── Logs/
│   ├── Collection/        # Logs por servidor
│   └── Errors/            # Solo errores
└── Temp/                  # Archivos temporales
```


## 🔧 Configuración

Editar `Config/Settings.psd1`:

```powershell
@{
    LogLevel = 'Info'              # Debug, Verbose, Info, Warning, Error
    LogRetentionDays = 30
    DefaultThrottleLimit = 10
    CommandTimeout = 300
    AlsoExportJSON = $true         # Exportar JSON además de XML
    CompressOldInventories = $false
}
```


## 📊 Schema del Inventario

### Versión 1 (Actual)

- **ServerInventory**: Contenedor principal
    - OS (OSInfo): Sistema operativo
    - Hardware (HardwareInfo): CPU, RAM, Discos
    - Network (NetworkInfo[]): Adaptadores de red
    - Status (CollectionStatus): Estado de recopilación


### Versión 2 (Futura)

- Añadir `IISInfo`: Sites, AppPools, Bindings
- Certificados SSL
- Información de servicios Windows
- Máquinas virtuales Hyper-V, y su estado de ejecución


## 🔄 Migración de Schemas

Las migraciones se ejecutan **automáticamente** al importar inventarios antiguos:

```powershell
# Inventario guardado con schema v1
$inv = Import-ServerInventory -ServerName "SRV01"
# → Se migra automáticamente a v2
# → Se guarda la versión actualizada
```

Para evitar migración automática:

```powershell
$inv = Import-ServerInventory -ServerName "SRV01" -NoMigration
```


## 🎨 Integración con WPF UI

```powershell
# En tu ViewModel
Import-Module .\InventarioServidores.psm1

# Cargar datos
$servers = Get-AllServerInventories

# Binding a DataGrid
$observableCollection = [System.Collections.ObjectModel.ObservableCollection[ServerInventory]]::new()
$servers | ForEach-Object { $observableCollection.Add($_) }

# En XAML:
# <DataGrid ItemsSource="{Binding Servers}">
#   <DataGridTextColumn Binding="{Binding ServerName}" />
#   <DataGridTextColumn Binding="{Binding OS.Name}" />
# </DataGrid>
```


## 📝 Ejemplos Avanzados

### Reporte de servidores desactualizados

```powershell
Get-AllServerInventories -IncludeStale | 
    Where-Object { $_.IsStale(7) } |
    Select-Object ServerName, LastInventory, @{N='DaysOld';E={((Get-Date) - $_.LastInventory).Days}} |
    Export-Csv -Path "servidores_desactualizados.csv"
```


### Análisis de hardware

```powershell
$all = Get-AllServerInventories

# RAM total en el datacenter
$totalRAM = ($all | Measure-Object -Property {$_.Hardware.RAMBytes} -Sum).Sum / 1TB
Write-Host "RAM Total: $([Math]::Round($totalRAM, 2)) TB"

# Servidores con poco espacio en disco
$all | ForEach-Object {
    $server = $_
    $_.Hardware.Disks | Where-Object { $_.PercentFree -lt 20 } | ForEach-Object {
        [PSCustomObject]@{
            Servidor = $server.ServerName
            Disco = $_.DeviceID
            EspacioLibre = $_.PercentFree
            GB_Libres = [Math]::Round($_.FreeBytes / 1GB, 2)
        }
    }
}
```


## 🧪 Testing

```powershell
# Ejecutar tests Pester (cuando estén implementados)
Invoke-Pester -Path .\Tests\
```


## 🛠️ Desarrollo Futuro

- [x] **UI WPF**: Aplicacion grafica con DataGrid, busqueda y vista de detalles *(Fase 2 - completada)*
- [ ] **Tests Pester**: Suite automatizada para funciones publicas, privadas y migraciones
- [ ] **Archivado de logs**: Rotacion automatica con politica de retencion
- [ ] **Schema v2 - IIS, Servicios y Hyper-V**: Recoleccion de sitios web, application pools, certificados SSL, servicios Windows y maquinas virtuales Hyper-V
- [ ] **Tracking historico**: Snapshots por fecha y comparativa de cambios
- [ ] **Exportacion a SQL**: Base de datos centralizada para consultas avanzadas
- [ ] **Alertas**: Notificaciones por umbrales (disco, uptime, inventario desactualizado)
- [ ] **Inventario incremental**: Solo recopilar lo que cambio desde la ultima ejecucion
- [ ] **Soporte Linux**: Via SSH/CIM (PowerShell 7+)
- [ ] **PowerShell Gallery**: Publicacion para instalacion con `Install-Module`


> Roadmap detallado por fases en [`Roadmap.md`](Docs/Roadmap.md)

> Apartado técnico en: [`Technical-README.md`](Docs/Technical-README.md) y  [`Propuesta de Arquitectura.md`](Docs/Propuesta%20de%20Arquitectura.md)


## 📄 Licencia

Uso interno

## 👤 Autor

Jose Miguel Ballester - SysAdmin/SRE/Devops

## 🤝 Contribuciones

Para contribuir al proyecto:

1. Crea una rama feature
2. Añade tests para nuevas funcionalidades
3. Documenta cambios en el README
4. Actualiza el schema version si es necesario