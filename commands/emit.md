# speckit.telemetry.emit

Two sub-commands share this entrypoint:

## `speckit.telemetry.emit <phase> <event_type>`

Invoked by the spec-kit hook runtime on `before_<phase>` and `after_<phase>`.
Writes one v1 JSON line to `.specify/telemetry/events/YYYY-MM.jsonl`.

- `<phase>`: one of `constitution` / `specify` / `clarify` / `plan` / `tasks` / `implement` / `checklist` / `analyze` / `taskstoissues`
- `<event_type>`: `started` / `completed` / `aborted`

Shell out to whichever script flavour is installed:

- PowerShell: `pwsh -File .specify/extensions/telemetry/scripts/powershell/emit-event.ps1 <phase> <event_type>`
- Bash: `bash .specify/extensions/telemetry/scripts/bash/emit-event.sh <phase> <event_type>`

## `speckit.telemetry.emit record-activity <phase> <activity_type>`

Invoked by the AI assistant during a phase, once per user_turn received and
once per ai_tool_use emitted. Appends a timestamped record to the current
phase's state file so the Active Window Computer can compute `active_time_ms`
at `after_<phase>`.

- `<phase>`: same enum as above (the currently active phase)
- `<activity_type>`: `user_turn` or `ai_tool_use`

Shell out:

- PowerShell: `pwsh -File .specify/extensions/telemetry/scripts/powershell/record-activity.ps1 <phase> <activity_type>`
- Bash: `bash .specify/extensions/telemetry/scripts/bash/record-activity.sh <phase> <activity_type>`

## Contract

Both sub-commands:

- Always exit `0` (FR-010 additive-telemetry principle).
- Never write PII, user-prompt text, or artefact content — only metadata.
- Emit `[telemetry] WARN:` to stderr on any internal failure, never block
  the underlying SDD command or AI workflow.

See the full contract at
[`specs/POC-sdd-telemetry/contracts/hook-contract.md`](../../../specs/POC-sdd-telemetry/contracts/hook-contract.md).
