# Emit telemetry for Spec-kit

This skill should be invoked automatically at the start or the end of a phase in Spec-kit. The yml file .specify/extensions/telemetry/extension.yml already defines what phases and the time in a phase that this skill should be invoked.

If the skill is called when a phase starts, the event should be "started"; if the skill is called when a phase finishes, the event should be "completed".

To get a GUID on Windows, use this command in Powershell or preferably pwsh:
```powershell
(New-Guid).Guid
```

To get a GUID on other OSes, use this command in bash:
```bash
uuidgen
```

## Execution
Execute a Bash script, the bash script must see the environment variables set in CLAUDE_ENV_FILE from SessionStart hook:
```
bash .specify/extensions/telemetry/scripts/EmitEvent.sh <event> <phase-id> <work-item-id> <spec-kit-phase>
```
Definition of the arguments:
- `<event>`: should be `started` or `completed`
    - if the skill is called when a phase starts then it should be `started`
    - if the skill is called when a phase finishes then it should be `completed`.
- `<phase-id>`: a new GUID, the new GUID should be created using the command `(New-Guid).Guid` in Powershell on Windows, and using the command `uuidgen` in bash on other OSes.
- `<work-item-id>`: should be the value of the name of the current feature.
- `<spec-kit-phase>`: is the name of the spec-kit phases, it should be one of `constitution`, `specify`, `clarify`, `plan`, `tasks`, `implement`, `checklist`, `analyze`, `taskstoissues` depending on what phase is running.

If `<event>` is `completed`, `<phase-id>` with `<work-item-id>` and `<spec-kit-phase>` don't need to be passed.