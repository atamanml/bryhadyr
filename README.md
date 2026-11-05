<p align="center"><img src="docs/img/brygadyr.svg" width="120" alt=""></p>

# brygadyr

**A foreman for you and your AI agents: one task tracker, one protocol, one project manager that nags.**

You run several Claude Code sessions a day (cloud, server, laptop), a Telegram agent, maybe a tablet on the desk.
Every one of them finds work that somebody has to do later, and every one of them forgets to write it down.
`brygadyr` (Ukrainian *бригадир*, the foreman of a work crew) fixes that with three parts that already exist and one small protocol:

| Part | What it is | Who made it |
|------|------------|-------------|
| **Tracker** | [OpenTodo](https://github.com/OpenTodoApp/OpenTodo): self-hosted, one Go binary, SQLite, ≈ 20 MB RAM, a real web app with Kanban, a built-in **MCP** endpoint and two-way **Obsidian** sync | Raffaele Pizzari ([support him](#support-the-opentodo-author)) |
| **Protocol** | One Markdown file every agent reads at session start: what counts as a task, when to write it, how to close it with a summary and checks, where the Obsidian note goes | this repo |
| **Distribution** | A Claude Code plugin + committed templates (cloud sessions), a Hermes SOUL block (Telegram), project instructions (claude.ai). Change the file, push, everyone follows | this repo |
| **Project manager** | [Hermes Agent](https://github.com/NousResearch/hermes-agent) cron jobs on Claude: morning plan, silent midday ping, evening report, weekly review. It sorts what the agents dumped, proposes deadlines, and nags you in Telegram | this repo |

```
 you (phone, tablet on the desk, Obsidian)        AI agents (Claude Code cloud · server · laptop, claude.ai, Hermes)
            │ web app / Obsidian Tasks files                        │ MCP «tasks» + the protocol
            └──────────────────────►  OpenTodo  ◄───────────────────┘
                                         ▲
                       Hermes PM (cron on Claude): plan · ping · report · weekly review → Telegram
```

## Why

- **One source of truth.** Humans and agents write to the same tracker; agents never invent deadlines, the PM does, after you say «ok».
- **Nothing gets lost between sessions.** A big task ends with a note in Obsidian and a summary with the checks that were actually run. The next session starts by reading the open tasks of its repo.
- **Cheap on purpose.** The tracker idles at 20 MB. The PM runs three short Claude jobs a day, about 10–20 USD a month on Sonnet with Haiku for the pings. Chats stay on whatever cheap model you already use.
- **One commit changes the rules everywhere.** The protocol is a file. Plugins auto-update, cloud sessions clone fresh, Hermes is refreshed by your deploy.

## Quick start (about an hour)

1. **Tracker:** `stack/` → `docker compose up -d`, create the owner account, enable *AI assistants* and create an `agent` token. [docs/01-opentodo.md](docs/01-opentodo.md)
2. **MCP for agents:** local Claude Code (`claude mcp add`), cloud sessions (`.mcp.json` + environment secrets), claude.ai (custom connector over a public path). [docs/02-mcp.md](docs/02-mcp.md)
3. **Protocol everywhere:** `claude plugin marketplace add <you>/brygadyr`, `claude plugin install brygadyr@brygadyr`; `scripts/sync.sh <repo>` for repos that run in the cloud. [docs/05-protocol.md](docs/05-protocol.md)
4. **Obsidian:** `ot vault init <vault>/OpenTodo` on the server, or the OpenTodo Obsidian plugin on your devices. [docs/03-obsidian.md](docs/03-obsidian.md)
5. **Project manager:** `hermes/install.sh` adds the SOUL block, the MCP server and four cron jobs. [docs/04-pm-agent.md](docs/04-pm-agent.md)
6. **Fill the tracker once:** run the harvest prompt in every project. [docs/06-harvest.md](docs/06-harvest.md)

## The protocol in one breath

A *big task* is one message from you that changes more than one file or takes over ~30 minutes. For a big task the agent
(1) looks up the open tasks of its repo, (2) creates or claims one task, (3) on finishing writes an Obsidian note from the template,
closes the task with a six-line summary (*done / verified / not verified / decisions / next / note*) and files at most five follow-ups,
with no deadline. Small tasks never touch the tracker. Full text: [plugin/PROTOCOL.md](plugin/PROTOCOL.md) (English) ·
[plugin/PROTOCOL.uk.md](plugin/PROTOCOL.uk.md) (Ukrainian).

## Repository layout

| Path | What |
|------|------|
| `plugin/` | the Claude Code plugin: `PROTOCOL.md`, skill, `SessionStart` hook, `.mcp.json`; `.claude-plugin/marketplace.json` at the root makes this repo a marketplace |
| `templates/` | what to commit into any repo whose sessions run in the cloud (`.claude/settings.json`, `.mcp.json`, note and summary templates) |
| `hermes/` | SOUL block, config fragment (MCP + model aliases), four cron prompts, `install.sh` |
| `stack/` | OpenTodo `docker-compose.yml` and `.env.example` |
| `scripts/` | `sync.sh` (copy the plugin into a repo), `check.sh` (validate manifests and the hook), `harvest-prompt.md` |
| `docs/` | setup guides, costs, the reasoning |
| `examples/` | a finished Obsidian note and a task summary, as agents produce them |

## Support the OpenTodo author

`brygadyr` is a thin layer; the heavy lifting is OpenTodo by **Raffaele Pizzari** ([@pixari](https://github.com/pixari)), AGPL-3.0, actively developed.
If this setup saves you a subscription, send some of it his way: [GitHub Sponsors](https://github.com/sponsors/pixari) · [Buy Me a Coffee](https://buymeacoffee.com/pixari).
As he puts it: using it, sharing it or reporting a bug helps just as much.

## Status and credits

Built in November 2026 for one home server (a NUC with 3.7 GB of RAM, Debian, Tailscale) by [@atamanml](https://github.com/atamanml) with Claude.
Everything here is what actually runs there, generalised. Issues and PRs welcome, in English or Ukrainian. MIT.
