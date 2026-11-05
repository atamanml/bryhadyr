#!/usr/bin/env bash
# Smoke test of stop-check.sh on synthetic transcripts: big task without closing blocks; big task with closing, small task,
# no-change session and a repeated Stop (stop_hook_active) pass silently; a second Stop of the same session_id passes, another session blocks. Run: bash plugin/hooks/test-stop-check.sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Git Bash on Windows: native python cannot open /tmp/... paths
if command -v cygpath >/dev/null 2>&1; then tmp="$(cygpath -m "$tmp")"; fi

use() { printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t","name":"%s","input":%s}]}}\n' "$1" "$2"; }
user() { printf '{"type":"user","message":{"role":"user","content":"do the thing"}}\n'; }

{ user; use Edit '{"file_path":"/repo/a.py"}'; use Write '{"file_path":"/repo/b.py"}'; use Bash '{"command":"git commit -m x"}'; } >"$tmp/big-open.jsonl"
{ cat "$tmp/big-open.jsonl"; use mcp__plugin_bryhadyr_tasks__add_comment '{"id":"1"}'; use mcp__plugin_bryhadyr_tasks__complete_tasks '{}'; } >"$tmp/big-closed.jsonl"
{ user; use Edit '{"file_path":"/repo/a.py"}'; use Edit '{"file_path":"/repo/a.py"}'; use Read '{"file_path":"/repo/b.py"}'; } >"$tmp/small.jsonl"
{ user; use Read '{"file_path":"/repo/a.py"}'; use Write '{"file_path":"/tmp/x.txt"}'; use Edit '{"file_path":"/repo/only.py"}'; use Write '{"file_path":"C:\\Users\\x\\AppData\\Local\\Temp\\claude\\scratchpad\\y.txt"}'; } >"$tmp/none.jsonl"

# the hook keeps its once-per-session marker in the temp dir: point it at the test dir
export TMPDIR="$tmp" TEMP="$tmp" TMP="$tmp"
run() { # name active [session_id] -> hook stdout
  printf '{"session_id":"%s","transcript_path":"%s","hook_event_name":"Stop","stop_hook_active":%s}' "${3:-$1}" "$tmp/$1.jsonl" "$2" | bash "$here/stop-check.sh"
}
fail=0
expect_block() { out="$(run "$1" "$2" "${3:-}")"; if printf '%s' "$out" | grep -q '"decision": "block"'; then echo "ok   $1 (active=$2): blocks"; else echo "FAIL $1 (active=$2): expected block, got: $out"; fail=1; fi; }
expect_pass() { out="$(run "$1" "$2" "${3:-}")"; if [ -z "$out" ]; then echo "ok   $1 (active=$2): passes"; else echo "FAIL $1 (active=$2): expected silence, got: $out"; fail=1; fi; }

expect_block big-open false
expect_pass big-open true
expect_pass big-open false
expect_block big-open false sess-weird/../id
expect_block big-open false other-session
expect_pass big-open false other-session
expect_pass big-closed false
# a repository listed in BRYHADYR_UNTRACKED_REPOS is left alone, even after a big task
out="$(printf '{"session_id":"untracked","transcript_path":"%s/big-open.jsonl","cwd":"/work/Scraper-Repo","stop_hook_active":false}' "$tmp" | BRYHADYR_UNTRACKED_REPOS='scraper' bash "$here/stop-check.sh")"
if [ -z "$out" ]; then echo "ok   untracked repo: passes"; else echo "FAIL untracked repo: expected silence, got: $out"; fail=1; fi
# the Ukrainian reason
out="$(printf '{"session_id":"ukrainian","transcript_path":"%s/big-open.jsonl","stop_hook_active":false}' "$tmp" | PROTOCOL_LANG=uk bash "$here/stop-check.sh")"
if printf '%s' "$out" | grep -q 'велика задача'; then echo "ok   PROTOCOL_LANG=uk: Ukrainian reason"; else echo "FAIL Ukrainian reason: $out"; fail=1; fi
expect_pass small false
expect_pass none false
out="$(printf '{"transcript_path":"%s/missing.jsonl"}' "$tmp" | bash "$here/stop-check.sh")"; [ -z "$out" ] || { echo "FAIL missing transcript: $out"; fail=1; }
out="$(printf 'not json' | bash "$here/stop-check.sh")"; [ -z "$out" ] || { echo "FAIL bad stdin: $out"; fail=1; }
[ "$fail" = 0 ] && echo "stop-check OK"
exit "$fail"
