#!/usr/bin/env bash
# Browser checks for theme toggle + latest video. Needs the repo root served on :8765 with a latest.json.
set -euo pipefail
CHROME="${CHROME:-$HOME/.cache/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-linux64/chrome-headless-shell}"
PROFILE="$(mktemp -d)"
"$CHROME" --headless --no-sandbox --disable-gpu --user-data-dir="$PROFILE" \
  --force-dark-mode --blink-settings=preferredColorScheme=0 --virtual-time-budget=10000 \
  --dump-dom "http://127.0.0.1:8765/tools/test/theme-test.html" 2>/dev/null \
  | sed 's/<pre id="out">//' | grep -E '^RESULT (PASS|FAIL)|^DONE$' || true
rm -rf "$PROFILE"
