#!/bin/bash
set -e
pwsh -NoProfile -File "$(dirname "$0")/UploadLog.ps1" "$@"
exit $?