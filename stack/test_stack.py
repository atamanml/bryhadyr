#!/usr/bin/env python3
"""Tests of notes_mirror.py and task_replies.py with a stub of OpenTodo's MCP endpoint (no network, no real tracker).

Run: python3 stack/test_stack.py   (part of scripts/check.sh)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import notes_mirror as nm  # noqa: E402
import task_replies as tr  # noqa: E402

SESSION_ID = "0b8c1d52-1111-4222-8333-444455556666"
TASK_ID = "aaaaaaaa-1111-4222-8333-444455556666"


class RenderTests(unittest.TestCase):
    def test_frontmatter_wikilinks_and_head(self):
        text = "---\ntask: x\n---\n# Title\nSee [[Other note|the other]] and [[Plain]] and ![[pic.png]]\n"
        out = nm.render(text, "10 - Projects/Infra/a.md", f"https://todo.example/?task={TASK_ID}")
        self.assertTrue(out.startswith("> Copy from Obsidian, edit it there: `10 - Projects/Infra/a.md` · [task](https://todo.example/?task="))
        self.assertIn("the other", out)
        self.assertNotIn("[[", out)
        self.assertIn("*(attachment: pic.png)*", out)
        self.assertNotIn("task: x", out)

    def test_ukrainian_words(self):
        out = nm.render("# T\n![[a.png]]\n", "p.md", "https://t/?task=1", "uk")
        self.assertIn("Копія з Obsidian", out)
        self.assertIn("[задача]", out)
        self.assertIn("вкладення: a.png", out)

    def test_long_note_is_cut_under_the_limit_and_says_so(self):
        text = "\n".join(f"line {i} " + "x" * 80 for i in range(1000))
        out = nm.render(text, "p.md", None)
        self.assertLessEqual(len(out), 20_000)
        self.assertIn("Cut:", out)
        self.assertTrue(out.rstrip().endswith("Obsidian.*"))

    def test_no_obsidian_scheme_in_the_text(self):
        self.assertNotIn("obsidian://", nm.render("# T\nbody", "10 - Projects/A/b.md", None))

    def test_obsidian_url_quotes_vault_and_path(self):
        self.assertEqual(nm.obsidian_url("My Vault", "10 - Projects/A/b c.md"),
                         "obsidian://open?vault=My%20Vault&file=10%20-%20Projects%2FA%2Fb%20c")


class RuleTests(unittest.TestCase):
    def test_example_rules_file_loads_and_matches(self):
        root, rules = nm.load_rules(HERE / "notes-rules.example.json")
        self.assertEqual(root, "10 - Projects")
        self.assertEqual(nm.project_for("Infra/a.md", rules), "Infra")
        self.assertEqual(nm.project_for("finance-status-1.md", rules), "Finance")
        self.assertIsNone(nm.project_for("Private/diary.md", rules))
        self.assertIsNone(nm.project_for("Infra/deep/a.md", rules), "a pattern covers one folder level only")

    def test_secret_scanner(self):
        self.assertTrue(nm.SECRET.search("token ot_" + "a" * 20))
        self.assertTrue(nm.SECRET.search("-----BEGIN RSA PRIVATE KEY-----"))
        self.assertFalse(nm.SECRET.search("nothing here"))

    def test_task_id_in_frontmatter(self):
        match = nm.TASK_ID.search(f"project: A\ntask: {TASK_ID}\n")
        self.assertEqual(match.group(1), TASK_ID)
        self.assertIsNone(nm.TASK_ID.search("task: —\n"))


class ReplyTests(unittest.TestCase):
    def comment(self, body):
        return {"untrusted_text": {"body": body}}

    def test_session_line_in_both_languages(self):
        self.assertEqual(tr.SESSION.search(f"From: x\nSession: {SESSION_ID} · box").group(1), SESSION_ID)
        self.assertEqual(tr.SESSION.search(f"Сесія: `{SESSION_ID}`").group(1), SESSION_ID)
        self.assertIsNone(tr.SESSION.search("Session: not-an-id"))

    def test_answer_of(self):
        self.assertEqual(tr.answer_of([self.comment("Agent: working on it"), self.comment("Take option B")]), "Take option B")
        self.assertIsNone(tr.answer_of([]))
        self.assertIsNone(tr.answer_of([self.comment("Agent: I think B")]), "an agent's comment is not an answer")
        self.assertIsNone(tr.answer_of([self.comment("Агент: думаю B")]))
        self.assertIsNone(tr.answer_of([self.comment("- just closing it")]), "a comment starting with a dash is a note to self")
        self.assertIsNone(tr.answer_of([self.comment("Passed to session x.")]), "the script's own comment")
        self.assertIsNone(tr.answer_of([self.comment("   ")]))

    def test_session_settings_maps_unknown_mode_to_auto(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "s.jsonl"
            path.write_text(json.dumps({"cwd": "/work/app", "permissionMode": "bypassPermissions"}) + "\n", encoding="utf-8")
            self.assertEqual(tr.session_settings(path), ("/work/app", "auto"))
            path.write_text(json.dumps({"cwd": "/work/app", "permissionMode": "acceptEdits"}) + "\n", encoding="utf-8")
            self.assertEqual(tr.session_settings(path), ("/work/app", "acceptEdits"))


class Stub(BaseHTTPRequestHandler):
    """A tiny OpenTodo: enough of /mcp and the history endpoint for one run of each script."""
    calls: list[tuple[str, dict]] = []
    closed_by = "web:browser"

    def log_message(self, *args):
        pass

    def _send(self, payload):
        data = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self._send({"changeSets": [{"changes": [{"field": "completed_at", "to": "2026-11-05T10:00:00Z"}], "device": self.closed_by}]})

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        name, args = request["params"]["name"], request["params"]["arguments"]
        Stub.calls.append((name, args))
        if self.headers.get("Authorization") != "Bearer test-token":
            return self._send({"error": {"message": "unauthorized"}})
        results = {
            "list_projects": {"projects": [{"id": "p1", "untrusted_text": {"name": "Infra"}}]},
            "get_note": None,
            "get_task": {"task": {"id": TASK_ID, "origin": None, "untrusted_text": {"title": "Which plan?", "description": f"From: a question\nSession: {SESSION_ID} · box", "labels": ["waiting"]}},
                         "comments": [{"untrusted_text": {"body": "Take plan B"}}]},
            "list_tasks": {"tasks": [{"id": TASK_ID, "completed": True, "completed_at": "2026-11-05T10:00:00Z"}]},
        }
        if name == "get_note":
            return self._send({"result": {"isError": True, "content": [{"text": "not_found"}]}})
        self._send({"result": {"structuredContent": results.get(name, {})}})


class EndToEndTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), Stub)
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def env(self, home: str, **extra):
        base = {k: v for k, v in os.environ.items() if not k.startswith(("OPENTODO_", "OBSIDIAN_", "BRYHADYR_"))}
        base.update(HOME=home, USERPROFILE=home, XDG_STATE_HOME=str(Path(home) / "state"), OPENTODO_BASE_URL="https://todo.example",
                    OPENTODO_AGENT_TOKEN="test-token", OPENTODO_MCP_URL=self.url + "/mcp", OPENTODO_LOCAL_URL=self.url, PYTHONUTF8="1")
        base.update(extra)
        return base

    def test_notes_mirror_creates_notes_links_the_task_and_skips_the_rest(self):
        Stub.calls = []
        with tempfile.TemporaryDirectory() as home:
            vault = Path(home) / "vault"
            (vault / "10 - Projects/Infra").mkdir(parents=True)
            (vault / "10 - Projects/Private").mkdir()
            (vault / "10 - Projects/Infra/a.md").write_text(f"---\ntask: {TASK_ID}\n---\n# A\ntext\n", encoding="utf-8")
            (vault / "10 - Projects/Infra/b.md").write_text("# B\nkey ot_" + "z" * 24 + "\n", encoding="utf-8")
            (vault / "10 - Projects/Private/diary.md").write_text("# Not for the tracker\n", encoding="utf-8")
            rules = Path(home) / "rules.json"
            rules.write_text(json.dumps({"root": "10 - Projects", "rules": [["Infra/*.md", "Infra"]]}), encoding="utf-8")
            env = self.env(home, OBSIDIAN_VAULT=str(vault), BRYHADYR_NOTES_RULES=str(rules))
            run = subprocess.run([sys.executable, str(HERE / "notes_mirror.py")], env=env, capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 1, run.stdout + run.stderr)       # b.md looks like a secret: reported as failed
            self.assertIn("mirrored: Infra/a.md -> Infra", run.stdout)
            self.assertIn("skipped, looks like a secret: Infra/b.md", run.stderr)
            names = [c[0] for c in Stub.calls]
            self.assertEqual(names.count("create_note"), 1)
            self.assertNotIn("diary", json.dumps(Stub.calls), "a file outside the rules is never read into the tracker")
            created = next(a for n, a in Stub.calls if n == "create_note")
            self.assertEqual(created["project_id"], "p1")
            self.assertIn("Copy from Obsidian", created["description"])
            self.assertIn("update_tasks", names)                               # the origin chip
            self.assertIn("append_to_note", names)                             # the link to the mirrored note
            first = len(Stub.calls)
            again = subprocess.run([sys.executable, str(HERE / "notes_mirror.py")], env=env, capture_output=True, text=True, check=False)
            self.assertIn("0 changed", again.stdout)
            self.assertEqual(len([c for c in Stub.calls[first:] if c[0] == "create_note"]), 0, "an unchanged note is not written again")

    def test_notes_mirror_without_rules_file_stops_with_a_hint(self):
        with tempfile.TemporaryDirectory() as home:
            run = subprocess.run([sys.executable, str(HERE / "notes_mirror.py"), "--dry-run"], env=self.env(home), capture_output=True, text=True, check=False)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("notes-rules.example.json", run.stderr)

    def test_task_replies_dry_run_delivers_or_relays(self):
        try:
            subprocess.run(["pgrep", "-f", "nothing-matches-this"], capture_output=True, check=False)
        except FileNotFoundError:
            self.skipTest("pgrep is not available")
        with tempfile.TemporaryDirectory() as home:
            env = self.env(home)
            Stub.closed_by = "web:browser"
            run = subprocess.run([sys.executable, str(HERE / "task_replies.py"), "poll", "--dry-run"], env=env, capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn("would relay", run.stdout)                           # no transcript of that session on this machine
            self.assertIn("the session is not on this machine", run.stdout)
            transcripts = Path(home) / ".claude/projects/-work-app"
            transcripts.mkdir(parents=True)
            (transcripts / f"{SESSION_ID}.jsonl").write_text(json.dumps({"cwd": "/work/app"}) + "\n", encoding="utf-8")
            run = subprocess.run([sys.executable, str(HERE / "task_replies.py"), "poll", "--dry-run"], env=env, capture_output=True, text=True, check=False)
            self.assertIn(f"would deliver: {TASK_ID} {SESSION_ID}", run.stdout)
            Stub.closed_by = "agent:claude"
            run = subprocess.run([sys.executable, str(HERE / "task_replies.py"), "poll", "--dry-run"], env=env, capture_output=True, text=True, check=False)
            self.assertIn("closed by an agent, skipped", run.stdout)
            Stub.closed_by = "web:browser"


if __name__ == "__main__":
    unittest.main(verbosity=1)
