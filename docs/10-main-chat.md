# 10 · A main chat per direction

One long chat that talks, plans *and* does the work grows until it forgets why it started. The fix is a split:
**one main chat per direction talks, thinks, plans and checks; the work goes to child sessions the chat starts itself.**

A *direction* is a product, a repository, an area of life: anything you come back to over weeks. Each one gets a folder and one main chat that you keep opening.

## The rule

| Where | What happens |
|-------|--------------|
| **Main chat** | answers, discusses, reads a little to answer (up to ~5 calls), makes a one-line edit, checks what the child sessions report |
| **Child session** | edits, commits, deploys, setup, browser work, multi-step research; its first message begins with "Worker session:" and holds a brief of at most 2 KB |
| **Subagents** | pieces of one job. Independent jobs get their own sessions, at most three at once |
| **Start refused** | a background subagent instead, and one line to you saying so |
| **`HANDOFF.md`** | the direction's memory in its folder: a new chat reads it first, the main chat updates it at the end of a topic with a line "Next step: …" |

The main chat starts a child session in the same turn the talk turns into action, without asking. In the Claude desktop app that is `start_session` with `initiation "user_asked"`. The app treats that as your own instruction only if you gave it, so you give it once, in your global `CLAUDE.md` (below); without it you get an offer card every time.

Full text: section 7 of [the protocol](../plugin/PROTOCOL.md). The `orchestrator` skill carries the same steps for the main chat and for the worker.

## Set it up

1. **Make a folder per direction** and put a `HANDOFF.md` in it (an empty file is fine; the main chat fills it). A direction with a repository keeps `HANDOFF.md` in the repo root. A folder without a repository holds just a `CLAUDE.md` and a `HANDOFF.md`.
2. **Install the block into your global `CLAUDE.md`:**

   ```bash
   python3 scripts/install_global_md.py            # English
   python3 scripts/install_global_md.py --lang uk  # Ukrainian
   python3 scripts/install_global_md.py --dry-run  # print the result, write nothing
   ```

   It writes `~/.claude/CLAUDE.md`, or the path you pass as the last argument. The block sits between `<!-- bryhadyr:begin … -->` and `<!-- bryhadyr:end -->`. A re-run replaces only that block; the rest of the file stays as it is, line ends included. A file with a lone marker is refused and left untouched.
3. **Fill in the table of directions** (name → folder). The first install appends it under the heading "My directions", below the managed block. That section is yours: a re-run never touches it. The chat uses the table to move itself: a chat that starts in the wrong place switches to the folder of the direction with `change_directory`.

An example of a filled table, with made-up directions:

| Direction | Folder |
|-----------|--------|
| Shop website | `~/work/shop` |
| Newsletter | `~/work/newsletter` |
| Home network | `~/notes/home-network` |

4. **The SessionStart hook** (the plugin carries it) reads the folder the chat starts in. A repository, or a folder with a `CLAUDE.md` or `HANDOFF.md`, is a direction: no warning. Any other folder gets a one-line hint to switch to the direction's folder.

## Good to know

- On a weak server keep the number of long-lived sessions low and check free memory before you start one.
- A session's report is a claim. The main chat checks the diff, CI or a run of its own, and merges or publishes only when you say so.
