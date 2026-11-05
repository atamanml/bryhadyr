# Contributing

Issues and pull requests are welcome, in English or Ukrainian.

- Keep `plugin/PROTOCOL.md` and `plugin/PROTOCOL.uk.md` in sync; a change to one needs the same change in the other.
- `scripts/check.sh` must pass (manifests valid, the three hooks and their tests, the Python scripts of `stack/` and their tests, shellcheck clean).
- A change to a user-facing line in a hook or a script gets its Ukrainian twin (`PROTOCOL_LANG=uk` / `BRYHADYR_LANG=uk`) and a test.
- No personal hosts, tokens, names, session or task ids in the repo: placeholders only (`<host>`, `OWNER/bryhadyr`, `ot_…`, `<opentodo-url>`). Anything that differs per installation is a variable or a config file (`BRYHADYR_UNTRACKED_REPOS`, `notes-rules.json`), never a constant.
- A new surface (another agent framework, another tracker) goes into `docs/` with the same table: mechanism, what reaches the session, how it updates.
