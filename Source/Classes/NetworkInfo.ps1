# NetworkInfo.ps1
# Información de Red

class NetworkInfo {
    [string]$AdapterName
    [string]$Description
    [string]$MACAddress
    [string[]]$IPAddress
    [string[]]$SubnetMask
    [string[]]$DefaultGateway
    [string[]]$DNSServers
    [bool]$DHCPEnabled
    [string]$DHCPServer
    [string]$Status
    [long]$Speed
    
    NetworkInfo() {}
    
    [string] GetSpeedFormatted() {
        if ($this.Speed -eq 0) {
            return "N/A"
        }
        $mbps = $this.Speed / 1MB
        if ($mbps -ge 1000) {
            return "$($mbps / 1000) Gbps"
        }
        return "$mbps Mbps"
    }
    
    [string] ToString() {
        return "$($this.AdapterName) - $($this.IPAddress -join ', ')"
    }
}
