#!/usr/bin/env bash
# sync.sh — copy the plugin's protocol, hook, skill and .mcp.json into a repo as committed files, for sessions that install no plugins
# (Claude Code cloud sessions). Usage: scripts/sync.sh /path/to/repo [owner/bryhadyr-fork]
# Idempotent. Merges the marketplace, plugin and hook entries into the repo's .claude/settings.json, keeping what is there.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
R="${1:?usage: sync.sh /path/to/repo [owner/bryhadyr]}"
FORK="${2:-OWNER/bryhadyr}"
[ -d "$R" ] || { echo "no such directory: $R"; exit 1; }
mkdir -p "$R/.claude/bryhadyr" "$R/.claude/skills/bryhadyr"
cp "$HERE/plugin/PROTOCOL.md" "$HERE/plugin/hooks/session-start.sh" "$R/.claude/bryhadyr/"
[ -f "$HERE/plugin/PROTOCOL.uk.md" ] && cp "$HERE/plugin/PROTOCOL.uk.md" "$R/.claude/bryhadyr/"
cp "$HERE/plugin/skills/bryhadyr/SKILL.md" "$R/.claude/skills/bryhadyr/SKILL.md"
cp "$HERE/plugin/.mcp.json" "$R/.mcp.json"
python3 - "$R/.claude/settings.json" "$HERE/templates/claude-settings.json" "$FORK" <<'PY'
import json, os, sys
dst, src, fork = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(dst)) if os.path.exists(dst) else {}
f = json.loads(open(src).read().replace("OWNER/bryhadyr", fork))
for key in ("extraKnownMarketplaces", "enabledPlugins", "hooks"):
    d.setdefault(key, {}).update(f[key])
json.dump(d, open(dst, "w"), indent=2, ensure_ascii=False); open(dst, "a").write("\n")
print("synced", dst)
PY
echo "done: commit .claude/ and .mcp.json in $R"
