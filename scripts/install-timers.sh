#!/usr/bin/env bash
# install-timers.sh — install the user systemd timers of stack/: the notes mirror (every 15 min) and/or the session replies (every minute).
# Usage: scripts/install-timers.sh notes|replies|all      Run on the machine that has the vault and the Claude Code sessions.
# Needs stack/.env with OPENTODO_BASE_URL and OPENTODO_AGENT_TOKEN; the mirror also needs ~/.config/bryhadyr/notes-rules.json
# (copy stack/notes-rules.example.json). Idempotent. Remove with `systemctl --user disable --now <name>.timer`.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WHAT="${1:?usage: install-timers.sh notes|replies|all}"
case "$WHAT" in notes) UNITS="bryhadyr-notes-mirror";; replies) UNITS="bryhadyr-task-replies";; all) UNITS="bryhadyr-notes-mirror bryhadyr-task-replies";; *) echo "usage: install-timers.sh notes|replies|all"; exit 1;; esac
for var in OPENTODO_BASE_URL OPENTODO_AGENT_TOKEN; do
  grep -qE "^${var}=.+" "$HERE/stack/.env" 2>/dev/null || { echo "missing $var in $HERE/stack/.env"; exit 1; }
done
case "$WHAT" in notes|all)
  [ -f "${BRYHADYR_NOTES_RULES:-$HOME/.config/bryhadyr/notes-rules.json}" ] || {
    echo "no notes rules file: mkdir -p ~/.config/bryhadyr && cp $HERE/stack/notes-rules.example.json ~/.config/bryhadyr/notes-rules.json, then edit it"; exit 1; } ;;
esac
D="$HOME/.config/systemd/user"; mkdir -p "$D"
for u in $UNITS; do
  sed "s|@REPO@|$HERE|g" "$HERE/stack/systemd/$u.service" > "$D/$u.service"
  cp "$HERE/stack/systemd/$u.timer" "$D/$u.timer"
done
systemctl --user daemon-reload
for u in $UNITS; do systemctl --user enable --now "$u.timer"; done
systemctl --user --no-pager list-timers 'bryhadyr-*' | head -5
