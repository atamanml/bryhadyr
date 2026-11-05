# 5 · The protocol and how it reaches every session

The single source of truth is `plugin/PROTOCOL.md` (and `PROTOCOL.uk.md`). Everything else copies or points to it.

## Distribution

| Surface | Mechanism | After a push |
|---------|-----------|--------------|
| **Claude Code on a server or laptop** | this repo as a plugin marketplace: `claude plugin marketplace add <you>/bryhadyr && claude plugin install bryhadyr@bryhadyr --scope user`; the plugin brings the skill and three hooks | `claude plugin update bryhadyr@bryhadyr` (a deploy hook on the server; `autoUpdate: true` in the marketplace entry for interactive use) |
| **Claude Code cloud sessions** | cloud sessions do not install plugins declared in a repo, but they do read committed files: `scripts/sync.sh <repo>` copies the hooks, the skill, the protocol and an `.mcp.json` into `.claude/` of any repo; commit them there | the infra repo: next session; other repos: the hook fetches a fresher `PROTOCOL.md` through `gh` when `PROTOCOL_SOURCE_REPO=<you>/bryhadyr` is set and the session can read it, otherwise the synced copy |
| **Hermes** | the SOUL block written by `hermes/install.sh` (PM rules + the path of the protocol file) | `hermes/install.sh --soul-only` from your deploy |
| **claude.ai** | project instructions = sections 1–4 of `PROTOCOL.md`, connector `tasks` enabled | by hand, rarely |

**The plugin does not register an MCP server.** Register `tasks` once per machine instead, in user scope
(`claude mcp add -s user --transport http tasks <url> --header "Authorization: Bearer ot_…"`, see [docs/02-mcp.md](02-mcp.md)), or commit
`templates/mcp.json` as `.mcp.json` into a repo (cloud sessions; `scripts/sync.sh` does it). A plugin that carries its own `.mcp.json` registers a
*second* server named `plugin_bryhadyr_tasks` next to the one you already have, with a token that is often missing, and the session
shows a failed connection on every start. One registration, in the place you control, is calmer.

## The three hooks

All three exist in two homes with the same script: the plugin (`${CLAUDE_PLUGIN_ROOT}/hooks/`) and the committed copy
(`<repo>/.claude/bryhadyr/`, registered in `.claude/settings.json` by `scripts/sync.sh`). Each is best effort: no python, bad JSON or an
unreadable transcript means "let it through". Python is found as `python3`, `python` or `py`, each *run once*, because `python3` is a dead
stub on some Windows machines. None of them spends tokens or writes to the tracker.

| Hook | Event | What it does |
|------|-------|--------------|
| `session-start.sh` | `SessionStart` | puts the protocol into the context, with the repo name, whether MCP `tasks` is reachable (user scope, or token + repo `.mcp.json`), and a ready-to-paste line `Session: <id> · <machine>` for a task that waits for you |
| `stop-check.sh` | `Stop` | if the session changed more than one file or made a commit but never called `add_comment` / `complete_tasks` on the tracker, blocks **once** with a reminder of protocol §3. A marker file in the temp dir keeps it from blocking twice, even if registered in both homes. Small tasks and sessions without changes pass silently. It does not see changes made through `sed -i` or shell redirects |
| `task-check.sh` | `PreToolUse` on `create_tasks` | refuses a task without a `From:` line, and a `waiting` task without a `Session:` line; the agent gets the reason and writes the task again |

Tests run in `scripts/check.sh`: `plugin/hooks/test-stop-check.sh` and `plugin/hooks/test-task-check.sh` feed synthetic transcripts and tool calls.

## Environment variables

| Variable | Used by | Meaning |
|----------|---------|---------|
| `OPENTODO_MCP_URL` | hooks, `.mcp.json`, scripts | default `http://127.0.0.1:8080/mcp` |
| `OPENTODO_AGENT_TOKEN` | `.mcp.json`, scripts | the agent token; never printed |
| `PROTOCOL_LANG` | hooks, `hermes/install.sh` | `uk` picks `PROTOCOL.uk.md`, the Ukrainian reasons of the hooks and the Ukrainian SOUL and prompts |
| `PROTOCOL_SOURCE_REPO` | `session-start.sh` | `owner/repo`: fetch a fresher `PROTOCOL.md` through `gh` (≤ 5 s) |
| `BRYHADYR_UNTRACKED_REPOS` | all three hooks | a regular expression for repository folder names that stay out of the tracker (say `scraper|sandbox`). There the SessionStart line says "leave the tracker alone", the Stop hook is silent, and `task-check.sh` refuses `create_tasks` |
| `BRYHADYR_UNTRACKED_HINT` | `session-start.sh`, `task-check.sh` | where tasks of such a repository go instead, e.g. `Write them to notes/tasks.md.` |
| `BRYHADYR_LANG` | `stack/*.py` | `uk` for the Ukrainian text the scripts write into OpenTodo |

Set them where the hooks run: `~/.config/environment.d/` on a Linux desktop, the shell profile on a server, the cloud environment's settings for cloud sessions.

## Changing the rules for everyone

1. Edit `plugin/PROTOCOL.md` and `plugin/PROTOCOL.uk.md`, bump the version in the heading.
2. `scripts/check.sh`; `scripts/sync.sh` for each repo that carries committed copies; commit those.
3. Push. Servers and laptops update the plugin; cloud sessions clone fresh; Hermes is refreshed by your deploy; claude.ai by hand.

## Ideas not implemented yet (PRs welcome)

- The SessionStart hook pulling the repo's open tasks through OpenTodo's REST API so the agent starts with them in context without a tool call.
- A `Stop` hook that posts the session summary itself instead of reminding the agent to.
- Seeing edits made through `sed -i` and shell redirects in the Stop hook (it reads tool calls, not the file system).

## Orchestrator and worker sessions

A large piece of work has one orchestrator chat: it plans, starts worker sessions with a short brief and checks what they report by running it. Workers stay inside their brief and never merge. The roles are in section 7 of the protocol, and the `orchestrator` skill walks through them.
