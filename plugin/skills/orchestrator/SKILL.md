---
name: orchestrator
description: Lead a large piece of work as the orchestrator chat, or work as a session under a brief. Use when the user asks the chat to orchestrate, to split work across sessions, when a task spans several repositories or PRs, when a session is getting long or expensive, or when a session was started from another one with a brief.
---

# Orchestrator and worker sessions

The rules are in `PROTOCOL.md`, section 7.

## If you are the orchestrator

1. Work out the problem yourself. Ask only what is the person's to decide.
2. Do small things here. Separate work (another repository, its own PR) goes to a new session, with a brief of at most 2 KB: the task, the files as `path:lines`, and "done when".
3. A session's report is a claim. Check it yourself: the diff, CI, a run of your own.
4. Merging to the main branch and anything public happens only on the person's word.
5. When the context grows past about 250k tokens, hand the work over in a short file (what is done, what is next, the files, what was tried and why it failed, open questions) rather than compacting.

## If you are a worker session

1. Do only what the brief says.
2. Found something else? Do not do it. Tell the orchestrator in one line.
3. A decision that belongs to the person: ask the orchestrator, or create a `waiting` task with a `Session:` line.
4. Do not merge PRs and do not start sessions unless the brief says so.
5. End with a report: the PR or commit, what you verified by running it, what you did not verify.
