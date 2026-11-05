# 3 · Obsidian: notes and the task mirror

Three independent links between the tracker and your vault: tasks as Markdown (two-way, `ot vault`), agent notes (written by sessions, below),
and those notes shown inside OpenTodo (one-way, [docs/08-notes-in-opentodo.md](08-notes-in-opentodo.md)).

## Tasks as Markdown (`ot vault`)

The `ot` CLI (release binary `ot-<os>-<arch>`, or `go install github.com/OpenTodoApp/opentodo/cmd/ot@latest`) keeps a folder in two-way sync
with your account: one file per project, `Inbox.md` for tasks without a project, one Obsidian Tasks line per task:

```
- [ ] Book the plumber 📅 2026-10-25 [time:: 09:00] [deadline:: 2026-10-30] ⏫ #errands 🆔 t-home1
```

On the server, next to the vault that Syncthing (or any sync) spreads to your devices:

```bash
ot login https://<your-opentodo>                      # or OPENTODO_URL + OPENTODO_TOKEN (a «full» token)
ot vault init ~/obsidian/OpenTodo --adopt             # --adopt takes existing .md files (the harvest files, for example)
ot vault watch ~/obsidian/OpenTodo                    # keep it running: a user systemd unit, see below
```

Rules: one syncing device per folder (`vault_owned`, `--take-over` to move it); a field changed on both sides → the app wins and the line goes
to `<file>.conflict.md`; a removed line trashes the task. The Obsidian Tasks and Dataview plugins render the files; neither is required.

```ini
# ~/.config/systemd/user/opentodo-vault.service
[Unit]
Description=OpenTodo <-> Obsidian vault two-way sync
After=network-online.target
[Service]
EnvironmentFile=%h/.config/opentodo/vault.env     # OPENTODO_URL=…  OPENTODO_TOKEN=ot_…  (0600)
ExecStart=%h/.local/bin/ot vault watch %h/obsidian/OpenTodo
Restart=on-failure
RestartSec=30
[Install]
WantedBy=default.target
```

Alternative or addition: the **OpenTodo Obsidian plugin** on each device syncs its own folder over https while Obsidian is open, and can send a
line from any note to the tracker as a task.

## Agent notes

The protocol makes every big task end with a note at `obsidian/10 - Projects/<Project>/<YYYY-MM-DD> <Title>.md` (template in
`templates/obsidian-note.md`). Notes live in the infra repo and reach the vault through its deploy. Two lines tie a note to its task:

- `task: <full task id>` in the note's frontmatter, and a link `[task](<opentodo-url>/?task=<id>)` in its last line;
- `Note: 10 - Projects/<Project>/<file>.md` in the task's description (and in the closing comment).

With the notes mirror running, the note also appears in OpenTodo (Notes, same project), rendered, and the task gets a chip that opens it in
Obsidian. Without it the tablet shows the path and Obsidian holds the full text. A Dataview query for an overview:

```dataview
TABLE project, status, agent, task FROM "10 - Projects" WHERE contains(tags, "agent") SORT date DESC
```

Agents in cloud sessions of other repositories write the note through the GitHub API into the infra repo's `main` (the skill explains how);
without access they print the note in their final answer and the orchestrator saves it.
