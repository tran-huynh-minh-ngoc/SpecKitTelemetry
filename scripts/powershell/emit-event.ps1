param(
    [string]$phaseId,
    [string]$specKitPhase,
    [string]$event
)

$tempDir = [System.IO.Path]::GetTempPath()
$stateFileName = "$phaseId.$specKitPhase.json"
$stateFilePath = Join-Path $tempDir $stateFileName

$currentTimestamp = (Get-Date).ToUniversalTime()

if ($event -eq "started") {
    $eventData = @{
        phaseId = $phaseId
        specKitPhase = $specKitPhase
        event = "started"
        timestamp = $currentTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ")
        metrics = @{
            numberOfAiToolCall = 0
            numberOfHumanInteraction = 0
        }
    }

    $outputJson = $eventData | ConvertTo-Json -Compress
    $outputJson | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    $yearMonth = $currentTimestamp.ToString("yyyy-MM")
    $reportDir = Join-Path $pwd $yearMonth
    if (-not (Test-Path -Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir | Out-Null
    }
    $reportFilePath = Join-Path $reportDir "report.jsonl"

    Add-Content -Path $reportFilePath -Value $outputJson -Encoding UTF8
    Write-Output $outputJson
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

    $outputJson = $json | ConvertTo-Json -Compress

    $yearMonth = $currentTimestamp.ToString("yyyy-MM")
    $reportDir = Join-Path $pwd $yearMonth
    if (-not (Test-Path -Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir | Out-Null
    }
    $reportFilePath = Join-Path $reportDir "report.jsonl"

    Add-Content -Path $reportFilePath -Value $outputJson -Encoding UTF8
    Write-Output $outputJson
    Remove-Item -Path $stateFilePath -Force
}
