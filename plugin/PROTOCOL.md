# Agent protocol · v2

The single source of truth for every AI agent that works for the owner: Claude Code (cloud, server, laptop), the Telegram agent (Hermes), claude.ai chats.
To change the rules for everyone, change this file and push: the plugin, the committed templates and the Hermes SOUL block carry it.
Ukrainian version: `PROTOCOL.uk.md` (keep both in sync; the owner's language wins in notes and task titles).

## 1. Where things live

| What | Where | How to write |
|------|-------|--------------|
| Tasks | OpenTodo, MCP server `tasks` | `search_tasks`, `create_tasks`, `update_tasks`, `complete_tasks`, `add_comment` |
| Documentation and notes | the Obsidian vault, mirrored in the infra repo under `obsidian/` | a file in the repo → push to `main` → the deploy copies it into the vault |
| Code and project plans | the project's own repository (`docs/`, `README`) | as usual, PR or commit |

Projects in OpenTodo: **Owner**, **Family** (one per person), **Home**, **Agents** (sections = repositories: `infra`, `app-a`, `app-b`, `other`).
Labels: `agent` (created by an agent), `blocked`, `waiting` (needs a human), `quick` (≤ 15 min), `idea`, `done-by-agent`.
Obsidian folder per project: `obsidian/10 - Projects/<Project name>/` (same name as in OpenTodo; a new folder is a new project, create it without asking).

## 2. What is a "big task"

Big = one message from the owner that changes more than one file, or takes over ~30 minutes, or anything you will want to remember later
(a decision, a deploy, a new integration, an investigation). Everything else (change a button colour, fix a typo) is small: leave the tracker alone
unless the owner says "write it down".

## 3. Session rhythm (Claude Code and claude.ai)

1. **Start.** Look at the open tasks of your project: `search_tasks` / `list_tasks` for the repository's section. If the owner's request is already
   there, work on that task (`update_tasks` → status doing); do not create a duplicate.
2. **Start of a big task.** Not in the tracker → create one task in **Agents** (section = repo, label `agent`, status doing):
   title = verb + object, ≤ 120 characters; one sentence in the notes saying what the owner asked.
3. **End of a big task.** Mandatory, before the final answer:
   - **Obsidian note** `obsidian/10 - Projects/<Project>/<YYYY-MM-DD> <Title>.md` from the template in section 5 (summary, what was done,
     checks, decisions, what is left). Commit to `main` of the infra repo (from another repo: through `gh api` / the GitHub MCP
     `create_or_update_file`; Obsidian-only changes go to `main` without a PR).
   - **Task in OpenTodo**: `complete_tasks` + `add_comment` with the summary of section 4. Label `done-by-agent`.
   - **Follow-ups**: everything left for a human, blocked or postponed → separate tasks (`agent`, no deadline, ≤ 5 per session),
     each linking to the note.
4. **Small task.** Nothing in the tracker; if a "later" grew out of it, one follow-up task.
5. **Once per session, not more.** Do not update the tracker after every step; one summary at the end of a big task.

The PM agent sorts agent tasks by priority and deadline; agents never set deadlines.

## 4. Summary format in the task (`add_comment`, 6–10 lines)

```
Done: <1–2 sentences, what exactly>
Verified: <tests / linters / manual checks, with the result: "24 tests green", "curl /healthz → 200">
Not verified: <what could not be checked from here and why>
Decisions: <1–3 key decisions with the reason>
Next: <follow-up tasks by title, or "none">
Note: obsidian/10 - Projects/<Project>/<file>.md · <link to PR / commit / session>
```

## 5. Obsidian note template

```markdown
---
project: <Project>
date: <YYYY-MM-DD>
task: <OpenTodo task id or "—">
agent: <claude-code-cloud | claude-code-server | claude-code-laptop | hermes | claude.ai>
status: done | partial | blocked
tags: [agent, <repo>]
---
# <Task title>

**Summary:** one sentence on why this was done.

## What was done
- …

## Checks
- <what was run> → <result>

## Decisions and why
- …

## What is left / risks
- …

Links: <PR, commit, session, document in the repo>
```

Notes and task titles are written in the owner's language; code, commits and file names as in the project. Secrets never appear in notes or tasks.

## 6. Hermes (Telegram) and claude.ai

- Hermes: the "Protocol: personal PM" block of `SOUL.md` (`hermes/install.sh`) points at this file instead of copying it, because the SOUL rides on every Telegram message; it writes notes straight into the vault folder.
- claude.ai (web / apps): the project instructions of your claude.ai project = sections 1–4 of this file; the `tasks` connector enabled.
  Both are updated by hand after a protocol change (rare).

## 7. Chat orchestrator and cost

The owner sets the goal, the chat drives it to a result: it works things out itself first, then acts, and asks only what is the owner's to decide.
Cost ≈ calls × average context × model price.

- **One task = one session.** Separate work (another repository, its own PR) goes to a new session with a brief; small things stay in this chat.
  A session's report is a claim: the orchestrator checks the result and the diff.
- **Hand over with a file, not with compaction.** Context over 250k → a 1–2 KB handoff: done, next, files `path:lines`, what was tried and why it failed, open questions.
- **Subagents do not save money:** 2–3 per task, one at a time, brief ≤ 2 KB (task, files, definition of done). At 180k context or 80 calls a subagent hands its work in.
- **Cache:** do not change `CLAUDE.md`, plugins, MCP servers or the model in the middle of a task. Commands over 3 minutes run in the background, not in a wait loop.
- **Read ranges, edit with patches,** fold test output to the summary and the failures, keep reports short.
- **Models:** a mid-size model for implementation and routine; the larger one for diff review and numeric logic; the strongest for 1–2 architectural forks; the smallest for search.
- **Verification is not trimmed:** "done" only after a run. A saving that causes over 20 % rework is fake.
