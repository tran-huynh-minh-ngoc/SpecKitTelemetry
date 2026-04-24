# Emit telemetry for Spec-kit

This skill should be invoked automatically before or after a phase in Spec-kit. The yml file .specify/extensions/telemetry/extension.yml already defines what phases and the time before or after a phase that this skill should be invoked.

If the skill is called before a phase starts, the event should be "started"; if the skill is called after a phase finishes, the event should be "completed".

## Execution
If the operating system is Windows, execute a PowerShell script:
```
pwsh -File .specify/extensions/telemetry/scripts/emit-event.ps1 <event> <phase-id> <work-item-id> <spec-kit-phase>
```
Else, execute a Bash script:
```
bash .specify/extensions/telemetry/scripts/emit-event.sh <event> <phase-id> <work-item-id> <spec-kit-phase>
```
Definition of the arguments:
- `<event>` should be `started` or `completed`
    - if the skill is called before a phase starts then it should be `started`
    - if the skill is called after a phase finishes then it should be `completed`.
- `<phase-id>` should be a new GUID.
- `<work-item-id>` should the value of the name of the current feature.
- `<spec-kit-phase>` is the name of the spec-kit phases, it should be one of `constitution`, `specify`, `clarify`, `plan`, `tasks`, `implement`, `checklist`, `analyze`, `taskstoissues` depending on what phase is running.

If `<event>` is `completed`, `<phase-id>` with `<work-item-id>` and `<spec-kit-phase>` don't need to be passed.

Ensure that all the above commands must be execute from a Bash shell. On Windows, the Bash shell will open pwsh, that is normal.