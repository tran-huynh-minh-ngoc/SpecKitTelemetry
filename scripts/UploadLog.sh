#!/bin/bash
set -e
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    pwsh -NoProfile -File "$(dirname "$0")/UploadLog.ps1" "$@"
    exit $?
    ;;
esac

. "$(dirname "$0")/_Prepare.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/../telemetry-config.yml"
TELEMETRY_CONFIG=$(yq eval . "$CONFIG_PATH")
REPORT_DIR=$(echo "$TELEMETRY_CONFIG" | yq eval '.events_dir' -)
FILE_PATH=$(find "$REPORT_DIR" -maxdepth 1 -name "*.$SESSION_ID.jsonl" | head -1)
PROJECT_ID=$(echo "$TELEMETRY_CONFIG" | yq eval '.project_id' -)

ENDPOINT_URL="https://storage.googleapis.com"
REGION_NAME="${GCLOUD_REGION_NAME}"
BUCKET_NAME="${GCLOUD_BUCKET_NAME}"
ACCESS_KEY="${GCLOUD_HMAC_ACCESS_KEY}"
SECRET_KEY="${GCLOUD_HMAC_SECRET_KEY}"
FILE_NAME=$(basename "$FILE_PATH")
OBJECT_NAME="$PROJECT_ID/speckit/$FILE_NAME"

# Extract host from endpoint URL
ENDPOINT_HOST=$(echo "$ENDPOINT_URL" | sed 's|https://||' | sed 's|http://||')

# Helper function to calculate AWS Signature V4
sign_request() {
    local method=$1
    local bucket=$2
    local key=$3
    local region=$4
    local access_key=$5
    local secret_key=$6
    local timestamp=$7
    local payload_hash=$8
    local host=$9

    local date_stamp=$(echo "$timestamp" | cut -d'T' -f1 | tr -d '-')
    local amz_date=$(echo "$timestamp" | tr -d '-' | tr ':' '0' | cut -c1-16)

    # Canonical request
    local canonical_uri="/$bucket/$key"
    local canonical_querystring=""
    local canonical_headers="host:${host}\nx-amz-content-sha256:${payload_hash}\nx-amz-date:${amz_date}\n"
    local signed_headers="host;x-amz-content-sha256;x-amz-date"

    local canonical_request="${method}\n${canonical_uri}\n${canonical_querystring}\n${canonical_headers}\n${signed_headers}\n${payload_hash}"

    # String to sign
    local credential_scope="${date_stamp}/${region}/s3/aws4_request"
    local canonical_request_hash=$(echo -ne "$canonical_request" | openssl dgst -sha256 -hex | awk '{print $2}')
    local string_to_sign="AWS4-HMAC-SHA256\n${amz_date}\n${credential_scope}\n${canonical_request_hash}"

    # Signature
    local kDate=$(echo -ne "AWS4${secret_key}" | openssl dgst -sha256 -mac HMAC -macopt key: -hex 2>/dev/null || echo -ne "AWS4${secret_key}" | openssl sha256 -hmac '' -r | awk '{print $1}')
    local kRegion=$(echo -ne "$date_stamp" | openssl dgst -sha256 -mac HMAC -macopt "key:${kDate}" -hex 2>/dev/null || echo -ne "$date_stamp" | openssl sha256 -hmac "${kDate}" -r | awk '{print $1}')
    local kService=$(echo -ne "s3" | openssl dgst -sha256 -mac HMAC -macopt "key:${kRegion}" -hex 2>/dev/null || echo -ne "s3" | openssl sha256 -hmac "${kRegion}" -r | awk '{print $1}')
    local kSigning=$(echo -ne "aws4_request" | openssl dgst -sha256 -mac HMAC -macopt "key:${kService}" -hex 2>/dev/null || echo -ne "aws4_request" | openssl sha256 -hmac "${kService}" -r | awk '{print $1}')
    local signature=$(echo -ne "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "key:${kSigning}" -hex 2>/dev/null || echo -ne "$string_to_sign" | openssl sha256 -hmac "${kSigning}" -r | awk '{print $1}')

    # Authorization header
    local authorization="AWS4-HMAC-SHA256 Credential=${access_key}/${credential_scope}, SignedHeaders=${signed_headers}, Signature=${signature}"

    echo "$authorization"
}

# Calculate file hash
FILE_HASH=$(openssl dgst -sha256 -hex "$FILE_PATH" | awk '{print $2}')

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Calculate Authorization header
AUTH_HEADER=$(sign_request "PUT" "$BUCKET_NAME" "$OBJECT_NAME" "$REGION_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$TIMESTAMP" "$FILE_HASH" "$ENDPOINT_HOST")

# Format AMZ date for headers
AMZ_DATE=$(echo "$TIMESTAMP" | tr -d '-' | tr ':' '0' | cut -c1-16)

# Check if remote object exists and compare timestamps
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: $AUTH_HEADER" \
    -H "x-amz-date: $AMZ_DATE" \
    -H "x-amz-content-sha256: $FILE_HASH" \
    -X HEAD \
    "$ENDPOINT_URL/$BUCKET_NAME/$OBJECT_NAME")

if [ "$HTTP_CODE" = "200" ]; then
    LOCAL_MODIFIED_TIME=$(stat -f %m "$FILE_PATH" 2>/dev/null || stat -c %Y "$FILE_PATH")
    REMOTE_MODIFIED=$(curl -s -I \
        -H "Authorization: $AUTH_HEADER" \
        -H "x-amz-date: $AMZ_DATE" \
        -H "x-amz-content-sha256: $FILE_HASH" \
        "$ENDPOINT_URL/$BUCKET_NAME/$OBJECT_NAME" | grep -i "last-modified" | cut -d' ' -f2-)
    REMOTE_MODIFIED_TIME=$(date -d "$REMOTE_MODIFIED" +%s)

    if [ "$LOCAL_MODIFIED_TIME" -le "$REMOTE_MODIFIED_TIME" ]; then
        echo "Local file is not newer than remote file. Skipping upload."
        exit 0
    fi
fi

# Upload file using curl
curl -X PUT \
    -H "Authorization: $AUTH_HEADER" \
    -H "x-amz-date: $AMZ_DATE" \
    -H "x-amz-content-sha256: $FILE_HASH" \
    --data-binary "@$FILE_PATH" \
    "$ENDPOINT_URL/$BUCKET_NAME/$OBJECT_NAME"

echo "File uploaded successfully to gs://$BUCKET_NAME/$OBJECT_NAME"
