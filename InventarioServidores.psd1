# InventarioServidores.psd1
# Manifest del Módulo

@{
    # Metadata del módulo
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'  # Genera uno nuevo con [guid]::NewGuid()
    Author = 'Tu Nombre'
    CompanyName = 'Tu Empresa'
    Copyright = '(c) 2026. Todos los derechos reservados.'
    Description = 'Sistema de inventario automatizado para servidores Windows con soporte para recopilación remota, versionado de schema y exportación a múltiples formatos.'
    
    # Requisitos
    PowerShellVersion = '5.1'
    
    # Módulo root
    RootModule = 'InventarioServidores.psm1'
    
    ScriptsToProcess = @(
        'Source/Classes/CollectionStatus.ps1'
        'Source/Classes/OSInfo.ps1'
        'Source/Classes/HardwareInfo.ps1'
        'Source/Classes/NetworkInfo.ps1'
        'Source/Classes/IISInfo.ps1'
        'Source/Classes/ServerInventory.ps1'
    )
    
    # Funciones a exportar
    FunctionsToExport = @(
        'Get-ServerInventory'
        'Get-AllServerInventories'
        'Update-ServerInventory'
        'Import-ServerInventory'
        'Export-ServerInventory'
        'Invoke-BulkInventoryCollection'
    )
    
    # Cmdlets a exportar (ninguno, solo funciones)
    CmdletsToExport = @()
    
    # Variables a exportar (ninguna)
    VariablesToExport = @()
    
    # Aliases a exportar (ninguno por ahora)
    AliasesToExport = @()
    
    # Archivos privados
    PrivateData = @{
        PSData = @{
            Tags = @('Inventory', 'Server', 'Monitoring', 'Infrastructure', 'DevOps', 'SRE')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v1.0.0 - Release Inicial
- Schema v1 con soporte para OS, Hardware, Network
- Recopilación remota vía PowerShell Remoting
- Sistema de logging thread-safe
- Exportación a XML (Export-Clixml) y JSON
- Migración automática de schemas
- Inventario masivo con control de concurrencia
'@
        }
    }
}
