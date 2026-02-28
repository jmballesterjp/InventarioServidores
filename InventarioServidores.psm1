# InventarioServidores.psm1
# Módulo principal de Inventario de Servidores

#Requires -Version 5.1

# === Variables del Módulo ===
$script:ModuleRoot = $PSScriptRoot
$script:DataPath = Join-Path $ModuleRoot "Data"
$script:LogPath = Join-Path $ModuleRoot "Logs"
$script:TempPath = Join-Path $ModuleRoot "Temp"
$script:ConfigPath = Join-Path $ModuleRoot "Config"

# === Clases ===
# Las clases se cargan vía ScriptsToProcess en el .psd1, en el scope global del llamante.
# NO se redefinen aquí: redefinirlas con Invoke-Expression crea un segundo tipo con distinto
# contexto (.NET TypeHandle), causando el error "cannot convert ServerInventory to ServerInventory"
# cuando el UI crea instancias directamente con [ServerInventory]::new() y las pasa a funciones
# del módulo que esperan el tipo definido aquí.

# === Cargar Funciones Private ===
$privateFunctions = Get-ChildItem -Path (Join-Path $ModuleRoot "Source\Private\*.ps1") -ErrorAction SilentlyContinue

foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Función Private cargada: $($function.Name)"
    }
    catch {
        Write-Warning "Error al cargar función Private '$($function.Name)': $_"
    }
}

# === Cargar Funciones Public ===
$publicFunctions = Get-ChildItem -Path (Join-Path $ModuleRoot "Source\Public\*.ps1") -ErrorAction SilentlyContinue

foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Función Public cargada: $($function.Name)"
    }
    catch {
        Write-Warning "Error al cargar función Public '$($function.Name)': $_"
    }
}

# === Inicializar Módulo ===
Initialize-InventoryModule

# === Exportar Funciones Public ===
$functionsToExport = $publicFunctions | ForEach-Object { $_.BaseName }
Export-ModuleMember -Function $functionsToExport

# === Mensaje de Bienvenida ===
Write-Verbose "Módulo InventarioServidores cargado correctamente"
Write-Verbose "Funciones disponibles: $($functionsToExport -join ', ')"
