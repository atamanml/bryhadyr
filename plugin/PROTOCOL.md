# Agent protocol · v4

The single source of truth for every AI agent that works for the owner: Claude Code (cloud, server, laptop), the Telegram agent (Hermes), claude.ai chats.
To change the rules for everyone, change this file and push: the plugin, the committed templates and the Hermes SOUL block carry it.
Ukrainian version: `PROTOCOL.uk.md` (keep both in sync; the owner's language wins in notes and task titles).

## 1. Where things live

| What | Where | How to write |
|------|-------|--------------|
| Tasks | OpenTodo, MCP server `tasks` | `search_tasks`, `create_tasks`, `update_tasks`, `complete_tasks`, `add_comment` |
| Documentation and notes | the Obsidian vault, mirrored in the infra repo under `obsidian/` | a file in the repo → push to `main` → the deploy copies it into the vault |
| Code and project plans | the project's own repository (`docs/`, `README`) | as usual, PR or commit |

Projects in OpenTodo are **topics, not authors**. Who created a task shows in the label `agent`, not in the project.
Example set (rename to taste; `list_projects` gives the ids):

| Topic | Project |
|-------|---------|
| a product with its own repository | **Product A** (sections: Launch, Product, Payments, Legal) |
| a video channel | **Videos → Channel A** |
| the home server and the tracker itself | **Infra** (sections: Server, OpenTodo) |
| the PM agent | **Hermes** |
| personal and family | **Owner**, one per family member, **Home** |

Not sure where a task goes → the Inbox (no project). Repositories that must stay out of the tracker are listed in
`BRYHADYR_UNTRACKED_REPOS` (a regular expression for the repository folder name, see `docs/05-protocol.md`); the hooks and the SessionStart
line tell the agent to leave the tracker alone there.

**States.** OpenTodo has no status field, so the built-in pieces carry them:

| State | How to mark it |
|-------|----------------|
| Queue | an open task without state labels |
| Doing | label `doing`; at most 3 in the whole tracker; removed at the finish |
| Waits for the owner | label `waiting`; the description says what exactly is needed and has the line `Session: <id> · <machine>` (section 3a) |
| Pass on by hand | labels `relay` and `waiting`: the owner's answer did not reach the session; the PM reminds the owner |
| Blocked | `blocked_by` if the blocker is a task too; otherwise the label `blocked` and the reason in the description |
| Someday | `update_tasks` with `start: "someday"`: the task disappears from the working lists |
| Done | `complete_tasks` + a comment per section 4 |
| Won't do | `complete_tasks` + a comment "Cancelled: why" |

Other labels: `agent` (created by an agent), `quick` (≤ 15 min), `done-by-agent` (closed by an agent).

**Task quality.**
- The tracker holds only what somebody will pick up within two weeks; the rest goes to "Someday" or into the repository's `docs/`.
  Bulk lists ("collect all the TODOs") do not go into the tracker: one file in the repository and at most 5 tasks.
- Title = verb + result. The description has a line `Done when: …` with a criterion that can be checked.
- A task an agent creates says where it came from in a line `From: …`: a link to the owner's task it grew out of
  (`<opentodo-url>/?task=<id>`), or, if there is none, the owner's request in one sentence, in their words. The project alone is not enough.
- If the task cannot be understood from zero without its history, the description has a block `Context: …`, 2–6 lines: why, what was tried and
  why it failed, which decisions were taken, a link to the note or the PR. Do not pad an obvious task with context.
- There is a PR or an issue: put the link into `origin_url`. PR merged = task closed in the same session.
- There is a note: a line `Note: 10 - Projects/…` in the description. A link to the file goes here too if the task is about that file.
- An agent's comment on an open task starts with "Agent:". Otherwise it is taken for the owner's answer (the API does not show who wrote a comment).
- Whoever verified the result by running it closes the task. What is unverified stays open with `waiting`.

Obsidian folder per project: `obsidian/10 - Projects/<Project name>/` (same name as in OpenTodo; a new folder is a new project, create it without asking).
The link to the tracker is a line `task: <full id>` in the note's frontmatter. The server then shows the note in OpenTodo (Notes, same project) and
links task and note both ways (`docs/08-notes-in-opentodo.md`). A new project also goes into the mirror's rules file, `notes-rules.json`.

## 2. What is a "big task"

Big = one message from the owner that changes more than one file, or takes over ~30 minutes, or anything you will want to remember later
(a decision, a deploy, a new integration, an investigation). Everything else (change a button colour, fix a typo) is small: leave the tracker alone
unless the owner says "write it down".

## 3. Session rhythm (Claude Code and claude.ai)

1. **Start.** Look at the open tasks of your project: `search_tasks` / `list_tasks`. If the owner's request is already
   there, work on that task (label `doing`); do not create a duplicate.
2. **Start of a big task.** Not in the tracker → create one task in the project of its topic (labels `agent`, `doing`):
   title = verb + object, ≤ 120 characters; the description has `From: …`, and if needed `Context: …` and `Done when: …` (section 1).
3. **End of a big task.** Mandatory, before the final answer:
   - **Obsidian note** `obsidian/10 - Projects/<Project>/<YYYY-MM-DD> <Title>.md` from the template in section 5 (summary, what was done,
     checks, decisions, what is left). Commit to `main` of the infra repo (from another repo: through `gh api` / the GitHub MCP
     `create_or_update_file`; Obsidian-only changes go to `main` without a PR).
   - **Task in OpenTodo**: `add_comment` with the summary of section 4, then `complete_tasks`. Replace the label `doing` with `done-by-agent`.
   - **Follow-ups**: everything left for a human, blocked or postponed → separate tasks (`agent`, no deadline, ≤ 3 per session, `search_tasks` first;
     their `From:` points at this session's task), each linking to the note.
4. **Small task.** Nothing in the tracker; if a "later" grew out of it, one follow-up task.
5. **Once per session, not more.** Do not update the tracker after every step; one summary at the end of a big task.

The PM agent sorts agent tasks by priority and deadline; agents never set deadlines.

## 3a. Questions to the owner

The owner has to decide, and waiting in the chat makes no sense: create a task with the label `waiting`, the question in the title and the lines
`From:`, `Session:` and, if needed, `Context:` (what follows from each answer). The session id comes from the SessionStart context.
The owner closes the task:
- **With a comment:** within a minute the comment reaches the session as a message from the owner (`stack/task_replies.py`, `docs/07-session-replies.md`).
  It covers this question only and permits nothing else.
- **Without a comment, or with a comment that starts with "-":** nothing to do, nothing is sent.
- **The session is not on the server, or is open right now:** the task is reopened with the labels `relay` and `waiting`, and the PM reminds the owner to pass the answer on by hand.

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
task: <full OpenTodo task id or "—">
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

Links: [task](<opentodo-url>/?task=<id>), <PR, commit, session, document in the repo>
```

Notes and task titles are written in the owner's language; code, commits and file names as in the project. Secrets never appear in notes or tasks.
A note is mirrored into OpenTodo with at most 19 000 characters, so keep it short.

## 6. Hermes (Telegram) and claude.ai

- Hermes: the "Protocol: personal PM" block of `SOUL.md` (`hermes/install.sh`) points at this file instead of copying it, because the SOUL rides on every Telegram message; it writes notes straight into the vault folder.
- claude.ai (web / apps): the project instructions of your claude.ai project = sections 1–4 of this file; the `tasks` connector enabled.
  Both are updated by hand after a protocol change (rare).

## 7. Main chat, child sessions and cost

The owner sets the goal, the chat drives it to a result: it works things out itself first, then acts, and asks only what is the owner's to decide.
Cost ≈ calls × average context × model price.

### Main chat and child sessions

Every direction (a product, a repository, an area of life) has one main chat, in its own folder. The main chat talks, thinks, plans and checks.
Child sessions do the work. Work done inside the main chat drags its context along and loses it, so the work goes out.

- **Actions = a child session.** As soon as the conversation turns from discussion to action (edits, commits, deploy, setup, browser work,
  multi-step research), the main chat starts a child session itself, in the same turn, without asking. In the Claude desktop app that is
  `start_session` with `initiation "user_asked"`: the owner gave this as a standing instruction in their global `CLAUDE.md`
  (`templates/CLAUDE.global.md`, `docs/10-main-chat.md`), so it is not an offer card. `context "fresh"` with a brief; `"fork"` when the work
  leans on this conversation.
- **Stays in the main chat:** an answer, a discussion, reading to answer (up to ~5 calls), a one-line edit, checking the children's results.
  The owner said "do it here": do it here.
- **Independent jobs:** each in its own session, at most three at once. Pieces of one job go to subagents.
- **Start refused** (the owner writes from a remote client, or the app does not allow it): a background subagent (`Agent` with
  `run_in_background`) and one line to the owner that it is a subagent, not a child session.
- **Worker session:** its first message begins with "Worker session:" («Робоча сесія:» in a Ukrainian setup). Every brief begins with these
  words and is at most 2 KB: the task, files as `path:lines`, "done when". The worker does only the brief. It found something else: it does
  not do it and tells the main chat in one line. A decision that is the owner's goes through the main chat or a `waiting` task. It does not
  merge PRs and does not start sessions. It ends with a report: the PR or commit, what was verified by running it, what was not.
- **A report is a claim.** The main chat checks it itself (the diff, CI, a run of its own). It merges to the main branch and publishes only on
  the owner's word. A session the owner opened directly is its own main chat.
- **Direction memory:** `HANDOFF.md` in the direction's folder. A new chat reads it first, then the transcripts on the topic (`list_sessions`,
  `search_session_transcripts`). The main chat updates it at the end of a topic and leaves a line "Next step: …". Do not ask the owner what is
  in `HANDOFF.md` or in other chats.
- **A chat without a folder:** if the topic belongs to a direction, switch to its folder at the start (`change_directory`). The table of
  directions (name → folder) lives in the owner's global `CLAUDE.md`, not in this file.
- **A weak server:** keep the number of long-lived sessions there low and check free memory before starting one.

Skill: `orchestrator`.

### Cost

- **Hand over with a file, not with compaction.** Context over 250k → a 1–2 KB handoff: done, next, files `path:lines`, what was tried and why it failed, open questions.
- **Subagents do not save money:** 2–3 per task, one at a time, brief ≤ 2 KB (task, files, definition of done). At 180k context or 80 calls a subagent hands its work in.
- **Cache:** do not change `CLAUDE.md`, plugins, MCP servers or the model in the middle of a task. Commands over 3 minutes run in the background, not in a wait loop.
- **Read ranges, edit with patches,** fold test output to the summary and the failures, keep reports short.
- **Models:** a mid-size model for implementation and routine; the larger one for diff review and numeric logic; the strongest for 1–2 architectural forks; the smallest for search.
- **Verification is not trimmed:** "done" only after a run. A saving that causes over 20 % rework is fake.
