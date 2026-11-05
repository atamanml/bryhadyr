#!/usr/bin/env bash
# PreToolUse hook of bryhadyr, on create_tasks of the OpenTodo MCP. Same two homes as session-start.sh.
# Refuses a task that does not say where it came from (`From:`), and a task waiting for the owner (label `waiting`) that does not say
# which session asked (`Session:`). The agent gets the reason and writes the task again. The Ukrainian words `Звідки:` and `Сесія:` count too.
# Env: BRYHADYR_UNTRACKED_REPOS (regex for repository folder names that are not tracked: every task is refused there, with
# BRYHADYR_UNTRACKED_HINT as the advice), PROTOCOL_LANG=uk for the Ukrainian reason.
# Best effort: any failure (no python, bad JSON) lets the call through.
set -u
input="$(cat)"
PY=""
for p in python3 python py; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'pass' >/dev/null 2>&1; then PY="$p"; break; fi
done
[ -n "$PY" ] || exit 0
read -r -d '' PYSRC <<'PYEOF'
import json, os, re, sys

try:
    hook = json.loads(sys.argv[1])
except ValueError:
    sys.exit(0)
if not str(hook.get("tool_name") or "").endswith("create_tasks"):
    sys.exit(0)
uk = os.environ.get("PROTOCOL_LANG") == "uk"


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}, ensure_ascii=False))
    sys.exit(0)


untracked = os.environ.get("BRYHADYR_UNTRACKED_REPOS", "")
if untracked:
    try:
        if re.search(untracked, os.path.basename(str(hook.get("cwd") or "").replace("\\", "/").rstrip("/")), re.I):
            hint = os.environ.get("BRYHADYR_UNTRACKED_HINT", "")
            deny(("Протокол агентів: це репо в OpenTodo не ведемо. " if uk else "Agent protocol: this repository is not tracked in OpenTodo. ") + hint)
    except re.error:
        pass
items = (hook.get("tool_input") or {}).get("items") or []
problems = []
for item in items:
    if not isinstance(item, dict):
        continue
    description = str(item.get("description") or "")
    title = str(item.get("title") or "")[:60]
    if not re.search(r"^(From|Звідки):", description, re.M):
        problems.append(("«%s»: нема рядка «Звідки: …»" if uk else "«%s»: no line «From: …»") % title)
    labels = [str(l).lower() for l in item.get("labels") or []]
    if "waiting" in labels and not re.search(r"^(Session|Сесія):", description, re.M):
        problems.append(("«%s»: мітка waiting без рядка «Сесія: <id>»" if uk else "«%s»: label waiting without a line «Session: <id>»") % title)
if problems:
    if uk:
        deny("Протокол агентів, розділ 1. " + "; ".join(problems[:5]) + ". Допиши в описі: «Звідки: <посилання на задачу власника або його прохання одним реченням>»; "
             "для задачі, що чекає власника, ще «Сесія: <id> · <машина>» із контексту старту сесії, «Контекст: …» і «Нотатка: <шлях в Obsidian>», якщо є. Потім створи задачу знову.")
    deny("Agent protocol, section 1. " + "; ".join(problems[:5]) + ". Add to the description: «From: <link to the owner's task, or the owner's request in one sentence>»; "
         "for a task that waits for the owner also «Session: <id> · <machine>» from the session start context, «Context: …» and «Note: <Obsidian path>» if there is one. Then create the task again.")
PYEOF
PYTHONIOENCODING=utf-8 "$PY" -c "$PYSRC" "$input" 2>/dev/null || true
exit 0
