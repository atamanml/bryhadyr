# 4 · The project manager: Hermes on Claude

The PM is not a new service. It is four cron jobs and a protocol block inside [Hermes Agent](https://github.com/NousResearch/hermes-agent),
which already has Telegram, cron with per-job model override, a native MCP client and per-user sessions. The jobs run on Claude through the
Anthropic API; the rest of Hermes keeps whatever cheap model you use for chat.

## What it does

| Job | When | Model | What |
|-----|------|-------|------|
| `pm-morning` | weekdays 08:00 | Sonnet 5.5 | intake of new agent tasks (project, section, priority, proposed deadline), plan of the day with 3 main tasks, overdue block, at most one question |
| `pm-midday` | weekdays 14:00 | Haiku 5.5 | silent unless a p1 is untouched, something is stuck 3+ days, or an agent added work |
| `pm-evening` | daily 20:00 | Sonnet 5.5 | done today, what to move and where, stuck items, tomorrow's 1–3, the `relay` block |
| `pm-weekly` | Sunday 18:00 | Sonnet 5.5 | what got done, what is stuck, projects without movement, 3 proposals, deadlines to confirm, **hygiene**, up to 7 tasks for next week's focus, a short block for each family member |

Rules that keep it bearable (SOUL block, `hermes/SOUL-pm.md`): never invent tasks; deadlines are proposals until you say "ok"; overdue → one line a day;
no empty reports (a quiet cron run answers exactly `[SILENT]`, so Hermes sends nothing); at most 3 unprompted messages a day; one pass over the tools per run.
The prompts name the OpenTodo tools `mcp__tasks__*`.

## The board stays healthy on its own

The PM is also the janitor. It never closes or postpones a task without your "ok" (obvious duplicates excepted).

- **Intake by topic.** Agents file tasks straight into the project of their topic (protocol §1), so the morning job does not sort a pile;
  it takes tasks with the label `agent` created in the last 24 hours, checks the section, proposes priority and deadline. A task without a
  `From:` line is not guessed at: the report asks where it came from.
- **Weekly hygiene** (up to 10 lines of "confirm: ok/no"): `doing` older than 7 days, an open task with no deadline older than 30 days
  (to Someday or cancel), Someday older than 90 days (close).
- **Weekly focus:** up to 7 tasks for next week; after your "ok" they get the `sector` of that week, so "this week" is one filter.
- **`relay`.** When your answer to a question could not reach the session ([docs/07-session-replies.md](07-session-replies.md)), the task is
  reopened with `relay` + `waiting`. Morning and evening digests list these in a block "Pass to the session" (title, session id, your answer).
  It counts as important news: not worth silence. The PM never closes such a task itself.

## Cost

Sonnet 5.5 is 2 / 10 USD per million tokens (cache reads 0.20), Haiku 5.5 0.10 / 0.50. With a stable SOUL (cached) and a few tool calls per run:

| Job | runs/month | ≈ tokens per run (in, mostly cached / out) | ≈ USD/month |
|-----|-----------|-------------------------------------------|-------------|
| morning | 22 | 25k / 3k | 4 |
| midday (Haiku) | 22 | 15k / 0.5k | 0.1 |
| evening | 30 | 25k / 3k | 5 |
| weekly | 4 | 60k / 5k | 1 |
| PM chats on Claude (`/model pm`), optional | | | 5–10 |
| **total** | | | **10–20** |

Without `ANTHROPIC_API_KEY` the jobs run on Hermes' default model instead and cost whatever that model costs.
Watch it in the Anthropic console the first month. Too high → move the evening job to `pm-cheap`, then trim the prompts' tool calls.

## Install

```bash
# ~/.hermes/.env: OPENTODO_MCP_URL=http://127.0.0.1:8080/mcp, TELEGRAM_ALLOWED_USERS, OPENTODO_AGENT_TOKEN
# (copied from stack/.env if missing), ANTHROPIC_API_KEY (optional),
# PM_DEFAULT_MODEL + PM_DEFAULT_PROVIDER (optional: your everyday chat model, for `/model default`, see below)
hermes/install.sh                 # SOUL block, config fragment, 4 cron jobs, gateway restart
PROTOCOL_LANG=uk hermes/install.sh   # Ukrainian SOUL block and prompts
~/.hermes/hermes-agent/venv/bin/hermes cron list
~/.hermes/hermes-agent/venv/bin/hermes cron run <id-of-pm-morning>     # try it now
```

What the installer does and why:

- **Jobs.** `hermes cron create` takes the prompt as a positional argument and has no model aliases, so the installer passes `--model` and
  `--provider` explicitly. Re-running updates existing jobs (`hermes cron edit`) instead of skipping them.
- **Without `ANTHROPIC_API_KEY`** the jobs are created without a model override and run on the default Hermes model. Add the key to
  `~/.hermes/.env` and re-run to move them to Claude (Sonnet 5.5 for morning, evening and weekly; Haiku 5.5 for midday).
- **`config.yaml`** is merged with `ruamel.yaml`, so your comments and formatting survive; a changed file is backed up as
  `config.yaml.bak-pm-<timestamp>` first.
- **The token stays in `.env`.** The config keeps the literal `${OPENTODO_AGENT_TOKEN}`; Hermes expands it at run time.
- **Only 13 OpenTodo tools.** `tools.include` in `hermes/config-fragment.yaml` limits Hermes to the tools the PM needs, so the full schema list
  does not ride on every Telegram message.
- **The SOUL block points at the protocol file** (`plugin/PROTOCOL.md` or `.uk.md`) instead of embedding a copy, for the same reason.
- **`/model default` and the Mixture-of-Agents trap.** The installer adds the aliases `pm` (Sonnet) and `pm-cheap` (Haiku). Setting
  `PM_DEFAULT_MODEL` and `PM_DEFAULT_PROVIDER` also adds `default`, so `/model pm` for a planning chat is undone by `/model default`.
  It also writes `moa.presets.default.enabled: false`, and that line is the point: Hermes ships a Mixture-of-Agents preset that is *also*
  called `default`, and Hermes matches presets before aliases. Without the switch, `/model default` starts the multi-model ensemble (several
  model calls per message) instead of returning to your model. `--provider moa` still reaches the ensemble when you want it. The alias and
  the switch are only written when both variables are set, because the everyday model is yours.
- `hermes/install.sh --soul-only` is what a deploy hook calls after a protocol change; it restarts the gateway only when the SOUL block changed.

## Skill, profile, or what?

A Hermes *profile* is a separate bot with separate memory. You want the same bot, so the PM is a SOUL block plus cron jobs with their own model.
Interactive PM questions in chat ("what's on today?") are answered by the chat's default model with the same MCP tools, which is fine for lookups;
for a real planning conversation switch with `/model pm` (the alias the installer adds) and back with `/model default`. Hermes does not switch models by
topic, and this repo does not try to.

## Family

Add their Telegram ids to `TELEGRAM_ALLOWED_USERS`; Hermes keeps a session per user. Their tasks live in their own OpenTodo project and in
"Home" (invite them in OpenTodo). A fifth job with `--deliver telegram:<their id>` and the weekly prompt's last section gives them their own
Sunday summary.
