#!/usr/bin/env bash
# SessionStart hook of bryhadyr. Two homes, one script:
#   * the plugin (server, laptop): ROOT = ${CLAUDE_PLUGIN_ROOT}
#   * a committed copy in a repo (cloud sessions install no plugins): ROOT = <repo>/.claude/bryhadyr
# Prints JSON with `additionalContext`: the protocol (PROTOCOL.md next to this script, PROTOCOL.<lang>.md when PROTOCOL_LANG is set),
# the repo name and whether the OpenTodo MCP token is present. Optional live refresh: with PROTOCOL_SOURCE_REPO=owner/repo and a working
# `gh`, a fresher PROTOCOL.md is fetched from that repo's default branch (≤ 5 s), so a push reaches machines whose copy is behind.
# No secrets are read or printed.
set -u
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -f "$ROOT/PROTOCOL.md" ] || ROOT="$(cd "$(dirname "$0")" && pwd)"
file="PROTOCOL.md"; [ -n "${PROTOCOL_LANG:-}" ] && [ -f "$ROOT/PROTOCOL.${PROTOCOL_LANG}.md" ] && file="PROTOCOL.${PROTOCOL_LANG}.md"
repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
protocol="$(cat "$ROOT/$file" 2>/dev/null || echo "PROTOCOL.md not found next to $0")"
origin="local copy"
if [ -n "${PROTOCOL_SOURCE_REPO:-}" ] && command -v gh >/dev/null 2>&1; then
  live="$(timeout 5 gh api "repos/${PROTOCOL_SOURCE_REPO}/contents/plugin/${file}" -H 'Accept: application/vnd.github.raw' 2>/dev/null)" || live=""
  if [ -n "$live" ] && [ "$live" != "$protocol" ]; then protocol="$live"; origin="fresh copy from ${PROTOCOL_SOURCE_REPO}"; fi
fi
if [ -n "${OPENTODO_AGENT_TOKEN:-}" ]; then
  mcp="MCP «tasks» is configured (${OPENTODO_MCP_URL:-http://127.0.0.1:8080/mcp}): write tasks directly."
else
  mcp="OPENTODO_AGENT_TOKEN is not set: MCP «tasks» is unavailable here. Put tasks in the final answer as an Obsidian Tasks list under «## ${repo}» (protocol section 3, fallback), or use the claude.ai connector if the session has one."
fi
ctx="$(printf '## Agent protocol (bryhadyr; repo: %s; %s)\n%s\n\n%s\n' "$repo" "$origin" "$mcp" "$protocol")"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$ctx" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]}}, ensure_ascii=False))
PY
else
  printf '%s\n' "$ctx"     # plain stdout is accepted as context for SessionStart too
fi
