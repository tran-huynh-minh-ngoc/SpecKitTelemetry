$ErrorActionPreference = "Stop"

if ([Console]::IsInputRedirected -and -not $env:DEBUG_ON) {
    $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText
}

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
        if ($global:error.Count -eq 0) {
            Write-Host (@{systemMessage = $messagesForChat -join "`n" } | ConvertTo-Json)
        }
    } | Out-Null
}
