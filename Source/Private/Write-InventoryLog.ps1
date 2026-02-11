# Write-InventoryLog.ps1
# Sistema de logging thread-safe para el módulo

function Write-InventoryLog {
    <#
    .SYNOPSIS
        Escribe mensajes de log para el sistema de inventario
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]$Level = 'Info',
        
        [Parameter()]
        [string]$ServerName,
        
        [Parameter()]
        [switch]$ErrorLog
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$Level]"
        
        if ($ServerName) {
            $logEntry += " [$ServerName]"
        }
        
        $logEntry += " $Message`n"
        
        # Master log (thread-safe con System.IO.File)
        $masterLog = Join-Path $script:LogPath "Master.log"
        $masterDir = Split-Path $masterLog -Parent
        
        if (-not (Test-Path $masterDir)) {
            [void][System.IO.Directory]::CreateDirectory($masterDir)
        }
        
        [System.IO.File]::AppendAllText($masterLog, $logEntry, [System.Text.Encoding]::UTF8)
        
        # Server-specific log
        if ($ServerName) {
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $serverLogDir = Join-Path $script:LogPath "Collection"
            $serverLog = Join-Path $serverLogDir "$ServerName`_$dateStamp.log"
            
            if (-not (Test-Path $serverLogDir)) {
                [void][System.IO.Directory]::CreateDirectory($serverLogDir)
            }
            
            [System.IO.File]::AppendAllText($serverLog, $logEntry, [System.Text.Encoding]::UTF8)
        }
        
        # Error log separado
        if ($ErrorLog -and $ServerName) {
            $errorLogDir = Join-Path $script:LogPath "Errors"
            $errorLog = Join-Path $errorLogDir "$ServerName`_$dateStamp.log"
            
            if (-not (Test-Path $errorLogDir)) {
                [void][System.IO.Directory]::CreateDirectory($errorLogDir)
            }
            
            [System.IO.File]::AppendAllText($errorLog, $logEntry, [System.Text.Encoding]::UTF8)
        }
        
        # También escribir a verbose stream si está habilitado
        if ($Level -eq 'Verbose') {
            Write-Verbose $Message
        }
        elseif ($Level -eq 'Warning') {
            Write-Warning $Message
        }
        elseif ($Level -eq 'Error') {
            Write-Error $Message -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning "Error al escribir log: $_"
    }
}
