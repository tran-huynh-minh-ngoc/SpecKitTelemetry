#Requires -Version 7.1
using namespace System.Globalization
using namespace System.IO
using namespace System.Net.Http
using namespace System.Security.Cryptography
using namespace System.Text
$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_Prepare.ps1"

$configPath = "$PSScriptRoot/../telemetry-config.yml"
$telemetryConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml
$reportDir = $telemetryConfig.events_dir
$projectId = $telemetryConfig.project_id
$matchingFiles = @(Get-ChildItem -Path $reportDir -Filter "*.$sessionId.jsonl")
if ($matchingFiles.Count -eq 0) {
    Write-Host "Error: No log file found matching pattern '*.$sessionId.jsonl' in $reportDir"
    exit 0
}
if ($matchingFiles.Count -gt 1) {
    Write-Host "Warning: Multiple log files found. Using the first one."
}
$filePath = $matchingFiles[0].FullName

$endpointUrl = "https://storage.googleapis.com"
$regionName = $env:GCLOUD_REGION_NAME
$bucketName = $env:GCLOUD_BUCKET_NAME
$accessKey = $env:GCLOUD_HMAC_ACCESS_KEY
$secretKey = $env:GCLOUD_HMAC_SECRET_KEY
$objectName = (Join-Path $projectId "speckit" ([System.IO.Path]::GetFileName($filePath))).Replace('\', '/')
$timestamp = [DateTime]::UtcNow

#region Functions
function Format-Uri([string]$Uri) {
    [Uri]::EscapeDataString($Uri).Replace("%2F", "/")
}

function New-CanonicalRequest([string]$Verb, [string]$AbsolutePath, [hashtable]$QueryParams, [hashtable]$Headers, [string]$PayloadHash) {
    $canonicalURI = Format-Uri $AbsolutePath
    $canonicalQueryString = (
        $QueryParams.GetEnumerator() |
        Sort-Object -Property Key |
        ForEach-Object { "$(Format-Uri ($_.Key))=$(Format-Uri ($_.Value))" }
    ) -join "&"

    $canonicalHeadersStr = (
        $Headers.GetEnumerator() |
        Sort-Object -Property Key |
        ForEach-Object { "$($_.Key.ToLower()):$($_.Value.Trim())" }
    ) -join "`n"
    $canonicalHeadersStr += "`n"

    $signedHeaders = ($Headers.Keys | Sort-Object | ForEach-Object { $_.ToLower() }) -join ";"

    return $Verb, $canonicalURI, $canonicalQueryString, $canonicalHeadersStr, $signedHeaders, $PayloadHash -join "`n"
}

function New-StringToSign([string]$CanonicalRequest, [DateTime]$Timestamp, [string]$Region) {
    $timeStampISO8601Format = $Timestamp.ToString("yyyyMMddTHHmmssZ", [CultureInfo]::InvariantCulture)
    $dateStr = $Timestamp.ToString("yyyyMMdd", [CultureInfo]::InvariantCulture)
    $scope = "$dateStr/$Region/s3/aws4_request"

    $canonicalBytes = [Encoding]::UTF8.GetBytes($CanonicalRequest)
    $hash = ([SHA256]::Create().ComputeHash($canonicalBytes) | ForEach-Object { "{0:x2}" -f $_ }) -join ""

    return "AWS4-HMAC-SHA256", $timeStampISO8601Format, $scope, $hash -join "`n"
}

function New-SigningKey([string]$SecretKey, [DateTime]$Timestamp, [string]$Region) {
    $dateStr = $Timestamp.ToString("yyyyMMdd", [CultureInfo]::InvariantCulture)
    $dateKeyData = [Encoding]::UTF8.GetBytes("AWS4$SecretKey")
    $dateKeyMsg = [Encoding]::UTF8.GetBytes($dateStr)

    $dateKey = [HMACSHA256]::HashData($dateKeyData, $dateKeyMsg)

    $regionMsg = [Encoding]::UTF8.GetBytes($Region)
    $dateRegionKey = [HMACSHA256]::HashData($dateKey, $regionMsg)

    $serviceMsg = [Encoding]::UTF8.GetBytes("s3")
    $dateRegionServiceKey = [HMACSHA256]::HashData($dateRegionKey, $serviceMsg)

    $requestMsg = [Encoding]::UTF8.GetBytes("aws4_request")
    return [HMACSHA256]::HashData($dateRegionServiceKey, $requestMsg)
}

function New-Signature([string]$StringToSign, [byte[]]$SecretKey) {
    $signMsg = [Encoding]::UTF8.GetBytes($StringToSign)
    $signatureBytes = [HMACSHA256]::HashData($SecretKey, $signMsg)
    return ($signatureBytes | ForEach-Object { "{0:x2}" -f $_ }) -join ""
}
#endregion

$absolutePath = "/$bucketName/$objectName"
$canonicalQueryParams = @{}
$client = [HttpClient]::new()
$url = "https://storage.googleapis.com$absolutePath"
$credentialStr = "$accessKey/$($timestamp.ToString("yyyyMMdd", [CultureInfo]::InvariantCulture))/$regionName/s3/aws4_request"
$emptyPayloadHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

#region HEAD request
$headCanonicalHeaders = @{
    "host" = "storage.googleapis.com"
    "x-amz-content-sha256" = $emptyPayloadHash
    "x-amz-date" = $timestamp.ToString("yyyyMMddTHHmmssZ", [CultureInfo]::InvariantCulture)
}
$headCanonicalRequest = New-CanonicalRequest "HEAD" $absolutePath $canonicalQueryParams $headCanonicalHeaders $emptyPayloadHash
$headStringToSign = New-StringToSign $headCanonicalRequest $timestamp $regionName
$headSigningKey = New-SigningKey $secretKey $timestamp $regionName
$headSignature = New-Signature $headStringToSign $headSigningKey
$headRequest = [HttpRequestMessage]::new([HttpMethod]::Head, $url)
$headSignedHeaders = ($headCanonicalHeaders.Keys | Sort-Object) -join ";"
$null = $headRequest.Headers.TryAddWithoutValidation("Authorization", "AWS4-HMAC-SHA256 " +
    "Credential=$credentialStr," +
    "SignedHeaders=$headSignedHeaders," +
    "Signature=$headSignature")
$headRequest.Headers.Add("X-Amz-Content-Sha256", $headCanonicalHeaders["x-amz-content-sha256"])
$headRequest.Headers.Add("X-Amz-Date", $headCanonicalHeaders["x-amz-date"])
$headResponse = $client.Send($headRequest)
if ($headResponse.StatusCode -eq 200) {
    $lastModifiedValues = $null
    if ($headResponse.Content.Headers.TryGetValues("Last-Modified", [ref]$lastModifiedValues)) {
        $remoteLastModified = [DateTime]::Parse($lastModifiedValues[0]).ToUniversalTime()
        $localLastModified = (Get-Item $filePath).LastWriteTime.ToUniversalTime()
        if ($localLastModified -lt $remoteLastModified) {
            Write-Host "Local log file is unchanged. Skipping upload."
            exit 0
        }
    } else {
        Write-Host "Remote log file exists but Last-Modified header is missing. Proceeding with upload."
    }
} elseif ($headResponse.StatusCode -eq 404) {
    Write-Host "Remote log file is not available. Proceed to upload."
} else {
    $headResponse.EnsureSuccessStatusCode() | Out-Null
}
#endregion

#region PUT request
$localFileStream = [File]::Open($filePath, [FileMode]::Open, [FileAccess]::Read, [FileShare]::ReadWrite)
$payloadHash = ([SHA256]::Create().ComputeHash($localFileStream) | ForEach-Object { "{0:x2}" -f $_ }) -join ""
$null = $localFileStream.Seek(0, [SeekOrigin]::Begin)
$canonicalHeaders = @{
    "host" = "storage.googleapis.com"
    "x-amz-content-sha256" = $payloadHash
    "x-amz-date" = $timestamp.ToString("yyyyMMddTHHmmssZ", [CultureInfo]::InvariantCulture)
}
$canonicalRequest = New-CanonicalRequest "PUT" $absolutePath $canonicalQueryParams $canonicalHeaders $payloadHash
$stringToSign = New-StringToSign $canonicalRequest $timestamp $regionName
$signingKey = New-SigningKey $secretKey $timestamp $regionName
$signature = New-Signature $stringToSign $signingKey
$putRequest = [HttpRequestMessage]::new([HttpMethod]::Put, $url)
$signedHeaders = ($canonicalHeaders.Keys | Sort-Object) -join ";"
$null = $putRequest.Headers.TryAddWithoutValidation("Authorization", "AWS4-HMAC-SHA256 " +
    "Credential=$credentialStr," +
    "SignedHeaders=$signedHeaders," +
    "Signature=$signature")
$putRequest.Headers.Add("X-Amz-Content-Sha256", $canonicalHeaders["x-amz-content-sha256"])
$putRequest.Headers.Add("X-Amz-Date", $canonicalHeaders["x-amz-date"])
$putRequest.Content = [StreamContent]::new($localFileStream)
$response = $client.Send($putRequest)
$response.EnsureSuccessStatusCode() | Out-Null
#endregion

Write-Host "Log file uploaded successfully to gs://$bucketName/$objectName"