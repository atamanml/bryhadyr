<!-- bryhadyr:begin (managed by scripts/install_global_md.py: re-running replaces everything between the markers, edit outside them) -->
## Agent protocol (bryhadyr)

Full protocol: the `bryhadyr` plugin puts it into the context at the start of a session (`plugin/PROTOCOL.md` in the bryhadyr repository). This block works even when the hook did not run.

### Main chat and child sessions (my standing instruction)
Every direction has one main chat, in its own folder. The main chat talks, thinks, plans and checks. Child sessions do the work.
- **Actions = a child session.** As soon as the conversation turns from discussion to action (edits, commits, deploy, setup, browser work, multi-step research), start a child session yourself, in the same turn, without asking: `start_session` with `initiation "user_asked"`. This sentence is my standing request, not an offer card. `context "fresh"` with a brief; `"fork"` when the work leans on this conversation.
- **Stays in the main chat:** an answer, a discussion, reading to answer (up to ~5 calls), a one-line edit, checking the children's results. If I say "do it here", do it here.
- **Independent jobs:** each in its own session, at most three at once. Pieces of one job: subagents.
- **Start refused** (I write from a remote client, or the app does not allow it): a background subagent (`Agent` with `run_in_background`) and one line to me that it is a subagent, not a child session.
- **Worker session:** its first message begins with "Worker session:". It does only the brief and starts no sessions. Begin every brief with these words.
- **Direction memory:** `HANDOFF.md` in the direction's folder. A new chat reads it first, then the transcripts on the topic (`list_sessions`, `search_session_transcripts`). The main chat updates it at the end of a topic and leaves a line "Next step: …". Do not ask me what is already in `HANDOFF.md` or in other chats.
- **A chat without a folder:** if the topic belongs to a direction, switch to its folder at the start (`change_directory`).
- **A weak server:** keep the number of long-lived sessions there low and check free memory before starting one.

The table of directions (name → folder) is in the section "My directions" of this file, below this block.

### Tasks and notes
A big task (more than one file, or about 30 minutes) → a task in the tracker through the MCP server `tasks` (the project is the topic; label `agent`; lines `From:` and `Done when:`). At the end: a note in the vault and a summary comment in the task: Done / Verified / Not verified / Decisions / Next / Note. Follow-ups for a human are separate tasks, up to 3 per session, `search_tasks` first, no duplicates. A question to me (label `waiting`) is written so that it can be closed: options, a line "I propose: …" and, for reversible decisions, "No answer by <date>: …". No secrets in tasks or notes.
<!-- bryhadyr:end -->

## My directions

| Direction | Folder |
|-----------|--------|
| <direction name> | `<path to its folder>` |
| <another direction> | `<path to its folder>` |

A folder with no repository of its own holds just a `CLAUDE.md` and a `HANDOFF.md`.
