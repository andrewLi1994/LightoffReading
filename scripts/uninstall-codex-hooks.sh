#!/usr/bin/env bash
set -euo pipefail

HOOKS_PATH="${CODEX_HOOKS_PATH:-$HOME/.codex/hooks.json}"
MARKER="LightoffReading Codex Integration"
PORT="${LIGHTOFF_READING_ACTIVITY_PORT:-38561}"

if [[ ! -f "$HOOKS_PATH" ]]; then
    echo "No Codex hooks file found at $HOOKS_PATH"
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to edit $HOOKS_PATH safely." >&2
    exit 1
fi

python3 - "$HOOKS_PATH" "$MARKER" "$PORT" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
marker = sys.argv[2]
port = sys.argv[3]

with path.open("r", encoding="utf-8") as file:
    root = json.load(file)

hooks = root.get("hooks")
if not isinstance(hooks, dict):
    print(f"No hooks object found in {path}")
    raise SystemExit(0)

removed = 0
for event in list(hooks.keys()):
    groups = hooks.get(event)
    if not isinstance(groups, list):
        continue

    next_groups = []
    for group in groups:
        if not isinstance(group, dict):
            next_groups.append(group)
            continue

        handlers = group.get("hooks")
        if not isinstance(handlers, list):
            next_groups.append(group)
            continue

        next_handlers = []
        for handler in handlers:
            status = handler.get("statusMessage", "") if isinstance(handler, dict) else ""
            command = handler.get("command", "") if isinstance(handler, dict) else ""
            is_lightoff_hook = marker in status or f"127.0.0.1:{port}/state/" in command
            if is_lightoff_hook:
                removed += 1
            else:
                next_handlers.append(handler)

        if next_handlers:
            updated_group = dict(group)
            updated_group["hooks"] = next_handlers
            next_groups.append(updated_group)

    if next_groups:
        hooks[event] = next_groups
    else:
        hooks.pop(event, None)

root["hooks"] = hooks
path.write_text(json.dumps(root, ensure_ascii=True, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(f"Removed {removed} LightoffReading Codex hook(s) from {path}")
PY
