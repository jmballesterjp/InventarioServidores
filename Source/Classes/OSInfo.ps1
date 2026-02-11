# OSInfo.ps1
# Información del Sistema Operativo

class OSInfo {
    [string]$Name
    [string]$Version
    [string]$Build
    [string]$Architecture
    [string]$InstallDate
    [string]$LastBootTime
    [int]$UptimeDays
    [string]$SerialNumber
    [string]$RegisteredUser
    [string]$Organization
    
    OSInfo() {}
    
    [string] ToString() {
        return "$($this.Name) $($this.Version) (Build $($this.Build))"
    }
    
    [string] GetUptimeFormatted() {
        if ($this.UptimeDays -eq 0) {
            return "Menos de 1 día"
        }
        elseif ($this.UptimeDays -eq 1) {
            return "1 día"
        }
        else {
            return "$($this.UptimeDays) días"
        }
    }
}
