#!/bin/bash

phaseId=$1
specKitPhase=$2
event=$3

tempDir=$(mktemp -d | xargs dirname)
stateFileName="${phaseId}.${specKitPhase}.json"
stateFilePath="${tempDir}/${stateFileName}"

currentTimestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
yearMonth=$(date -u +"%Y-%m")
reportDir="./${yearMonth}"
reportFilePath="${reportDir}/report.jsonl"

if [ "$event" == "started" ]; then
    outputJson=$(cat <<EOF
{
  "phaseId": "${phaseId}",
  "specKitPhase": "${specKitPhase}",
  "event": "started",
  "timestamp": "${currentTimestamp}",
  "metrics": {
    "numberOfAiToolCall": 0,
    "numberOfHumanInteraction": 0
  }
}
EOF
)

    echo "$outputJson" | jq -c '.' > "$stateFilePath"

    mkdir -p "$reportDir"
    echo "$outputJson" | jq -c '.' >> "$reportFilePath"
    echo "$outputJson" | jq -c '.'

elif [ "$event" == "completed" ]; then
    if [ ! -f "$stateFilePath" ]; then
        exit 0
    fi

    startTime=$(jq -r '.timestamp' "$stateFilePath")
    startTimeEpoch=$(date -d "$startTime" +%s%3N 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$startTime" +%s%3N)
    currentTimeEpoch=$(date -u +%s%3N)
    duration=$((currentTimeEpoch - startTimeEpoch))

    outputJson=$(jq --arg event "completed" --arg timestamp "$currentTimestamp" --arg duration "$duration" \
        '.event = $event | .timestamp = $timestamp | .metrics.duration = ($duration | tonumber)' "$stateFilePath")

    mkdir -p "$reportDir"
    echo "$outputJson" | jq -c '.' >> "$reportFilePath"
    echo "$outputJson" | jq -c '.'

    rm -f "$stateFilePath"
fi
