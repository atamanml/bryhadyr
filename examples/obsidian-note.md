---
project: Infrastructure
date: 2026-11-05
task: 3f1c2a9e-6b4d-4e0a-9c57-1d2e3f4a5b6c
agent: claude-code-cloud
status: done
tags: [agent, infra]
---
# Replace the hand-written tracker with OpenTodo

**Summary:** one tracker for people and agents, with MCP and Obsidian sync, instead of 500 lines of custom code.

## What was done
- `stacks/opentodo`: compose with the official image, `127.0.0.1:8091`, healthcheck, first-start MCP presets.
- Tailnet entry on `:8447`, public MCP path under a secret segment on 443 for the claude.ai connector.
- `opentodo-vault.service`: `ot vault watch` keeps `~/obsidian/OpenTodo` in sync; Syncthing spreads it.

## Checks
- `docker compose config` → valid; `yamllint --strict`, `shellcheck` → clean.
- OpenTodo docs v0.22.0: MCP stateless JSON, protocol 2025-11-25 → matches what claude.ai sends.
- Not checked from the cloud: the funnel path mount on the live Tailscale; the RAM figure on the NUC.

## Decisions and why
- Port 443 is shared with another MCP funnel because claude.ai rejects non-standard ports; the other service's switch no longer turns the funnel off.
- Agents never set deadlines; the PM does after an "ok", so the board does not fill with fake urgency.

## What is left / risks
- Owner: create the account, the agent token, run `make opentodo-expose`, add the connector in claude.ai.

Links: [task](https://todo.example.com/?task=3f1c2a9e-6b4d-4e0a-9c57-1d2e3f4a5b6c), branch `ccr-23c3ab1f-1stp92`, `docs/services/opentodo.md`
