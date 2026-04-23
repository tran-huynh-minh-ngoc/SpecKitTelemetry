param(
    [string]$phaseId,
    [string]$workItemId,
    [string]$specKitPhase,
    [string]$event
)
$ErrorActionPreference = "Stop"

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser
}

$configPath = if ((Get-Location).Path.EndsWith(".specify\extensions\telemetry\scripts")) {
    ".specify/extensions/telemetry/scripts/telemetry-config.yml"
} else {
    "../telemetry-config.yml"
}
$telemetryConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml

$tempDir = [System.IO.Path]::GetTempPath()
$stateFilePath = Join-Path $tempDir "$phaseId.$specKitPhase.json"
$currentTimestamp = (Get-Date).ToUniversalTime()
$reportDir = Join-Path $telemetryConfig.events_dir $currentTimestamp.ToString("yyyy-MM")
$reportFilePath = Join-Path $reportDir "report.jsonl"

function SaveStateFile($json) {
    $json | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force
}

function ReportEvent($eventData, $saveState = $true) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    $json = $eventData | ConvertTo-Json -Compress
    if ($saveState) {
        SaveStateFile $json
    }
    Add-Content -Path $reportFilePath -Value $json -Encoding UTF8
    Write-Output $json
}

function DeleteStateFile {
    Remove-Item -Path $stateFilePath -Force
}

if ($event -eq "started") {
    $eventData = @{
        event_id = [guid]::NewGuid().ToString()
        phase_id = $phaseId
        work_item_id = $workItemId
        project_id = $telemetryConfig.project_id
        phase = $specKitPhase
        event_type = "started"
        timestamp_utc = $currentTimestamp
        invocation_seq = 1
        invocation_kind = "initial"
        signals = @{
            duration_ms = 0
            ai_tool_use_count = 0
            user_turn_count = 0
            artifact_change_count = 0
            active_time_ms = 0
            idle_threshold_ms_at_capture = 300000
        }
    }
    ReportEvent $eventData
} elseif ($event -eq "suspended") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json
    $eventData.event_id = [guid]::NewGuid().ToString()
    $eventData.event_type = "suspended"
    $eventData.signals.duration_ms = [int](($currentTimestamp - $eventData.timestamp_utc).TotalMilliseconds)
    $eventData.timestamp_utc = $currentTimestamp
    ReportEvent $eventData
} elseif ($event -eq "resumed") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json
    $eventData.event_id = [guid]::NewGuid().ToString()
    $eventData.invocation_seq++
    $eventData.signals.user_turn_count++
    $eventData.invocation_kind = "refinement"
    $eventData.event_type = "resumed"
    $eventData.timestamp_utc = $currentTimestamp
    ReportEvent $eventData
} elseif ($event -eq "ai_tool_called") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json
    $eventData.signals.ai_tool_use_count++
    $json = $eventData | ConvertTo-Json -Compress
    SaveStateFile $json
} elseif ($event -eq "artifact_changed") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json
    $eventData.signals.artifact_change_count++
    $json = $eventData | ConvertTo-Json -Compress
    SaveStateFile $json
} elseif ($event -eq "completed") {
    $eventData = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json
    $eventData.event_id = [guid]::NewGuid().ToString()
    $eventData.event_type = "completed"
    $eventData.signals.duration_ms = [int](($currentTimestamp - $eventData.timestamp_utc).TotalMilliseconds)
    $eventData.timestamp_utc = $currentTimestamp
    ReportEvent $eventData false
    DeleteStateFile
}
