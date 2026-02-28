# Roadmap - InventarioServidores

> Documento de planificacion de mejoras y evolucion del proyecto.
> Organizado por fases secuenciales, de menor a mayor complejidad y dependencia.
> Ultima actualizacion: Febrero 2026

---

## Estado Actual

| Fase | Estado | Descripcion |
|------|--------|-------------|
| **Fase 1** - Modulo base | ✅ Completada | Clases tipadas, 6 cmdlets publicos, logging thread-safe, schema versioning, persistencia dual (Clixml + JSON) |
| **Fase 2** - UI WPF | ✅ Completada | DataGrid con servidores, busqueda en tiempo real, vista de detalles con JSON tree view expandible, MVVM-lite |
| **Fase 3+** - Mejoras | ⏳ Planificada | Detalle a continuacion |

---

## Fase 3 - Consolidacion y Calidad

> Objetivo: Estabilizar lo existente antes de anadir funcionalidad nueva.

### 3.1 Tests Pester

- Implementar suite de tests automatizados con Pester 5+
- Tests unitarios para funciones privadas (`Write-InventoryLog`, `Invoke-SchemaMigration`, `Test-ServerInventorySchema`)
- Tests unitarios para cmdlets publicos (`Get-ServerInventory`, `Update-ServerInventory`, `Export-ServerInventory`, etc.)
- Tests de integracion para el flujo completo: recoleccion -> almacenamiento -> importacion -> migracion
- Validar que la cadena de migraciones v1 -> v2 funciona correctamente con datos reales

### 3.2 Archivado automatico de Logs

- Implementar rotacion/archivado de logs antiguos
- Nueva subcarpeta `Logs/Archive/` para logs que superen la politica de retencion (`LogRetentionDays` en `Settings.psd1`)
- Script o funcion de mantenimiento que mueva logs antiguos al archivo

### 3.3 Verificacion de scripts de ejemplo

- Revisar y asegurar que los 3 scripts en `Scripts/Examples/` funcionan correctamente tras los cambios recientes
- Validar la ventana de detalles del servidor (`ServerDetailsWindow`) end-to-end
- Verificar que las operaciones de anadir/eliminar servidor desde la UI completan el flujo

---

## Fase 4 - Schema v2: IIS, Servicios y Hyper-V

> Objetivo: Ampliar el modelo de datos con informacion de IIS, servicios Windows y maquinas virtuales Hyper-V.
> Dependencia: Fase 3 (los tests deben existir para validar la migracion).

### 4.1 Upgrade del Schema a v2

- Completar la clase `IISInfo` (actualmente placeholder):
  - Sites: nombre, ID, physical path, bindings, estado
  - Application Pools: nombre, runtime version, estado
  - Certificados SSL asociados
- Anadir recoleccion de servicios Windows relevantes
- Añadir recoleccion de informacion de máquinas virtuales (Hyper-V)
- Implementar funcion de migracion `Update-SchemaFrom1To2`
- Incrementar `[ServerInventory]::CurrentSchemaVersion` a 2

### 4.2 Recoleccion remota de IIS

- Ampliar `Get-RemoteServerInventory` para consultar IIS via WMI/CIM o `Get-Website`/`Get-WebBinding`
- Manejar el caso de servidores sin IIS instalado (graceful degradation)
- Logging especifico para la recoleccion IIS

### 4.3 Pruebas de migracion

- Tests Pester especificos para la migracion v1 -> v2
- Validar con inventarios reales de v1 que se migran correctamente
- Verificar que la UI muestra los nuevos campos de IIS, servicios y Hyper-V

---

## Fase 5 - Tracking Historico y Auditorias

> Objetivo: Permitir comparativas entre inventarios en el tiempo.

### 5.1 Historico de inventarios

- Guardar snapshots anteriores antes de sobrescribir (actualmente cada `Update-ServerInventory` reemplaza el archivo)
- Estructura propuesta: `Data/Inventory/{ServerName}/` con archivos por fecha o un indice de versiones
- Nuevo cmdlet: `Get-ServerInventoryHistory -ServerName "SRV01" -Last 5`

### 5.2 Comparativa de cambios

- Funcion para comparar dos inventarios y mostrar diferencias (RAM anadida, disco cambiado, OS actualizado)
- Formato de salida tipo diff legible
- Util para auditorias y deteccion de cambios no autorizados

---

## Fase 6 - Almacenamiento Centralizado

> Objetivo: Escalar mas alla de archivos locales.

### 6.1 Exportacion a SQL

- Soporte para persistir inventarios en base de datos SQL Server o SQLite
- Permite consultas avanzadas, reportes cruzados y acceso multi-usuario
- Mantener compatibilidad con el sistema actual de archivos (no reemplazar, anadir)

### 6.2 Dashboard / Reportes

- Dashboard web como alternativa ligera a la UI WPF (HTML + JS estatico generado desde PowerShell)
- Reportes automaticos: servidores desactualizados, uso de disco, uptime excesivo

---

## Fase 7 - Alertas y Monitorizacion

> Objetivo: Pasar de inventario pasivo a monitorizacion activa.

### 7.1 Sistema de alertas

- Notificaciones cuando un servidor supera umbrales configurables:
  - Disco por debajo del X% libre
  - Uptime superior a N dias (indica que no se reinicia/parchea)
  - Inventario desactualizado (mas de N dias sin recopilar)
- Canales: email, log, o integracion con sistemas de tickets

### 7.2 Inventario incremental

- Recopilar solo lo que ha cambiado desde la ultima ejecucion
- Reduce tiempo de ejecucion y carga en servidores target
- Requiere almacenar un hash o timestamp por seccion del inventario

---

## Fase 8 - Extensibilidad y Multiplataforma

> Objetivo: Ampliar el alcance del proyecto mas alla de Windows.

### 8.1 Soporte Linux / SSH

- Recoleccion via SSH Remoting (requiere PowerShell 7+ o modulo SSH)
- Adaptadores para comandos equivalentes en Linux (`lscpu`, `free`, `df`, `ip addr`)
- Deteccion automatica del SO del target y seleccion del metodo de recoleccion

### 8.2 Sistema de credenciales robusto

- Migrar de `.cred.xml` por usuario a Secret Management Module (cross-platform)
- Soporte para Azure Key Vault o HashiCorp Vault en entornos enterprise

### 8.3 Publicacion en PowerShell Gallery

- Preparar el modulo para distribucion publica via `Install-Module InventarioServidores`
- Cumplir requisitos de la Gallery: licencia, tags, release notes

---

## Fase 9 - Separacion de Scripts

> Objetivo: Organizar scripts operativos mas alla de los ejemplos.

### 9.1 Scripts de recoleccion dedicados

- Carpeta `Scripts/Collection/` con scripts para escenarios especificos (inventario programado, por grupo de servidores, etc.)

### 9.2 Scripts de mantenimiento

- Carpeta `Scripts/Maintenance/` con scripts de limpieza, archivado de logs, verificacion de integridad de datos

---

## Resumen Visual

```
Fase 3  ──►  Fase 4  ──►  Fase 5  ──►  Fase 6  ──►  Fase 7  ──►  Fase 8
Tests        Schema v2    Historico    SQL/Web      Alertas      Linux
Logs         IIS          Auditorias   Dashboard    Incremental  Gallery
Pulido       Servicios    Diff                      Umbrales     Vault
             Hyper-V
```

> Cada fase puede iniciarse de forma independiente, pero se recomienda el orden secuencial para maximizar la estabilidad del proyecto.
