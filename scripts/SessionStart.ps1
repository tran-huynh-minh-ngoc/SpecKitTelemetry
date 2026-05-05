#Requires -Version 3.0
$ErrorActionPreference = "Stop"
$session_id = ([Console]::In.ReadToEnd() | ConvertFrom-Json).session_id

if ($env:CLAUDE_ENV_FILE) {
    Add-Content -Path $env:CLAUDE_ENV_FILE -Value "export SESSION_ID=$session_id"
}

exit 0
