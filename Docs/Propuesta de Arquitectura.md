## Propuesta Formal de Arquitectura

### Estructura de Directorios Recomendada

Basándome en las mejores prácticas de la comunidad PowerShell, propongo esta estructura:[^1_1][^1_2]

```
InventarioServidores/
├── Source/
│   ├── Public/                 # Funciones expuestas al usuario/UI
│   ├── Private/                # Funciones internas del módulo
│   └── Classes/                # Clases PSCustomObject si es necesario
├── Config/
│   ├── Credentials/            # Archivos de credenciales (.cred.xml)
│   └── Settings.psd1           # Configuración general del proyecto
├── Data/
│   ├── Inventory/              # Archivos servidor.var.xml
│   └── Templates/              # Plantillas de objetos/configuraciones
├── Logs/
│   ├── Archive/                # Logs antiguos
│   ├── Collection/             # Logs de inventariado por servidor y fecha
│   └── Errors/                 # Logs de errores específicos
├── Scripts/
│   └── Examples/               # Scripts de ejemplo de uso
├── Temp/                       # Archivos temporales
├── Tests/                      # Tests Pester
├── UI/                         # Componentes WPF
│   ├── Views/                  # Archivos XAML
│   ├── ViewModels/             # Lógica de presentación
│   └── Helpers/                # Utilidades UI (carga XAML, TreeView JSON)
├── InventarioServidores.psd1   # Module manifest
├── InventarioServidores.psm1   # Module loader
└── README.md
```


### Arquitectura del Sistema

**Capa de Datos:**

- Serialización con `Export-Clixml` para objetos complejos
- Nomenclatura: `{NombreServidor}.var.xml`
- Ventaja: Preserva tipos de datos PowerShell nativamente[^1_3]

**Capa de Lógica:**

- Funciones Public: APIs para la UI y uso manual
- Funciones Private: Operaciones internas, validaciones, helpers
- Auto-carga mediante dot-sourcing en el .psm1[^1_2]

**Capa de Presentación:**

- WPF separado con patrón MVVM (Model-View-ViewModel)
- Comunicación mediante cmdlets del módulo


## Temas Ambiguos que Requieren Debate

### 1. **Formato de Serialización: Export-Clixml vs JSON/XML**

> ✅ **DECISIÓN TOMADA:** Export-Clixml como formato principal (preserva tipos) + export secundario a JSON configurable desde `Settings.psd1`.

**Pregunta crítica:** ¿Has considerado las limitaciones de Export-Clixml?

**Consideraciones:**

- **Export-Clixml**:[^1_3]
    - ✅ Preserva tipos complejos de PowerShell perfectamente
    - ✅ Incluye metadatos de tipo
    - ❌ Solo legible desde PowerShell
    - ❌ Archivos más grandes
    - ❌ No versionable en Git de forma útil
- **Alternativa JSON:**
    - ✅ Interoperable con otras herramientas
    - ✅ Legible por humanos
    - ✅ Mejor para control de versiones
    - ❌ Pierde información de tipos complejos[^1_3]

**Mi recomendación:** Mantén Export-Clixml PERO considera un Export secundario a JSON para reporting/auditoría.

### 2. **Gestión de Credenciales**

> ✅ **DECISIÓN TOMADA:** Archivos `.cred.xml` por usuario (Opción 4). Suficiente para el alcance actual (un administrador ejecutando).

**Pregunta crítica:** ¿Cómo planeas manejar las credenciales en entornos multi-usuario y ejecución remota?

**Problemas detectados:**

- `Export-Clixml` con credenciales solo funciona para el usuario que las exportó[^1_4]
- En ejecución remota necesitarás CredSSP, delegación Kerberos, o cuentas de servicio

**Opciones:**

1. **Credential Manager API** (Windows)
2. **Secret Management Module** (cross-platform, más moderno)
3. **Azure Key Vault / HashiCorp Vault** (empresarial)
4. **Archivos .cred.xml** por usuario (tu enfoque actual) - limitado pero simple

**¿Qué escenario tienes?** ¿Un solo usuario ejecutando? ¿Múltiples usuarios? ¿Ejecución programada?

### 3. **Estrategia de Ejecución Remota**

> ✅ **DECISIÓN TOMADA:** PowerShell Remoting (WinRM/WSMan) con `Invoke-Command`, para el alcance inicial. Entorno Windows-only en dominio Active Directory.

**Pregunta crítica:** ¿Qué protocolo/método de ejecución remota vas a usar?

**Opciones:**

- **PowerShell Remoting (WSMan):** Estándar, requiere configuración
- **CIM/WMI:** Más universal pero menos flexible
- **SSH Remoting:** Cross-platform pero requiere PS 7+
- **API REST/WinRM:** Para entornos heterogéneos

**Define:**

- ¿Servidores Windows, Linux, o mixto?
- ¿Están en dominio Active Directory?
- ¿Necesitas atravesar firewalls/DMZs?


### 4. **Modelo de Datos del Inventario**

> ✅ **DECISIÓN TOMADA:** Schema rígido con clases tipadas (`ServerInventory`, `OSInfo`, `HardwareInfo`, `DiskInfo`, `NetworkInfo`, `CollectionStatus`, `IISInfo`) + `[hashtable]$CustomProperties` como escape hatch. Versionado de schema con migración secuencial.

**Pregunta crítica:** ¿Qué estructura tendrá tu PSCustomObject?

**Necesitas definir:**

```powershell
# Ejemplo de estructura base
[PSCustomObject]@{
    ServerName = ""
    FQDN = ""
    IPAddress = @()
    OS = @{
        Name = ""
        Version = ""
        Build = ""
    }
    Hardware = @{
        CPU = ""
        RAM = ""
        Disk = @()
    }
    Software = @()
    Services = @()
    LastInventory = [datetime]
    CollectionStatus = "" # Success/Partial/Failed
    # ¿Qué más necesitas?
}
```

**Decisiones arquitectónicas:**

- ¿Schema rígido o flexible?
- ¿Versionado del schema (v1, v2...)?
- ¿Validación al importar?


### 5. **Concurrencia y Jobs**

> ✅ **DECISIÓN TOMADA:** `Start-Job` con `ThrottleLimit` configurable (1-50). Compatible con PS 5.1 (no requiere PS 7+). Barra de progreso con `Write-Progress`.

**Pregunta crítica:** ¿Cómo ejecutarás el inventario de múltiples servidores?

**Opciones:**

- **Invoke-Command -AsJob:** Paralelo, nativo
- **ForEach-Object -Parallel:** PS 7+, más simple
- **Start-ThreadJob:** Ligero, PS 7+
- **Runspaces:** Máximo control, más complejo

**¿Cuántos servidores simultáneos?** Esto impacta el diseño del sistema de logs y gestión de errores.

### 6. **Estrategia de Logging**

> ✅ **DECISIÓN TOMADA:** Write-InventoryLog custom (facade pattern) con `[System.IO.File]::AppendAllText` (thread-safe, atómico). Logs por servidor en `Collection/` y errores en `Errors/`. Sin dependencia de PSFramework.

**Pregunta crítica:** ¿Necesitas logs centralizados o por servidor inventariado?

**Estructura posible:**

```
Logs/
├── Master.log                    # Log general del sistema
├── Collection_YYYYMMDD.log       # Log por ejecución
└── Errors/
    └── ServerName_YYYYMMDD.log   # Errores específicos
```

**¿Usarás Write-Log personalizado o módulos como PSFramework?**

### 7. **Integración UI-Backend**

> ✅ **DECISIÓN TOMADA:** Opción A - Módulo compartido. La UI importa el módulo directamente y usa los cmdlets públicos. MVVM-lite con XAML separado y `ObservableCollection` para binding.

**Pregunta crítica:** ¿La UI lanzará cmdlets tras importar el módulo o invocará scripts?

**Opción A - Módulo compartido:**

```powershell
# En WPF
Import-Module .\InventarioServidores.psm1
Get-ServerInventory -ServerName "SRV01"
```

**Opción B - Scripts wrapper:**

```powershell
# UI ejecuta scripts que usan el módulo internamente
& .\Scripts\Collection\Invoke-InventoryCollection.ps1 -Servers @("SRV01")
```

**Mi recomendación:** Opción A con el módulo exponiendo cmdlets claros (Get-, Set-, Update-, Export-).

### 8. **Manejo de Archivos Temporales**

> ✅ **DECISIÓN TOMADA:** Por el momento no se usa directorio `Temp/`. Los archivos temporales se eliminaron del diseño inicial; los datos se persisten directamente en `Data/Inventory/`. No obstante, no se descarta en operaciones futuras más costosas.

**Pregunta crítica:** ¿Para qué usarás los temporales?

**Casos comunes:**

- Colecciones parciales antes de merge
- Archivos de trabajo durante procesamiento remoto
- Caché de operaciones costosas

**¿Necesitas limpieza automática? ¿Política de retención?**

## Recomendaciones Adicionales

### Testing

Incluye **Pester tests** desde el inicio:[^1_5]

```powershell
Tests/
├── Unit/
│   ├── Public.Tests.ps1
│   └── Private.Tests.ps1
└── Integration/
    └── RemoteCollection.Tests.ps1
```


### Versionado

Usa **semantic versioning** en el manifest (.psd1):

```powershell
ModuleVersion = '1.0.0'
```


### Documentación

Implementa **Comment-Based Help** en todas las funciones públicas:[^1_5]

```powershell
<#
.SYNOPSIS
    Recopila inventario de un servidor remoto
.DESCRIPTION
    ...
.EXAMPLE
    Get-ServerInventory -ServerName "SRV01"
#>
```


## Preguntas para Continuar *(todas resueltas)*

1. ~~¿Qué información específica necesitas inventariar?~~ → **OS, Hardware (CPU, RAM, Disco), Red (IPs, adaptadores), IIS (placeholder), Estado de colección**
2. ~~¿Frecuencia de actualización del inventario?~~ → **Bajo demanda** con parámetro `-Force` y detección de staleness (obsolescencia) configurable en `Settings.psd1`
3. ~~¿Necesitas histórico/auditoría de cambios entre inventarios?~~ → **No en v1.** Cada inventario sobrescribe el anterior. Roadmap: histórico en v2+
4. ~~¿El UI será read-only o también permitirá modificaciones/acciones remotas?~~ → **Lectura + lanzamiento de recolección remota** desde la UI. No permite edición manual de datos
5. ~~¿Cuántos servidores aproximadamente gestionarás?~~ → **Escala media (10-100)**, con `ThrottleLimit` configurable para paralelismo
<span style="display:none">[^1_10][^1_6][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://www.reddit.com/r/PowerShell/comments/1e2pnpm/best_practices_in_creating_modules/

[^1_2]: https://stackoverflow.com/questions/43032681/powershell-module-structure

[^1_3]: https://www.reddit.com/r/PowerShell/comments/1g5302k/json_equivalent_to_importclixml_and_exportclixml/

[^1_4]: https://www.reddit.com/r/AskNetsec/comments/2gln8o/is_powershells_getcredential_exportclixml_secure/

[^1_5]: https://dev.to/this-is-learning/how-to-write-better-powershell-scripts-architecture-and-best-practices-emh

[^1_6]: https://forums.powershell.org/t/powershell-module-best-practices/13290

[^1_7]: https://www.reddit.com/r/PowerShell/comments/5z5j59/what_are_your_module_best_practices/

[^1_8]: https://www.scriptrunner.com/blog-admin-architect/building-your-first-powershell-module

[^1_9]: https://stackoverflow.com/questions/71575378/powershell-for-software-inventory

[^1_10]: https://jdhitsolutions.com/blog/powershell/7549/building-a-powershell-inventory/


---

## 4. Decisiones Arquitectónicas: Schema y Versionado

### **¿Schema Rígido o Flexible?**

**Schema Rígido (Recomendado para tu caso):**

```powershell
# Defines una clase con propiedades fijas
class ServerInventory {
    [string]$ServerName
    [string]$FQDN
    [datetime]$LastInventory
    [int]$SchemaVersion = 1  # Crítico para migraciones (v1 en implementación actual)
    [OSInfo]$OS
    [HardwareInfo]$Hardware
    [NetworkInfo]$Network
    [IISInfo]$IIS
    [CollectionStatus]$Status
}

class IISInfo {
    [string]$Version
    [Site[]]$Sites
    [AppPool[]]$AppPools
}

class Site {
    [string]$Name
    [int]$ID
    [string]$PhysicalPath
    [Binding[]]$Bindings
    [hashtable]$Authentication
}
```

**Ventajas:**

- ✅ IntelliSense completo en VS Code
- ✅ Validación de tipos automática
- ✅ Errores en tiempo de desarrollo, no en runtime
- ✅ Facilita refactoring

**Desventajas:**

- ❌ Cambios requieren recompilar/actualizar código
- ❌ Menos flexible para propiedades ad-hoc

**Schema Flexible (PSCustomObject puro):**

```powershell
$inventory = [PSCustomObject]@{
    ServerName = "SRV01"
    SchemaVersion = 2
    # Puedes añadir propiedades dinámicamente
}
Add-Member -InputObject $inventory -MemberType NoteProperty -Name "CustomField" -Value "Value"
```

**Ventajas:**

- ✅ Añadir propiedades sin tocar código
- ✅ Útil para entornos heterogéneos

**Desventajas:**

- ❌ Sin IntelliSense
- ❌ Errores solo en runtime
- ❌ Difícil de mantener en equipos

**MI RECOMENDACIÓN:** **Schema rígido con clases + extensibility point flexible**

```powershell
class ServerInventory {
    [int]$SchemaVersion = 1
    # ... propiedades fijas ...
    [hashtable]$CustomProperties = @{}  # Escape hatch para casos especiales
}
```


### **Versionado del Schema**

Inspirándome en patrones de migración de bases de datos:[^2_1][^2_2]

**Implementación:**

```powershell
class ServerInventory {
    [int]$SchemaVersion = 1  # Current version (v1 en implementación actual)
    hidden static [int]$CurrentSchemaVersion = 1
    hidden static [int]$OldestSupportedVersion = 1
    
    # Constructor para nuevos inventarios
    ServerInventory() {
        $this.SchemaVersion = [ServerInventory]::CurrentSchemaVersion
    }
}

# En tu módulo principal
function Import-ServerInventory {
    param([string]$Path)
    
    $inventory = Import-Clixml -Path $Path
    
    # Migration pipeline
    if ($inventory.SchemaVersion -lt [ServerInventory]::CurrentSchemaVersion) {
        Write-InventoryLog -Message "Migrando $($inventory.ServerName) de v$($inventory.SchemaVersion) a v$([ServerInventory]::CurrentSchemaVersion)" -Level Info
        $inventory = Invoke-SchemaMigration -Inventory $inventory
    }
    
    return $inventory
}

function Invoke-SchemaMigration {
    param($Inventory)
    
    # Sequential migration chain
    while ($Inventory.SchemaVersion -lt [ServerInventory]::CurrentSchemaVersion) {
        switch ($Inventory.SchemaVersion) {
            1 { $Inventory = Update-SchemaFrom1To2 -Inventory $Inventory }
            2 { $Inventory = Update-SchemaFrom2To3 -Inventory $Inventory }
            # ... añadir según evolucione
        }
    }
    
    return $Inventory
}

function Update-SchemaFrom1To2 {
    param($Inventory)
    
    Write-InventoryLog -Message "Migrando schema 1 -> 2 para $($Inventory.ServerName)" -Level Info
    
    # Ejemplo: Añadir nueva propiedad IIS que no existía en v1
    if (-not $Inventory.PSObject.Properties['IIS']) {
        Add-Member -InputObject $Inventory -MemberType NoteProperty -Name 'IIS' -Value $null
    }
    
    # Transformar datos existentes si es necesario
    if ($Inventory.OS -is [string]) {
        # Convertir de string plano a objeto estructurado
        $Inventory.OS = [PSCustomObject]@{
            Name = $Inventory.OS
            Version = "Unknown"
            Build = "Unknown"
        }
    }
    
    $Inventory.SchemaVersion = 2
    
    # Auto-save migrated version
    Export-ServerInventory -Inventory $Inventory -Force
    
    return $Inventory
}
```

**Estrategias de Migración según el Cambio:**


| Tipo de Cambio | Estrategia | Ejemplo |
| :-- | :-- | :-- |
| **Añadir propiedad nueva** | Valor por defecto `$null` o calculado | Añadir `IIS` en v2 [^2_2] |
| **Renombrar propiedad** | Copiar valor antiguo → nuevo nombre | `RAM` → `Memory` |
| **Eliminar propiedad** | Deprecar primero, eliminar después | Mantener v1-v2, eliminar en v3+ |
| **Cambiar tipo** | Transformación de datos | `[string]` → `[OSInfo]` |
| **Reestructurar jerarquía** | Mover propiedades entre objetos | `Disk` → `Hardware.Storage` |

### **Validación al Importar**

```powershell
function Test-ServerInventorySchema {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        $Inventory,
        
        [switch]$Strict  # Forzar schema exacto vs. mínimo
    )
    
    # Validación mínima
    $requiredProperties = @('ServerName', 'SchemaVersion', 'LastInventory')
    
    foreach ($prop in $requiredProperties) {
        if (-not $Inventory.PSObject.Properties[$prop]) {
            Write-InventoryLog -Message "Falta propiedad requerida: $prop" -Level Error
            return $false
        }
    }
    
    # Validación de versión
    if ($Inventory.SchemaVersion -lt [ServerInventory]::OldestSupportedVersion) {
        Write-InventoryLog -Message "Schema version $($Inventory.SchemaVersion) demasiado antigua (mínimo: $([ServerInventory]::OldestSupportedVersion))" -Level Error
        return $false
    }
    
    if ($Strict) {
        # Validar que todas las propiedades esperadas existen
        # y son del tipo correcto
        if ($Inventory.OS -isnot [OSInfo]) {
            Write-InventoryLog -Message "La propiedad OS debe ser de tipo [OSInfo]" -Level Error
            return $false
        }
    }
    
    return $true
}
```


### **Situaciones de Transición Real:**

**Escenario 1: Inventario masivo mezclado**

```powershell
# Tienes 150 servidores inventariados
# 100 con schema v1 (sin IIS)
# 50 con schema v2 (con IIS)
# Actualizas el código a v3 (añadir certificados SSL)

# Al cargar cualquier inventario:
$inventory = Import-ServerInventory -Path "Data\Inventory\SRV01.var.xml"
# → Auto-migra v1→v2→v3 transparentemente
# → Guarda versión migrada
# → UI siempre recibe schema actual
```

**Escenario 2: Rollback de código**

```powershell
# Despliegas código v3 pero tiene un bug
# Vuelves a código v2
# Algunos archivos ya son v3

# Solución 1: Degradación graceful
if ($inventory.SchemaVersion -gt [ServerInventory]::CurrentSchemaVersion) {
    Write-InventoryLog -Message "Inventario de versión más reciente ($($inventory.SchemaVersion)), algunos datos pueden faltar" -Level Warning
    # Ignora propiedades desconocidas
}

# Solución 2: Version pinning
# Mantén v2 del módulo disponible:
Import-Module .\InventarioServidores.psm1 -RequiredVersion 2.0.0
```

**Escenario 3: Migración de datos calculados**

```powershell
# v1: Guardabas RAM en GB como [int]
# v2: Quieres bytes precisos [long]
# Problema: Información original perdida (32GB → ¿cuántos bytes exactos?)

function Update-SchemaFrom1To2 {
    # Aproximación desde GB
    if ($Inventory.Hardware.RAM -is [int]) {
        $Inventory.Hardware.RAMBytes = [long]($Inventory.Hardware.RAM * 1GB)
        # Marcar como aproximado
        $Inventory.Hardware.RAMBytesApproximate = $true
    }
    
    # Forzar re-inventario para obtener dato preciso
    $Inventory.Status.RequiresRefresh = $true
}
```


## 5 \& 6. Concurrencia y Logging

### **Sistema de Logging con Jobs**

```powershell
# Source/Private/Write-InventoryLog.ps1
function Write-InventoryLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        
        [string]$ServerName,  # Si es log específico de servidor
        
        [switch]$ErrorLog  # Escribir también en error log
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $(if($ServerName){"[$ServerName] "})$Message"
    
    # Master log (thread-safe)
    $masterLog = Join-Path $script:LogPath "Master.log"
    [System.IO.File]::AppendAllText($masterLog, "$logEntry`n", [System.Text.Encoding]::UTF8)
    
    # Server-specific log
    if ($ServerName) {
        $dateStamp = Get-Date -Format "yyyyMMdd"
        $serverLog = Join-Path $script:LogPath "Collection/$ServerName`_$dateStamp.log"
        
        # Crear directorio si no existe (thread-safe)
        $dir = Split-Path $serverLog
        if (-not (Test-Path $dir)) {
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        }
        
        [System.IO.File]::AppendAllText($serverLog, "$logEntry`n", [System.Text.Encoding]::UTF8)
    }
    
    # Error log separado
    if ($ErrorLog -and $ServerName) {
        $errorLog = Join-Path $script:LogPath "Errors/$ServerName`_$dateStamp.log"
        $errorDir = Split-Path $errorLog
        if (-not (Test-Path $errorDir)) {
            [System.IO.Directory]::CreateDirectory($errorDir) | Out-Null
        }
        [System.IO.File]::AppendAllText($errorLog, "$logEntry`n", [System.Text.Encoding]::UTF8)
    }
}
```

**⚠️ KEY: Thread-Safety con Jobs**

Cuando usas `-AsJob`, múltiples runspaces escriben logs simultáneamente. Opciones:

1. **File locking manual** (tu Write-InventoryLog usa `[System.IO.File]::AppendAllText` que es atómico)
2. **Synchronized hashtable** para buffer en memoria
3. **PSFramework** (maneja esto automáticamente)

### **PSFramework vs Write-Log Personalizado**

> ✅ **DECISIÓN TOMADA:** Se implementó `Write-InventoryLog` custom (facade pattern) con 5 niveles (Verbose, Info, Warning, Error, Critical). Sin dependencias externas. Los snippets de PSFramework a continuación se mantienen como referencia de la alternativa evaluada.

**PSFramework**:[^2_3][^2_4]

```powershell
# Instalar
Install-Module PSFramework -Scope CurrentUser

# Configurar en tu módulo
Set-PSFLoggingProvider -Name logfile -InstanceName InventarioServidores -Enabled $true -FilePath "C:\Logs\Inventario"

# Usar en tu código
Write-PSFMessage -Level Host -Message "Iniciando inventario" -Tag 'Collection'
Write-PSFMessage -Level Warning -Message "Servidor no responde" -Tag 'Error' -Target "SRV01"
Write-PSFMessage -Level Verbose -Message "Recopilando info IIS" -Tag 'IIS' -Target "SRV02"

# Features automáticos:
# - Runspace-safe (perfecto para jobs)
# - Niveles de log configurables por usuario/máquina
# - Múltiples providers simultáneos (file + eventlog + Azure)
# - Rotación automática de logs
# - Structured logging (tags, targets)
```

**Ventajas PSFramework:**

- ✅ Runspace-safe out-of-the-box[^2_3]
- ✅ Configuración externa sin cambiar código
- ✅ Logs estructurados (filtrar por Tag, Target)
- ✅ Integración con sistemas enterprise (Splunk, Graylog)
- ✅ Automatic debug logging

**Desventajas:**

- ❌ Dependencia externa
- ❌ Curva de aprendizaje inicial
- ❌ Overhead mínimo de performance

**Write-Log Custom:**

**Ventajas:**

- ✅ Control total del formato
- ✅ Cero dependencias
- ✅ Ligero y simple

**Desventajas:**

- ❌ Tienes que implementar thread-safety manualmente
- ❌ Rotación de logs manual
- ❌ Sin configuración externa

**MI RECOMENDACIÓN:** Empieza con **Write-Log custom simple** (ya tienes la base), pero diseñalo como "facade":

```powershell
function Write-InventoryLog {
    param($Message, $Level, $ServerName)
    
    # Hoy: tu implementación custom
    # Mañana: switch interno a PSFramework
    # → Los callers no cambian
}
```

Si el proyecto crece o necesitas múltiples destinos de log, migra internamente a PSFramework.

### **Manejo de Concurrencia en Jobs**

```powershell
function Invoke-BulkInventoryCollection {
    [CmdletBinding()]
    param(
        [string[]]$ServerNames,
        [int]$ThrottleLimit = 10  # Máximo jobs paralelos
    )
    
    Write-InventoryLog "Iniciando inventario de $($ServerNames.Count) servidores (concurrencia: $ThrottleLimit)"
    
    $jobs = @()
    $completed = 0
    $total = $ServerNames.Count
    
    foreach ($server in $ServerNames) {
        # Control de concurrencia
        while ((Get-Job -State Running | Where-Object Name -like "Inventory_*").Count -ge $ThrottleLimit) {
            Start-Sleep -Milliseconds 500
            
            # Procesar jobs completados
            $finished = Get-Job -State Completed | Where-Object Name -like "Inventory_*"
            foreach ($job in $finished) {
                $completed++
                Write-Progress -Activity "Inventario masivo" -Status "Procesando resultados" -PercentComplete (($completed/$total)*100)
                
                $result = Receive-Job -Job $job
                # Procesar resultado, guardar inventario
                Save-InventoryResult -Result $result
                
                Remove-Job -Job $job
            }
        }
        
        # Lanzar nuevo job
        $job = Start-Job -Name "Inventory_$server" -ScriptBlock {
            param($srv, $modulePath, $logPath)
            
            # IMPORTANTE: Importar módulo en el runspace del job
            Import-Module $modulePath
            
            # Configurar logging para este runspace
            $script:LogPath = $logPath
            
            try {
                Write-InventoryLog -Message "Iniciando recopilación" -ServerName $srv
                
                $inventory = Get-RemoteServerInventory -ServerName $srv
                
                Write-InventoryLog -Message "Recopilación exitosa" -Level Info -ServerName $srv
                
                return @{
                    Success = $true
                    ServerName = $srv
                    Inventory = $inventory
                }
            }
            catch {
                Write-InventoryLog -Message "Error: $_" -Level Error -ServerName $srv -ErrorLog
                
                return @{
                    Success = $false
                    ServerName = $srv
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $server, $PSScriptRoot, $script:LogPath
        
        $jobs += $job
    }
    
    # Esperar jobs restantes
    Wait-Job -Job $jobs | Out-Null
    
    # Procesar últimos resultados
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job
        Save-InventoryResult -Result $result
        Remove-Job -Job $job
    }
    
    Write-InventoryLog "Inventario masivo completado: $completed/$total servidores"
}
```

**KEY para Logs en Jobs:**
Cada job tiene su propio runspace, pero si usas `[System.IO.File]::AppendAllText`, los writes son atómicos y thread-safe. El Master.log recibirá entradas de todos los jobs intercaladas (ordenadas por timestamp).

## 7. UI WPF y Binding

### **Opción A: Módulo Compartido (RECOMENDADO)**

```powershell
# En tu aplicación WPF (C# o PowerShell + ShowUI)
Import-Module .\InventarioServidores.psm1

# ViewModel
class MainViewModel : INotifyPropertyChanged {
    [ObservableCollection[ServerInventory]]$Servers
    
    method LoadServers() {
        $inventories = Get-AllServerInventories  # Cmdlet del módulo
        $this.Servers.Clear()
        foreach ($inv in $inventories) {
            $this.Servers.Add($inv)
        }
    }
    
    method RefreshServer([string]$serverName) {
        Start-Job -ScriptBlock {
            param($name)
            Import-Module .\InventarioServidores.psm1
            Update-ServerInventory -ServerName $name
        } -ArgumentList $serverName
        
        # Polling o events para actualizar UI cuando termine
    }
}
```

**No es bloqueante.** La UI puede:

1. Leer archivos `.var.xml` existentes → instantáneo
2. Lanzar jobs de actualización → asíncrono
3. Usar file watchers para detectar cambios

### **Binding a DataGrid en WPF**

```xml
<!-- MainWindow.xaml -->
<DataGrid ItemsSource="{Binding Servers}" AutoGenerateColumns="False" IsReadOnly="True">
    <DataGrid.Columns>
        <DataGridTextColumn Header="Servidor" Binding="{Binding ServerName}" Width="150"/>
        <DataGridTextColumn Header="IP" Binding="{Binding IPAddress[^2_0]}" Width="120"/>
        <DataGridTextColumn Header="SO" Binding="{Binding OS.Name}" Width="200"/>
        <DataGridTextColumn Header="RAM (GB)" Binding="{Binding Hardware.RAMFormatted}" Width="100"/>
        <DataGridTextColumn Header="Último Inventario" Binding="{Binding LastInventory, StringFormat='yyyy-MM-dd HH:mm'}" Width="150"/>
        <DataGridTemplateColumn Header="Estado" Width="100">
            <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                    <Border Background="{Binding Status.Color}" CornerRadius="3" Padding="5,2">
                        <TextBlock Text="{Binding Status.Text}" Foreground="White" HorizontalAlignment="Center"/>
                    </Border>
                </DataTemplate>
            </DataGridTemplateColumn.CellTemplate>
        </DataGridTemplateColumn>
    </DataGrid.Columns>
</DataGrid>
```

**Cómo funciona:**[^2_5][^2_6]

- `ItemsSource` se bindea a una colección (`ObservableCollection` para updates automáticos)
- Cada `Binding` accede a propiedades del objeto PowerShell
- Puedes bindear a propiedades anidadas: `{Binding OS.Name}`
- Conversiones automáticas (datetime → string con StringFormat)


### **Actualización Asíncrona con Jobs**

```powershell
# En el ViewModel
method StartInventoryCollection([string[]]$serverNames) {
    # Job que actualiza inventarios
    $this.CollectionJob = Start-Job -ScriptBlock {
        param($servers, $modulePath)
        Import-Module $modulePath
        Invoke-BulkInventoryCollection -ServerNames $servers
    } -ArgumentList $serverNames, $this.ModulePath
    
    # Timer para polling (WPF DispatcherTimer)
    $this.Timer.Start()
}

method OnTimerTick() {
    if ($this.CollectionJob.State -eq 'Completed') {
        $this.Timer.Stop()
        
        # Recargar datos
        $this.LoadServers()
        
        # Limpiar job
        Remove-Job $this.CollectionJob
        
        # Notificar UI
        $this.OnPropertyChanged("StatusMessage")
    }
}
```

**Alternativa: FileSystemWatcher**

```powershell
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "Data\Inventory"
$watcher.Filter = "*.var.xml"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
    # Trigger UI reload desde el thread de UI (Dispatcher.Invoke)
    $viewModel.ReloadServer($Event.SourceEventArgs.Name)
}

$watcher.EnableRaisingEvents = $true
```


### **Propiedades Calculadas para UI**

```powershell
class ServerInventory {
    [string]$ServerName
    [HardwareInfo]$Hardware
    
    # Propiedad calculada para display
    [string] hidden get_RAMFormatted() {
        return "$([Math]::Round($this.Hardware.RAMBytes / 1GB, 2)) GB"
    }
    
    [PSCustomObject] hidden get_StatusDisplay() {
        return [PSCustomObject]@{
            Text = $this.Status.ToString()
            Color = switch($this.Status) {
                'Success' { '#4CAF50' }
                'Partial' { '#FF9800' }
                'Failed'  { '#F44336' }
            }
        }
    }
}
```

Esto permite binding directo: `{Binding RAMFormatted}` sin lógica en XAML.

## Estructura Final de Código

```powershell
# InventarioServidores.psm1
$script:ModuleRoot = $PSScriptRoot
$script:DataPath = Join-Path $ModuleRoot "Data"
$script:LogPath = Join-Path $ModuleRoot "Logs"
$script:ConfigPath = Join-Path $ModuleRoot "Config"

# Cargar clases primero
. (Join-Path $ModuleRoot "Source\Classes\ServerInventory.ps1")
. (Join-Path $ModuleRoot "Source\Classes\HardwareInfo.ps1")
. (Join-Path $ModuleRoot "Source\Classes\IISInfo.ps1")

# Cargar funciones Private
Get-ChildItem (Join-Path $ModuleRoot "Source\Private\*.ps1") | ForEach-Object {
    . $_.FullName
}

# Cargar funciones Public
Get-ChildItem (Join-Path $ModuleRoot "Source\Public\*.ps1") | ForEach-Object {
    . $_.FullName
}

# Exportar solo Public
$publicFunctions = Get-ChildItem (Join-Path $ModuleRoot "Source\Public\*.ps1") | 
    ForEach-Object { $_.BaseName }

Export-ModuleMember -Function $publicFunctions
```


## Próximos Pasos Recomendados *(todos completados en Phase 1)*

1. ~~**Implementar clases base** con schema v1~~ ✅ 6 clases en `Source/Classes/`
2. ~~**Crear función de recopilación remota básica** (solo OS + Hardware)~~ ✅ `Get-RemoteServerInventory` con WMI/CIM
3. ~~**Implementar Export/Import con validación**~~ ✅ `Export-ServerInventory`, `Import-ServerInventory`, `Test-ServerInventorySchema`
4. ~~**Crear cmdlets Public**~~ ✅ 6 cmdlets: `Get-`, `Get-All`, `Update-`, `Import-`, `Export-`, `Invoke-Bulk`
5. ~~**Proof-of-concept WPF** simple con DataGrid~~ ✅ UI completa con DataGrid, búsqueda, TreeView JSON expandible
6. ~~**Añadir IIS collection**~~ ✅ Clase `IISInfo` como placeholder (schema v1, colección IIS en roadmap v2)
7. ~~**Implementar migration pipeline**~~ ✅ `Invoke-SchemaMigration` con cadena secuencial y protección anti-bucle
<span style="display:none">[^2_10][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://news.ycombinator.com/item?id=11481593

[^2_2]: https://docs.metaplay.io/game-server-programming/how-to-guides/entity-schema-versions-and-migrations.html

[^2_3]: https://psframework.org/docs/PSFramework/Logging/overview

[^2_4]: https://psframework.org/docs/quickstart/PSFramework/logging/

[^2_5]: https://www.youtube.com/watch?v=lvk04dMLgIQ

[^2_6]: https://www.youtube.com/watch?v=8pSvdT55LFk

[^2_7]: https://stackoverflow.com/questions/33677026/flyway-migration-schema-version

[^2_8]: https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/powershell-cmdlet-for-migration-evaluation?view=sql-server-ver17

[^2_9]: https://gist.github.com/mkropat/1ba7ffd1d14f55f63fb3

[^2_10]: https://www.reddit.com/r/programming/comments/1fzskr1/5_strategies_for_reliable_schema_migrations/


---
