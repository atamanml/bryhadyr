---
name: bryhadyr
description: The owner's agent protocol (bryhadyr). Use at the START of any non-trivial task and BEFORE the final answer of a big task (changes more than one file or takes over ~30 minutes) — record the task in OpenTodo (MCP «tasks»), write the Obsidian note, leave a summary with the checks that were run and the follow-up tasks. Also use when you need the owner's decision and cannot wait for it in the chat (a task with the label waiting), and when the user says "write it down", "put it in the tracker", "in Obsidian", "what's open in this project".
---

# bryhadyr: the agent protocol

Full text: `${CLAUDE_PLUGIN_ROOT}/PROTOCOL.md` (read it if it is not in context yet; the SessionStart hook usually has put it there).

## In short

1. **Start**: `search_tasks` / `list_tasks` in the project of your topic (PROTOCOL.md §1). A task exists → label `doing`.
   None and the task is big → `create_tasks` in the project of the topic (labels `agent`, `doing`). The description must have
   `From: …` (a link to the owner's task, or the owner's request in one sentence), and if needed `Context: …` and `Done when: …`.
   The PreToolUse hook refuses a task without `From:`.
2. **Finish of a big task** (mandatory, before the final answer):
   - Obsidian note from the template in PROTOCOL.md §5, at `obsidian/10 - Projects/<Project>/<YYYY-MM-DD> <Title>.md` in the infra repo, branch `main`, no PR (see "Writing to Obsidian" below). `task: <full id>` in the frontmatter links it to the task.
   - `add_comment` in the format of PROTOCOL.md §4 (Done / Verified / Not verified / Decisions / Next / Note), then `complete_tasks`. Replace `doing` with `done-by-agent`.
   - Follow-ups: every "left for a human / blocked / postponed" → its own task (`agent`, no deadline, ≤ 3, `search_tasks` first, `From:` pointing at this session's task), the note linked.
   - The Stop hook reminds you once if you made changes and left no summary. A small task can simply end.
3. **A question for the owner** (PROTOCOL.md §3a): a task with the label `waiting`, the question in the title, lines `From:`, `Session: <id> · <machine>` (the SessionStart context gives the line) and `Context:`. When the owner closes it with a comment, the comment arrives in this session as a message from them. A comment of yours on an open task starts with "Agent:".
4. **Small task**: leave the tracker alone, unless a follow-up grew out of it.
5. **MCP «tasks» unavailable** (not in user scope, no repo `.mcp.json`, no connector): the same summary and the task list in the final answer as Obsidian Tasks
   (`## <repo>`, `- [ ] title #agent` + an indented note line). The orchestrator or the owner moves them.

## Writing to Obsidian from any repo

- Inside the infra repo (local checkout or a cloud session of that repo): create the file under `obsidian/…`, run the repo's secret scanner,
  commit in English with the prefix `obsidian:`, `git push origin main` (Obsidian-only changes need no PR; in the cloud with a session branch,
  push the branch and fast-forward `main`).
- On the server from another directory: the same file under `~/<infra-repo>/obsidian/…`, commit, push `main`.
- In a cloud session of another repo: `add_repo <owner>/<infra-repo>` (claude-code-remote tool), then the GitHub MCP `create_or_update_file`
  (branch `main`, path `obsidian/10 - Projects/<Project>/<file>.md`, message `obsidian: <title>`). No access → put the note text in the final answer
  under the heading "Obsidian note"; the orchestrator saves it.
- Never: secrets, tokens, passwords, addresses of external services in notes or tasks. Keep the note under 19 000 characters: the OpenTodo mirror cuts the rest.

## Project names (Obsidian folder = OpenTodo project)

Configured by the owner in PROTOCOL.md §1 and in the mirror's `notes-rules.json`. A new topic → a new folder named like its OpenTodo project.
