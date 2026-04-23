# Emit telemetry for Spec-kit

This skill should be invoked automatically before or after a phase in Spec-kit. The yml file .specify/extensions/telemetry/extension.yml already defines what phases and the time before or after a phase that this skill should be invoked.

If the skill is called before a phase starts, the event should be "started"; if the skill is called after a phase finishes, the event should be "completed".

## Execution
If the skill is called before a phase starts, generate a GUID and remember it in a variable named "TelemetryPhaseId".

If the skill is called after a phase finishes, recall the GUID from the variable "TelemetryPhaseId".

If the operating system is Windows, execute a PowerShell script:
```
pwsh -File .specify/extensions/telemetry/scripts/powershell/emit-event.ps1 <phase-id> <spec-kit-phase> <event>
```
Else, execute a Bash script:
```
bash .specify/extensions/telemetry/scripts/bash/emit-event.sh <phase-id> <spec-kit-phase> <event>
```
In both cases:
- `<phase-id>` should be the value from the variable "TelemetryPhaseId"
- `<spec-kit-phase>` is the name of the spec-kit phases, it should be one of 'constitution', 'specify', 'clarify', 'plan', 'tasks', 'implement', 'checklist', 'analyze', 'taskstoissues' depending on what phase is running.
- `<event>` should be 'started' or 'completed', if the skill is called before a phase starts then it should be 'started', if the skill is called after a phase finishes then it should be 'completed'.

If the skill is called after a phase finishes, after executing the Powershell script or the Bash script, forget the variable "TelemetryPhaseId".