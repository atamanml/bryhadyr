# 2 · MCP: giving every agent the tracker

OpenTodo serves MCP at `POST /mcp` (streamable HTTP, stateless, JSON responses, protocol versions 2025-03-26 … 2025-11-25).
Auth: `Authorization: Bearer ot_…`. The tools: `today_summary`, `list_projects`, `list_tasks`, `search_tasks`, `get_task`, notes, timers,
routines; writes: `create_tasks`, `update_tasks`, `complete_tasks`, `reopen_tasks`, `move_tasks`, `schedule_tasks`, projects, sections,
labels, `add_comment`, reminders, `trash_tasks`. Full list in OpenTodo's `docs/mcp.md`.

## Three kinds of clients

| Client | URL | How the token gets there |
|--------|-----|--------------------------|
| **Claude Code on the server** (also agents spawned there) | `http://127.0.0.1:8080/mcp` | `claude mcp add -s user --transport http tasks http://127.0.0.1:8080/mcp --header "Authorization: Bearer ot_…"`, or the plugin's `.mcp.json` with `OPENTODO_AGENT_TOKEN` in the shell environment |
| **Claude Code on a laptop in the tailnet** | `https://<host>.ts.net:8447/mcp` | the same `claude mcp add`, or the plugin with `OPENTODO_MCP_URL` + `OPENTODO_AGENT_TOKEN` in the environment |
| **Cloud sessions** (claude.ai/code) | the public URL below | the committed `.mcp.json` from `templates/` reads `OPENTODO_MCP_URL` and `OPENTODO_AGENT_TOKEN` from the cloud environment's secrets, or the claude.ai connector |
| **claude.ai** (web, apps, and cloud sessions through the account) | the public URL below | Settings → Connectors → Add custom connector, no OAuth, request header `Authorization: Bearer ot_…` |
| **Hermes** | local or tailnet URL | `mcp_servers.tasks` in `config.yaml`, written by `hermes/install.sh` |

## A public URL for claude.ai without exposing the app

claude.ai needs a public https endpoint on port 443. With Tailscale Funnel, mount only the MCP path under a secret segment:

```bash
tailscale funnel --bg --https=443 --set-path=/$(openssl rand -hex 16)/mcp http://127.0.0.1:8080/mcp
```

The connector URL becomes `https://<host>.ts.net/<secret>/mcp`. Without a token the endpoint answers 401, and nothing else of the app is reachable
from the internet. Verify from outside:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' -X POST "https://<host>.ts.net/<secret>/mcp" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
# 401 = reached OpenTodo (no token); 404/502 = the path mount is wrong
```

Funnel allows only ports 443, 8443 and 10000, and claude.ai rejects non-standard ports, so 443 it is. If 443 already serves another funnel at `/`,
the path mount coexists with it. Any reverse proxy with a public domain works the same way: forward only `/<secret>/mcp` → `/mcp`.

## What the agent sees

The plugin's SessionStart hook tells the session whether `OPENTODO_AGENT_TOKEN` is set. Without it the protocol's fallback applies: the agent
prints its tasks as an Obsidian Tasks list in the final answer, and the orchestrator (or `ot vault --adopt`) moves them in. No agent is ever
blocked on the tracker being unreachable.
