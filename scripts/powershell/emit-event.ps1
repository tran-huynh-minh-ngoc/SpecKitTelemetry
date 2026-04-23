param(
    [string]$phaseId,
    [string]$projectId,
    [string]$specKitPhase,
    [string]$event
)

$tempDir = [System.IO.Path]::GetTempPath()
$stateFileName = "$phaseId.$projectId.$specKitPhase.json"
$stateFilePath = Join-Path $tempDir $stateFileName

$currentTimestamp = (Get-Date).ToUniversalTime()

if ($event -eq "started") {
    $eventData = @{
        phaseId = $phaseId
        projectId = $projectId
        specKitPhase = $specKitPhase
        event = "started"
        timestamp = $currentTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ")
        metrics = @{
            numberOfAiToolCall = 0
            numberOfHumanInteraction = 0
        }
    }

    $json = $eventData | ConvertTo-Json -Compress
    $json | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    $yearMonth = $currentTimestamp.ToString("yyyy-MM")
    $reportDir = Join-Path $pwd $yearMonth
    if (-not (Test-Path -Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir | Out-Null
    }
    $reportFilePath = Join-Path $reportDir "report.jsonl"

    Add-Content -Path $reportFilePath -Value $json -Encoding UTF8
}
elseif ($event -eq "completed") {
    try {
        $json = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        exit
    }

    $startTime = $json.timestamp
    $duration = [int](($currentTimestamp - $startTime).TotalMilliseconds)

    $json.event = "completed"
    $json.timestamp = $currentTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $json.metrics | Add-Member -NotePropertyName "duration" -NotePropertyValue $duration

    $minifiedJson = $json | ConvertTo-Json -Compress

    $yearMonth = $currentTimestamp.ToString("yyyy-MM")
    $reportDir = Join-Path $pwd $yearMonth
    if (-not (Test-Path -Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir | Out-Null
    }
    $reportFilePath = Join-Path $reportDir "report.jsonl"

    Add-Content -Path $reportFilePath -Value $minifiedJson -Encoding UTF8
    Remove-Item -Path $stateFilePath -Force
}
