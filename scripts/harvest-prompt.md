# Harvest prompt: collect a project's open work, without flooding the tracker

Paste into any Claude chat (Code, claude.ai, remote) in the project. The PM agent sorts priorities and deadlines afterwards.
Approach: **the full list goes into one file in the repository; the tracker gets at most 5 tasks**, the ones somebody will pick up within two weeks.
Everything is evidence-based: invent nothing, no duplicates, no deadlines or priorities, no code changes.

```text
Collect every open piece of work of this project.

Sources (look at all that exist): README and docs/ (sections "Next", "Not done", "TODO", "Open questions", plans with statuses),
TODO/FIXME/XXX comments in code, open GitHub issues and PRs, branches without a PR, the last 20 commits (promises like "later",
"temporary", "for now without"), CLAUDE.md/AGENTS.md. For Claude sessions: what earlier reports left "for the human".

1. Write the full list to docs/backlog.md in this repository (create it, or update it if it exists): one line per item, grouped by theme,
   each with its source (file/section/link) and one sentence of context. Put the stale ones under "Looks obsolete: …" with the reason.
   Commit that file.
2. Then pick at most 5 items that somebody can realistically start within two weeks and put only those into my OpenTodo tracker.
   Everything else stays in docs/backlog.md, or goes to the "Someday" state if I ask for it.

A tracker task:
- title = verb + result, ≤ 120 characters;
- description lines: "From: <the source: file/section/link>", "Context: <2–6 lines, only when the task is not obvious>", "Done when: <a check that can be run>";
- labels: agent, plus waiting (needs a human) or blocked (with the reason), quick (≤ 15 min) where it fits; no deadline, no priority;
- project = the project of the topic (list_projects); not sure → the Inbox (no project).

Where to write the tasks:
- If the MCP server "tasks" (OpenTodo) is available: search_tasks first to avoid duplicates, then create_tasks. Print the created list at the end.
- If it is unavailable: print the tasks in Obsidian Tasks format and nothing else after the heading:
  ## <repo-name>
  - [ ] <task title> #agent [#blocked|#waiting|#quick]
    - From: <source>
    - Done when: <check>
```

Where the second option ends up: the orchestrator collects the lists into `obsidian/OpenTodo/Inbox.md` (Obsidian Tasks format); the file reaches the vault
through the deploy, and `ot vault init <vault>/OpenTodo --adopt` loads the lines into OpenTodo.
