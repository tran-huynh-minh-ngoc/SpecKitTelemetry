This Powershell script should:

- Read the passed arguments in this order: `<phase-id>`, `<work-item-id>`, `<spec-kit-phase>`, `<event>`
- Read `telemetry-config.yml` into a variable named `telemetryConfig`: if the current directory ends with `/scripts` (or `\scripts` on Windows), read from `../telemetry-config.yml`, otherwise read from `.specify/extensions/telemetry/telemetry-config.yml`.
- If `<event>` is 'started':
    - Create a new state file (json) named `<phase-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments, overwriting existing file if any.
    - Create a json that has the content like this, using values from the arguments, the values of fields in `telemetryConfig`, with `<the-current-timestamp>` is the current time in ISO 8601 format in UTC, for example "2026-04-23T02:06:08Z":
    ```json
    {
        "event_id": "<new-guid>",
        "phase_id": "<phase-id>",
        "work_item_id": "<work-item-id>",
        "project_id": "{telemetryConfig.project_id}",
        "phase": "<spec-kit-phase>",
        "event_type": "started",
        "timestamp_utc": "<the-current-timestamp>",
        "invocation_seq": 1,
        "invocation_kind": "initial",
        "signals": {
            "duration_ms": 0,
            "ai_tool_use_count": 0,
            "user_turn_count": 0,
            "artifact_change_count": 0,
            "active_time_ms": 0,
            "idle_threshold_ms_at_capture": 300000
        }
    }
    ```
    - Write the json into the temp file above.
    - Append the json into a file named `report.jsonl` in a directory path named `{telemetryConfig.events_dir}/YYYY-MM` where `YYYY` is the current year and `MM` is the current month, the appended json has to be minified as a single line, if the file doesn't exist then create it.
    - Log the json to the console

- If `<event>` is `suspended`:
    - Read the state file (json) named `<phase-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments.
    - Assign new guid to the field `event_id` in json
    - Calculate the current timestamp
    - Calculate the duration in milliseconds by current timestamp minus the timestamp_utc in the json state file
    - Change the field `event_type` of the json into `suspended`
    - Change the field `timestamp_utc` of the json into the calculated current timestamp above in ISO 8601 format in UTC, for example "2026-04-23T02:06:08Z"
    - Set `signals.duration_ms` of the json to the duration value above.
    - Write the json back to the temp file above.
    - Append the json into a file named `report.jsonl` in a directory path named `{telemetryConfig.events_dir}/YYYY-MM` where `YYYY` is the current year and `MM` is the current month, the appended json has to be minified as a single line, if the file doesn't exist then create it.
    - Log the json to the console

- If `<event>` is `resumed`:
    - Read the state file (json) named `<phase-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments.
    - Assign new guid to the field `event_id` in json
    - Increase the value of the field `invocation_seq` by one
    - Increase the value of the field `signals.user_turn_count` by one
    - Assign the value `refinement` into the field `invocation_kind` in json
    - Change the field `event_type` of the json into `resumed`
    - Calculate the current timestamp
    - Change the field `timestamp_utc` of the json into the calculated current timestamp above in ISO 8601 format in UTC, for example "2026-04-23T02:06:08Z"
    - Write the json back to the temp file above.
    - Append the json into a file named `report.jsonl` in a directory path named `{telemetryConfig.events_dir}/YYYY-MM` where `YYYY` is the current year and `MM` is the current month, the appended json has to be minified as a single line, if the file doesn't exist then create it.
    - Log the json to the console

- If `<event>` is `ai_tool_called`:
    - Read the state file (json) named `<phase-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments.
    - Increase the value of the field `signals.ai_tool_use_count` by one
    - Write the json back to the temp file above.

- If `<event>` is `artifact_changed`:
    - Read the state file (json) named `<phase-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments.
    - Increase the value of the field `signals.artifact_change_count` by one
    - Write the json back to the temp file above.

- If `<event>` is `completed`:
    - Read the state file (json) named `<phase-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments.
    - Assign new guid to the field `event_id` in json
    - Calculate the current timestamp
    - Calculate the duration in milliseconds by current timestamp minus the timestamp_utc in the json state file
    - Change the field `event_type` of the json into `completed`
    - Change the field `timestamp_utc` of the json into the calculated current timestamp above in ISO 8601 format in UTC, for example "2026-04-23T02:06:08Z"
    - Set `signals.duration_ms` of the json to the duration value above.
    - Append the json into a file named `report.jsonl` in a directory path named `{telemetryConfig.events_dir}/YYYY-MM` where `YYYY` is the current year and `MM` is the current month, the appended json has to be minified as a single line, if the file doesn't exist then create it.
    - Log the json to the console
    - Delete the temp file.