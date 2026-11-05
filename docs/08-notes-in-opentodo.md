# 8 · Obsidian notes inside OpenTodo

The protocol makes every big task end with an Obsidian note (summary, checks, decisions). On a tablet on the desk you read tasks, not a
vault. `stack/notes_mirror.py` copies selected notes into OpenTodo's **Notes** section, rendered, in the same project as their tasks, and
links a note and its task both ways. Obsidian stays the source; nothing flows back.

```
 obsidian/10 - Projects/Infra/2026-11-05 Replace the tracker.md      OpenTodo
 ───────────────────────────────────────────────────────────         ──────────────────────────────────────────
 ---                                                                  project Infra → Notes:
 task: 3f1c2a9e-…-…                           ─── every 15 min ──►     "2026-11-05 Replace the tracker" (rendered)
 ---                                                                    > Copy from Obsidian, edit it there: `10 - Projects/…` · [task](…)
 # Replace the tracker …                                              the task 3f1c2a9e:
                                                                        • chip "open in Obsidian"   (origin: obsidian://…)
                                                                        • description line "Note: [title](<opentodo-url>/notes/<id>)"
```

## Install

```bash
mkdir -p ~/.config/bryhadyr && cp stack/notes-rules.example.json ~/.config/bryhadyr/notes-rules.json   # then edit it
python3 stack/notes_mirror.py --dry-run          # what it would mirror, writes nothing
scripts/install-timers.sh notes                  # user systemd timer: bryhadyr-notes-mirror.timer, every 15 minutes
```

Needs `stack/.env` with `OPENTODO_BASE_URL` and `OPENTODO_AGENT_TOKEN`; the OpenTodo project of each rule must exist.

| Setting | Default | Meaning |
|---------|---------|---------|
| `OBSIDIAN_VAULT` | `~/obsidian` | the vault folder on this machine |
| `OBSIDIAN_VAULT_NAME` | the folder's name | the vault's **name on the device that opens the link**; Obsidian resolves `obsidian://open?vault=<name>` by that name |
| `BRYHADYR_NOTES_RULES` | `~/.config/bryhadyr/notes-rules.json` | the allowlist below |
| `OPENTODO_MCP_URL` | `http://127.0.0.1:8080/mcp` | the app's MCP endpoint, local |
| `BRYHADYR_LANG` | `en` | `uk` for the Ukrainian head line and link text |

## The rules file is an allowlist on purpose

```json
{ "root": "10 - Projects",
  "rules": [ ["Infra/*.md", "Infra"], ["Product A/*.md", "Product A"], ["finance-*.md", "Finance"] ] }
```

Each rule is a glob under `root` (one folder level, `fnmatch` syntax) and the name of the OpenTodo project. A vault usually also holds notes
that must never reach a tracker that agents can read, so a file is mirrored only if a rule names it. A new project folder therefore needs a
new line here (the protocol says so too). Files that match `ot_…`, `sk-…`, `ghp_…` or a private-key header are **skipped and reported**
(exit code 1), whatever the rules say.

## What exactly is mirrored

- The text without frontmatter; `[[wiki links]]` become plain text, `![[attachments]]` become a marker `(attachment: name)`.
- A first line pointing at the source path. If the frontmatter has `task: <full id>`, the head line also links the task.
- Linking the task (when `task:` is set): the task gets an `origin` of kind `obsidian` with the `obsidian://` link, **unless it already has
  an origin** (a PR or an issue wins), and a line `Note: [title](<opentodo-url>/notes/<id>)` in its description, once.
- Note ids derive from the path, so a lost state file cannot duplicate notes; the state file only remembers a hash per note, so an unchanged
  note costs no request. Raising `RENDER_VERSION` in the script rewrites everything.
- A deleted or no-longer-matching file moves its copy to the **Trash** of OpenTodo, where it can be restored.
- Conflict copies (`*.conflict.*`) are ignored.

## Limits, honestly

- **`obsidian://` links are stripped from the note text.** OpenTodo removes them from rendered Markdown, so the note body cannot link into
  Obsidian. That is why the head line prints the plain path, and why the **task chip** (the `origin`) is the one clickable way back to Obsidian.
- **The vault name must match the device.** The link opens only on a device where a vault of that name is open, and only if that device has the file.
- **A note is at most 20 000 characters in OpenTodo.** The script cuts at 19 000, at a line end, and says so under the cut with a pointer to
  Obsidian. Keep agent notes short (the protocol asks for it).
- **One way.** Edit in Obsidian; a change made in OpenTodo is overwritten at the next change of the file.
- **Up to 15 minutes of delay,** and every changed note costs a handful of requests (the limit is 30 writes a minute; the script waits it out).
- **Not a sync of the vault.** Tasks as Markdown are the other, two-way mechanism (`docs/03-obsidian.md`, `ot vault`); the two do not interact.
