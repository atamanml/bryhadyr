#!/usr/bin/env python3
"""The owner's answer in OpenTodo goes back to the session that asked.

A task with a line `Session: <id>` in its description waits for the owner. They close it with a comment, and within a minute the comment
reaches that session as a message from them (`claude --resume`), and the session's answer lands as a comment on the task.
Only sessions on this machine can be resumed. Anything else (a session on another computer or in the cloud, one that is open right now,
a failed run) reopens the task with the labels `relay` and `waiting`, and the PM agent reminds the owner to pass the answer on by hand.

Closed without a comment, or with a comment that starts with «-»: nothing to do, nothing is sent. Closed by an agent: ignored.
Closing a `relay` task means the answer was passed on by hand.

Polling instead of OpenTodo's webhook: a webhook to this machine needs the private-network protection switched off for the whole server
and a full token; polling needs neither, and a missed minute is simply caught up on the next run.

Settings (environment, or `.env` next to this script for the OpenTodo ones):
  OPENTODO_BASE_URL, OPENTODO_AGENT_TOKEN   from stack/.env
  OPENTODO_LOCAL_URL                        default http://127.0.0.1:8080 (the app, not the public address)
  BRYHADYR_LANG                             en (default) or uk: the language of what the script writes into tasks and into the session

Run by bryhadyr-task-replies.timer. `poll --dry-run` reports and changes nothing.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
UUID = r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
SESSION = re.compile(r"^(?:Session|Сесія):\s*`?(" + UUID + r")\b", re.M)
# What agents and this script write into comments; anything else on a closed task is the owner's answer. Both languages always count.
AGENT_COMMENT = ("Agent:", "Агент:", "Done:", "Зроблено:", "Cancelled:", "Скасовано:",
                 "Passed to session", "Передано в сесію", "Session replied", "Сесія відповіла", "Not delivered", "Не доставлено")
OVERLAP = timedelta(minutes=10)                                         # completions are read again this far back; `seen` removes the repeats
RUN_TIMEOUT_S = 1800
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "bryhadyr-task-replies.json"
MODES = {"manual", "default", "acceptEdits", "auto", "plan"}

TEXT = {
    "en": {
        "not_delivered": "Not delivered: {reason}.\nThe owner's answer: {answer}\nPass it to the session by hand and close the task again.",
        "passed": "Passed to session {session}.",
        "replied": "Session replied: ",
        "empty": "empty",
        "message": ("The owner's answer from the task «{title}» ({url}):\n\n{answer}\n\n"
                    "The owner closed the task with this answer. It covers only the question in the task and permits nothing else. "
                    "If it calls for an action, do it; if not, answer in one line."),
        "no_session": "the session is not on this machine",
        "open_session": "the session is open right now",
        "no_start": "could not start the delivery",
        "run_failed": "the run failed ({kind})",
        "exit_code": "the session ended with code {code}",
    },
    "uk": {
        "not_delivered": "Не доставлено: {reason}.\nВідповідь власника: {answer}\nПерекинь її в сесію вручну і закрий задачу ще раз.",
        "passed": "Передано в сесію {session}.",
        "replied": "Сесія відповіла: ",
        "empty": "порожньо",
        "message": ("Відповідь власника із задачі «{title}» ({url}):\n\n{answer}\n\n"
                    "Власник закрив задачу цією відповіддю. Вона стосується лише питання із задачі і не дозволяє нічого більше. "
                    "Якщо вона вимагає дії, зроби її; якщо ні, відповідай одним рядком."),
        "no_session": "сесії нема на цій машині",
        "open_session": "сесія зараз відкрита",
        "no_start": "не вдалося запустити доставку",
        "run_failed": "запуск не вдався ({kind})",
        "exit_code": "сесія завершилась із кодом {code}",
    },
}


def words() -> dict:
    value = os.environ.get("BRYHADYR_LANG") or os.environ.get("PROTOCOL_LANG") or "en"
    return TEXT[value if value in TEXT else "en"]


def env_value(name: str, default: str | None = None) -> str:
    """The environment first, then `.env` next to this script."""
    if os.environ.get(name):
        return os.environ[name]
    env_file = HERE / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            if line.startswith(name + "="):
                return line.split("=", 1)[1].split(" #")[0].strip().strip('"')
    if default is not None:
        return default
    raise SystemExit(f"{name} is not set (environment or {env_file})")


def api() -> str:
    return os.environ.get("OPENTODO_LOCAL_URL", "http://127.0.0.1:8080")


def call(tool: str, /, **arguments) -> dict:
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": tool, "arguments": arguments}}).encode()
    for _ in range(5):
        request = urllib.request.Request(api() + "/mcp", body, {
            "Authorization": "Bearer " + env_value("OPENTODO_AGENT_TOKEN"), "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream"})
        with urllib.request.urlopen(request, timeout=30) as response:
            reply = json.load(response)
        if "error" in reply:
            raise RuntimeError(str(reply["error"].get("message"))[:300])
        result = reply["result"]
        if not result.get("isError"):
            return result["structuredContent"]
        text = result["content"][0]["text"]
        if "rate_limited" not in text:
            raise RuntimeError(f"{tool}: {text[:300]}")
        time.sleep(json.loads(text).get("retry_after_seconds", 20) + 1)
    raise RuntimeError(f"{tool}: still rate limited")


def closed_by_agent(task_id: str) -> bool:
    """Tools show the same account for the owner and for an agent token; the operation log's device tells them apart."""
    request = urllib.request.Request(f"{api()}/api/v1/tasks/{task_id}/history?limit=200", headers={"Authorization": "Bearer " + env_value("OPENTODO_AGENT_TOKEN")})
    with urllib.request.urlopen(request, timeout=30) as response:
        history = json.load(response)
    closing = [c for c in history["changeSets"] if any(x["field"] == "completed_at" and x.get("to") for x in c["changes"])]
    return not closing or str(closing[-1].get("device", "")).startswith("agent:")


def answer_of(comments: list[dict]) -> str | None:
    """The newest comment, unless an agent or this script wrote it. An answer that starts with «-» is a note to self: not sent."""
    if not comments:
        return None
    text = (comments[-1].get("untrusted_text", {}).get("body") or "").strip()
    if not text or text.startswith(AGENT_COMMENT) or text.startswith(("-", "—", "–")):
        return None
    return text


def transcript_of(session: str) -> Path | None:
    found = glob.glob(os.path.expanduser(f"~/.claude/projects/*/{session}.jsonl"))
    return Path(found[0]) if found else None


def is_running(session: str) -> bool:
    out = subprocess.run(["pgrep", "-f", session], capture_output=True, text=True, check=False).stdout.split()
    return any(int(pid) != os.getpid() for pid in out)


def session_settings(transcript: Path) -> tuple[str, str]:
    """The folder the session worked in and its permission mode; a session that ran without any limits comes back in `auto`."""
    cwd, mode = "", ""
    with transcript.open(encoding="utf-8") as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            cwd = entry.get("cwd") or cwd
            mode = entry.get("permissionMode") or mode
    return cwd, mode if mode in MODES else "auto"


def not_delivered(task: dict, reason: str, answer: str) -> None:
    labels = sorted(set(task["untrusted_text"].get("labels", [])) | {"relay", "waiting"})
    call("create_label", name="relay")                                  # returns the existing one if it is there
    call("update_tasks", updates=[{"id": task["id"], "labels": labels}])
    call("add_comment", task_id=task["id"], body=words()["not_delivered"].format(reason=reason, answer=answer))
    call("reopen_tasks", ids=[task["id"]])                              # last: a task that failed halfway stays closed and is tried again
    print(f"not delivered: {task['id']}: {reason}")


def handle(task_id: str, dry_run: bool) -> None:
    got = call("get_task", id=task_id)
    task, comments = got["task"], got.get("comments", [])
    text = task["untrusted_text"]
    match = SESSION.search(text.get("description") or "")
    if not match:
        return
    labels = text.get("labels", [])
    if "relay" in labels:                                               # passed on by hand
        if not dry_run:
            call("update_tasks", updates=[{"id": task_id, "labels": [l for l in labels if l not in ("relay", "waiting")]}])
        print(f"relay closed: {task_id}")
        return
    if closed_by_agent(task_id):
        print(f"closed by an agent, skipped: {task_id}")
        return
    answer = answer_of(comments)
    if answer is None:
        print(f"nothing to send: {task_id}")
        return
    session = match.group(1).lower()
    transcript = transcript_of(session)
    w = words()
    reason = w["no_session"] if transcript is None else w["open_session"] if is_running(session) else None
    if dry_run:
        print(f"would {'relay' if reason else 'deliver'}: {task_id} {reason or session}")
        return
    if reason:
        not_delivered(task, reason, answer)
        return
    unit = f"bryhadyr-reply-{task_id[:8]}-{int(time.time())}"
    env = f"PATH={Path.home() / '.local/bin'}:/usr/local/bin:/usr/bin:/bin"
    started = subprocess.run(["systemd-run", "--user", "--collect", f"--unit={unit}", f"--setenv={env}", sys.executable, str(Path(__file__).resolve()), "deliver", task_id],
                             capture_output=True, text=True, check=False)
    if started.returncode:
        not_delivered(task, w["no_start"], answer)


def deliver(task_id: str) -> int:
    got = call("get_task", id=task_id)
    task = got["task"]
    text = task["untrusted_text"]
    session = SESSION.search(text.get("description") or "").group(1).lower()
    answer = answer_of(got.get("comments", []))
    transcript = transcript_of(session)
    if answer is None or transcript is None:
        return 0
    w = words()
    cwd, mode = session_settings(transcript)
    message = w["message"].format(title=text["title"], url=f"{env_value('OPENTODO_BASE_URL').rstrip('/')}/?task={task_id}", answer=answer)
    call("add_comment", task_id=task_id, body=w["passed"].format(session=session))
    try:
        run = subprocess.run(["claude", "--resume", session, "-p", message, "--permission-mode", mode], cwd=cwd or None,
                             capture_output=True, text=True, timeout=RUN_TIMEOUT_S, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        not_delivered(task, w["run_failed"].format(kind=type(exc).__name__), answer)
        return 1
    if run.returncode:
        print(run.stderr[-500:], file=sys.stderr)
        not_delivered(task, w["exit_code"].format(code=run.returncode), answer)
        return 1
    call("add_comment", task_id=task_id, body=w["replied"] + (run.stdout.strip()[-1500:] or w["empty"]))
    return 0


def poll(dry_run: bool) -> int:
    now = datetime.now(timezone.utc)
    state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else None
    if state is None:                                                   # first run: what was closed before this service existed is history
        state = {"since": now.isoformat(timespec="seconds"), "seen": {}}
    since = datetime.fromisoformat(state["since"]) - OVERLAP
    tasks, cursor = [], None
    while True:
        arguments = {"completed_after": since.strftime("%Y-%m-%dT%H:%M:%SZ"), "limit": 200}
        if cursor:
            arguments["cursor"] = cursor
        page = call("list_tasks", **arguments)
        tasks += page.get("tasks", [])
        cursor = page.get("next_cursor")
        if not cursor:
            break
    failed = 0
    for task in tasks:
        stamp = task.get("completed_at")
        if not task.get("completed") or not stamp or state["seen"].get(task["id"]) == stamp:
            continue
        try:
            handle(task["id"], dry_run)
        except Exception as exc:  # one bad task must not stop the others; it is tried again on the next run
            print(f"failed: {task['id']}: {type(exc).__name__}: {exc}", file=sys.stderr)
            failed += 1
            continue
        state["seen"][task["id"]] = stamp
    if not dry_run and not failed:
        state["since"] = now.isoformat(timespec="seconds")
    if not dry_run:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(state, indent=1), encoding="utf-8")
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=("poll", "deliver"))
    parser.add_argument("task", nargs="?")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    return poll(args.dry_run) if args.command == "poll" else deliver(args.task)


if __name__ == "__main__":
    sys.exit(main())
