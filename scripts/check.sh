#!/usr/bin/env bash
# check.sh — validate the manifests, the three hooks (with their tests), the Python scripts of stack/ (with their tests) and the shell scripts.
# Run in CI and before a release. Needs bash, python3; shellcheck and PyYAML are used when present.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== manifests"
for f in .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json plugin/hooks/hooks.json templates/claude-settings.json templates/mcp.json stack/notes-rules.example.json hermes/config-fragment.yaml; do
  case "$f" in
    *.json) python3 -m json.tool "$f" >/dev/null ;;
    *.yaml) python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$f" 2>/dev/null || python3 -c 'print("(yaml module missing, skipped)")' ;;
  esac
done
[ ! -e plugin/.mcp.json ] || { echo "plugin/.mcp.json must not exist: the plugin registers no MCP server (templates/mcp.json is the one to copy)"; exit 1; }

echo "== SessionStart hook"
CLAUDE_PLUGIN_ROOT=plugin bash plugin/hooks/session-start.sh </dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart" and d["hookSpecificOutput"]["additionalContext"]'
# token + a repo .mcp.json -> "configured"; Ukrainian protocol; the session id from the hook input becomes a ready-to-paste line
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/repo" "$T/home"; cp templates/mcp.json "$T/repo/.mcp.json"; ( cd "$T/repo" && git init -q . )
( cd "$T/repo" && HOME="$T/home" OPENTODO_AGENT_TOKEN=x PROTOCOL_LANG=uk CLAUDE_PLUGIN_ROOT="$OLDPWD/plugin" bash "$OLDPWD/plugin/hooks/session-start.sh" \
    <<<'{"session_id":"0b8c1d52-1111-4222-8333-444455556666","hook_event_name":"SessionStart"}' ) \
  | python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; assert "configured" in c and "Протокол" in c and "Сесія: 0b8c1d52-1111-4222-8333-444455556666" in c, c'
# MCP registered in user scope
echo '{"mcpServers":{"tasks":{}}}' > "$T/home/.claude.json"
( cd "$T/repo" && HOME="$T/home" OPENTODO_AGENT_TOKEN='' CLAUDE_PLUGIN_ROOT="$OLDPWD/plugin" bash "$OLDPWD/plugin/hooks/session-start.sh" </dev/null ) \
  | python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; assert "user scope" in c, c'
# a repository from BRYHADYR_UNTRACKED_REPOS is left alone
( cd "$T/repo" && HOME="$T/home" BRYHADYR_UNTRACKED_REPOS='repo' BRYHADYR_UNTRACKED_HINT='Put tasks in notes.md.' CLAUDE_PLUGIN_ROOT="$OLDPWD/plugin" bash "$OLDPWD/plugin/hooks/session-start.sh" </dev/null ) \
  | python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; assert "not tracked" in c and "notes.md" in c, c'

echo "== Stop and PreToolUse hooks"
bash plugin/hooks/test-stop-check.sh
bash plugin/hooks/test-task-check.sh

echo "== stack/ scripts"
python3 -m py_compile stack/notes_mirror.py stack/task_replies.py stack/test_stack.py
python3 stack/test_stack.py

echo "== secrets and private names in tracked files"
if git ls-files -z | xargs -0 grep -nIE 'ot_[A-Za-z0-9_-]{16,}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY|[a-z0-9-]+\.ts\.net' | grep -vE '<host>\.|<tailnet>' ; then
  echo "the lines above look like a secret or a real tailnet name"; exit 1
fi

if command -v shellcheck >/dev/null; then
  echo "== shellcheck"
  shellcheck --severity=warning plugin/hooks/*.sh scripts/*.sh hermes/install.sh
fi
echo "bryhadyr OK"
