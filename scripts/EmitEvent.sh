#!/bin/bash
set -e
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    pwsh -NoProfile -File "$(dirname "$0")/EmitEvent.ps1" "$@"
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

configPath="$(dirname "$0")/../telemetry-config.yml"

telemetryConfig=$(yq eval -o json '.' "$configPath")
projectId=$(echo "$telemetryConfig" | jq -r '.project_id')
eventsDir=$(echo "$telemetryConfig" | jq -r '.events_dir')

tempDir=$(mktemp -d | xargs dirname)
stateFilePath="${tempDir}/SpecKitTelemetry.${SESSION_ID}.json"
currentTimestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
reportDir="${eventsDir}"
reportFilePath="${reportDir}/$(date -u +"%Y-%m").${SESSION_ID}.jsonl"

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

if [ "$event" = "submitted" ]; then
    if [ -f "$stateFilePath" ]; then
        eventData=$(cat "$stateFilePath")
    else
        eventData=$(jq -n \
            --arg span_id "$(uuidgen)" \
            --arg project_id "$projectId" \
            --arg timestamp_utc "$currentTimestamp" \
            '{
                event_id: "",
                event_type: "",
                span_id: $span_id,
                phase_id: "",
                phase: "",
                work_item_id: "",
                project_id: $project_id,
                timestamp_utc: $timestamp_utc,
                invocation_seq: 0,
                invocation_kind: "initial",
                metrics: {
                    ai_tool_use_count: 0,
                    artifact_change_count: 0
                }
            }')
    fi

    phase=$(echo "$eventData" | jq -r '.phase')
    if [ "$phase" != "" ] && [ "$phase" != "null" ]; then
        eventData=$(echo "$eventData" | jq \
            --arg event_id "$(uuidgen)" \
            --arg span_id "$(uuidgen)" \
            --arg timestamp_utc "$currentTimestamp" \
            '.event_id = $event_id | .span_id = $span_id | .event_type = "resumed" | .invocation_seq += 1 | .invocation_kind = "refinement" | .timestamp_utc = $timestamp_utc | .metrics.ai_tool_use_count = 0 | .metrics.artifact_change_count = 0')
        ReportEvent "$eventData"
    else
        SaveStateFile "$(echo "$eventData" | jq -c '.')"
    fi

elif [ "$event" = "stopped" ]; then
    if [ -f "$stateFilePath" ]; then
        eventData=$(cat "$stateFilePath")
        phase=$(echo "$eventData" | jq -r '.phase')
        type=$(echo "$eventData" | jq -r '.event_type')

        if [ "$phase" != "" ] && [ "$phase" != "null" ] && [ "$type" != "completed" ]; then
            eventData=$(echo "$eventData" | jq \
                --arg event_id "$(uuidgen)" \
                --arg timestamp_utc "$currentTimestamp" \
                '.event_id = $event_id | .event_type = "suspended" | .timestamp_utc = $timestamp_utc')
            ReportEvent "$eventData"
        elif [ "$phase" != "" ] && [ "$phase" != "null" ] && [ "$type" = "completed" ]; then
            eventData=$(echo "$eventData" | jq \
                --arg event_id "$(uuidgen)" \
                --arg timestamp_utc "$currentTimestamp" \
                '.event_id = $event_id | .timestamp_utc = $timestamp_utc')
            ReportEvent "$eventData" false
            DeleteStateFile
        else
            DeleteStateFile
        fi
    fi

elif [ "$event" = "started" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq \
        --arg event_id "$(uuidgen)" \
        --arg phase_id "$phaseId" \
        --arg work_item_id "$workItemId" \
        --arg phase "$specKitPhase" \
        '.event_id = $event_id | .phase_id = $phase_id | .phase = $phase | .work_item_id = $work_item_id | .event_type = "started"')
    ReportEvent "$eventData"

elif [ "$event" = "completed" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq '.event_type = "completed"')
    SaveStateFile "$(echo "$eventData" | jq -c '.')"

elif [ "$event" = "ai_tool_called" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq '.metrics.ai_tool_use_count += 1')
    SaveStateFile "$(echo "$eventData" | jq -c '.')"

elif [ "$event" = "artifact_changed" ]; then
    eventData=$(cat "$stateFilePath")
    eventData=$(echo "$eventData" | jq '.metrics.artifact_change_count += 1')
    SaveStateFile "$(echo "$eventData" | jq -c '.')"

elif [ "$event" = "error_occured" ]; then
    eventData=$(cat "$stateFilePath")
    phase=$(echo "$eventData" | jq -r '.phase')
    if [ "$phase" = "" ] || [ "$phase" = "null" ]; then
        ReportEvent "$eventData" false
    fi
    eventData=$(echo "$eventData" | jq \
        --arg event_id "$(uuidgen)" \
        --arg timestamp_utc "$currentTimestamp" \
        '.event_id = $event_id | .event_type = "error_occured" | .timestamp_utc = $timestamp_utc')
    ReportEvent "$eventData" false
    DeleteStateFile
fi