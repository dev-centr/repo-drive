#!/usr/bin/env bash
# macOS Quick Action / Automator shell script wrapper.
# Install: Automator > Quick Action > Run Shell Script > Pass input as arguments
#   /path/to/repo-drive/shell/macos/open-in-issues-browser.sh "$@"
set -euo pipefail
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <path>" >&2
  exit 1
fi
exec repodrive open-issues "$TARGET"
