#Requires -Version 6.0
param(
    [string]$event,
    [string]$phaseId,
    [string]$workItemId,
    [string]$specKitPhase
)
$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_Prepare.ps1"

$configPath = "$PSScriptRoot/../telemetry-config.yml"
$telemetryConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml
$tempDir = [System.IO.Path]::GetTempPath()
$stateFilePath = Join-Path $tempDir "SpecKitTelemetry.$sessionId.json"
$currentTimestamp = (Get-Date).ToUniversalTime()
$reportDir = $telemetryConfig.events_dir
$reportFilePath = Join-Path $reportDir ($currentTimestamp.ToString("yyyy-MM") + ".$sessionId.jsonl")

function Save-StateFile($json) {
    $json | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force
}

function Write-Event($eventData, $saveState = $true) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    $json = $eventData | ConvertTo-Json -Compress
    if ($saveState) {
        Save-StateFile $json
    }
    Add-Content -Path $reportFilePath -Value $json -Encoding UTF8
    Write-Output $json
}

function Remove-StateFile {
    Remove-Item -Path $stateFilePath -Force
}

# event from Claude hook or equivalent
if ($event -eq "submitted") {
    try {
        $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        $eventData = [ordered]@{
            event_id = ""
            event_type = ""
            span_id = [guid]::NewGuid().ToString()
            phase_id = ""
            phase = ""
            work_item_id = ""
            project_id = $telemetryConfig.project_id
            timestamp_utc = $currentTimestamp
            invocation_seq = 0
            invocation_kind = "initial"
            metrics = [ordered]@{
                ai_tool_use_count = 0
                artifact_change_count = 0
            }
        }
    }
    if ($eventData.phase -ne "") {
        $eventData.event_id = [guid]::NewGuid().ToString()
        $eventData.span_id = [guid]::NewGuid().ToString()
        $eventData.event_type = "resumed"
        $eventData.invocation_seq++
        $eventData.invocation_kind = "refinement"
        $eventData.timestamp_utc = $currentTimestamp
        $eventData.metrics.ai_tool_use_count = 0
        $eventData.metrics.artifact_change_count = 0
        Write-Event $eventData
    }
    else {
        $json = $eventData | ConvertTo-Json -Compress
        Save-StateFile $json
    }
}
# event from Claude hook or equivalent
elseif ($event -eq "stopped") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    if ($eventData.phase -ne "" -and $eventData.event_type -ne "completed") {
        $eventData.event_id = [guid]::NewGuid().ToString()
        $eventData.event_type = "suspended"
        $eventData.timestamp_utc = $currentTimestamp
        Write-Event $eventData
    }
    elseif ($eventData.phase -ne "" -and $eventData.event_type -eq "completed") {
        $eventData.event_id = [guid]::NewGuid().ToString()
        $eventData.timestamp_utc = $currentTimestamp
        Write-Event $eventData false
        Remove-StateFile
        & "$PSScriptRoot/UploadLog.ps1"
    }
    else {
        Remove-StateFile
    }
}
# spec-kit event
elseif ($event -eq "started") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    $eventData.event_id = [guid]::NewGuid().ToString()
    $eventData.phase_id = $phaseId
    $eventData.phase = $specKitPhase
    $eventData.work_item_id = $workItemId
    $eventData.event_type = "started"
    Write-Event $eventData
}
# spec-kit event
elseif ($event -eq "completed") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    $eventData.event_type = "completed"
    $json = $eventData | ConvertTo-Json -Compress
    Save-StateFile $json
}
# event from Claude hook or equivalent
elseif ($event -eq "ai_tool_called") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    $eventData.metrics.ai_tool_use_count++
    $json = $eventData | ConvertTo-Json -Compress
    Save-StateFile $json
}
# event from Claude hook or equivalent
elseif ($event -eq "artifact_changed") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    $eventData.metrics.artifact_change_count++
    $json = $eventData | ConvertTo-Json -Compress
    Save-StateFile $json
}
# event from Claude hook or equivalent
elseif ($event -eq "error_occured") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    if ($eventData.phase -eq "") {        
        Write-Event $eventData false
    }
    $eventData.event_id = [guid]::NewGuid().ToString()
    $eventData.event_type = "error_occured"
    $eventData.timestamp_utc = $currentTimestamp
    Write-Event $eventData false
    Remove-StateFile    
    & "$PSScriptRoot/UploadLog.ps1"
}
