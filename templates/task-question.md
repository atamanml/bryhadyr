A task an agent files when it needs the owner's decision and does not want to wait in the chat (protocol §3a).
Fields for `create_tasks`; the hook `plugin/hooks/task-check.sh` refuses it without the first two description lines.

title:       Which plan for the import: A (rewrite) or B (patch)?        # the question itself, ≤ 120 characters
labels:      agent, waiting
project:     <the project of the topic>
description: |
  From: <the owner's task this grew out of: <opentodo-url>/?task=<id> , or the request in one sentence>
  Session: <session id> · <machine>          # the SessionStart context prints this line ready to paste
  Context: A is two days and removes the legacy path; B is two hours and keeps it. I tried B on a copy: it passes the tests.
           Answer "A" or "B" in a comment and close the task.
  Note: 10 - Projects/<Project>/<file>.md    # when there is one
  Done when: the owner has answered
