---
name: tidy-sessions
description: Tidy up Claude Code sessions. Use when the user says their sessions are a mess, asks to restart chats so a new config applies, to archive or group sessions, to clean worktrees, or to review what is still running.
---

# Tidy up sessions

Look first and change nothing, then show a plan, then act once the person agrees. Archiving can be undone, deleting cannot: do not use `delete_session`.

## 1. Look, change nothing

- `list_sessions` with a large `limit`, `get_settings`, `list_groups`, `list_start_targets`, `list_scheduled_tasks`.
- On every server: `ps` for `claude` processes, `tmux ls`, `free -m`, the age of the newest transcripts in `~/.claude/projects/*`, `systemctl --user` units.
- Worktrees: `bash "${CLAUDE_PLUGIN_ROOT}/tools/worktree_audit.sh" <repo>`.
- For a session you cannot judge, `list_events` with `limit: 3` shows where it stopped.

Cloud sessions are not in this list; tell the person so.

## 2. What usually turns out to be true

- **No mass restart is needed.** A session with no live process (`isRunning: false`) picks up the new config with its next message. Look at live processes separately.
- **Runs of scheduled tasks pile up** as separate sessions. Archive them and set `auto_archive_inactive_days`; they cannot be grouped.
- **A `claude remote-control` process may be managed.** Before replacing one, find what keeps it alive: its parent process, tmux, `systemctl --user`, the service's docs. Restarting a live process cuts the chats open in it.
- **Check memory before adding processes.** Each takes 100–250 MB.

## 3. The plan

A table: what to archive, what to show the person first (unfinished work, files that live only in a temporary folder), what stays. Then settings changes, and what you will not touch and why. Act only after they agree.

## 4. Acting

- **Archive** with `archive_session`, one at a time, with a short `reason`. A session with an open PR stays until the PR is closed.
- **Groups** use the tracker's project names. Only the person removes an empty group.
- **Worktrees:** only clean, merged, with no process inside, with `git worktree remove` and no `--force`. Keep the branches.
- **A process inside a worktree:** find out whose it is. Stop only your own forgotten one.
- **`claude mcp list` prints secret URL paths:** mask it (`sed -E 's#/[A-Za-z0-9_-]{24,}#/<secret>#g'`), never read it raw.

## 5. Report

How many there were and are now, what changed, what you left alone and why, what waits for a decision.
