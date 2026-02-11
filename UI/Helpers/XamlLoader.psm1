# XamlLoader.ps1
# Utilidad para cargar archivos XAML en PowerShell

# Cargar ensamblados WPF al nivel del módulo
Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
Add-Type -AssemblyName PresentationCore -ErrorAction Stop
Add-Type -AssemblyName WindowsBase -ErrorAction Stop

function Load-XamlWindow {
    <#
    .SYNOPSIS
        Carga un archivo XAML y devuelve la ventana WPF
    
    .PARAMETER XamlPath
        Ruta al archivo XAML
    
    .EXAMPLE
        $window = Load-XamlWindow -XamlPath ".\UI\Views\MainWindow.xaml"
    #>
    [CmdletBinding()]
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$XamlPath
    )
    
    try {
        # Leer XAML
        [xml]$xaml = Get-Content -Path $XamlPath -Encoding UTF8
        
        # Crear XmlNodeReader
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        
        # Cargar XAML
        $window = [Windows.Markup.XamlReader]::Load($reader)
        
        if ($null -eq $window) {
            throw "No se pudo cargar la ventana desde el XAML"
        }
        
        Write-Verbose "Ventana XAML cargada correctamente desde: $XamlPath"
        
        return $window
    }
    catch {
        Write-Error "Error al cargar XAML desde '$XamlPath': $_"
        throw
    }
}

function Get-XamlControl {
    <#
    .SYNOPSIS
        Obtiene un control específico de una ventana XAML por su nombre
    
    .PARAMETER Window
        Ventana WPF
    
    .PARAMETER ControlName
        Nombre del control (atributo Name en XAML)
    
    .EXAMPLE
        $btnRefresh = Get-XamlControl -Window $window -ControlName "btnRefresh"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Window,
        
        [Parameter(Mandatory)]
        [string]$ControlName
    )
    
    try {
        $control = $Window.FindName($ControlName)
        
        if ($null -eq $control) {
            Write-Warning "No se encontró el control '$ControlName' en la ventana"
            return $null
        }
        
        Write-Verbose "Control '$ControlName' obtenido correctamente"
        return $control
    }
    catch {
        Write-Error "Error al obtener control '$ControlName': $_"
        return $null
    }
}

function Get-AllXamlControls {
    <#
    .SYNOPSIS
        Obtiene todos los controles con nombre de una ventana XAML
    
    .PARAMETER Window
        Ventana WPF
    
    .PARAMETER ControlNames
        Array de nombres de controles
    
    .EXAMPLE
        $controls = Get-AllXamlControls -Window $window -ControlNames @("btnRefresh", "dgServers", "txtStatus")
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Window,
        
        [Parameter(Mandatory)]
        [string[]]$ControlNames
    )
    
    $controls = @{}
    
    foreach ($name in $ControlNames) {
        $control = Get-XamlControl -Window $Window -ControlName $name
        if ($null -ne $control) {
            $controls[$name] = $control
        }
    }
    
    Write-Verbose "Obtenidos $($controls.Count) controles de $($ControlNames.Count) solicitados"
    
    return $controls
}

# Exportar funciones
Export-ModuleMember -Function Load-XamlWindow, Get-XamlControl, Get-AllXamlControls
