$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_Common.ps1"

$session_id = ([Console]::In.ReadToEnd() | ConvertFrom-Json).session_id

if ($env:CLAUDE_ENV_FILE) {
    Add-Content -Path $env:CLAUDE_ENV_FILE -Value "export SESSION_ID=$session_id"
}

Write-ToChat "Session Id was stored into the env SESSION_ID."