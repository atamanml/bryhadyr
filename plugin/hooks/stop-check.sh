#!/usr/bin/env bash
# Stop hook of bryhadyr. Same two homes as session-start.sh (plugin ROOT or <repo>/.claude/bryhadyr).
# Reads the hook JSON on stdin, scans the session transcript (`transcript_path`, JSONL) and, if a BIG task was done
# (more than one file edited, or a git commit made) but no OpenTodo closing call (complete_tasks / add_comment on an MCP server
# whose name has "tasks" or "OpenTodo") was made, prints {"decision":"block","reason":...} once so the agent writes the summary
# of PROTOCOL.md section 3. It blocks at most once per session: `stop_hook_active` exits at once, and a marker file
# bryhadyr-stop-<session_id> in the temp dir stops later turns (and a second registration of this hook) from blocking again.
# Small tasks and sessions without changes pass silently. No tokens are spent here and nothing is written to the tracker.
# Env: BRYHADYR_UNTRACKED_REPOS (regex for repository folder names that are not tracked: pass silently),
# PROTOCOL_LANG=uk for the Ukrainian reason.
# Best effort: any failure (no python, unreadable transcript, bad JSON) means "let it stop".
set -u
input="$(cat)"
PY=""
for p in python3 python py; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'pass' >/dev/null 2>&1; then PY="$p"; break; fi
done
[ -n "$PY" ] || exit 0
read -r -d '' PYSRC <<'PYEOF'
import hashlib, json, os, re, sys, tempfile

try:
    hook = json.loads(sys.argv[1])
except ValueError:
    sys.exit(0)
if hook.get("stop_hook_active"):
    sys.exit(0)
path = hook.get("transcript_path")
if not path:
    sys.exit(0)
untracked = os.environ.get("BRYHADYR_UNTRACKED_REPOS", "")
if untracked:
    try:
        if re.search(untracked, os.path.basename(str(hook.get("cwd") or "").replace("\\", "/").rstrip("/")), re.I):
            sys.exit(0)                                        # this repository is not tracked in OpenTodo
    except re.error:
        pass

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
SHELL_TOOLS = {"Bash", "PowerShell"}
COMMIT = re.compile(r"\bgit\b[^\n|;&]*\bcommit\b")
# scratch, temp and Claude's own memory files are not project changes
NOISE = ("/scratchpad/", "/tmp/", "/temp/", "/.claude/projects/")

files, committed, closed = set(), False, False
try:
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            msg = entry.get("message")
            content = msg.get("content") if isinstance(msg, dict) else None
            if entry.get("type") != "assistant" or not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                name, args = block.get("name") or "", block.get("input") or {}
                low = name.lower()
                if name in EDIT_TOOLS:
                    fp = str(args.get("file_path") or args.get("notebook_path") or "").replace("\\", "/")
                    if fp and not any(n in fp.lower() for n in NOISE):
                        files.add(fp.lower())
                elif name in SHELL_TOOLS:
                    command = str(args.get("command") or "")
                    if COMMIT.search(command):
                        committed = True
                    if "complete_tasks" in command or "add_comment" in command:      # the tracker reached through the shell, over ssh say
                        closed = True
                elif low.startswith("mcp__") and ("tasks" in low or "opentodo" in low):
                    if low.endswith(("complete_tasks", "add_comment")):
                        closed = True
except OSError:
    sys.exit(0)

if closed or not (len(files) > 1 or committed):
    sys.exit(0)

# at most one block per session: a marker file keyed by session_id (O_EXCL makes it atomic, so the plugin and the committed
# settings.json copy of this hook cannot both block). If the marker cannot be written, do not block.
sid = re.sub(r"[^A-Za-z0-9_-]", "_", str(hook.get("session_id") or ""))[:64]
if not sid:
    sid = hashlib.sha1(path.encode("utf-8", "replace")).hexdigest()
try:
    os.close(os.open(os.path.join(tempfile.gettempdir(), "bryhadyr-stop-" + sid), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
except OSError:
    sys.exit(0)

if os.environ.get("PROTOCOL_LANG") == "uk":
    reason = (
        "Протокол агентів: схоже, це була велика задача (змінено файлів: %d%s), але підсумок у трекері не залишено. "
        "Перед завершенням зроби розділ 3 PROTOCOL.md: add_comment у форматі розділу 4 (зроблено / перевірено / не перевірено / "
        "рішення / далі / нотатка), complete_tasks, Obsidian-нотатка за шаблоном розділу 5 і follow-up задачі. "
        "Якщо MCP «tasks» недоступний, віддай підсумок секцією у форматі Obsidian Tasks у відповіді. "
        "Якщо задача насправді мала (дрібна правка, нічого згадувати потім), просто заверши відповідь: повторно хук не блокуватиме."
    ) % (len(files), ", був коміт" if committed else "")
else:
    reason = (
        "Agent protocol: this looks like a big task (files changed: %d%s) but no summary was left in the tracker. "
        "Before you finish, do section 3 of PROTOCOL.md: add_comment in the format of section 4 (done / verified / not verified / "
        "decisions / next / note), complete_tasks, the Obsidian note from the template of section 5, and the follow-up tasks. "
        "If the MCP server «tasks» is unavailable, give the summary as an Obsidian Tasks section in the answer. "
        "If the task was really small (a minor fix, nothing to remember later), just finish the answer: the hook will not block again."
    ) % (len(files), ", a commit was made" if committed else "")
sys.stdout.write(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False) + "\n")
PYEOF
PYTHONIOENCODING=utf-8 "$PY" -c "$PYSRC" "$input" 2>/dev/null || true
exit 0
