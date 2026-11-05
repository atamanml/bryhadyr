#!/usr/bin/env python3
"""One-way mirror of Obsidian project notes into OpenTodo, so a note can be read rendered next to its tasks.

Obsidian stays the source: a mirrored note says so in its first line and the next change of the file overwrites edits made
in OpenTodo. A note whose frontmatter has `task: <uuid>` also links both ways: the task gets a chip that opens the note in
Obsidian (unless it already has an origin, such as a PR) and a line in its description with a link to the mirrored note.

Only the files named by the rules file are read. The vault may also hold private notes, so the rules are an allowlist on purpose:
a new project folder goes into the rules file by hand (see notes-rules.example.json). Files that look like they hold a secret are
skipped and reported.

Settings (environment, or `.env` next to this script for the OpenTodo ones):
  OPENTODO_BASE_URL, OPENTODO_AGENT_TOKEN   from stack/.env
  OPENTODO_MCP_URL                          default http://127.0.0.1:8080/mcp
  OBSIDIAN_VAULT                            default ~/obsidian
  OBSIDIAN_VAULT_NAME                       the vault's name on the device that opens obsidian:// links; default: the folder name of OBSIDIAN_VAULT
  BRYHADYR_NOTES_RULES                      default ~/.config/bryhadyr/notes-rules.json
  BRYHADYR_LANG                             en (default) or uk: the language of the lines the script writes into OpenTodo

Run by bryhadyr-notes-mirror.timer. `--dry-run` reports and writes nothing. Exit 1 if any file failed.
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

SECRET = re.compile(r"\bot_[A-Za-z0-9_-]{16,}|\bsk-[A-Za-z0-9_-]{16,}|\bgh[pousr]_[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY")
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n?", re.S)
TASK_ID = re.compile(r"^task:\s*[\"']?([0-9a-fA-F]{8}-[0-9a-fA-F-]{27})\b", re.M)
NAMESPACE = uuid.UUID("6f1d0c52-8d5e-4a55-9a43-0f2f6c1f7a10")  # note ids derive from the path, so a lost state cannot duplicate notes
MAX_TEXT = 19_000                                                       # OpenTodo refuses a note over 20 000 characters
RENDER_VERSION = "3"                                                    # raise when render() changes, so every note is written again
HERE = Path(__file__).resolve().parent

TEXT = {
    "en": {
        "head": "> Copy from Obsidian, edit it there: `{path}`",
        "task": "task",
        "attachment": "*(attachment: {name})*",
        "cut": "*Cut: {size} characters, OpenTodo allows 20 000. The full text is in Obsidian.*",
        "note": "Note",
    },
    "uk": {
        "head": "> Копія з Obsidian, правити там: `{path}`",
        "task": "задача",
        "attachment": "*(вкладення: {name})*",
        "cut": "*Обрізано: {size} символів, ліміт OpenTodo 20 000. Повний текст в Obsidian.*",
        "note": "Нотатка",
    },
}


def lang() -> str:
    value = os.environ.get("BRYHADYR_LANG") or os.environ.get("PROTOCOL_LANG") or "en"
    return value if value in TEXT else "en"


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


class ToolError(RuntimeError):
    pass


class Tool:
    """`tools/call` of the local OpenTodo MCP. Waits out the limit of 30 writes a minute."""

    def __init__(self, url: str, token: str) -> None:
        self.url, self.token = url, token

    def __call__(self, name: str, **arguments) -> dict:
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": name, "arguments": arguments}}).encode()
        for _ in range(5):
            request = urllib.request.Request(self.url, body, {
                "Authorization": "Bearer " + self.token, "Content-Type": "application/json", "Accept": "application/json, text/event-stream",
            })
            with urllib.request.urlopen(request, timeout=30) as response:
                reply = json.load(response)
            if "error" in reply:
                raise ToolError(str(reply["error"].get("message"))[:300])
            result = reply["result"]
            if not result.get("isError"):
                return result["structuredContent"]
            text = result["content"][0]["text"]
            if "rate_limited" not in text:
                raise ToolError(text[:300])
            time.sleep(json.loads(text).get("retry_after_seconds", 20) + 1)
        raise ToolError(f"{name}: still rate limited")


def load_rules(path: Path) -> tuple[str, list[tuple[str, str]]]:
    """(root folder under the vault, [(glob under the root, OpenTodo project), ...]) from the rules file."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        root, rules = str(data["root"]), [(str(p), str(project)) for p, project in data["rules"]]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(f"cannot read the rules file {path}: {exc}. Copy stack/notes-rules.example.json there and edit it.")
    if not root or not rules:
        raise SystemExit(f"{path}: needs a non-empty \"root\" and \"rules\"")
    return root, rules


def project_for(rel: str, rules: list[tuple[str, str]]) -> str | None:
    for pattern, project in rules:
        if fnmatch.fnmatchcase(rel, pattern) and rel.count("/") == pattern.count("/"):
            return project
    return None


def obsidian_url(vault: str, path: str) -> str:
    return "obsidian://open?vault=%s&file=%s" % (urllib.parse.quote(vault, safe=""), urllib.parse.quote(path.removesuffix(".md"), safe=""))


def render(text: str, path: str, task_url: str | None, language: str = "en") -> str:
    """The note's text for OpenTodo: a pointer to the source, then the Markdown without frontmatter and without wiki syntax."""
    words = TEXT[language]
    body = FRONTMATTER.sub("", text, count=1)
    body = re.sub(r"!\[\[([^\]|]+)(\|[^\]]*)?\]\]", lambda m: words["attachment"].format(name=m.group(1)), body)
    body = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", body)
    body = re.sub(r"\[\[([^\]]+)\]\]", r"\1", body)
    head = words["head"].format(path=path)                              # OpenTodo strips obsidian:// links from Markdown, only the task chip opens them
    if task_url:
        head += f" · [{words['task']}]({task_url})"
    out = head + "\n\n" + body.strip() + "\n"
    if len(out) <= MAX_TEXT:
        return out
    return out[:MAX_TEXT].rsplit("\n", 1)[0] + "\n\n" + words["cut"].format(size=len(out)) + "\n"


def link_task(tool: Tool, task_id: str, path: str, url: str, note_url: str, title: str, language: str = "en") -> None:
    task = tool("get_task", id=task_id)["task"]
    if not task.get("origin"):
        tool("update_tasks", updates=[{"id": task_id, "origin": {"kind": "obsidian", "id": path, "url": url}}])
    if note_url not in (task.get("untrusted_text", {}).get("description") or ""):
        tool("append_to_note", task_id=task_id, text=f"{TEXT[language]['note']}: [{title}]({note_url})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    vault = Path(os.environ.get("OBSIDIAN_VAULT", Path.home() / "obsidian"))
    vault_name = os.environ.get("OBSIDIAN_VAULT_NAME") or vault.name   # what obsidian:// links open on the device
    rules_path = Path(os.environ.get("BRYHADYR_NOTES_RULES", Path.home() / ".config/bryhadyr/notes-rules.json"))
    root_name, rules = load_rules(rules_path)
    language = lang()
    base_url = env_value("OPENTODO_BASE_URL").rstrip("/")
    tool = Tool(env_value("OPENTODO_MCP_URL", "http://127.0.0.1:8080/mcp"), env_value("OPENTODO_AGENT_TOKEN"))
    state_path = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "bryhadyr-notes-mirror.json"
    state: dict[str, str] = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    projects = {p["untrusted_text"]["name"]: p["id"] for p in tool("list_projects")["projects"]}

    failed = changed = 0
    seen: set[str] = set()
    root = vault / root_name
    for file in sorted(root.rglob("*.md")):
        rel = file.relative_to(root).as_posix()
        project = project_for(rel, rules)
        if project is None or ".conflict." in rel:
            continue
        seen.add(rel)
        path = f"{root_name}/{rel}"
        try:
            text = file.read_text(encoding="utf-8")
            if SECRET.search(text):
                print(f"skipped, looks like a secret: {rel}", file=sys.stderr)
                failed += 1
                continue
            frontmatter = FRONTMATTER.match(text)
            task = TASK_ID.search(frontmatter.group(1)) if frontmatter else None
            task_id = task.group(1).lower() if task else None
            digest = hashlib.sha256("\0".join((RENDER_VERSION, language, text, project, vault_name, base_url)).encode()).hexdigest()
            if state.get(rel) == digest:
                continue
            changed += 1
            if project not in projects:
                raise ToolError(f"no project {project}")
            if args.dry_run:
                print(f"would mirror: {rel} -> {project}" + (f" (task {task_id[:8]})" if task_id else ""))
                continue
            note_id = str(uuid.uuid5(NAMESPACE, path))
            link = obsidian_url(vault_name, path)
            content = render(text, path, f"{base_url}/?task={task_id}" if task_id else None, language)
            try:
                version = tool("get_note", id=note_id)["note"]["body_version"]
            except ToolError:
                tool("create_note", id=note_id, title=file.stem, description=content, project_id=projects[project])
            else:
                tool("update_note", id=note_id, title=file.stem, description=content, base_version=version, project_id=projects[project])
            if task_id:
                link_task(tool, task_id, path, link, f"{base_url}/notes/{note_id}", file.stem, language)
            state[rel] = digest
            print(f"mirrored: {rel} -> {project}")
        except (ToolError, OSError, urllib.error.URLError, KeyError, ValueError) as exc:
            print(f"failed: {rel}: {exc}", file=sys.stderr)
            failed += 1

    for rel in sorted(set(state) - seen):                               # the file is gone: its copy goes to the Trash, where it can be restored
        if args.dry_run:
            print(f"would trash: {rel}")
            continue
        try:
            tool("trash_note", ids=[str(uuid.uuid5(NAMESPACE, f"{root_name}/{rel}"))])
            del state[rel]
            print(f"trashed: {rel}")
        except (ToolError, urllib.error.URLError) as exc:
            print(f"failed to trash: {rel}: {exc}", file=sys.stderr)
            failed += 1

    if not args.dry_run:
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(seen)} notes, {changed} changed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
