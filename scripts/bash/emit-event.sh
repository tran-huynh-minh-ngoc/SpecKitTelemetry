#!/bin/bash

phaseId=$1
projectId=$2
specKitPhase=$3
event=$4

tempDir=$(mktemp -d | xargs dirname)
stateFileName="${phaseId}.${projectId}.${specKitPhase}.json"
stateFilePath="${tempDir}/${stateFileName}"

currentTimestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
yearMonth=$(date -u +"%Y-%m")
reportDir="./${yearMonth}"
reportFilePath="${reportDir}/report.jsonl"

if [ "$event" == "started" ]; then
    eventData=$(cat <<EOF
{
  "phaseId": "${phaseId}",
  "projectId": "${projectId}",
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

    echo "$eventData" | jq -c '.' > "$stateFilePath"

    mkdir -p "$reportDir"
    echo "$eventData" | jq -c '.' >> "$reportFilePath"

elif [ "$event" == "completed" ]; then
    if [ ! -f "$stateFilePath" ]; then
        exit 0
    fi

    startTime=$(jq -r '.timestamp' "$stateFilePath")
    startTimeEpoch=$(date -d "$startTime" +%s%3N 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$startTime" +%s%3N)
    currentTimeEpoch=$(date -u +%s%3N)
    duration=$((currentTimeEpoch - startTimeEpoch))

    json=$(jq --arg event "completed" --arg timestamp "$currentTimestamp" --arg duration "$duration" \
        '.event = $event | .timestamp = $timestamp | .metrics.duration = ($duration | tonumber)' "$stateFilePath")

    mkdir -p "$reportDir"
    echo "$json" | jq -c '.' >> "$reportFilePath"

    rm -f "$stateFilePath"
fi
