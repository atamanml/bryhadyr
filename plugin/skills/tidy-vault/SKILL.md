---
name: tidy-vault
description: Reorganise an Obsidian vault. Use when the user asks to clean up, restructure or sort their Obsidian vault or inbox, or says their notes are a mess.
---

# Tidy up a vault

A vault holds private things. Work from names and structure, and read a note only as far as you need to decide where it belongs. Delete nothing: empty notes go to `.trash`, the rest moves.

## 1. Look, change nothing

`python3 "${CLAUDE_PLUGIN_ROOT}/tools/vault_audit.py" <vault> --deps <repo> <other folders with scripts>`

It shows structure, junk, broken links and which code names a folder. Read the vault's `README.md` and its inbox rule too, if there is one.

## 2. What must not move

- **A folder a pipeline or a bot writes to.** It shows in `--deps`, and a move breaks the writer. Describe it in the README as an exception.
- **Notes linked from tasks.** `notes_mirror.py` derives a note's id from its path and a task's chip points at the path: a note with `task:` in its frontmatter moves only together with a fix of the task's origin.
- **The inbox folder itself,** if a digest reads it. Sort what is inside, keep the folder.

## 3. Where things go

- A project: `<projects>/<Project>/`, named as in the tracker.
- **Access details, financial details, personal data: a `Private` subfolder.** The notes mirror matches one level only, so it stays out of the tracker and away from agents. Check `project_for` for each such note.
- If a move brings a folder under the mirror, look at what else comes with it. Agents should not get wider access by accident.

## 4. Acting

1. A backup outside the vault and outside any sync: `tar czf ~/vault-before-reorg-<date>.tar.gz …`, mode 600. Large media can stay out.
2. Move together: `mv` in the vault and `git mv` in a repository copy, if the file is tracked. If the texts differ, the vault's is newer.
3. Check first: the source exists, the target does not. Otherwise stop.
4. Update the vault's `README.md` and every rule that names an old path.

## 5. Verifying

- `vault_audit.py` again: no more broken links than before. A `[[Name]]` without a path survives a move, a link with a path does not.
- `notes_mirror.py --dry-run`, then a real run twice: the second changes nothing.
- Show the person what moved where, and where the backup is.
