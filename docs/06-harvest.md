# 6 · Filling the tracker the first time

New tracker, empty board, but every project already carries dozens of "later" items in READMEs, TODO comments, open issues, stale branches
and the final messages of old sessions. The harvest prompt (`scripts/harvest-prompt.md`) collects them once, project by project.

Run it in a session per project, in parallel: Claude Code (cloud or local), claude.ai, a remote session on your computer. With MCP available
the session writes straight into the **Agents** project; without it, it prints an Obsidian Tasks list that you (or an orchestrator session)
append to `obsidian/OpenTodo/Agents.md`, which `ot vault init --adopt` turns into tasks.

What came out of it in the reference setup: 20 tasks for the infrastructure repo, 25 for a Telegram bot, 24 for a scraper, plus a short
"looks obsolete" list per project that the weekly review closes. The PM then spends its first mornings on intake: project, section, priority,
proposed deadlines.

Repeat the harvest only when a project has been out of the protocol for a while; day to day, the protocol keeps the board current.
