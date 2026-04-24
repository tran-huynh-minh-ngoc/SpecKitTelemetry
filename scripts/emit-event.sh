#!/bin/bash
set -e
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    pwsh -NoProfile -File "$(dirname "$0")/emit-event.ps1" "$@"
    exit $?
    ;;
esac

event=$1
phaseId=$2
workItemId=$3
specKitPhase=$4

if [ -z "$SESSION_ID" ]; then
    echo "Error: SESSION_ID environment variable is not set or empty" >&2
    exit 1
fi

if [[ "$(pwd)" == */scripts ]]; then
    configPath="../telemetry-config.yml"
else
    configPath=".specify/extensions/telemetry/telemetry-config.yml"
fi
telemetryConfig=$(yq eval -o json '.' "$configPath")
projectId=$(echo "$telemetryConfig" | jq -r '.project_id')
eventsDir=$(echo "$telemetryConfig" | jq -r '.events_dir')

tempDir=$(mktemp -d | xargs dirname)
stateFilePath="${tempDir}/SpecKitTelemetry.${SESSION_ID}.json"
currentTimestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
reportDir="${eventsDir}/$(date -u +"%Y-%m")"
reportFilePath="${reportDir}/report.jsonl"

SaveStateFile() {
    local json=$1
    echo "$json" > "$stateFilePath"
}

ReportEvent() {
    local eventData=$1
    local saveState=${2:-true}
    mkdir -p "$reportDir"
    local json=$(echo "$eventData" | jq -c '.')
    if [ "$saveState" = true ]; then
        SaveStateFile "$json"
    fi
    echo "$json" >> "$reportFilePath"
    echo "$json"
}

DeleteStateFile() {
    rm -f "$stateFilePath"
}

if [ "$event" = "started" ]; then
    eventData=$(jq -n \
        --arg event_id "$(uuidgen)" \
        --arg phase_id "$phaseId" \
        --arg work_item_id "$workItemId" \
        --arg project_id "$projectId" \
        --arg phase "$specKitPhase" \
        --arg timestamp_utc "$currentTimestamp" \
        '{
            event_id: $event_id,
            phase_id: $phase_id,
            work_item_id: $work_item_id,
            project_id: $project_id,
            phase: $phase,
            event_type: "started",
            timestamp_utc: $timestamp_utc,
            invocation_seq: 1,
            invocation_kind: "initial",
            signals: {
                duration_ms: 0,
                ai_tool_use_count: 0,
                user_turn_count: 0,
                artifact_change_count: 0,
                active_time_ms: 0,
                idle_threshold_ms_at_capture: 300000
            }
        }')
    ReportEvent "$eventData"

elif [ "$event" = "suspended" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq \
        --arg event_id "$(uuidgen)" \
        --arg timestamp_utc "$currentTimestamp" \
        --argjson duration_ms "$(date -d "$currentTimestamp" +%s%3N) - $(echo "$eventData" | jq -r '.timestamp_utc' | xargs -I {} date -d {} +%s%3N)" \
        '.event_id = $event_id | .event_type = "suspended" | .timestamp_utc = $timestamp_utc | .signals.duration_ms = $duration_ms')
    ReportEvent "$eventData"

elif [ "$event" = "resumed" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq \
        --arg event_id "$(uuidgen)" \
        --arg timestamp_utc "$currentTimestamp" \
        '.event_id = $event_id | .invocation_seq += 1 | .signals.user_turn_count += 1 | .signals.duration_ms = 0 | .invocation_kind = "refinement" | .event_type = "resumed" | .timestamp_utc = $timestamp_utc')
    ReportEvent "$eventData"

elif [ "$event" = "ai_tool_called" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq '.signals.ai_tool_use_count += 1')
    json=$(echo "$eventData" | jq -c '.')
    SaveStateFile "$json"

elif [ "$event" = "artifact_changed" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq '.signals.artifact_change_count += 1')
    json=$(echo "$eventData" | jq -c '.')
    SaveStateFile "$json"

elif [ "$event" = "completed" ]; then
    eventData=$(cat "$stateFilePath")
    startTimestamp=$(echo "$eventData" | jq -r '.timestamp_utc')
    durationMs=$(( $(date -d "$currentTimestamp" +%s%3N) - $(date -d "$startTimestamp" +%s%3N) ))
    eventData=$(echo "$eventData" | jq \
        --arg event_id "$(uuidgen)" \
        --arg timestamp_utc "$currentTimestamp" \
        --argjson duration_ms "$durationMs" \
        '.event_id = $event_id | .event_type = "completed" | .timestamp_utc = $timestamp_utc | .signals.duration_ms = $duration_ms')
    ReportEvent "$eventData" false
    DeleteStateFile
fi
