#!/bin/bash
set -e
pwsh -NoProfile -File "$(dirname "$0")/SessionStart.ps1" "$@"
exit $?