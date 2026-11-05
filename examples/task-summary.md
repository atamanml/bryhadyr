Done: replaced the custom task stack with OpenTodo (compose, tailnet entry, public MCP path, vault sync unit); docs and Makefile targets updated.
Verified: docker compose config, yamllint --strict, shellcheck, secret scanner → all clean; OpenTodo MCP contract checked against its docs (v0.22.0).
Not verified: the Tailscale funnel path mount and OpenTodo's RAM on the server (no server access from the cloud session).
Decisions: shared funnel port 443 (claude.ai needs a standard port); agents never set deadlines, the PM proposes them.
Next: "Create owner account and agent token", "Run make opentodo-expose", "Add the claude.ai connector", "Set up the tablet".
Note: obsidian/10 - Projects/Infrastructure/2026-11-05 Replace the hand-written tracker with OpenTodo.md · commit 258845e
