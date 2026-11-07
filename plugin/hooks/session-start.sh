#!/usr/bin/env bash
# SessionStart hook of bryhadyr. Two homes, one script:
#   * the plugin (server, laptop): ROOT = ${CLAUDE_PLUGIN_ROOT}
#   * a committed copy in a repo (cloud sessions install no plugins): ROOT = <repo>/.claude/bryhadyr
# Prints JSON with `additionalContext`: the protocol (PROTOCOL.md next to this script, PROTOCOL.<lang>.md when PROTOCOL_LANG is set),
# the repo name, whether the OpenTodo MCP server is reachable from here (registered in user scope, or the token is in the environment)
# and the id of this session, which a task that waits for the owner needs (protocol section 3a).
# Optional live refresh: with PROTOCOL_SOURCE_REPO=owner/repo and a working `gh`, a fresher PROTOCOL.md is fetched from that repo's
# default branch (≤ 5 s), so a push reaches machines whose copy is behind.
# BRYHADYR_UNTRACKED_REPOS: a regular expression for repository folder names that stay out of the tracker (BRYHADYR_UNTRACKED_HINT says
# where their tasks go instead). No secrets are read or printed.
set -u
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -f "$ROOT/PROTOCOL.md" ] || ROOT="$(cd "$(dirname "$0")" && pwd)"
file="PROTOCOL.md"; [ -n "${PROTOCOL_LANG:-}" ] && [ -f "$ROOT/PROTOCOL.${PROTOCOL_LANG}.md" ] && file="PROTOCOL.${PROTOCOL_LANG}.md"
top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo="$(basename "$top")"
protocol="$(cat "$ROOT/$file" 2>/dev/null || echo "PROTOCOL.md not found next to $0")"
origin="local copy"
if [ -n "${PROTOCOL_SOURCE_REPO:-}" ] && command -v gh >/dev/null 2>&1; then
  live="$(timeout 5 gh api "repos/${PROTOCOL_SOURCE_REPO}/contents/plugin/${file}" -H 'Accept: application/vnd.github.raw' 2>/dev/null)" || live=""
  if [ -n "$live" ] && [ "$live" != "$protocol" ]; then protocol="$live"; origin="fresh copy from ${PROTOCOL_SOURCE_REPO}"; fi
fi
# a working python: `python3` may be a dead stub (Windows Store alias), so try each candidate and run it once
PY=""
for p in python3 python py; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'pass' >/dev/null 2>&1; then PY="$p"; break; fi
done
user_scope=""
if [ -n "$PY" ] && [ -f "$HOME/.claude.json" ]; then
  user_scope="$("$PY" -c 'import json,os; print("yes" if "tasks" in json.load(open(os.path.expanduser("~/.claude.json"),encoding="utf-8")).get("mcpServers",{}) else "")' 2>/dev/null)"
fi
untracked=""
if [ -n "${BRYHADYR_UNTRACKED_REPOS:-}" ] && printf '%s' "$repo" | grep -qiE -- "$BRYHADYR_UNTRACKED_REPOS"; then untracked=1; fi
if [ -n "$untracked" ]; then
  mcp="This repository is not tracked in OpenTodo: leave the tracker alone. ${BRYHADYR_UNTRACKED_HINT:-}"
elif [ -n "$user_scope" ]; then
  mcp="MCP «tasks» is configured (user scope): write tasks directly."
elif [ -n "${OPENTODO_AGENT_TOKEN:-}" ] && [ -f "$top/.mcp.json" ]; then
  mcp="MCP «tasks» is configured (${OPENTODO_MCP_URL:-http://127.0.0.1:8080/mcp}): write tasks directly."
else
  mcp="MCP «tasks» is not registered here (neither user scope nor a repo .mcp.json with OPENTODO_AGENT_TOKEN). Put tasks in the final answer as an Obsidian Tasks list under «## ${repo}» (protocol section 3, fallback), or use the claude.ai connector if the session has one."
fi
# a chat outside any repository: a direction folder (CLAUDE.md or HANDOFF.md inside) is fine and gets no warning;
# any other folder gets a hint to move into the direction's folder (protocol section 7)
if ! git rev-parse --show-toplevel >/dev/null 2>&1 && [ ! -f CLAUDE.md ] && [ ! -f HANDOFF.md ]; then
  if [ "${PROTOCOL_LANG:-}" = "uk" ]; then
    mcp="$mcp Чат без папки напрямку ($(pwd)): пам'ять (CLAUDE.md, HANDOFF.md) сюди не підтягнеться. Якщо тема про напрямок, перейди в його папку через change_directory (таблиця напрямків у глобальному CLAUDE.md, розділ 7 протоколу) і прочитай HANDOFF.md."
  else
    mcp="$mcp A chat without a direction folder ($(pwd)): its memory (CLAUDE.md, HANDOFF.md) is not loaded here. If the topic belongs to a direction, switch to its folder with change_directory (the table of directions is in the global CLAUDE.md, protocol section 7) and read HANDOFF.md."
  fi
fi
# the session id arrives in the hook's JSON on stdin (not when run by hand from a terminal)
input=""
[ -t 0 ] || IFS= read -r -t 2 input || true
sid="$(printf '%s' "$input" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p')"
if [ -n "$sid" ]; then
  label="Session"; [ "${PROTOCOL_LANG:-}" = "uk" ] && label="Сесія"
  mcp="$mcp Line for a task that waits for the owner: $label: $sid · $(hostname)"
fi
ctx="$(printf '## Agent protocol (bryhadyr; repo: %s; %s)\n%s\n\n%s\n' "$repo" "$origin" "$mcp" "$protocol")"
if [ -n "$PY" ]; then
  PYTHONIOENCODING=utf-8 "$PY" -c 'import json, sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]}}, ensure_ascii=False))' "$ctx"
else
  printf '%s\n' "$ctx"     # plain stdout is accepted as context for SessionStart too
fi
