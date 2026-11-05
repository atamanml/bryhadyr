# 6 · Filling the tracker the first time

New tracker, empty board, but every project already carries dozens of "later" items in READMEs, TODO comments, open issues, stale branches
and the final messages of old sessions. The harvest prompt (`scripts/harvest-prompt.md`) collects them once, project by project.

## The rule: one file, at most five tasks

The first version of this guide dumped everything into the tracker: 20 tasks for an infrastructure repo, 25 for a Telegram bot, 24 for a scraper.
It worked as a list and failed as a board: nobody picks up 70 tasks, the PM spent its first mornings sorting them, and the real next steps
drowned. So the harvest now does this per project:

1. **The full list goes into one file in the repository**, `docs/backlog.md`: one line per item, grouped by theme, with its source and a
   sentence of context, plus a "Looks obsolete" block. It is versioned, greppable and costs the tracker nothing.
2. **At most 5 items become tasks**: the ones somebody can realistically start within two weeks. Each has `From:` (the source), `Done when:`
   (a check that can be run) and `Context:` only when the task is not obvious. This is the quality bar of the protocol (§1).
3. Everything else stays in the file. When an item becomes real, a session turns it into a task and removes the line.

Run it in a session per project, in parallel: Claude Code (cloud or local), claude.ai, a remote session on your computer. With MCP available
the session writes straight into the project of its topic (or the Inbox if unsure); without it, it prints an Obsidian Tasks list that you (or an
orchestrator session) append to `obsidian/OpenTodo/Inbox.md`, which `ot vault init --adopt` turns into tasks.

Repeat the harvest only when a project has been out of the protocol for a while; day to day, the protocol keeps the board current:
the "Someday" state and the PM's weekly hygiene (docs/04-pm-agent.md) clear what ages out.
