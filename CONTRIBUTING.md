# Contributing

Issues and pull requests are welcome, in English or Ukrainian.

- Keep `plugin/PROTOCOL.md` and `plugin/PROTOCOL.uk.md` in sync; a change to one needs the same change in the other.
- `scripts/check.sh` must pass (manifests valid, the hook prints valid JSON, shellcheck clean).
- No personal hosts, tokens or names in the repo: placeholders only (`<host>`, `OWNER/bryhadyr`, `ot_…`).
- A new surface (another agent framework, another tracker) goes into `docs/` with the same table: mechanism, what reaches the session, how it updates.
