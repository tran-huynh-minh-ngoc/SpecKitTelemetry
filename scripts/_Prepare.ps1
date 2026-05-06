$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_Common.ps1"

$sessionId = $env:SESSION_ID
if ([string]::IsNullOrEmpty($sessionId) -and [Console]::IsInputRedirected) {
    $sessionId = ([Console]::In.ReadToEnd() | ConvertFrom-Json).session_id
}
if ([string]::IsNullOrEmpty($sessionId)) {
    Write-ToChat "SESSION_ID environment variable is not set or empty"
    exit 0
}
$env:SESSION_ID = $sessionId

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser
}