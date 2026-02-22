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
    StaleThresholdDays = 7  # Días sin actualizar para considerar un inventario como anticuado (Stale)
    
    # Exports
    AlsoExportJSON = $true
    CompressOldInventories = $false
}
