# 1 · OpenTodo: the tracker

[OpenTodo](https://github.com/OpenTodoApp/OpenTodo) by Raffaele Pizzari: a self-hosted task manager in one Go binary with SQLite,
about 20 MB of RAM idle, a PWA with Inbox / Today / Upcoming, projects with sections and a Kanban view, labels, recurring tasks,
reminders, a built-in MCP endpoint and two-way Markdown sync with Obsidian. AGPL-3.0, released often. [Support the author](../README.md#support-the-opentodo-author).

## Why this one

| | OpenTodo | Conatus | Markboard | Super Productivity | writing your own |
|---|---|---|---|---|---|
| RAM | ≈ 20 MB | Next.js + PostgreSQL + object store | hosted only | PostgreSQL + Caddy + SMTP, beta | 80 MB and your weekends |
| MCP | built in, read and write, agent-scoped tokens | separate npm server | yes | capture only, OAuth | you write it |
| Obsidian | `ot vault` two-way sync + plugin | no | no | no | no |
| Web UI | full app, Kanban | Todoist-like | Kanban | desktop/mobile apps | a board |

## Install

```bash
cp stack/.env.example stack/.env && $EDITOR stack/.env      # OPENTODO_BASE_URL, OPENTODO_SETUP_TOKEN=$(openssl rand -hex 16)
docker compose -f stack/docker-compose.yml up -d
docker compose -f stack/docker-compose.yml logs | grep -i setup        # the one-time registration code
curl -s http://127.0.0.1:8080/healthz
```

The container binds to `127.0.0.1` only. Put something in front:

- **Tailscale** (what the reference setup uses): `tailscale serve --bg --https=8447 http://127.0.0.1:8080` gives `https://<host>.<tailnet>.ts.net:8447`
  to every device on the tailnet with a valid certificate. The Obsidian plugin and passkeys need https.
- **Caddy / nginx**: `reverse_proxy opentodo:8080`; nginx needs `proxy_set_header X-Forwarded-For` and `proxy_buffering off` for live updates.
  Do not put `/mcp`, `/dav/` or `/feeds/*` behind a login wall.

Then open the URL, create the owner account (it asks for `OPENTODO_SETUP_TOKEN` and the code from the log), turn on 2FA or a passkey,
and invite family members with one-time links (Settings → Members). Sign-up closes after the owner exists.

## Tokens

Settings → Integrations → AI assistants: enable *Allow AI assistants* and *Assistants may make changes*; per user, enable *Changes to my tasks*.
Create a token "can make changes" (scope `agent`) for Claude Code / claude.ai / Hermes. A full-access token on `/mcp` gets read tools only.
For `ot vault` sync you need a `full` token (Settings → API tokens). Store every token in your password manager, never in a repo.

Limits worth knowing: 50 items per MCP call, 30 write calls per minute, 1000 changed items per day per token.

## Projects and labels

Create once (or let the PM agent do it from the chat): **Owner**, one project per family member, **Home**, **Agents** with sections named after
your repositories. Labels: `agent`, `blocked`, `waiting`, `quick`, `idea`, `done-by-agent`. These names are referenced by the protocol; change them
there if you change them here.

## Tablet on the desk

The PWA works on an iPad (Guided Access) or Android (Fully Kiosk Browser). Project view → `v` toggles list and Kanban; a project "Home" with sections
"To do / Doing / Done" makes a good wall board. Keep the screen on in the OS settings; the app asks for a wake lock but that is not reliable.

## Backups and upgrades

Settings → Server: scheduled snapshots into `/data/backups` (or S3 / WebDAV) while running. Restore:
`docker compose stop app && docker compose run --rm --no-deps app restore /data/backups/<file>.tar.gz && docker compose start app`.
Upgrade: `docker compose pull && docker compose up -d`; migrations run at start. Lost owner password: `docker compose exec app /opentodo reset-owner-password`.
