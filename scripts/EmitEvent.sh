#!/bin/bash
set -e
pwsh -NoProfile -File "$(dirname "$0")/EmitEvent.ps1" "$@"
exit $?