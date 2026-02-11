# Initialize-InventoryModule.ps1
# Inicializa el módulo y crea estructura de directorios

function Initialize-InventoryModule {
    <#
    .SYNOPSIS
        Inicializa el módulo creando directorios necesarios
    
    .DESCRIPTION
        Crea la estructura de directorios si no existe:
        - Data/Inventory
        - Data/Templates
        - Logs/Collection
        - Logs/Errors
        - Temp
        - Config/Credentials
    #>
    [CmdletBinding()]
    param()
    
    $directories = @(
        (Join-Path $script:DataPath 'Inventory')
        (Join-Path $script:DataPath 'Templates')
        (Join-Path $script:LogPath 'Collection')
        (Join-Path $script:LogPath 'Errors')
        $script:TempPath
        (Join-Path $script:ConfigPath 'Credentials')
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                [void](New-Item -Path $dir -ItemType Directory -Force)
                Write-Verbose "Directorio creado: $dir"
            }
            catch {
                Write-Warning "No se pudo crear directorio $dir`: $_"
            }
        }
    }
    
    # Crear archivo de configuración por defecto si no existe
    $settingsFile = Join-Path $script:ConfigPath 'Settings.psd1'
    if (-not (Test-Path $settingsFile)) {
        $defaultSettings = @"
@{
    # Configuración del módulo InventarioServidores
    
    # Rutas
    DataPath = 'Data'
    LogPath = 'Logs'
    TempPath = 'Temp'
    
    # Logging
    LogLevel = 'Info'  # Debug, Verbose, Info, Warning, Error
    LogRetentionDays = 30
    
    # Colección
    DefaultThrottleLimit = 10
    CommandTimeout = 300  # segundos
    
    # Exports
    AlsoExportJSON = `$true
    CompressOldInventories = `$false
}
"@
        try {
            Set-Content -Path $settingsFile -Value $defaultSettings -Force
            Write-Verbose "Archivo de configuración creado: $settingsFile"
        }
        catch {
            Write-Warning "No se pudo crear archivo de configuración: $_"
        }
    }
    
    Write-Verbose "Módulo inicializado correctamente"
}
