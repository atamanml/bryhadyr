#!/usr/bin/env bash
# install.sh — set up the PM in Hermes Agent: SOUL block (PM protocol + a pointer to the shared agent protocol), config fragment
# (MCP → OpenTodo, model aliases), four cron jobs. Idempotent: re-running refreshes the SOUL block, the config and the jobs.
# Needs in ~/.hermes/.env: OPENTODO_MCP_URL (e.g. http://127.0.0.1:8080/mcp), TELEGRAM_ALLOWED_USERS, OPENTODO_AGENT_TOKEN
# (copied from stack/.env when ~/.hermes/.env lacks it). ANTHROPIC_API_KEY is optional: with it the jobs run on Claude, without it
# on the default Hermes model; add the key and re-run to move them to Claude.
# Optional in ~/.hermes/.env: PM_DEFAULT_MODEL and PM_DEFAULT_PROVIDER (your everyday chat model, as Hermes names it, e.g. <model-id> and <provider>).
# They add the alias `default`, so `/model default` returns to it after `/model pm`, and switch off Hermes' built-in Mixture-of-Agents
# preset that is also called `default` (a preset wins over an alias; see hermes/config-fragment.yaml).
# Env: PROTOCOL_LANG=uk picks the Ukrainian SOUL block and prompts. `--soul-only` refreshes the SOUL block alone (for deploy hooks).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
HERMES_DIR="${HERMES_DIR:-$HOME/.hermes}"
H="$HERMES_DIR/hermes-agent/venv/bin/hermes"
PY="$HERMES_DIR/hermes-agent/venv/bin/python"
ENV_FILE="$HERMES_DIR/.env"
L="${PROTOCOL_LANG:-}"; sfx=""; [ -n "$L" ] && sfx=".$L"
SOUL_FRAG="$HERE/hermes/SOUL-pm${sfx}.md"; [ -f "$SOUL_FRAG" ] || SOUL_FRAG="$HERE/hermes/SOUL-pm.md"
PROTO="$HERE/plugin/PROTOCOL${sfx}.md"; [ -f "$PROTO" ] || PROTO="$HERE/plugin/PROTOCOL.md"
MARK="$(head -1 "$SOUL_FRAG")"     # the «## Protocol: …» heading is the block marker

restart_gateway() { systemctl --user restart hermes-gateway.service && echo "restarted hermes-gateway"; }

echo "=== 1. SOUL.md: PM protocol"
SOUL="$HERMES_DIR/SOUL.md"; BLOCK="$(mktemp)"
# the shared protocol rides on every Telegram message if copied into SOUL, so the block only points at the file
sed "s|{{PROTOCOL_PATH}}|$PROTO|g" "$SOUL_FRAG" > "$BLOCK"
BEFORE="$(cat "$SOUL" 2>/dev/null || true)"
if grep -qF "$MARK" "$SOUL" 2>/dev/null; then
  "$PY" - "$SOUL" "$BLOCK" "$MARK" <<'PYEOF'
import re, sys
soul, frag, mark = open(sys.argv[1]).read(), open(sys.argv[2]).read().rstrip("\n") + "\n", sys.argv[3]
pat = re.compile("^" + re.escape(mark) + r".*?(?=^## |\Z)", re.S | re.M)
open(sys.argv[1], "w").write(pat.sub(lambda m: frag, soul, count=1))
PYEOF
else
  printf '\n' >> "$SOUL"; cat "$BLOCK" >> "$SOUL"
fi
rm -f "$BLOCK"
if [ "$BEFORE" = "$(cat "$SOUL")" ]; then SOUL_CHANGED=0; echo "unchanged"; else SOUL_CHANGED=1; echo "updated"; fi
if [ "${1:-}" = "--soul-only" ]; then
  if [ "$SOUL_CHANGED" = 1 ] && systemctl --user is-active --quiet hermes-gateway.service; then restart_gateway; fi
  exit 0
fi

echo "=== 2. secrets in $ENV_FILE (values are never printed)"
if ! grep -qE '^OPENTODO_AGENT_TOKEN=.+' "$ENV_FILE"; then
  T="$(sed -n 's/^OPENTODO_AGENT_TOKEN=\([^ #]*\).*/\1/p' "$HERE/stack/.env" 2>/dev/null || true)"
  [ -n "$T" ] || { echo "missing OPENTODO_AGENT_TOKEN in $ENV_FILE and stack/.env"; exit 1; }
  printf '\nOPENTODO_AGENT_TOKEN=%s\n' "$T" >> "$ENV_FILE"; echo "OPENTODO_AGENT_TOKEN copied from stack/.env"
fi
for var in OPENTODO_MCP_URL TELEGRAM_ALLOWED_USERS; do
  grep -qE "^${var}=.+" "$ENV_FILE" || { echo "missing $var in $ENV_FILE"; exit 1; }
done
OWNER="$(sed -n 's/^TELEGRAM_ALLOWED_USERS=["]*\([0-9]*\).*/\1/p' "$ENV_FILE")"
[ -n "$OWNER" ] || { echo "TELEGRAM_ALLOWED_USERS has no numeric id in $ENV_FILE"; exit 1; }
if grep -qE '^ANTHROPIC_API_KEY=.+' "$ENV_FILE"; then
  MAIN_MODEL=claude-sonnet-5-5; CHEAP_MODEL=claude-haiku-5-5; PROVIDER=anthropic; echo "jobs run on Claude"
else
  MAIN_MODEL=""; CHEAP_MODEL=""; PROVIDER=""; echo "no ANTHROPIC_API_KEY: jobs run on the default Hermes model; add the key and re-run to move them to Claude"
fi

echo "=== 3. config.yaml: mcp_servers.tasks, model aliases, cron.wrap_response (comments kept, backup on change)"
# the token stays in .env: the config keeps the literal ${OPENTODO_AGENT_TOKEN}, Hermes expands it at run time
OPENTODO_MCP_URL="$(sed -n 's/^OPENTODO_MCP_URL=["]*\([^" ]*\).*/\1/p' "$ENV_FILE")" \
PM_DEFAULT_MODEL="${PM_DEFAULT_MODEL:-$(sed -n 's/^PM_DEFAULT_MODEL=["]*\([^" ]*\).*/\1/p' "$ENV_FILE")}" \
PM_DEFAULT_PROVIDER="${PM_DEFAULT_PROVIDER:-$(sed -n 's/^PM_DEFAULT_PROVIDER=["]*\([^" ]*\).*/\1/p' "$ENV_FILE")}" \
"$PY" - "$HERMES_DIR/config.yaml" "$HERE/hermes/config-fragment.yaml" <<'PYEOF'
import io, os, shutil, sys, time
from ruamel.yaml import YAML
path, frag_path = sys.argv[1], sys.argv[2]
y = YAML(); y.preserve_quotes = True; y.width = 4096; y.indent(mapping=2, sequence=4, offset=2)
before = open(path).read()
cfg = y.load(before) or {}
def merge(dst, src):
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict): merge(dst[k], v)
        else: dst[k] = v
frag = YAML(typ="safe").load(open(frag_path).read().replace("${OPENTODO_MCP_URL}", os.environ["OPENTODO_MCP_URL"]))
merge(cfg, frag)
if os.environ.get("PM_DEFAULT_MODEL") and os.environ.get("PM_DEFAULT_PROVIDER"):
    # `/model default` goes back to the everyday model; a preset of the same name would win over the alias, so it is switched off
    merge(cfg, {"model_aliases": {"default": {"model": os.environ["PM_DEFAULT_MODEL"], "provider": os.environ["PM_DEFAULT_PROVIDER"]}},
                "moa": {"presets": {"default": {"enabled": False}}}})
buf = io.StringIO(); y.dump(cfg, buf); after = buf.getvalue()
if after == before: print("unchanged")
else:
    shutil.copy2(path, f"{path}.bak-pm-{time.strftime('%Y%m%d%H%M%S')}")
    tmp = path + ".tmp"; open(tmp, "w").write(after); os.replace(tmp, path); print("merged")
PYEOF

echo "=== 4. cron jobs (times are in the gateway's time zone)"
job_id() {  # id of the job with this exact name, empty when there is none
  "$PY" - "$HERMES_DIR/cron/jobs.json" "$1" <<'PYEOF'
import json, sys
try: d = json.load(open(sys.argv[1]))
except OSError: sys.exit(0)
for j in (d.get("jobs", []) if isinstance(d, dict) else d):
    if j.get("name") == sys.argv[2]: print(j["id"]); break
PYEOF
}
job() {  # name schedule prompt-name model   (the prompt is positional in `cron create`; there is no --prompt and no model alias)
  local name="$1" sched="$2" file="$HERE/hermes/jobs/$3${sfx}.md" model="$4" id
  [ -f "$file" ] || file="$HERE/hermes/jobs/$3.md"
  id="$(job_id "$name")"
  if [ -n "$id" ]; then
    "$H" cron edit "$id" --schedule "$sched" --prompt "$(cat "$file")" --model "$model" --provider "$PROVIDER" >/dev/null && echo "updated: $name"
  elif [ -n "$model" ]; then
    "$H" cron create "$sched" "$(cat "$file")" --name "$name" --model "$model" --provider "$PROVIDER" --deliver "telegram:$OWNER" >/dev/null && echo "created: $name"
  else
    "$H" cron create "$sched" "$(cat "$file")" --name "$name" --deliver "telegram:$OWNER" >/dev/null && echo "created: $name"
  fi
}
job pm-morning "0 8 * * 1-5"  pm-morning "$MAIN_MODEL"
job pm-midday  "0 14 * * 1-5" pm-midday  "$CHEAP_MODEL"
job pm-evening "0 20 * * *"   pm-evening "$MAIN_MODEL"
job pm-weekly  "0 18 * * 0"   pm-weekly  "$MAIN_MODEL"

echo "=== 5. restart the gateway so the MCP tools and the SOUL block load"
restart_gateway
"$H" cron list | grep -E 'Name:|Next run:' | grep -A1 'pm-' || true
