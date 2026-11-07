---
name: orchestrator
description: The main chat of a direction and its child sessions. Use at the moment a conversation turns from discussion to action (edits, commits, deploy, setup, browser work, multi-step research), when the user asks to orchestrate, delegate, split work or start a session, when a task spans several repositories or PRs, when a session is getting long or expensive, when a chat starts without a project folder, or when the first message begins with "Worker session:" («Робоча сесія:»).
---

# Main chat and child sessions

The rules are in `PROTOCOL.md`, section 7. The setup for the person is in `docs/10-main-chat.md`.

## If you are the main chat

The main chat talks, thinks, plans and checks. Child sessions do the work.

1. Work out the problem yourself. Ask only what is the person's to decide. Read the direction's `HANDOFF.md` first, then the transcripts on the topic (`list_sessions`, `search_session_transcripts`).
2. The conversation turned to action (edits, commits, deploy, setup, browser work, multi-step research): start a child session yourself, in the same turn, without asking. In the Claude desktop app: `start_session` with `initiation "user_asked"` (the person's standing instruction in their global `CLAUDE.md`, not an offer card). `context "fresh"` with a brief; `"fork"` when the work leans on this conversation. `start_session` and the other session tools may be deferred: if they are not in your tool list, load them through ToolSearch first and treat them as unavailable only after that fails.
3. The brief is at most 2 KB and begins with "Worker session:" («Робоча сесія:» in a Ukrainian setup). It holds: the task, files as `path:lines`, "done when".
4. Stays here: an answer, a discussion, reading to answer (up to ~5 calls), a one-line edit, checking results. The person said "do it here": do it here.
5. Independent jobs: each in its own session, at most three at once. Pieces of one job: subagents.
6. Start refused (the person writes from a remote client, or the app does not allow it): a background subagent (`Agent` with `run_in_background`) and one line to the person that it is a subagent, not a child session.
7. A session's report is a claim. Check it yourself: the diff, CI, a run of your own. Merging to the main branch and anything public happens only on the person's word.
8. At the end of a topic update `HANDOFF.md` and leave a line "Next step: …". When the context grows past about 250k tokens, hand the work over in a short file (done, next, files, what was tried and why it failed, open questions) rather than compacting.
9. A chat without a folder, but the topic belongs to a direction: `change_directory` into its folder (the table of directions is in the person's global `CLAUDE.md`).
10. On a weak server keep the number of long-lived sessions low and check free memory before starting one.

## If you are a worker session (the first message begins with "Worker session:")

1. Do only what the brief says.
2. Found something else? Do not do it. Tell the main chat in one line.
3. A decision that belongs to the person: ask the main chat, or create a `waiting` task with a `Session:` line.
4. Do not merge PRs and do not start sessions.
5. End with a report: the PR or commit, what you verified by running it, what you did not verify.
