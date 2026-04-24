#!/bin/bash
set -e
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    pwsh -NoProfile -File "$(dirname "$0")/SessionStart.ps1" "$@"
    exit $?
    ;;
esac

session_id=$(jq -r '.session_id')

if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export SESSION_ID=$session_id" >> "$CLAUDE_ENV_FILE"
fi

exit 0