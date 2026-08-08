#!/usr/bin/env bash
# Nautilus script: copy to ~/.local/share/nautilus/scripts/ and chmod +x
TARGET="$1"
exec repodrive open-issues "$TARGET"
