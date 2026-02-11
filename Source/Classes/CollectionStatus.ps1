# CollectionStatus.ps1
# Estado de la recopilación de inventario

enum CollectionResult {
    Success
    Partial
    Failed
    NotStarted
}

class CollectionStatus {
    [CollectionResult]$Result
    [string]$Message
    [datetime]$Timestamp
    [hashtable]$Details
    [string[]]$Errors
    [string[]]$Warnings
    
    CollectionStatus() {
        $this.Result = [CollectionResult]::NotStarted
        $this.Timestamp = Get-Date
        $this.Details = @{}
        $this.Errors = @()
        $this.Warnings = @()
    }
    
    [void] SetSuccess([string]$message) {
        $this.Result = [CollectionResult]::Success
        $this.Message = $message
        $this.Timestamp = Get-Date
    }
    
    [void] SetPartial([string]$message) {
        $this.Result = [CollectionResult]::Partial
        $this.Message = $message
        $this.Timestamp = Get-Date
    }
    
    [void] SetFailed([string]$message) {
        $this.Result = [CollectionResult]::Failed
        $this.Message = $message
        $this.Timestamp = Get-Date
    }
    
    [void] AddError([string]$errorMessage) {
        $this.Errors += $errorMessage
    }
    
    [void] AddWarning([string]$warning) {
        $this.Warnings += $warning
    }
    
    [string] GetColorForUI() {
        switch ($this.Result) {
            'Success' { return '#4CAF50' }
            'Partial' { return '#FF9800' }
            'Failed'  { return '#F44336' }
            'NotStarted' { return '#9E9E9E' }
        }
        return '#9E9E9E'
    }
    
    [string] ToString() {
        return "$($this.Result): $($this.Message)"
    }
}
