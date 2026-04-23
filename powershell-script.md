This Powershell script should:

- Read the passed arguments in this order: `<phase-id>`, `<project-id>`, `<spec-kit-phase>`, `<event>`
- If `<event>` is 'started':
    - Create a new state file (json) named `<phase-id>.<project-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments, overwriting existing file if any.
    - Create a json that has the content like this, using values from the arguments, with `<the-current-timestamp>` is the current time in ISO 8601 format in UTC, for example "2026-04-23T02:06:08Z":
    ```json
    {
        "phaseId": "<phase-id>",
        "projectId": "<phase-id>",
        "specKitPhase": "<spec-kit-phase>",
        "event": "started",
        "timestamp": "<the-current-timestamp>",
        "metrics": {
            "numberOfAiToolCall": 0,
            "numberOfHumanInteraction": 0
        }
    }
    ```
    - Write the json into the temp file above.
    - Append the json into a file named `report.jsonl` in a folder named `YYYY-MM` where `YYYY` is the current year and `MM` is the current month, the appended json has to be minified as a single line, if the file doesn't exist then create it.
    - Log the json to the console
- If `<event>` is 'completed':
    - Read the state file (json) named `<phase-id>.<project-id>.<spec-kit-phase>.json` in the temp directory of the current operating system, using values from the arguments.
    - If the state file doesn't exist, just exit the script.
    - Calculate the current timestamp
    - Calculate the duration in milliseconds by current timestamp minus the timestamp in the json state file
    - Change the field `event` of the json into `completed`
    - Change the field `timestamp` of the json into the calculated current timestamp above in ISO 8601 format in UTC, for example "2026-04-23T02:06:08Z"
    - Set `metrics.duration` of the json to the duration value above.
    - Append the json into a file named `report.jsonl` in a folder named `YYYY-MM` where `YYYY` is the current year and `MM` is the current month, the appended json has to be minified as a single line, if the file doesn't exist then create it.
    - Log the json to the console
    - Delete the temp file.