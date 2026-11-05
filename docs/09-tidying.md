# Tidying up: sessions and the vault

A workflow like this one piles things up: dozens of sessions, runs of scheduled tasks, leftover worktrees, notes dropped in the wrong folder.
Two skills in the plugin clean that up the same careful way: **look without changing anything, show a plan, act after you agree, verify, report.**

| Skill | Say | What it does |
|-------|-----|--------------|
| `tidy-sessions` | "my sessions are a mess", "restart the chats so the config applies" | reviews sessions, scheduled runs, server processes and worktrees; archives, groups, sets auto-archive |
| `tidy-vault` | "sort my Obsidian", "go through the inbox" | finds junk and what depends on a folder, backs up, moves notes by topic, checks that links survived |

Both ship read-only tools you can run yourself:

```bash
python3 plugin/tools/vault_audit.py ~/obsidian --deps ~/my-repo ~/.hermes   # structure, junk, broken links, who names a folder; never prints a note's text
bash plugin/tools/worktree_audit.sh ~/my-repo                               # dirty, merged, or used by a running process
```

## What we learned doing this by hand

- **Restarting everything is usually unnecessary.** A session with no live process loads the new config with its next message.
- **A process that looks hand-started may be managed.** Ours were kept alive by a service and a kiosk daemon, and replacing them would have duplicated them. Find the parent before touching one.
- **A worktree is safe to remove only if it is clean, merged and has no process inside.** One of ours was serving a forgotten test server.
- **Moving a folder can widen access.** Moving family finance notes under a mirrored folder would have put them in the tracker, within reach of every agent. They went to a `Private` subfolder, which the mirror does not read.
- **Links without a path survive moves.** 2,500 wikilinks, no path in any of them, none broken by the reorganisation.

## Limits

- Cloud sessions are not in the session list, so `tidy-sessions` cannot see them.
- `vault_audit.py` finds dependencies by searching for a folder's name. A script that builds the path at run time will not show up.
- Moves spread through your sync tool to other devices, and a note open and edited elsewhere at that moment can produce a conflict copy.
