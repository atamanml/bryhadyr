# 5 · The protocol and how it reaches every session

The single source of truth is `plugin/PROTOCOL.md` (and `PROTOCOL.uk.md`). Everything else copies or points to it.

## Distribution

| Surface | Mechanism | After a push |
|---------|-----------|--------------|
| **Claude Code on a server or laptop** | this repo as a plugin marketplace: `claude plugin marketplace add <you>/bryhadyr && claude plugin install bryhadyr@bryhadyr --scope user`; the plugin brings the skill, the `SessionStart` hook and the `tasks` MCP server | `claude plugin update bryhadyr@bryhadyr` (a deploy hook on the server; `autoUpdate: true` in the marketplace entry for interactive use) |
| **Claude Code cloud sessions** | cloud sessions do not install plugins declared in a repo, but they do read committed files: `scripts/sync.sh <repo>` copies the hook, the skill, the protocol and `.mcp.json` into `.claude/` of any repo; commit them there | the infra repo: next session; other repos: the hook fetches a fresher `PROTOCOL.md` through `gh` when `PROTOCOL_SOURCE_REPO=<you>/bryhadyr` is set and the session can read it, otherwise the synced copy |
| **Hermes** | the SOUL block written by `hermes/install.sh` (PM rules + a copy of the protocol) | `hermes/install.sh --soul-only` from your deploy |
| **claude.ai** | project instructions = sections 1–4 of `PROTOCOL.md`, connector `tasks` enabled | by hand, rarely |

Environment variables the hook and `.mcp.json` understand: `OPENTODO_MCP_URL` (default `http://127.0.0.1:8080/mcp`), `OPENTODO_AGENT_TOKEN`,
`PROTOCOL_LANG` (`uk` picks `PROTOCOL.uk.md`), `PROTOCOL_SOURCE_REPO` (live refresh).

## What the hook injects

At session start the agent gets, as context: the protocol text, the repo name, and one line saying whether the MCP token is present.
Nothing is read from the network unless `PROTOCOL_SOURCE_REPO` is set; no secret is printed. Test it: `scripts/check.sh`.

## Changing the rules for everyone

1. Edit `plugin/PROTOCOL.md` (and the Ukrainian twin), bump the version in the heading.
2. `scripts/check.sh`; `scripts/sync.sh` for each repo that carries committed copies; commit those.
3. Push. Servers and laptops update the plugin; cloud sessions clone fresh; Hermes is refreshed by your deploy; claude.ai by hand.

## Ideas not implemented yet (PRs welcome)

- A `Stop` hook that, for a long session with no tracker write, returns the protocol reminder once (`decision: block` with a reason) instead of relying on the model.
- The SessionStart hook pulling the repo's open tasks through OpenTodo's REST API so the agent starts with them in context without a tool call.
- A Claude Code `Stop` hook that posts the session summary through `ot` automatically.
