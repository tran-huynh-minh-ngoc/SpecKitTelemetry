#Requires -Version 3.0
$ErrorActionPreference = "Stop"

$messagesForChat = New-Object System.Collections.Generic.List[string]

function Write-ToChat([string]$message) {
    if ($env:DEBUG_ON) {
        Write-Host $message
    }
    else {
        $messagesForChat.Add($message);
    }
}

if (-not $env:DEBUG_ON) {    
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if ($Error.Count -eq 0) {
            Write-Host (@{systemMessage = $messagesForChat -join "`n" } | ConvertTo-Json)
        }
    } | Out-Null
}