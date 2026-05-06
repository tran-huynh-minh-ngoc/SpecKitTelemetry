using System.Globalization;
using System.Net.Http;
using System.Security.Cryptography;

var accessKey = "";
var secretKey = "";
var region = "asia-southeast1";
var bucketName = "gridsz-adm-dev-export";
var localFilePath = @"C:\SubDrive\Infodation\telemetry\scripts\reports\telemetry\2026-05.test_session_id.jsonl";
var gcsObjectName = "testtest.jsonl";

var timestamp = DateTime.UtcNow;
using var localFileStream = File.Open(localFilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
var payloadHash = Convert.ToHexStringLower(SHA256.HashData(localFileStream));
localFileStream.Seek(0, SeekOrigin.Begin);
var absolutePath = $"/{bucketName}/{gcsObjectName}";
var canonicalQueryParams = new Dictionary<string, string>();
var canonicalHeaders = new Dictionary<string, string> {
    ["host"] = "storage.googleapis.com",
    ["x-amz-content-sha256"] = payloadHash,
    ["x-amz-date"] = timestamp.ToString("yyyyMMddTHHmmssZ", CultureInfo.InvariantCulture),
};
var canonicalRequest = MakeCanonicalRequest(HttpMethod.Put, absolutePath, canonicalQueryParams, canonicalHeaders, payloadHash);
var stringToSign = MakeStringToSign(canonicalRequest, timestamp, region);
var signature = ComputeSignature(stringToSign, MakeSigningKey(secretKey, timestamp, region));

using var client = new HttpClient();
var url = $"https://storage.googleapis.com{absolutePath}";
using var request = new HttpRequestMessage(HttpMethod.Put, url);
request.Headers.TryAddWithoutValidation("Authorization", "AWS4-HMAC-SHA256 "
    + $"Credential={accessKey}/{timestamp.ToString("yyyyMMdd", CultureInfo.InvariantCulture)}/{region}/s3/aws4_request,"
    + $"SignedHeaders={string.Join(';', canonicalHeaders.Keys.Order())},"
    + $"Signature={signature}");
request.Headers.Add("X-Amz-Content-Sha256", canonicalHeaders["x-amz-content-sha256"]);
request.Headers.Add("X-Amz-Date", canonicalHeaders["x-amz-date"]);
request.Content = new StreamContent(localFileStream);
var response = client.Send(request);
response.EnsureSuccessStatusCode();


static string EncodeUri(string uri) {
    return Uri.EscapeDataString(uri).Replace("%2F", "/");
}

static string MakeCanonicalRequest(
    HttpMethod verb, string absolutePath, IDictionary<string, string> queryParams, IDictionary<string, string> headers, string payloadHash
) {
    var canonicalURI = EncodeUri(absolutePath);
    var canonicalQueryString = string.Join('&', queryParams.OrderBy(e => e.Key).Select(e => $"{EncodeUri(e.Key)}={EncodeUri(e.Value)}"));
    var canonicalHeaders = string.Join('\n', headers.OrderBy(e => e.Key).Select(e => $"{e.Key.ToLower()}:{e.Value.Trim()}")) + '\n';
    var signedHeaders = string.Join(';', headers.Keys.Order().Select(e => e.ToLower()));
    return string.Join('\n', verb.Method, canonicalURI, canonicalQueryString, canonicalHeaders, signedHeaders, payloadHash);
}

static string MakeStringToSign(string canonicalRequest, DateTime timestamp, string region) {
    var timeStampISO8601Format = timestamp.ToString("yyyyMMddTHHmmssZ", CultureInfo.InvariantCulture);
    var scope = $"{timestamp.ToString("yyyyMMdd", CultureInfo.InvariantCulture)}/{region}/s3/aws4_request";
    var hash = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(canonicalRequest)));
    return string.Join('\n', "AWS4-HMAC-SHA256", timeStampISO8601Format, scope, hash);
}

static byte[] MakeSigningKey(string secretKey, DateTime timestamp, string region) {
    var dateKey = HMACSHA256.HashData(Encoding.UTF8.GetBytes($"AWS4{secretKey}"), Encoding.UTF8.GetBytes(timestamp.ToString("yyyyMMdd", CultureInfo.InvariantCulture)));
    var dateRegionKey = HMACSHA256.HashData(dateKey, Encoding.UTF8.GetBytes(region));
    var dateRegionServiceKey = HMACSHA256.HashData(dateRegionKey, Encoding.UTF8.GetBytes("s3"));
    return HMACSHA256.HashData(dateRegionServiceKey, Encoding.UTF8.GetBytes("aws4_request"));
}

static string ComputeSignature(string stringToSign, byte[] secretKey)
{
    return Convert.ToHexStringLower(HMACSHA256.HashData(secretKey, Encoding.UTF8.GetBytes(stringToSign)));
}