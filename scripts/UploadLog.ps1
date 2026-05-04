$ErrorActionPreference = "Stop"

$sessionId = $env:SESSION_ID
if ([string]::IsNullOrEmpty($sessionId) -and [Console]::IsInputRedirected) {
    $sessionId = ([Console]::In.ReadToEnd() | ConvertFrom-Json).session_id
}
if ([string]::IsNullOrEmpty($sessionId)) {
    Write-Error "SESSION_ID environment variable is not set or empty"
    exit 1
}

if (-not (Get-Module -ListAvailable -Name AWS.Tools.S3)) {
    Install-Module -Name AWS.Tools.S3 -Force -Scope CurrentUser
}
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser
}

$configPath = "$PSScriptRoot/../telemetry-config.yml"
$telemetryConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml
$reportDir = $telemetryConfig.events_dir
$filePath = (Get-ChildItem -Path $reportDir -Filter "*.$sessionId.jsonl")[0].FullName
$projectId = $telemetryConfig.project_id

$endpointUrl = "https://storage.googleapis.com"
$regionName = $telemetryConfig.gcloud_region_name
$bucketName = $telemetryConfig.gcloud_bucket_name
$accessKey = $telemetryConfig.gcloud_hmac_access_key
$secretKey = $telemetryConfig.gcloud_hmac_secret_key
$objectName = (Join-Path $projectId "speckit" [System.IO.Path]::GetFileName($filePath)).Replace('\', '/')

Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKey -StoreAs default

$remoteObject = Get-S3Object -BucketName $bucketName -Key $objectName -EndpointUrl $endpointUrl -Region $regionName

if ($remoteObject) {
    $localModifiedTime = (Get-Item $filePath).LastWriteTimeUtc
    $remoteModifiedTime = $remoteObject.LastModified.UtcDateTime
    if ($localModifiedTime -le $remoteModifiedTime) {
        Write-Host "Local file is not newer than remote file. Skipping upload."
        exit 0
    }
}

Write-S3Object -BucketName $bucketName -Key $objectName -FilePath $filePath -EndpointUrl $endpointUrl -Region regionName -Force

Write-Host "File uploaded successfully to gs://$bucketName/$objectName"