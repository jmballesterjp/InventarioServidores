# InventarioServidores

Sistema de inventario automatizado para servidores Windows. Recopila informacion de hardware, sistema operativo y red de forma remota, la almacena con versionado de schema, y la presenta tanto por consola (cmdlets PowerShell) como mediante una interfaz grafica WPF.

## El Problema

En entornos empresariales con decenas o cientos de servidores Windows, los administradores de sistemas gestionan el inventario de forma manual: hojas Excel desactualizadas, datos inconsistentes, sin automatizacion ni auditoria. Cuando se necesita saber que version de SO tiene un servidor o cuanto disco libre queda, la respuesta suele ser "dejame conectarme y mirarlo".

## La Solucion

**InventarioServidores** automatiza todo el ciclo:

1. **Recoleccion remota** - Se conecta via WinRM a los servidores y recopila OS, hardware, configuración de red
2. **Almacenamiento tipado** - Guarda los datos con clases PowerShell fuertemente tipadas (Export-Clixml) y opcionalmente en JSON
3. **Versionado de schema** - Migracion automatica cuando el modelo de datos evoluciona
4. **Visualizacion** - Interfaz sencilla en WPF (con DataGrid), y una vista detallada con un JSON-tree-view expandible
5. **Operaciones masivas** - Inventario en paralelo con control de concurrencia

---

## Stack Tecnologico

| Tecnologia | Uso |
|---|---|
| **PowerShell 5.1+** | Lenguaje principal. Clases con tipado fuerte, sistema de modulos con manifiesto, pipeline nativo |
| **WPF / XAML** | Interfaz grafica de escritorio. DataGrid, TreeView, data binding con ObservableCollection |
| **WinRM (PS Remoting)** | Recoleccion remota de datos via `Invoke-Command` contra servidores Windows |
| **Export-Clixml** | Serializacion nativa que preserva tipos PowerShell completos (clases, datetime, enums) |
| **JSON** | Formato de exportacion secundario, legible para auditorias e integraciones externas |
| **PowerShell Jobs** | Ejecucion paralela con control de concurrencia para inventarios masivos |
| **WMI / CIM** | Consultas de hardware, SO y red en servidores remotos (`Win32_OperatingSystem`, `Win32_Processor`, etc.) |
| **System.IO.File** | Operaciones de logging thread-safe con escritura atomica |
| **Git** | Control de versiones con ramas por feature y merge controlado |

---

## Arquitectura

El proyecto sigue una arquitectura por capas con separacion de responsabilidades:

```
+-------------------------------------------+
|            UI (WPF / XAML)                |
|   MainWindow  |  ServerDetails  |  MVVM   |
+-------------------------------------------+
|          Public API (Cmdlets)             |
|  Get-  |  Update-  |  Export-  |  Invoke- |
+-------------------------------------------+
|        Private (Business Logic)           |
|  RemoteCollection | Migration | Logging   |
+-------------------------------------------+
|           Data Model (Classes)            |
|  ServerInventory | OS | HW | Net | Status |
+-------------------------------------------+
|         Persistence (Disk)                |
|     Export-Clixml (.xml)  |  JSON         |
+-------------------------------------------+
```

**Patrones aplicados:**
- **MVVM** en la capa UI (ViewModels con data binding)
- **Schema Versioning** con cadena de migraciones secuenciales
- **Thread-safe logging** usando `[System.IO.File]::AppendAllText`
- **Module Manifest** para encapsulacion y distribucion

---

## Decisiones de Diseño

Cada decision arquitectonica del proyecto fue evaluada con analisis de alternativas antes de implementar. El razonamiento completo esta documentado en [Propuesta Formal de Arquitectura](Propuesta%20Formal%20de%20Arquitectura.md). A continuacion un resumen de las decisiones clave:

### Serializacion: Export-Clixml + JSON (dual)

| | Export-Clixml | JSON |
|---|---|---|
| **Ventaja** | Preserva tipos nativos de PowerShell (clases, datetime, enums, arrays tipados) | Legible por humanos y por cualquier herramienta externa |
| **Desventaja** | Solo legible desde PowerShell; archivos mas pesados | Pierde informacion de tipos complejos al serializar |
| **Uso en el proyecto** | Formato primario para persistencia interna (`*.var.xml`) | Formato secundario para auditorias e integraciones (`*.json`) |

**Decision:** Usar ambos. Export-Clixml como fuente de verdad (preserva el modelo completo), y JSON como exportacion opcional configurable via `Settings.psd1`.

### Schema: Rigido con punto de extensibilidad

Se evaluaron dos enfoques: schema rigido (clases PowerShell con propiedades fijas) vs schema flexible (PSCustomObject con propiedades dinamicas).

**Decision:** Schema rigido con clases + `[hashtable]$CustomProperties` como escape hatch. Las clases aportan IntelliSense en VS Code, validacion de tipos en tiempo de desarrollo y facilidad de refactoring. El campo `CustomProperties` permite almacenar datos ad-hoc sin modificar el schema (util en entornos heterogeneos).

### Logging: Custom facade vs PSFramework

PSFramework ofrece logging thread-safe out-of-the-box con multiples providers (file, eventlog, Azure), pero introduce una dependencia externa. El objetivo del proyecto es cero dependencias para maximizar portabilidad.

**Decision:** Implementar `Write-InventoryLog` como facade con `[System.IO.File]::AppendAllText` (escritura atomica a nivel de SO). Si en el futuro se necesita PSFramework, se cambia la implementacion interna sin modificar ninguno de los callers existentes.

### Concurrencia: Start-Job vs alternativas

| Opcion | Requiere | Ventaja | Desventaja |
|---|---|---|---|
| `Start-Job` | PS 5.1 | Nativo, compatible | Mayor overhead por proceso |
| `ForEach-Object -Parallel` | PS 7+ | Simple, moderno | Rompe compatibilidad PS 5.1 |
| `Start-ThreadJob` | PS 7+ | Ligero | Rompe compatibilidad PS 5.1 |
| Runspaces | PS 5.1 | Maximo rendimiento | Complejidad alta, dificil de mantener |

**Decision:** `Start-Job` con `ThrottleLimit` configurable (1-50). Mantiene compatibilidad con PowerShell 5.1 (presente en todos los Windows Server en produccion) sin sacrificar funcionalidad. El overhead por proceso es aceptable para el caso de uso (decenas de servidores, no miles).

### Ejecucion remota: WinRM (PS Remoting)

Se evaluaron WinRM, CIM/WMI directo y SSH Remoting. En un entorno 100% Windows Server con Active Directory, WinRM es la opcion natural: viene preconfigurado en la mayoria de servidores del dominio, soporta credenciales Kerberos, y permite ejecutar bloques completos de codigo remoto con `Invoke-Command`.

### UI: Hibrido MVVM-lite con XAML separado

Se eligio separar el XAML de la logica PowerShell en lugar de generar la UI programaticamente. Esto permite editar la interfaz con herramientas visuales (Visual Studio, Blend), mantener el diseño independiente del codigo, y escalar a ventanas adicionales sin complejidad. El patron MVVM se implementa de forma "lite": sin framework MVVM externo, usando `ObservableCollection` y event handlers directos.

---

## Estructura del Proyecto

```
Inventory-App/
|
|-- Source/                          # Codigo fuente del modulo
|   |-- Classes/                     # Modelo de datos (6 clases)
|   |   |-- ServerInventory.ps1      # Contenedor principal
|   |   |-- OSInfo.ps1               # Info del sistema operativo
|   |   |-- HardwareInfo.ps1         # Hardware, CPU, RAM, discos
|   |   |-- NetworkInfo.ps1          # Adaptadores de red
|   |   |-- CollectionStatus.ps1     # Estado de la recoleccion
|   |   +-- IISInfo.ps1              # Placeholder para Schema v2
|   |
|   |-- Public/                      # Cmdlets exportados (API publica)
|   |   |-- Get-ServerInventory.ps1
|   |   |-- Get-AllServerInventories.ps1
|   |   |-- Update-ServerInventory.ps1
|   |   |-- Import-ServerInventory.ps1
|   |   |-- Export-ServerInventory.ps1
|   |   +-- Invoke-BulkInventoryCollection.ps1
|   |
|   +-- Private/                     # Funciones internas
|       |-- Initialize-InventoryModule.ps1
|       |-- Write-InventoryLog.ps1
|       |-- Get-RemoteServerInventory.ps1
|       |-- Invoke-SchemaMigration.ps1
|       |-- Test-ServerInventorySchema.ps1
|       +-- Update-SchemaFrom1To2.ps1
|
|-- UI/                              # Interfaz grafica WPF
|   |-- Start-InventoryUI.ps1        # Launcher principal
|   |-- Views/
|   |   |-- MainWindow.xaml          # Ventana principal
|   |   +-- ServerDetailsWindow.xaml # Detalle de servidor
|   |-- ViewModels/
|   |   +-- MainViewModel.psm1       # ViewModel con data binding
|   +-- Helpers/
|       |-- XamlLoader.psm1          # Utilidades de carga XAML
|       +-- JsonTreeHelpers.psm1     # Visualizacion de JSON en arbol
|
|-- Scripts/Examples/                # Scripts de ejemplo
|   |-- 01-BasicUsage.ps1            # Uso basico del modulo
|   |-- 02-UIBasicTest.ps1           # UI con datos mock
|   +-- 03-UIWithData.ps1            # UI con datos reales
|
|-- Config/                          # Configuracion
|   +-- Credentials/                 # Credenciales almacenadas
|
|-- Data/                            # Almacenamiento de inventarios
|   |-- Inventory/                   # Archivos de datos (.xml, .json)
|   +-- Templates/                   # Plantillas de configuracion
|
|-- Logs/                            # Sistema de logging
|   |-- Collection/                  # Logs por servidor y fecha
|   +-- Errors/                      # Logs de errores
|
|-- InventarioServidores.psm1       # Loader del modulo
|-- InventarioServidores.psd1       # Manifiesto del modulo
+-- Propuesta Formal de Arquitectura.md  # Documento de diseño
```

---

## Requisitos Previos

- **Windows 10/11** o **Windows Server 2016+**
- **PowerShell 5.1** o superior (incluido en Windows 10+)
- **WinRM habilitado** en los servidores remotos a inventariar
- Para la UI: **.NET Framework 4.5+** (incluido en Windows 10+)

---

## Instalacion

```powershell
# 1. Clonar el repositorio
git clone https://github.com/jmballesterjp/InventarioServidores.git
cd Inventory-App

# 2. Importar el modulo
Import-Module .\InventarioServidores.psm1 -Force

# 3. Verificar que se cargo correctamente
Get-Command -Module InventarioServidores
```

Deberia mostrar las 6 funciones publicas disponibles.

---

## Uso

### Por Consola (Cmdlets)

```powershell
# Importar modulo
Import-Module .\InventarioServidores.psm1 -Force

# --- Inventariar un servidor ---
Update-ServerInventory -ServerName "localhost" -Force

# --- Consultar inventario ---
$inv = Get-ServerInventory -ServerName "localhost"
$inv.ServerName        # Nombre del servidor
$inv.OS.Name           # Sistema operativo
$inv.Hardware.GetRAMFormatted()  # RAM formateada
$inv.OS.GetUptimeFormatted()     # Uptime

# --- Ver discos ---
$inv.Hardware.Disks | Format-Table DeviceID, `
    @{N='Tamano';E={$_.GetSizeFormatted()}}, `
    @{N='Libre';E={$_.GetFreeFormatted()}}, `
    PercentFree

# --- Ver adaptadores de red ---
$inv.Network | Format-Table AdapterName, `
    @{N='IP';E={$_.IPAddress -join ', '}}, `
    MACAddress, `
    @{N='Velocidad';E={$_.GetSpeedFormatted()}}

# --- Listar todos los servidores inventariados ---
Get-AllServerInventories | Format-Table ServerName, `
    @{N='OS';E={$_.OS.Name}}, `
    @{N='RAM';E={$_.Hardware.GetRAMFormatted()}}, `
    LastInventory, `
    @{N='Estado';E={$_.Status.Result}}

# --- Exportar a JSON ---
$inv = Get-ServerInventory -ServerName "localhost"
Export-ServerInventory -Inventory $inv -AlsoExportJSON

# --- Inventario masivo en paralelo ---
$servidores = @("SRV01", "SRV02", "SRV03")
Invoke-BulkInventoryCollection -ServerName $servidores -ThrottleLimit 5
```

### Interfaz Grafica (WPF)

```powershell
# Lanzar la UI directamente
& .\Scripts\InventoryUI\Launch-UI.ps1

# O con datos de ejemplo
& .\Scripts\Examples\02-UIBasicTest.ps1

# O con datos reales del inventario
& .\Scripts\Examples\03-UIWithData.ps1
```

La interfaz ofrece:
- **DataGrid** con todos los servidores (nombre, IP, OS, RAM, uptime, estado)
- **Barra de busqueda** para filtrar servidores
- **Vista de detalles** con JSON tree view expandible
- **Botones de accion**: refrescar, inventariar seleccionado/todos, anadir, eliminar
- **Barra de estado** con conteo de servidores y ultima actualizacion
- **Indicadores de color** por estado: verde (Success), naranja (Partial), rojo (Failed)

---

## Funcionalidades Principales

### 1. Recoleccion Remota
Usa PowerShell Remoting (WinRM) para conectarse a servidores y recopilar informacion de OS, hardware y red. Soporta credenciales personalizadas.

### 2. Modelo de Datos Tipado
6 clases PowerShell con tipado fuerte:
- `ServerInventory` - Contenedor principal con metadata
- `OSInfo` - Sistema operativo, version, build, uptime
- `HardwareInfo` / `DiskInfo` - CPU, RAM, discos
- `NetworkInfo` - Adaptadores, IPs, MAC, velocidad
- `CollectionStatus` - Estado de la ultima recoleccion

### 3. Schema Versioning
Sistema de migracion automatica que actualiza inventarios antiguos al schema actual. Cadena de migraciones secuenciales (v1 -> v2 -> v3...) con proteccion contra bucles infinitos.

### 4. Persistencia Dual
- **XML (Export-Clixml)**: formato nativo que preserva tipos PowerShell
- **JSON**: formato legible para integraciones y auditorias

### 5. Operaciones Masivas
`Invoke-BulkInventoryCollection` ejecuta inventarios en paralelo usando PowerShell Jobs con limite de concurrencia configurable (1-50), logging thread-safe por servidor, y resumen de resultados.

### 6. Sistema de Logging
Logging thread-safe con `[System.IO.File]::AppendAllText`:
- `Logs/Master.log` - Log global del sistema
- `Logs/Collection/{Server}_{Date}.log` - Log por servidor
- `Logs/Errors/{Server}_{Date}.log` - Log de errores
- Niveles: Debug, Verbose, Info, Warning, Error

### 7. Interfaz Grafica WPF
Aplicacion de escritorio con patron MVVM:
- DataGrid con binding a `ObservableCollection`
- Carga dinamica de XAML
- JSON tree view recursivo con deteccion de referencias circulares
- Controles expandir/colapsar todo

---

## Modelo de Datos (Schema v1)

```
ServerInventory
|-- ServerName          : string
|-- FQDN                : string
|-- IPAddress           : string[]
|-- LastInventory       : datetime
|-- CreatedDate         : datetime
|-- CollectedBy         : string
|-- SchemaVersion       : int
|
|-- OS (OSInfo)
|   |-- Name, Version, Build, Architecture
|   |-- InstallDate, LastBootTime, UptimeDays
|   +-- SerialNumber, RegisteredUser, Organization
|
|-- Hardware (HardwareInfo)
|   |-- Manufacturer, Model, SerialNumber
|   |-- CPUName, CPUCores, CPULogicalProcessors, CPUMaxClockSpeed
|   |-- RAMBytes, RAMSlots, RAMSlotsUsed
|   +-- Disks[] (DiskInfo)
|       +-- DeviceID, VolumeName, FileSystem, SizeBytes, FreeBytes, PercentFree
|
|-- Network[] (NetworkInfo)
|   +-- AdapterName, MACAddress, IPAddress[], SubnetMask, DHCPEnabled, Speed
|
|-- Status (CollectionStatus)
|   +-- Result (Success|Partial|Failed|NotStarted), Message, Timestamp, Errors[], Warnings[]
|
+-- CustomProperties    : hashtable (extensibilidad)
```

---

## Estado del Proyecto

### Completado (Phase 1)
- Modulo PowerShell con manifiesto y 6 cmdlets publicas
- 6 clases de datos con tipado fuerte
- Recoleccion remota via WinRM
- Operaciones masivas en paralelo con control de concurrencia
- Persistencia dual (XML + JSON)
- Sistema de logging thread-safe
- Schema versioning con migracion automatica
- Interfaz WPF con DataGrid, busqueda, vista de detalles
- JSON tree view expandible con deteccion de ciclos
- Gestion de servidores (anadir/eliminar)

### Planificado (Phase 2)
- Recoleccion de informacion IIS (Schema v2)
- Suite de tests con Pester
- Base de datos SQL centralizada
- Sistema de alertas y notificaciones
- Tracking historico de cambios
- Actualizaciones incrementales
- Soporte Linux/SSH

---

## Documentacion Adicional

- [Propuesta de Arquitectura](Propuesta%20de%20Arquitectura.md) - Documento detallado de diseño con decisiones arquitectonicas, patrones y estrategias de implementacion.

---

## Licencia

(c) 2026. Todos los derechos reservados.
