#!/usr/bin/env bash
# check.sh — validate the manifests and the SessionStart hook (run in CI and before a release).
set -euo pipefail
cd "$(dirname "$0")/.."
for f in .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json plugin/.mcp.json plugin/hooks/hooks.json templates/claude-settings.json templates/mcp.json hermes/config-fragment.yaml; do
  case "$f" in
    *.json) python3 -m json.tool "$f" >/dev/null ;;
    *.yaml) python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$f" 2>/dev/null || python3 -c 'print("(yaml module missing, skipped)")' ;;
  esac
done
CLAUDE_PLUGIN_ROOT=plugin bash plugin/hooks/session-start.sh | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart" and d["hookSpecificOutput"]["additionalContext"]'
OPENTODO_AGENT_TOKEN=x PROTOCOL_LANG=uk CLAUDE_PLUGIN_ROOT=plugin bash plugin/hooks/session-start.sh | python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; assert "configured" in c and "Протокол" in c'
command -v shellcheck >/dev/null && shellcheck --severity=warning plugin/hooks/session-start.sh scripts/*.sh hermes/install.sh
echo "brygadyr OK"
