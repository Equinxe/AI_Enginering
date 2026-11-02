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
   - **Removing a variable from a settings file.** "Removing a variable from the file doesn't unset it in a running session; the removal takes effect the next time you launch `claude`" ([Environment variables](https://code.claude.com/docs/en/env-vars.md)). Deleting `CLAUDE_CODE_AUTO_COMPACT_WINDOW` from an `env` block therefore leaves the old window in force until you relaunch.
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

   When the override is unset, the window itself is the trigger: the same page defines the auto-compact window as "how full the context gets before compaction". The pages give no number for the "default percentage" the override cannot exceed.

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

   This test is not read-only. When the variable is unset, the command **saves** the value to your user settings, under `modelSettings` for the current model, and applies it to this session and later ones. To undo it, run `/autocompact auto`, which returns to the window tuned for the model. You can also delete that model's `autoCompactWindow` from `modelSettings` in `~/.claude/settings.json` ([Set the auto-compact window](https://code.claude.com/docs/en/model-config.md#set-the-auto-compact-window); [`modelSettings`](https://code.claude.com/docs/en/settings-reference.md#modelsettings)). Run the test with the size you actually want, so that a save is harmless.
3. **Set the window with `/autocompact`.** It applies to the current session and to later sessions on this model. To use the `autoCompactWindow` key or the variable instead, relaunch `claude` after the change. Do not expect `/clear` to apply it.
4. **Write the variable as a full token count**, such as `200000`. On Claude Code v2.1.304 or later, `200k` also works. Never write `200`.
5. **Read the status line against your window.** This is derived from the two pages above; neither page states it. Compaction runs when the status line reaches about (window × percentage ÷ 100) ÷ `context_window_size` × 100. Percentage is `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` when set, and 100 when it is unset (see cause 3). For example, a 400K window on a 1M model compacts near 40 %, not near 100 %.

**Prevention.** No framework check can prevent this. The window lives in the operator's own runtime configuration, which the framework neither installs nor reads. Two things limit the cost of a compaction that comes at the wrong moment:

- **This entry.** It makes the five causes quick to rule out.
- **The framework's `SessionStart` hook.** `install-hooks.sh` installs `hooks/session-start.sh` from `settings.example.json`. Claude Code runs a `SessionStart` hook that matches the `compact` source after compaction and adds its output to the compacted context ([What survives compaction](https://code.claude.com/docs/en/context-window.md#what-survives-compaction)). The hook prints the reading order and `SESSION_STATE.md`'s header, Next Step and blockers, so the session resumes from the recorded state, not from the summary alone. `/clear` fires the separate `clear` source ([Matcher patterns](https://code.claude.com/docs/en/hooks.md#matcher-patterns)). Since WU-IAENG-373, the template's matcher is `startup|resume|clear|compact`, so the hook also runs after `/clear` and re-injects the same state. A project installed before it gets `clear` when it re-runs `install-hooks.sh`, which updates the framework's earlier entry in place (`hooks/README.md`, Installation). Check the `SessionStart` matcher in the project's `.claude/settings.json` for what your installation does: without `clear`, the state is not re-injected after `/clear`.

## B. Your own status line no longer shows, or you want the context status line off

Audience: the operator, after `install-hooks.sh` has installed the context status line (WU-IAENG-379, issue #304). Pages checked on 26 October 2026.

**Symptom.** The status line shows `[<model>] ctx <n>% | 5h <n>%` where your own status line used to be. Or you want the framework's status line gone.

**Cause.** A `statusLine` in the project's `.claude/settings.json` wins over the one in your `~/.claude/settings.json` ([Settings precedence](https://code.claude.com/docs/en/settings.md#settings-precedence)). The framework's `hooks/context-statusline.sh` therefore runs your own command itself and prints its output. Its own line appears instead in four cases:
- your command exited non-zero, printed nothing, or took longer than `IAENG_CTX_CHAIN_TIMEOUT` seconds (10 by default). Claude Code also shows nothing for an empty output or a non-zero exit ([Script errors or hangs](https://code.claude.com/docs/en/statusline.md#script-errors-or-hangs));
- `jq` is not installed and your `statusLine` command holds a `\u` escape, which the script does not decode without `jq`;
- you have no `statusLine` of your own;
- your `statusLine` is in a `settings.local.json`. That one wins over the project's for you alone, so the framework's never runs, and `install-hooks.sh --check` reports it as `shadowed`.

**Remedy.** The one line that turns it off, run from the project root:

```bash
touch .ia-engineering/context-hooks.off
```

From the next update on, the script writes nothing and runs your own status line in its place, so you see exactly what you saw before the install, or nothing if you had none. The same holds with `IAENG_CONTEXT_HOOKS=off` in the environment Claude Code is launched from. Commit the file to turn it off for the whole project, or keep it untracked for yourself only. Do not delete the `statusLine` key instead: the next `install-hooks.sh` run adds it back. To check that your own command works on its own, run it with a sample payload, as the [status line page](https://code.claude.com/docs/en/statusline.md#script-errors-or-hangs) advises.

**Prevention.** `install-hooks.sh --check` reports the statusLine as `present`, `absent`, `near-miss` (a project statusLine kept as it is, such as one that runs under PowerShell) or `shadowed`. `hooks/README.md`, Context Status Line, gives the full contract.

## C. Every Bash command, or every edit, is refused without an "iaeng: BLOCKED" reason

Audience: the operator, with the guards installed by `install-hooks.sh` since WU-IAENG-410 (issue #351). Page checked on 29 October 2026.

**Symptom.** Claude Code refuses every Bash call, or every Edit and Write, in one checkout. The refusal does not carry the framework's `iaeng: BLOCKED —` line naming a rule. It may come about two minutes after the call.

**Cause.** The two guards, `block-escape-hatches.sh` (Bash) and `block-inline-suppression.sh` (Edit, Write, MultiEdit), are installed with `"onFailure": "block"` and a 120 s `timeout`. A failed guard then blocks the call, as exit code 2 would ([Block the action when a hook fails](https://code.claude.com/docs/en/hooks.md#block-the-action-when-a-hook-fails), Claude Code 2.1.295 or later). The page counts these as failures: the hook cannot start, it exits with a code other than 0 or 2, it reaches its timeout, or it prints JSON that cannot be parsed. In practice, check these in order:

1. **The hook files are missing in this checkout.** The usual case is a Claude Code session started inside a `git worktree` of the project whose framework submodule was never initialised (issue #368). The hooks then resolve from that worktree, the command in `.claude/settings.json` names a script that does not exist, and the hook cannot start. A subagent that Claude Code runs in a worktree is not affected. Observed on 29 October 2026 (WU-IAENG-414): its hooks ran with `$CLAUDE_PROJECT_DIR` set to the main checkout, so they resolved from the main checkout's initialised framework.
2. **The machine is too loaded for the guard to finish in 120 s.** On Windows, a guard's latency is mostly process creation, and it grows with the number of agents working in parallel (`Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md`).
3. **The guard itself failed,** for example with an exit code other than 0 or 2. That is a defect in the guard.

**Remedy.**

1. In a terminal, from that checkout's root, run `git submodule update --init`. Then check that the scripts the commands name exist: `ls ia-engineering/Adapters/ai-runtimes/claude-code/hooks/`.
2. Run fewer agents at once, then try the call again.
3. Run the guard by hand with a harmless payload. It must print nothing and exit 0:

   ```bash
   printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
     | bash ia-engineering/Adapters/ai-runtimes/claude-code/hooks/block-escape-hatches.sh; echo "exit $?"
   ```

   In the framework repository itself, the path starts at `Adapters/`. Any other result is a defect: open an issue with the output.

**Prevention.** Do not remove `onFailure`, or set it to `"continue"`, to get past this. Before WU-IAENG-410, the same checkout ran with no guard at all, and nothing said so. That is the failure this setting ends. `install-hooks.sh` reports a weakened guard entry as a near miss and adds the framework's entry back beside it.

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
- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` — the guards' latency under load, and why their timeout is 120 s

---

# Metadata

Owner: IA Engineering

Version: 0.0.15

Status: Draft

Category: Adapter — AI Runtime (Claude Code)

Severity: Recommended
