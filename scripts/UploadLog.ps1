$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_Prepare.ps1"

$configPath = "$PSScriptRoot/../telemetry-config.yml"
$telemetryConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml
$reportDir = $telemetryConfig.events_dir
$filePath = (Get-ChildItem -Path $reportDir -Filter "*.$sessionId.jsonl")[0].FullName
$projectId = $telemetryConfig.project_id

$endpointUrl = "https://storage.googleapis.com"
$regionName = $env:GCLOUD_REGION_NAME
$bucketName = $env:GCLOUD_BUCKET_NAME
$accessKey = $env:GCLOUD_HMAC_ACCESS_KEY
$secretKey = $env:GCLOUD_HMAC_SECRET_KEY
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