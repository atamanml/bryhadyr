# Harvest prompt: collect a project's open tasks into OpenTodo

Paste into any Claude chat (Code, claude.ai, remote) in the project. The PM agent sorts priorities and deadlines afterwards.
Approach: everything left for a human or the next agent becomes a task; invent nothing; no duplicates; no deadlines or priorities.

```text
Collect every open task of this project and put it into my OpenTodo task tracker.

Sources (look at all that exist): README and docs/ (sections "Next", "Not done", "TODO", "Open questions", plans with statuses),
TODO/FIXME/XXX comments in code, open GitHub issues and PRs, branches without a PR, the last 20 commits (promises like "later",
"temporary", "for now without"), CLAUDE.md/AGENTS.md. For Claude sessions: what earlier reports left "for the human".

Rules:
- A task = one concrete action with a verb, ≤ 120 characters. Notes: the source (file/section), one sentence of context, a link (PR, issue,
  session) if any. At most 25 tasks per project: merge trivia, set aside the stale ("looks obsolete: …").
- Labels: #agent, #<repo-name>, plus #blocked (waits on something), #waiting (waits on a human), #quick (≤ 15 min), #idea (optional).
- Invent nothing. No deadlines, no priorities. No code changes.

Where to write:
1. If the MCP server "tasks" (OpenTodo) is available: search_tasks first to avoid duplicates; then create_tasks into project "Agents"
   (section = repo name; create it if missing). Print the created list at the end.
2. If MCP "tasks" is unavailable: print the tasks in Obsidian Tasks format and nothing else after the heading:
   ## <repo-name>
   - [ ] <task title> #agent #<repo> [#blocked|#waiting|#quick|#idea]
     - <note: source; context; link>
   A separate block "Looks obsolete:" for what you advise closing.
```

Where option 2 ends up: the orchestrator collects the lists into `obsidian/OpenTodo/Agents.md` (Obsidian Tasks format); the file reaches the vault
through the deploy, and `ot vault init <vault>/OpenTodo --adopt` loads the lines into OpenTodo.
