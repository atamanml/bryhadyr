---
name: bryhadyr
description: The owner's agent protocol (bryhadyr). Use at the START of any non-trivial task and BEFORE the final answer of a big task (changes more than one file or takes over ~30 minutes) — record the task in OpenTodo (MCP «tasks»), write the Obsidian note, leave a summary with the checks that were run and the follow-up tasks. Also use when the user says "write it down", "put it in the tracker", "in Obsidian", "what's open in this project".
---

# bryhadyr: the agent protocol

Full text: `${CLAUDE_PLUGIN_ROOT}/PROTOCOL.md` (read it if it is not in context yet; the SessionStart hook usually has put it there).

## In short

1. **Start**: `search_tasks` / `list_tasks` for your repo's section of the **Agents** project. A task exists → `update_tasks` status doing.
   None and the task is big → `create_tasks` (project Agents, section = repo, label `agent`, status doing).
2. **Finish of a big task** (mandatory, before the final answer):
   - Obsidian note from the template in PROTOCOL.md §5, at `obsidian/10 - Projects/<Project>/<YYYY-MM-DD> <Title>.md` in the infra repo, branch `main`, no PR (see "Writing to Obsidian" below).
   - `complete_tasks` + `add_comment` in the format of PROTOCOL.md §4 (Done / Verified / Not verified / Decisions / Next / Note). Label `done-by-agent`.
   - Follow-ups: every "left for a human / blocked / postponed" → its own task (`agent`, no deadline, ≤ 5), the note linked in its notes.
3. **Small task**: leave the tracker alone, unless a follow-up grew out of it.
4. **MCP «tasks» unavailable** (no token, no connector): the same summary and the task list in the final answer as Obsidian Tasks
   (`## <repo>`, `- [ ] title #agent #<repo>` + an indented note line). The orchestrator or the owner moves them.

## Writing to Obsidian from any repo

- Inside the infra repo (local checkout or a cloud session of that repo): create the file under `obsidian/…`, run the repo's secret scanner,
  commit in English with the prefix `obsidian:`, `git push origin main` (Obsidian-only changes need no PR; in the cloud with a session branch,
  push the branch and fast-forward `main`).
- On the server from another directory: the same file under `~/<infra-repo>/obsidian/…`, commit, push `main`.
- In a cloud session of another repo: `add_repo <owner>/<infra-repo>` (claude-code-remote tool), then the GitHub MCP `create_or_update_file`
  (branch `main`, path `obsidian/10 - Projects/<Project>/<file>.md`, message `obsidian: <title>`). No access → put the note text in the final answer
  under the heading "Obsidian note"; the orchestrator saves it.
- Never: secrets, tokens, passwords, addresses of external services in notes or tasks.

## Project names (Obsidian folder = OpenTodo project)

Configured by the owner in PROTOCOL.md §1. A new repo → a new folder named after the repo.
