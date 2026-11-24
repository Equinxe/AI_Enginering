# Claude Code Troubleshooting

---

# Purpose

This catalog records failures that belong to the **Claude Code runtime**, not to the framework. A session driven by another runtime never meets them, so they stay out of `Governance/TROUBLESHOOTING.md`. That catalog is runtime-neutral by `Core/AI_MANIFEST.md`, Principle X (AI Agnostic).

Entries use the same four fields as the Governance catalog: **Symptom**, **Cause**, **Remedy**, **Prevention**. See its "How to Read an Entry" section.

Every claim about Claude Code's behaviour cites the official page it comes from, at `code.claude.com/docs/en/`. Claude Code changes often. When a page and this file disagree, the page is right, and this file needs a Work Unit to correct it.

---

# Find Your Message

Search this table for the start of the message you see, then go to its entry.

| The message or symptom | Entry |
|---|---|
| Starts with `iaeng: BLOCKED —` | D |
| Starts with `iaeng: stop gate —`, `iaeng: SESSION_STATE.md does not exist`, `iaeng: lint failed for` or `iaeng: no linter ran for` | D |
| `… is isolated in the worktree <path>, but this command … Refusing to run it …` | E |
| Claude Code asks permission for a call, or auto mode blocks one | E |
| Every Bash call, or every edit, is refused with no `iaeng:` line, sometimes about 120 s after the call | C |
| git refuses during cleanup: `cannot delete branch '<branch>' used by worktree at '<path>'`, `contains modified or untracked files`, `cannot remove a locked working tree`, `working trees containing submodules cannot be moved or removed` | `DAILY_USE.md`, Step 7 |
| On Windows, a git command in a worktree under `.claude/worktrees/` fails with `Filename too long` | `Governance/TROUBLESHOOTING.md`, entry AE |
| Compaction comes later than the window you set | A |
| Your own status line no longer shows | B |

Where a human runs a command that a guard refused, and why an Employee stops instead of rewording it, is in `DAILY_USE.md`, Where a Human Runs a Refused Command.

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
2. **The machine is too loaded for the guard to finish in 120 s.** On Windows, a guard's latency is mostly process creation, and it grows with the number of agents working in parallel. The framework's **parallel-agent cap** limits them per machine (`Core/ORCHESTRATION.md`, Step 4, Dispatch Rules; Director decision D3, 17 November 2026):
   - **6 subagents, Employees included**, counting every Claude Code session on the machine, the framework's own included.
   - **3** while any session on the machine runs a framework at v0.0.15 or earlier, whose escape-hatch guard starts 80 or more processes per call.
   - One fewer for every main session open on the machine beyond the first.

   What was measured (`Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md`, The Parallel-Agent Cap):
   - With the lighter guard of v0.0.16, 6 calls at a time on a machine at 100 % CPU, the slowest of 144 guard calls took 9.8 s, on a load lighter than the heaviest measured.
   - The cap of 3 with the v0.0.15 guard was not measured at 3 calls at a time. One call at a time, that guard took up to 36 s; 8 at a time, it passed 120 s.

   Cause 1, and a guard that exits with a wrong code, fail at once. A refusal that comes about 120 s after the call is a timeout: this cause, or a guard that hangs (cause 3).
3. **The guard itself failed,** for example with an exit code other than 0 or 2, or because it hangs. That is a defect in the guard.

**Remedy.**

1. In a terminal, from that checkout's root, run `git submodule update --init`. Then check that the scripts the commands name exist: `ls ia-engineering/Adapters/ai-runtimes/claude-code/hooks/`. On Windows, if that fails with `Filename too long`, see `Governance/TROUBLESHOOTING.md` entry AE. A worktree whose `ia-engineering/` is initialised this way needs `--force` to be removed later (`DAILY_USE.md`, Step 7).
2. Bring the machine back within the parallel-agent cap of cause 2, then try the call again. The project's `CLAUDE.md` tells the Main Agent to keep to it: at or above the cap, a dispatch waits, and the cap never refuses one (`Templates/PROJECT_CLAUDE.md`, Main Agent).
   - **A project on v0.0.16 or later whose `CLAUDE.md` predates the cap:** copy the paragraph from the template.
   - **A project on v0.0.15:** neither its Core nor its template carries a cap, so the template's pointer leads nowhere. Write this in its `CLAUDE.md` instead, the cap of the v0.0.15 pilot conditions (#452, condition 2): "Never have more than 3 subagents running at once on this machine, Employees included, one fewer for every main session open on it beyond the first. Every Claude Code session on it counts. At or above the cap, tell the Director what waits; the cap delays a dispatch and never refuses one."
3. Run the guard by hand with a harmless payload. It must print nothing and exit 0:

   ```bash
   printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
     | bash ia-engineering/Adapters/ai-runtimes/claude-code/hooks/block-escape-hatches.sh; echo "exit $?"
   ```

   In the framework repository itself, the path starts at `Adapters/`. Any other result is a defect: open an issue with the output.

**Prevention.** Do not remove `onFailure`, or set it to `"continue"`, to get past this. Before WU-IAENG-410, the same checkout ran with no guard at all, and nothing said so. That is the failure this setting ends. `install-hooks.sh` reports a weakened guard entry as a near miss and adds the framework's entry back beside it.

## D. A call is refused with `iaeng: BLOCKED —`

Audience: the operator, and the Main Agent reading an Employee's report. The reasons below are the ones the guards on `develop` print, read from the hooks on 24 November 2026.

**Symptom.** A Bash call, or an Edit or Write, is refused at once with four lines:

```
iaeng: BLOCKED — <reason>
  <the rule, and what to do instead>
  A control in the way is a rule in the way: escalate it with this message quoted.
  If the Director has decided this action, a human runs it by hand — the hook never learns exceptions.
```

**Cause.** One of the framework's two guards refused the call. `block-escape-hatches.sh` reads every Bash command, and `block-inline-suppression.sh` reads every Edit, Write and MultiEdit (`hooks/README.md`). The first line gives the reason, and the second gives the rule and what to do instead. The tables below list every reason the two guards print.

**Remedy.**

1. Find the reason in the tables below.
2. If the message's second line names an allowed form, use it. The guard prints that form itself, so using it is not a way around the guard.
3. Otherwise an Employee stops and quotes the message in its Work Unit Report. It never rewrites the command into another form that does the same thing: that is routing around a blocking control (`Standards/RISK_STANDARD.md`, Forbidden Practices). A refusal it believes is wrong is reported the same way, with why the command is legitimate, and the Main Agent files it as an issue.
4. If the Director decides that the action should happen, a human runs it outside Claude Code (`DAILY_USE.md`, Where a Human Runs a Refused Command).

**The guard could not read the call.** These reasons say nothing about what the command does. The guard refuses what it could not inspect (`hooks/README.md`, Design Rules). Report a refusal that persists, with the message.

| Reason, after `iaeng: BLOCKED —` | Guard | What to do |
|---|---|---|
| `cannot read the hook payload as a JSON object` | Edit | Report it: the guard could not parse what Claude Code sent. |
| `cannot read tool_input.command from the hook payload (is jq installed?)` | Bash | Install `jq`. If it is installed, the guard could not parse what Claude Code sent: report it. |
| `strip-quotes.awk is missing next to this hook` | Bash | The framework checkout is incomplete. `git -C ia-engineering status` names the missing file. |
| `the lexer (awk) failed or printed nothing for this command` | Bash | Check that `awk` runs in this shell. |
| `this command expands to more alternatives than the hook will enumerate` | Bash | Write the command without the brace expansion. |
| `a rule's pattern does not compile in this shell` | Bash | Report it, with the bash version. |
| `the byte mapping (tr) failed` | Bash | Check that `tr` runs in this shell. |
| `this command has more than 2000 pipeline segments after expansion` | Bash | Split the command, or write it to a script file and run that. |
| `the option extraction (grep -o) failed or printed nothing` | Bash | Check that `grep` runs in this shell. |
| `Adapters/scripts/suppression-patterns.tsv is missing` | Edit | The framework checkout is incomplete. `git -C ia-engineering status` names the missing file. |
| `suppression-patterns.tsv holds a pattern grep cannot compile` | Edit | Fix the row the message quotes. |
| `malformed row in suppression-patterns.tsv` | Edit | Each row is a label, a TAB, then a pattern. Fix the row the message quotes. |
| `suppression-patterns.tsv holds no patterns` | Edit | Restore the file: an empty list would allow everything. |

**An escape hatch.** The command does what `Standards/GIT_STANDARD.md` (Escape Hatches) forbids.

| Reason, after `iaeng: BLOCKED —` | What to do instead |
|---|---|
| `--no-verify disables the commit-msg and pre-commit hooks` | Fix what the git hook refuses. A git hook that is wrong is a Work Unit against the hook. |
| `git commit -n is --no-verify in short form` | The same. |
| `disabling commit signing` | Fix the signing setup. |
| `setting core.hooksPath disables every git hook` | Only `install.sh` writes this setting. When the reason ends with `if this is a read, run git config --get core.hooksPath`, run that. |
| `GIT_CONFIG_PARAMETERS (or an assigning builtin naming GIT_CONFIG_KEY_<n>) sets arbitrary git config` | Set the value another way, or a human runs it. |
| `GIT_CONFIG_KEY_<n> names a git config key this hook cannot read` | Write the key literally in the command. |
| `GIT_CONFIG_KEY_<n> with a variable or substituted index` | Write the index and the key literally in the command. |
| `GIT_CONFIG_KEY_<n> or git -c / --config-env sets commit.gpgsign, include.*, includeIf.*, alias.* or core.fsmonitor` | Use the setting the project already has. |
| `git stash sets work aside with no record` | Commit work in progress on the branch. `git stash list` and `git stash show` are allowed. |
| `interactive git command in a non-interactive session` | Use the non-interactive form, and check the result with `git log` or `git status`. |
| `force-push or mirror-push` | Never. The one sanctioned rewrite is the data-purge protocol, run by a human on a Director decision. |
| `a + prefix on a push refspec forces the update` | Push without the `+`. If the remote refuses, that refusal is information. |
| `deleting a protected branch on the remote` | Never, for `main`, `develop` or `release/*`. |
| `an empty source in a refspec deletes the remote branch` | The same. |
| `git reset --hard discards uncommitted work` | Inspect first. Prefer a new branch, or a checkout of the one path you mean. |
| `git clean -f deletes untracked files that may not be yours` | Report the unexpected files instead of deleting them. |
| `discarding every working-tree change at once` | Restore the one path you mean, by name. |
| `force-deleting a branch discards unmerged commits` | Use `git branch -d`, which refuses an unmerged branch. For a branch checked out in a worktree, remove the worktree first (`DAILY_USE.md`, Step 7). |
| `checkout --force discards every uncommitted change to switch` | Commit the changes, or report them, first. |
| `writing a git alias whose value is an escape hatch` | Do not write it: the alias is the forbidden command with a shorter name. |
| `update-ref -d deletes a ref outright` | Delete a branch with `git branch -d`. |
| `history rewrite` | A Director decision, run by a human with a bundle backup first (`Standards/DATA_PROTECTION_STANDARD.md`, purge protocol). |
| `recursive removal of the repository metadata or the filesystem root` | Never (`Standards/RISK_STANDARD.md`, operational catalog, Critical). |

**An approval label, or an inline suppression.**

| Reason, after `iaeng: BLOCKED —` | What to do instead |
|---|---|
| `applying control-change/approved or size/approved — only the Director applies these approval labels` | Ask the Director to apply it. Removing the label, listing labels and naming it in text are allowed (`hooks/README.md`, Approval Label Guard). |
| `inline suppression: <label> (<file>)` | Configure the rule for the project, or satisfy it (`Standards/CODE_QUALITY_STANDARD.md`, No Inline Suppression). A tool's false positive that configuration cannot scope is applied by a human, with the constraint named on the line before it. |

**The Stop gate.** `stop-gate.sh` runs when a session is about to stop. It blocks the stop, not a tool call, and the agent then does what the message asks.

| Message | What to do |
|---|---|
| `iaeng: stop gate — tracked files have uncommitted changes:` | Commit, with the `Work Unit:` and `Employee:` trailers, or say in the final message why the changes stay uncommitted and what the Director must decide. |
| `iaeng: stop gate — .ia-engineering/SESSION_STATE.md is behind the repository` | Update `SESSION_STATE.md`. This is expected after a pull of `develop` (`DAILY_USE.md`, Step 8). |

Three other Stop gate lines block nothing: `iaeng: stop gate — HEAD's last commit is dated after the system clock`, `iaeng: stop gate — could not determine whether SESSION_STATE.md is current`, and `iaeng: SESSION_STATE.md does not exist — not blocking`.

**After an edit.** `iaeng: lint failed for <file>` comes from `post-edit-lint.sh`, after the edit is made. It refuses nothing. It hands the lint failure back to be fixed (`Standards/CODE_QUALITY_STANDARD.md`). `iaeng: no linter ran for <file>` only says that no linter applied to that file.

**Prevention.** Each rule of the Bash guard has a refused case and an allowed case in `hooks/tests/escape-hatch-cases.tsv`, which the **Hook Tests** check runs on every Pull Request (`Governance/TROUBLESHOOTING.md` entry W). Nothing yet checks these tables against the reasons the guards print (issue #491). Until something does, a Work Unit that adds or rewords a reason updates this entry in the same commit, as `Standards/DOCUMENTATION_STANDARD.md` asks of every change.

## E. A call is refused, and the message is not the framework's

Audience: the operator, and the Main Agent reading an Employee's report. Pages checked on 24 November 2026.

**Symptom.** A tool call is refused, and no `iaeng:` line says why. Variants:

- An Employee in a worktree is refused with a message such as this one, observed on a framework Employee's worktree on 24 November 2026: `This agent is isolated in the worktree <path>, but this command names git in a form too complex to verify that it stays inside the worktree. Refusing to run it — a worktree-isolated agent's git operations must target its own worktree. Split it into plain, separate commands and run them from <path>.`
- Claude Code asks permission for the call, or auto mode blocks it. A block usually shows a notification, but not when the classifier gives no verdict.

**Cause.** Claude Code's own controls refused the call, not the framework's.

1. **The worktree isolation checks.** In an isolated worktree, Claude Code blocks an edit of a path in the main checkout, a command whose working directory is the main checkout, a command that redirects git into it, and a command whose git it cannot verify from the text stays inside the worktree ([Worktrees, How Claude Code enforces isolation](https://code.claude.com/docs/en/worktrees.md#how-claude-code-enforces-isolation)). The page says that last check cannot be turned off. [Errors, Command blocked by the worktree isolation checks](https://code.claude.com/docs/en/errors.md#command-blocked-by-the-worktree-isolation-checks) gives the forms of the message and what to do. The message above came from a git command aimed at a scratch repository in a temporary directory, in a form the check could not verify. In another session on the same day, git work in a scratch directory ran when it was written as plain commands with every path spelled out in full, and a relative path was refused with a message that asked for the path in full (observed on 24 November 2026).
2. **Permissions.** A call the permission mode does not allow waits on a prompt. In auto mode, a call the classifier blocks shows a notification, and `/permissions` lists it under **Recently blocked**. When the classifier gives no verdict, the block comes without the notification or the **Recently blocked** entry ([Permission modes, When auto mode falls back](https://code.claude.com/docs/en/permission-modes.md#when-auto-mode-falls-back)).
3. A guard that cannot start, fails or times out also refuses with no `iaeng:` line. If every call is refused, that is entry C.

**Remedy.**

1. **Isolation.** Follow the remedy the message prints, such as plain, separate commands, or a path spelled out in full. That is the check's own way through. Git work in the main checkout or in another worktree is not the Employee's in that dispatch: it says so in its Work Unit Report, and the Main Agent decides where that work runs.
2. **Permission.** Answer the prompt. For an auto-mode block, approve the action in `/permissions` so that Claude may retry, or run the command yourself in a terminal (`DAILY_USE.md`, Where a Human Runs a Refused Command). A block with no verdict has no entry to approve: [Errors, Auto mode cannot determine the safety of an action](https://code.claude.com/docs/en/errors.md#auto-mode-cannot-determine-the-safety-of-an-action) gives its message and what to do.
3. In both cases, an Employee never rewrites the command to get the same action past the check (`Standards/RISK_STANDARD.md`, Forbidden Practices).

**Prevention.** None from the framework: these controls and their settings are Claude Code's. They come up less when an Employee does all its git work in its own worktree, on a branch made from `origin/develop` (`DAILY_USE.md`, Step 3).

---

# Adding an Entry

Follow `Governance/TROUBLESHOOTING.md`, "Adding an Entry", with one more rule. Every claim about the runtime cites the page of its official documentation and the date it was checked. A claim the pages do not make is labelled as derived or as observed, with how it was observed.

---

# Related Documents

- `Governance/TROUBLESHOOTING.md` — the runtime-neutral catalog and its entry format
- `Adapters/ai-runtimes/claude-code/DAILY_USE.md` — the daily loop, its cleanup, and where a human runs a refused command
- `Core/AI_MANIFEST.md` — Principle X, why runtime-specific entries live here
- `Adapters/ai-runtimes/claude-code/hooks/README.md` — what `session-start.sh` prints and when
- `Adapters/ai-runtimes/claude-code/settings.example.json` — the `SessionStart` matcher the installer writes
- `Templates/SESSION_STATE.md` — the state the hook re-injects
- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` — the guards' latency under load, why their timeout is 120 s, and the parallel-agent cap

---

# Metadata

Owner: IA Engineering

Version: 0.0.18

Status: Draft

Category: Adapter — AI Runtime (Claude Code)

Severity: Recommended
