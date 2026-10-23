# Claude Code Troubleshooting

---

# Purpose

This catalog records failures that belong to the **Claude Code runtime**, not to the framework. A session driven by another runtime never meets them, so they stay out of `Governance/TROUBLESHOOTING.md`. That catalog is runtime-neutral by `Core/AI_MANIFEST.md`, Principle X (AI Agnostic).

Entries use the same four fields as the Governance catalog: **Symptom**, **Cause**, **Remedy**, **Prevention**. See its "How to Read an Entry" section.

Every claim about Claude Code's behaviour cites the official page it comes from, at `code.claude.com/docs/en/`. Claude Code changes often. When a page and this file disagree, the page is right, and this file needs a Work Unit to correct it.

---

# Catalog

## A. Claude Code compacts later than expected, or the compaction setting seems ignored

Audience: the operator who runs `claude` with the framework installed. Pages checked on 23 October 2026.

**Symptom.** You set a smaller auto-compact window, but the conversation grows well past it before Claude Code compacts. Variants:

- You edited `autoCompactWindow` or `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, ran `/clear`, and nothing changed.
- `/autocompact` accepts a value, but compaction does not follow it.
- The status line shows 40 % and compaction runs, or shows 90 % and it does not.

**Cause.** Five separate mechanisms produce this symptom. Check them in order.

1. **The default threshold is near the end of a 1M window.** If you don't set a window, models that run with a native 1M window compact at about 967K tokens. These include the Fable models, Sonnet 5 and later, Haiku 5.5, and Opus 4.7 and later. Claude Code caps any window you set at the model's context window. Sources: [Default auto-compact thresholds](https://code.claude.com/docs/en/model-config.md#default-auto-compact-thresholds) and [Set the auto-compact window](https://code.claude.com/docs/en/model-config.md#set-the-auto-compact-window).

2. **A changed value is not picked up until the session reads it again.**
   - **Shell variable.** Claude Code reads shell environment variables at startup. A change "take[s] effect the next time you launch `claude`" ([Environment variables](https://code.claude.com/docs/en/env-vars.md)).
   - **Settings `env` block.** A value set there is reapplied to the running session when you save the file. The exception is a feature that reads its variable once at startup, which keeps its startup value until you relaunch ([Environment variables](https://code.claude.com/docs/en/env-vars.md); [`env`, When Claude Code applies `env` values](https://code.claude.com/docs/en/settings-reference.md#env)).
   - **`/autocompact`.** The command saves the value for the current model and "applies it to the current session" ([Set the auto-compact window](https://code.claude.com/docs/en/model-config.md#set-the-auto-compact-window)).
   - **What no page says.** None of these pages says whether the auto-compact window is read once at startup. None says when an edited `autoCompactWindow` key takes effect in a running session. None says that `/clear` re-reads either value. Don't rely on `/clear`; use `/autocompact` or relaunch.

3. **Another source takes precedence.** The window comes from the first source in this order that sets it:
   1. `CLAUDE_CODE_AUTO_COMPACT_WINDOW`. It wins over the command, the flag and the setting, unless Claude Code ignores its value. While it is set, `/autocompact` "reports the override without saving".
   2. `--autocompact` on the command line. It overrides the saved setting for that launch only.
   3. The window `/autocompact` saved for the current model, under `modelSettings` in your user settings. It wins over a top-level `autoCompactWindow` in the same file. A higher-priority settings scope, such as managed settings, keeps its own window. In that case the command saves your value, the session keeps the scope's window, and the command says so.
   4. `autoCompactWindow`, for every model.
   5. The default for the model (item 1).

   Sources: [Set the auto-compact window](https://code.claude.com/docs/en/model-config.md#set-the-auto-compact-window); [`autoCompactWindow`](https://code.claude.com/docs/en/settings-reference.md#autocompactwindow).

   The variable has two traps of its own ([Values and warnings for `CLAUDE_CODE_AUTO_COMPACT_WINDOW`](https://code.claude.com/docs/en/model-config.md#claude_code_auto_compact_window-values)):
   - **A bare number means tokens.** `CLAUDE_CODE_AUTO_COMPACT_WINDOW=200` means 200 tokens, which is raised to the 100,000 minimum with a warning. `/autocompact 200` means 200,000.
   - **An unusable value is ignored.** If the value isn't a usable size, Claude Code ignores it, warns, and falls back to the flag, the command, the setting or the default.

   `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` does not set the window. It is "the percentage (1-100) of the auto-compact window at which auto-compaction triggers". It "can't raise the threshold, so values above the default percentage are ignored". It "applies only in sessions that compact before the model's context limit" ([Environment variables](https://code.claude.com/docs/en/env-vars.md)). Use it only to compact earlier inside the window, never to delay compaction.

4. **Auto-compaction is off.** There are two variables, and they do different things ([Environment variables](https://code.claude.com/docs/en/env-vars.md); [`autoCompactEnabled`](https://code.claude.com/docs/en/settings-reference.md#autocompactenabled)):
   - **`DISABLE_AUTO_COMPACT=1`** turns off automatic compaction and idle compaction. The manual `/compact` command still works. It overrides the `autoCompactEnabled` setting: whichever of the two turns auto-compact off, the other can't turn it back on.
   - **`DISABLE_COMPACT=1`** turns off all compaction, both automatic and `/compact`.

5. **The status line measures something else.** `context_window.used_percentage` is a percentage of `context_window_size`, "Maximum context window size in tokens. 200000 by default, or 1000000 for models with extended context". It counts input tokens only ([Context window fields](https://code.claude.com/docs/en/statusline.md#context-window-fields)). The model-config page says this directly for the variable: "The status line's `used_percentage` measures against the model's full context window, so while the variable is set, that percentage doesn't indicate when compaction will run" ([Set the auto-compact window](https://code.claude.com/docs/en/model-config.md#set-the-auto-compact-window)).

**Remedy.**

1. **Find what is set.** In the shell that launches `claude`:
   - Git Bash: `printenv | grep -E 'COMPACT'`
   - PowerShell: `Get-ChildItem Env: | Where-Object Name -like '*COMPACT*'`

   Then search the settings files for `autoCompactWindow`, `modelSettings`, `autoCompactEnabled` and the four variables above, under `env`. Search `~/.claude/settings.json`, the project's `.claude/settings.json` and `.claude/settings.local.json`, and any managed settings. A value in an `env` block does not appear in your shell.
2. **Use the command to test for the variable.** Run `/autocompact` with a size, such as `/autocompact 400k`. If it reports an override without saving, `CLAUDE_CODE_AUTO_COMPACT_WINDOW` is set. Unset the variable, or set it to the window you want, and relaunch.
3. **Set the window with `/autocompact`.** It applies to the current session and to later sessions on this model. To use the `autoCompactWindow` key or the variable instead, relaunch `claude` after the change. Do not expect `/clear` to apply it.
4. **Write the variable as a full token count**, such as `200000`. On Claude Code v2.1.304 or later, `200k` also works. Never write `200`.
5. **Read the status line against your window.** This is derived from the two pages above; neither page states it. Compaction runs when the status line reaches about (window × percentage ÷ 100) ÷ `context_window_size` × 100. Percentage is `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` when set. For example, a 400K window on a 1M model compacts near 40 %, not near 100 %.

**Prevention.** No framework check can prevent this. The window lives in the operator's own runtime configuration, which the framework neither installs nor reads. Two things limit the cost of a compaction that comes at the wrong moment:

- **This entry.** It makes the five causes quick to rule out.
- **The framework's `SessionStart` hook.** `install-hooks.sh` installs `hooks/session-start.sh` from `settings.example.json`. Claude Code runs a `SessionStart` hook that matches the `compact` source after compaction and adds its output to the compacted context ([What survives compaction](https://code.claude.com/docs/en/context-window.md#what-survives-compaction)). The hook prints the reading order and `SESSION_STATE.md`'s header, Next Step and blockers, so the session resumes from the recorded state, not from the summary alone. `/clear` fires the separate `clear` source ([Matcher patterns](https://code.claude.com/docs/en/hooks.md#matcher-patterns)). Check the `SessionStart` matcher in the project's `.claude/settings.json`. If it lacks `clear`, the hook does not run after `/clear`. WU-IAENG-373 adds `clear` to the template's matcher.

---

# Adding an Entry

Follow `Governance/TROUBLESHOOTING.md`, "Adding an Entry", with one more rule. Every claim about the runtime cites the page of its official documentation and the date it was checked. A claim the pages do not make is labelled as derived or as observed, with how it was observed.

---

# Related Documents

- `Governance/TROUBLESHOOTING.md` — the runtime-neutral catalog and its entry format
- `Core/AI_MANIFEST.md` — Principle X, why runtime-specific entries live here
- `Adapters/ai-runtimes/claude-code/hooks/README.md` — what `session-start.sh` prints and when
- `Adapters/ai-runtimes/claude-code/settings.example.json` — the `SessionStart` matcher the installer writes
- `Templates/SESSION_STATE.md` — the state the hook re-injects

---

# Metadata

Owner: IA Engineering

Version: 0.0.15

Status: Draft

Category: Adapter — AI Runtime (Claude Code)

Severity: Recommended
