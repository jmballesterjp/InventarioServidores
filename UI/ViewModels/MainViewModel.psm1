# MainViewModel.ps1
# ViewModel para la ventana principal

# Clase para representar un servidor en el DataGrid
class ServerViewModel {
    [string]$ServerName
    [string]$IPAddressFormatted
    [string]$OSName
    [string]$RAMFormatted
    [int]$UptimeDays
    [string]$LastInventoryFormatted
    [string]$StatusText
    [string]$StatusColor
    
    # Referencia al inventario completo
    hidden [object]$_inventory
    hidden [int]$_staleThresholdDays

    ServerViewModel([object]$inventory, [int]$staleThresholdDays) {
        $this._inventory = $inventory
        $this._staleThresholdDays = $staleThresholdDays
        $this.UpdateFromInventory($inventory)
    }
    
    [void] UpdateFromInventory([object]$inventory) {
        $this.ServerName = $inventory.ServerName
        
        # IP Address
        if ($inventory.IPAddress -and $inventory.IPAddress.Count -gt 0) {
            $this.IPAddressFormatted = $inventory.IPAddress[0]
        }
        else {
            $this.IPAddressFormatted = "N/A"
        }
        
        # OS
        if ($inventory.OS) {
            $this.OSName = $inventory.OS.Name
            $this.UptimeDays = $inventory.OS.UptimeDays
        }
        else {
            $this.OSName = "Desconocido"
            $this.UptimeDays = 0
        }
        
        # Hardware
        if ($inventory.Hardware) {
            $this.RAMFormatted = $inventory.Hardware.GetRAMFormatted()
        }
        else {
            $this.RAMFormatted = "N/A"
        }
        
        # Última actualización
        $this.LastInventoryFormatted = $inventory.LastInventory.ToString('yyyy-MM-dd HH:mm')
        
        # Estado (Stale sobreescribe el estado si el inventario está anticuado)
        # Si StaleThresholdDays = 0, la detección de Stale está desactivada
        $statusResult = $inventory.Status.Result.ToString()
        if ($this._staleThresholdDays -gt 0 -and $statusResult -ne 'NotStarted' -and $inventory.IsStale($this._staleThresholdDays)) {
            $this.StatusText  = 'Stale'
            $this.StatusColor = '#FFC107'
        }
        else {
            $this.StatusText  = $statusResult
            $this.StatusColor = $inventory.Status.GetColorForUI()
        }
    }
    
    [object] GetInventory() {
        return $this._inventory
    }
}

# Función para crear el ViewModel principal
function New-MainViewModel {
    <#
    .SYNOPSIS
        Crea el ViewModel principal de la aplicación
    
    .DESCRIPTION
        Inicializa una ObservableCollection con los servidores del inventario
    
    .EXAMPLE
        $viewModel = New-MainViewModel
    #>
    [CmdletBinding()]
    param()
    
    # Crear ObservableCollection vacía
    $serversCollection = New-Object System.Collections.ObjectModel.ObservableCollection[ServerViewModel]
    
    # Devolver hashtable con propiedades del ViewModel
    return @{
        Servers = $serversCollection
        SelectedServer = $null
        IsLoading = $false
        StatusMessage = "Listo"
    }
}

function Update-ServersInViewModel {
    <#
    .SYNOPSIS
        Actualiza la colección de servidores en el ViewModel
    
    .PARAMETER ViewModel
        ViewModel que contiene la colección
    
    .PARAMETER Inventories
        Array de inventarios (objetos ServerInventory)
    
    .EXAMPLE
        Update-ServersInViewModel -ViewModel $viewModel -Inventories $inventories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ViewModel,

        [Parameter(Mandatory)]
        [array]$Inventories,

        [int]$StaleThresholdDays = 7
    )

    # Limpiar colección actual
    $ViewModel.Servers.Clear()

    # Añadir cada inventario como ServerViewModel
    foreach ($inventory in $Inventories) {
        $serverVM = [ServerViewModel]::new($inventory, $StaleThresholdDays)
        $ViewModel.Servers.Add($serverVM)
    }
    
    Write-Verbose "ViewModel actualizado con $($Inventories.Count) servidores"
}

# Exportar funciones
Export-ModuleMember -Function New-MainViewModel, Update-ServersInViewModel
