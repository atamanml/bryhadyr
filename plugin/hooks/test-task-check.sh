#!/usr/bin/env bash
# Smoke test of task-check.sh (PreToolUse on create_tasks): a task without «From:» is refused, a `waiting` task without «Session:» is refused,
# complete tasks (English or Ukrainian words) pass, other tools pass, a repository from BRYHADYR_UNTRACKED_REPOS is refused.
# Run: bash plugin/hooks/test-task-check.sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
fail=0
run() { printf '%s' "$1" | env "${@:2}" bash "$here/task-check.sh"; }
expect_deny() { out="$(run "$2" "${@:3}")"; if printf '%s' "$out" | grep -q '"permissionDecision": "deny"'; then echo "ok   $1: denied"; else echo "FAIL $1: expected deny, got: $out"; fail=1; fi; }
expect_pass() { out="$(run "$2" "${@:3}")"; if [ -z "$out" ]; then echo "ok   $1: passes"; else echo "FAIL $1: expected silence, got: $out"; fail=1; fi; }
call() { printf '{"tool_name":"mcp__plugin_bryhadyr_tasks__create_tasks","cwd":"%s","tool_input":{"items":[%s]}}' "${2:-/work/app}" "$1"; }

expect_deny "no From:" "$(call '{"title":"Fix login","description":"Done when: it works"}')" X=1
expect_pass "From: given" "$(call '{"title":"Fix login","description":"From: the owner asked to fix login\nDone when: it works"}')" X=1
expect_pass "Ukrainian Звідки:" "$(call '{"title":"Виправити вхід","description":"Звідки: власник просив\nГотово, коли: працює"}')" X=1
expect_deny "waiting without Session:" "$(call '{"title":"Which plan?","labels":["waiting"],"description":"From: a question\nContext: two options"}')" X=1
expect_pass "waiting with Session:" "$(call '{"title":"Which plan?","labels":["waiting"],"description":"From: a question\nSession: 0b8c1d52-1111-4222-8333-444455556666 · box"}')" X=1
expect_pass "other tool" '{"tool_name":"mcp__plugin_bryhadyr_tasks__list_tasks","tool_input":{}}' X=1
expect_deny "untracked repo" "$(call '{"title":"x","description":"From: y"}' /work/Scraper-Repo)" BRYHADYR_UNTRACKED_REPOS=scraper BRYHADYR_UNTRACKED_HINT='Write to notes.md.'
expect_pass "tracked repo with the variable set" "$(call '{"title":"x","description":"From: y"}' /work/app)" BRYHADYR_UNTRACKED_REPOS=scraper
out="$(printf 'not json' | bash "$here/task-check.sh")"; [ -z "$out" ] || { echo "FAIL bad stdin: $out"; fail=1; }
[ "$fail" = 0 ] && echo "task-check OK"
exit "$fail"
