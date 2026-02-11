# Get-RemoteServerInventory.ps1
# Recopila información de un servidor remoto vía PowerShell Remoting

function Get-RemoteServerInventory {
    <#
    .SYNOPSIS
        Recopila inventario de un servidor remoto
    
    .DESCRIPTION
        Usa PowerShell Remoting (Invoke-Command) para recopilar información completa
        de hardware, sistema operativo y red de un servidor Windows remoto
    
    .PARAMETER ServerName
        Nombre o IP del servidor a inventariar
    
    .PARAMETER Credential
        Credencial para conectar (opcional si estás en dominio)
    
    .EXAMPLE
        Get-RemoteServerInventory -ServerName "SRV01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,
        
        [Parameter()]
        [PSCredential]$Credential
    )
    
    Write-InventoryLog -Message "Iniciando recopilación remota" -ServerName $ServerName -Level Info
    
    $inventory = [ServerInventory]::new($ServerName)
    
    try {
        # Parámetros para Invoke-Command
        $invokeParams = @{
            ComputerName = $ServerName
            ErrorAction = 'Stop'
        }
        
        if ($Credential) {
            $invokeParams.Credential = $Credential
        }
        
        # Recopilar datos remotamente
        $remoteData = Invoke-Command @invokeParams -ScriptBlock {
            $data = @{}
            
            # === Sistema Operativo ===
            try {
                $os = Get-CimInstance -ClassName Win32_OperatingSystem
                $cs = Get-CimInstance -ClassName Win32_ComputerSystem
                
                $data.OS = @{
                    Name = $os.Caption
                    Version = $os.Version
                    Build = $os.BuildNumber
                    Architecture = $os.OSArchitecture
                    InstallDate = $os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss')
                    LastBootTime = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
                    UptimeDays = [Math]::Round((New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)).TotalDays, 2)
                    SerialNumber = $os.SerialNumber
                    RegisteredUser = $os.RegisteredUser
                    Organization = $cs.Domain
                }
            }
            catch {
                $data.OSError = $_.Exception.Message
            }
            
            # === Hardware ===
            try {
                $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
                $ram = Get-CimInstance -ClassName Win32_PhysicalMemory
                $csProduct = Get-CimInstance -ClassName Win32_ComputerSystemProduct
                
                $data.Hardware = @{
                    Manufacturer = $cs.Manufacturer
                    Model = $cs.Model
                    SerialNumber = $csProduct.IdentifyingNumber
                    CPUName = $cpu.Name
                    CPUCores = $cpu.NumberOfCores
                    CPULogicalProcessors = $cpu.NumberOfLogicalProcessors
                    CPUMaxClockSpeed = $cpu.MaxClockSpeed
                    RAMBytes = ($ram | Measure-Object -Property Capacity -Sum).Sum
                    RAMSlots = ($cs.NumberOfProcessors * 4)  # Aproximación
                    RAMSlotsUsed = $ram.Count
                }
            }
            catch {
                $data.HardwareError = $_.Exception.Message
            }
            
            # === Discos ===
            try {
                $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
                $data.Disks = @($disks | ForEach-Object {
                    @{
                        DeviceID = $_.DeviceID
                        VolumeName = $_.VolumeName
                        FileSystem = $_.FileSystem
                        SizeBytes = $_.Size
                        FreeBytes = $_.FreeSpace
                        PercentFree = if($_.Size -gt 0) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 }
                        DriveType = 'Local Disk'
                    }
                })
            }
            catch {
                $data.DisksError = $_.Exception.Message
            }
            
            # === Red ===
            try {
                $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
                $data.Network = @($adapters | ForEach-Object {
                    $adapter = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "Index=$($_.Index)"
                    @{
                        AdapterName = $adapter.NetConnectionID
                        Description = $_.Description
                        MACAddress = $_.MACAddress
                        IPAddress = $_.IPAddress
                        SubnetMask = $_.IPSubnet
                        DefaultGateway = $_.DefaultIPGateway
                        DNSServers = $_.DNSServerSearchOrder
                        DHCPEnabled = $_.DHCPEnabled
                        DHCPServer = $_.DHCPServer
                        Status = $adapter.NetConnectionStatus
                        Speed = $adapter.Speed
                    }
                })
            }
            catch {
                $data.NetworkError = $_.Exception.Message
            }
            
            # === Información General ===
            $data.FQDN = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName
            $data.CollectedAt = Get-Date
            
            return $data
        }
        
        # Mapear datos remotos a objetos locales
        
        # FQDN e IP
        $inventory.FQDN = $remoteData.FQDN
        if ($remoteData.Network -and $remoteData.Network.Count -gt 0) {
            $inventory.IPAddress = $remoteData.Network[0].IPAddress
        }
        
        # OS
        if ($remoteData.OS) {
            $inventory.OS = [OSInfo]::new()
            $remoteData.OS.GetEnumerator() | ForEach-Object {
                $inventory.OS.$($_.Key) = $_.Value
            }
            Write-InventoryLog -Message "OS recopilado: $($inventory.OS.Name)" -ServerName $ServerName -Level Verbose
        }
        else {
            $inventory.Status.AddError("No se pudo recopilar información del OS: $($remoteData.OSError)")
        }
        
        # Hardware
        if ($remoteData.Hardware) {
            $inventory.Hardware = [HardwareInfo]::new()
            $remoteData.Hardware.GetEnumerator() | ForEach-Object {
                $inventory.Hardware.$($_.Key) = $_.Value
            }
            
            # Discos
            if ($remoteData.Disks) {
                $inventory.Hardware.Disks = @($remoteData.Disks | ForEach-Object {
                    $disk = [DiskInfo]::new()
                    $_.GetEnumerator() | ForEach-Object {
                        $disk.$($_.Key) = $_.Value
                    }
                    $disk
                })
            }
            
            Write-InventoryLog -Message "Hardware recopilado: $($inventory.Hardware.Manufacturer) $($inventory.Hardware.Model)" -ServerName $ServerName -Level Verbose
        }
        else {
            $inventory.Status.AddError("No se pudo recopilar información de hardware: $($remoteData.HardwareError)")
        }
        
        # Red
        if ($remoteData.Network) {
            $inventory.Network = @($remoteData.Network | ForEach-Object {
                $net = [NetworkInfo]::new()
                $_.GetEnumerator() | ForEach-Object {
                    $net.$($_.Key) = $_.Value
                }
                $net
            })
            Write-InventoryLog -Message "Red recopilada: $($inventory.Network.Count) adaptadores" -ServerName $ServerName -Level Verbose
        }
        else {
            $inventory.Status.AddWarning("No se pudo recopilar información de red: $($remoteData.NetworkError)")
        }
        
        # Determinar estado final
        if ($inventory.Status.Errors.Count -eq 0) {
            $inventory.Status.SetSuccess("Inventario recopilado exitosamente")
            Write-InventoryLog -Message "Recopilación completada exitosamente" -ServerName $ServerName -Level Info
        }
        elseif ($inventory.Status.Errors.Count -lt 3) {
            $inventory.Status.SetPartial("Inventario parcialmente recopilado con algunos errores")
            Write-InventoryLog -Message "Recopilación parcial: $($inventory.Status.Errors.Count) errores" -ServerName $ServerName -Level Warning
        }
        else {
            $inventory.Status.SetFailed("No se pudo recopilar la mayoría de la información")
            Write-InventoryLog -Message "Recopilación fallida" -ServerName $ServerName -Level Error -ErrorLog
        }
        
        $inventory.LastInventory = Get-Date
        
        return $inventory
    }
    catch {
        $inventory.Status.SetFailed("Error crítico: $($_.Exception.Message)")
        $inventory.Status.AddError($_.Exception.Message)
        Write-InventoryLog -Message "Error crítico en recopilación: $_" -ServerName $ServerName -Level Error -ErrorLog
        
        return $inventory
    }
}
