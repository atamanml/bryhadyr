#!/usr/bin/env bash
# install.sh — set up the PM in Hermes Agent: SOUL block (PM protocol + the shared agent protocol), config fragment (MCP → OpenTodo,
# model aliases), four cron jobs on Claude. Idempotent: re-running refreshes the SOUL block and the config, keeps existing jobs.
# Needs in ~/.hermes/.env: ANTHROPIC_API_KEY, OPENTODO_AGENT_TOKEN, OPENTODO_MCP_URL (e.g. http://127.0.0.1:8080/mcp), TELEGRAM_ALLOWED_USERS.
# Env: PROTOCOL_LANG=uk picks the Ukrainian SOUL block and prompts. `--soul-only` refreshes the SOUL block alone (for deploy hooks).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
HERMES_DIR="${HERMES_DIR:-$HOME/.hermes}"
H="$HERMES_DIR/hermes-agent/venv/bin/hermes"
PY="$HERMES_DIR/hermes-agent/venv/bin/python"
L="${PROTOCOL_LANG:-}"; sfx=""; [ -n "$L" ] && sfx=".$L"
SOUL_FRAG="$HERE/hermes/SOUL-pm${sfx}.md"; [ -f "$SOUL_FRAG" ] || SOUL_FRAG="$HERE/hermes/SOUL-pm.md"
PROTO="$HERE/plugin/PROTOCOL${sfx}.md"; [ -f "$PROTO" ] || PROTO="$HERE/plugin/PROTOCOL.md"
MARK="$(head -1 "$SOUL_FRAG")"     # the «## Protocol: …» heading is the block marker

for var in ANTHROPIC_API_KEY OPENTODO_AGENT_TOKEN OPENTODO_MCP_URL TELEGRAM_ALLOWED_USERS; do
  grep -qE "^${var}=.+" "$HERMES_DIR/.env" || { echo "missing $var in $HERMES_DIR/.env"; exit 1; }
done
OWNER="$(sed -n 's/^TELEGRAM_ALLOWED_USERS=["]*\([0-9]*\).*/\1/p' "$HERMES_DIR/.env")"

echo "=== 1. SOUL.md: PM protocol + shared agent protocol"
SOUL="$HERMES_DIR/SOUL.md"; BLOCK="$(mktemp)"
{ cat "$SOUL_FRAG"; echo; echo "### Shared agent protocol (plugin/PROTOCOL.md, copy)"; sed -e 's/^## /#### /' -e 's/^# /### /' "$PROTO"; } > "$BLOCK"
if grep -qF "$MARK" "$SOUL" 2>/dev/null; then
  "$PY" - "$SOUL" "$BLOCK" "$MARK" <<'PYEOF'
import re, sys
soul, frag, mark = open(sys.argv[1]).read(), open(sys.argv[2]).read().rstrip("\n") + "\n", sys.argv[3]
pat = re.compile("^" + re.escape(mark) + r".*?(?=^## |\Z)", re.S | re.M)
open(sys.argv[1], "w").write(pat.sub(lambda m: frag, soul, count=1))
PYEOF
  echo "updated"
else
  printf '\n' >> "$SOUL"; cat "$BLOCK" >> "$SOUL"; echo "appended"
fi
rm -f "$BLOCK"
if [ "${1:-}" = "--soul-only" ]; then
  systemctl --user is-active --quiet hermes-gateway.service && systemctl --user restart hermes-gateway.service && echo "restarted hermes-gateway"
  exit 0
fi

echo "=== 2. config.yaml: mcp_servers.tasks, model aliases, cron.wrap_response"
OPENTODO_AGENT_TOKEN="$(sed -n 's/^OPENTODO_AGENT_TOKEN=["]*\([^" ]*\).*/\1/p' "$HERMES_DIR/.env")" \
OPENTODO_MCP_URL="$(sed -n 's/^OPENTODO_MCP_URL=["]*\([^" ]*\).*/\1/p' "$HERMES_DIR/.env")" \
"$PY" - "$HERMES_DIR/config.yaml" "$HERE/hermes/config-fragment.yaml" <<'PYEOF'
import os, sys, yaml
path, frag_path = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(open(path)) or {}
text = open(frag_path).read().replace("${OPENTODO_AGENT_TOKEN}", os.environ["OPENTODO_AGENT_TOKEN"]).replace("${OPENTODO_MCP_URL}", os.environ["OPENTODO_MCP_URL"])
frag = yaml.safe_load(text)
def merge(dst, src):
    for k, v in src.items():
        dst[k] = merge(dst.get(k) or {}, v) if isinstance(v, dict) and isinstance(dst.get(k), dict) else v
    return dst
merge(cfg, frag)
open(path, "w").write(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False)); print("merged")
PYEOF

echo "=== 3. cron jobs (times are in the gateway's time zone)"
"$H" cron create --help 2>&1 | grep -q -- '--prompt' || { echo "this hermes has no 'cron create --prompt'; create the four jobs in the Hermes chat from hermes/jobs/*.md (docs/04-pm-agent.md)"; exit 1; }
job() {  # name schedule prompt-file model-alias
  local name="$1" sched="$2" file="$HERE/hermes/jobs/$3${sfx}.md" alias="$4"
  [ -f "$file" ] || file="$HERE/hermes/jobs/$3.md"
  if "$H" cron list --all 2>/dev/null | grep -q "$name"; then echo "exists: $name"; return; fi
  "$H" cron create "$sched" --name "$name" --prompt "$(cat "$file")" --model "$alias" --deliver "telegram:$OWNER" && echo "created: $name"
}
job pm-morning "0 8 * * 1-5"  pm-morning pm
job pm-midday  "0 14 * * 1-5" pm-midday  pm-cheap
job pm-evening "0 20 * * *"   pm-evening pm
job pm-weekly  "0 18 * * 0"   pm-weekly  pm

echo "=== 4. restart the gateway so the MCP tools and the SOUL block load"
systemctl --user restart hermes-gateway.service && echo "restarted hermes-gateway"
"$H" cron list
