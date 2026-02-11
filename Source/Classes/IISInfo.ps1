# IISInfo.ps1
# Información de IIS (Schema v2+)

class IISInfo {
    [string]$Version
    [bool]$IsInstalled
    [IISSite[]]$Sites
    [IISAppPool[]]$AppPools
    [string]$InstallPath
    
    IISInfo() {}
    
    [string] ToString() {
        return "IIS $($this.Version) - $($this.Sites.Count) sitios, $($this.AppPools.Count) app pools"
    }
}

class IISSite {
    [string]$Name
    [int]$ID
    [string]$State
    [string]$PhysicalPath
    [IISBinding[]]$Bindings
    [string]$ApplicationPool
    [hashtable]$Authentication
    
    IISSite() {}
    
    [string] GetBindingsFormatted() {
        return ($this.Bindings | ForEach-Object { $_.ToString() }) -join ', '
    }
    
    [string] ToString() {
        return "$($this.Name) [$($this.State)]"
    }
}

class IISBinding {
    [string]$Protocol
    [string]$BindingInformation
    [string]$HostName
    [int]$Port
    [string]$IPAddress
    [string]$CertificateHash
    [string]$CertificateStoreName
    
    IISBinding() {}
    
    [string] ToString() {
        if ($this.HostName) {
            return "$($this.Protocol)://$($this.HostName):$($this.Port)"
        }
        return "$($this.Protocol)://$($this.IPAddress):$($this.Port)"
    }
}

class IISAppPool {
    [string]$Name
    [string]$State
    [string]$ManagedRuntimeVersion
    [string]$ManagedPipelineMode
    [string]$IdentityType
    [bool]$Enable32BitAppOnWin64
    [int]$QueueLength
    [string]$StartMode
    
    IISAppPool() {}
    
    [string] ToString() {
        return "$($this.Name) [$($this.State)] - $($this.ManagedRuntimeVersion)"
    }
}
