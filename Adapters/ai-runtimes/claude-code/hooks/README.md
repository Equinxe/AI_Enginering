# Claude Code Hooks

---

# Purpose

`Adapters/git-hooks/` and `Adapters/github-actions/` enforce framework rules at commit time and at merge time. Both are late: by then the model has already run the command, written the file, or ended the session. Claude Code exposes **hooks** — shell commands it runs at fixed points of its own loop (session start, before and after a tool call, at stop) — and those points are early enough to refuse an action instead of rejecting its result.

These hooks make five rules mechanical for the one runtime that currently exposes the points to do it:

| Hook | Event | Rule enforced | Source |
|---|---|---|---|
| `session-start.sh` | `SessionStart` (startup, resume, compact) | Read first: `CLAUDE.md`, then `.ia-engineering/SESSION_STATE.md`, then the brief — printed into context with the *current* state (last update, next step, blockers) so the reading order is seen, not remembered. If `CLAUDE.md` does not exist yet (a project that has not completed `Workflows/PROJECT_BOOTSTRAP.md` Phase B / the `Workflows/ONBOARDING.md` Step 1 handoff), it says so instead of asserting the line, and names `Templates/PROJECT_CLAUDE.md` as the source when the framework's own root can be found. Also warns — never blocks — when `SESSION_STATE.md` is behind the repository, when its `_Last updated:` header was not refreshed on the file's last edit, or when it has grown past a size budget; see SESSION_STATE Freshness below | `Core/AGENT_CONDUCT.md`, Read First; `Core/CONTEXT_BUDGET.md` |
| `block-escape-hatches.sh` | `PreToolUse`, matcher `Bash` | No `--no-verify`, no `--no-gpg-sign`, no `stash` in place of a commit, no interactive git in a non-interactive session, no force/mirror push, no deletion of a protected branch, no `reset --hard` / `clean -f` / `checkout -- .` / `branch -D`, no history rewrite, no `rm -rf` of `.git` or `/`, no `core.hooksPath` write in any case spelling or via a global option, no opaque `GIT_CONFIG_PARAMETERS`/`GIT_CONFIG_KEY_<n>` env-var config injection, including through `printf -v`, `read`, `export`, `declare` and the other assigning builtins; no command that applies the Director-only approval labels (see Approval Label Guard below) | `Standards/GIT_STANDARD.md`, Escape Hatches; the Approval Label Guard section below |
| `block-inline-suppression.sh` | `PreToolUse`, matcher `Edit\|Write\|MultiEdit` | No inline linter / type-checker / test-runner disable written into code; no skipped or focused test; no swallowed exception. Documentation files are the named exemption — the Standard has to be able to quote what it forbids | `Standards/CODE_QUALITY_STANDARD.md`, No Inline Suppression |
| `post-edit-lint.sh` | `PostToolUse`, matcher `Edit\|Write\|MultiEdit` | The file just written passes `bash -n` and `shellcheck` (shell), and the project's own `.ia-engineering/lint.sh` when it exists; a failure returns to the model immediately. When nothing applicable ran, it says so | `Standards/CODE_QUALITY_STANDARD.md`, Automated Quality |
| `stop-gate.sh` | `Stop` | The session does not end with tracked files changed and uncommitted, unexplained (one continuation granted via the `stop_hook_active` guard). **Also blocks** when `.ia-engineering/SESSION_STATE.md` exists and is older than HEAD's last commit, so the agent updates it before the session ends; a missing file gets a non-blocking reminder instead — see SESSION_STATE Freshness below | `Core/AGENT_CONDUCT.md`, Reporting Contract; `Templates/SESSION_STATE.md` |

---

# What They Are Not

- **Not a substitute for the git hooks or CI.** A model can be run without these hooks; a Pull Request cannot merge into `main` without the CI checks. These hooks remove the *first* opportunity to break a rule; `Adapters/git-hooks/` is a second local guardrail of the same kind, skipped by `--no-verify` or a `core.hooksPath` override — the escape hatches the runtime hook refuses; `Adapters/github-actions/`, behind branch protection, removes the last opportunity — the one a developer machine cannot skip, within the conditions `SECURITY.md` (Where the boundary is) states.
- **Not the framework's policy.** Every rule here is stated in a Standard or a Core document first; the hook is the executable form, and where they disagree the document wins (`Registry/README.md`, Authority). A rule that exists only in a hook is a rule the framework does not have — see `Adapters/README.md`, the Check Convention.
- **Not configurable around.** There is no environment variable that disables a block. The exception path is the one the Standards define: a human applies the action by hand after the Director decides, and the decision is recorded (`Standards/RISK_STANDARD.md`). A hook that can be told to look away is a suggestion.

**Not an adversary boundary.** The escape-hatch hook reads the command text. It models the shell's own constructions — quoting, ANSI-C `$'\x2d'`, brace expansion, command substitution, and `printf`'s backslash escapes (`git push origin $(printf '\x2b')…` and `$(printf '\x2d\x2dforce')` are decoded like the quoted forms, because printf's decoding is a deterministic shell mechanic). It cannot see a flag whose *value* is produced at runtime: a token an external program prints (`$(python -c …)`, `$(base64 -d …)`, `$(echo .. | tr . -)`), a flag a variable carries (`F=--force; git push $F`) or one split across two variables, `eval "$CMD"`, or a flag read from a file. Recovering those would mean evaluating the command, which is the thing the hook exists to happen *before*, and each is one keystroke from the next — so the honest line is "shell mechanics, yes; runtime values, no." It stops an escape hatch reached for by habit — which is the realistic failure — and the server side stops the rest: branch protection and the required CI checks, which run where a developer machine cannot skip them (within the conditions stated in `SECURITY.md`, Where the boundary is). The `pre-push` hook is a second local guardrail, not part of that boundary — it is skipped by `--no-verify` or a `core.hooksPath` override — the escape hatches the runtime hook refuses. Claiming more than that would be the false confidence this framework refuses elsewhere.
- **Not AI-agnostic.** They target Claude Code's hook contract (JSON on stdin; exit 0 allow, exit 2 block with stderr to the model; `stop_hook_active` on Stop). Another runtime with equivalent points gets its own directory under `Adapters/ai-runtimes/`; the Standards they enforce are the same. This is the same boundary `generate-agents.sh` draws: runtime-specific mechanics live in the Adapter, never in `Core/` or `Standards/`.
- **Not a Bash-command scanner.** `block-inline-suppression.sh` sees only Edit/Write/MultiEdit. A directive written through the Bash tool (`sed -i`, `tee`, `>`) is not inspected here, by design — the command text cannot be read for it without refusing every command that merely mentions a directive. A server-side advisory check, `Inline Suppression`, scans the Pull Request's added lines with the same pattern list (`Adapters/scripts/suppression-patterns.tsv`, which this hook also reads and fails closed without); it is not a required check, so a Pull Request can still merge past it until the Director promotes it.

---

# Design Rules

**Fail closed.** A hook that cannot read its input — `jq` missing and the fallback extraction finding nothing — blocks with the reason, rather than allowing what it could not inspect. The `lib.sh` helpers read with `jq` when present and with a sed extraction of the flat fields otherwise; the fallback can over-block (it matches the whole payload for suppression patterns), never under-block.

**Strip before matching.** `block-escape-hatches.sh` removes single-quoted strings, double-quoted strings, and heredoc bodies before applying its patterns. A commit message that *mentions* `--no-verify` is not a use of it, and this framework's own Standards mention every pattern the hook blocks. A sibling kit's first version blocked its own documentation commits for this reason.

**Name the exemption.** Documentation files are exempt from the suppression hook, by extension, in the script. `git stash list` and `git stash show` are exempt from the stash rule. `git push --delete` of a non-protected branch is allowed. Each exemption is a line a reviewer can read; none is a fall-through.

**Say what did not run.** `post-edit-lint.sh` reports "no linter ran for this file" rather than exiting silently, because silence reads as a pass.

---

# Purple Exercise #112 Corrections (29 Sep 2026)

Director-authorized static penetration test of `block-escape-hatches.sh`. Three findings against the `core.hooksPath` rule and the global-options prefix, closed under WU-IAENG-306; the other findings from the same exercise are separate Work Units and out of scope here.

- **Case-insensitivity.** git treats a config section and key case-insensitively — `core.hooksPath`, `core.HooksPath` and `CORE.HOOKSPATH` all disable the same hook — and the rule matched only the lowercase spelling. It now uses `check_key`, the same case-insensitive helper already used for `commit.gpgsign`.
- **`GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_KEY_<n>`.** These environment variables set git config for every git command that inherits them. `GIT_CONFIG_PARAMETERS=` is refused as a token, because its encoding is not decoded from the stripped command text. `GIT_CONFIG_KEY_<n>=` is refused when its value is empty, ends at a separator, or contains a `$` (a variable or substitution, whole or partial), so the key cannot be read from the command text. A fully literal key is judged by the case-insensitive `core.hooksPath` rule; a literal non-hooksPath key such as `safe.directory` stays allowed.
- **Set through an assigning builtin, not just `NAME=` (WU-IAENG-316, PT2-07).** The variable can be set with no `NAME=` token: `printf -v`, `read`, `mapfile`/`readarray`, `export`/`readonly`/`declare`/`typeset`/`local`, `for NAME in`, `getopts`, `NAME+=` and `${NAME:=…}`. These are refused for `GIT_CONFIG_PARAMETERS` and for `GIT_CONFIG_KEY_<n>` (whose key is unreadable when a builtin sets it) when the name is the builtin's operand at command position, after any options and other names (`read -r a GIT_CONFIG_PARAMETERS`, `export A GIT_CONFIG_PARAMETERS`). Reading, removing and searching stay allowed: `printenv`, `echo "$GIT_CONFIG_PARAMETERS"`, `unset`, `grep`, `declare -p`, `export -p`, a commit message or heredoc that mentions the name. `export -n NAME` and `declare -n NAME` are allowed: `-n` removes the export attribute (or makes a reference) and sets no value. `GIT_CONFIG_VALUE_<n>` and `GIT_CONFIG_COUNT` are not refused in any form, as before; the key is what decides the risk. This is a speed bump: a name inside quotes (`export "GIT_CONFIG_PARAMETERS"`), a nameref (`declare -n r=GIT_CONFIG_PARAMETERS; r=…`), and a value built indirectly (`eval "$S"`, a script file) are still not seen. `read X < GIT_CONFIG_PARAMETERS` (a file of that name) is refused, a known false positive.
- **The global-options prefix (`G`) was too narrow.** It recognised `-C`, `-c`, `--git-dir=`, `--work-tree=`, `--no-pager` and `-P` — any OTHER real git global option ahead of the subcommand (`--no-replace-objects`, `--literal-pathspecs`, `-p`, `--no-optional-locks`, `--namespace=`, `--config-env=`, the space form of `--git-dir`) walked past every rule that anchors on `${G}<subcommand>`. `G` now matches every no-argument long option by shape, `-p`/`-P`, and the value-taking global options in both `=value` and `SPACE value` form.
- **The `core.hooksPath` read exemption was unanchored.** It matched a read flag and the key name anywhere in the command, in either order. It is now judged per segment (the command is split on `;`, `&`, `|` and newline): a segment is exempt only when it is a `git config` read (`--get`, `--get-all`, `--get-regexp`, `--list`, `-l`, `get`, `list`) that names `core.hooksPath`, with only a closed list of options (`--global`, `--system`, `--local`, `--worktree`, `--show-origin`, `--show-scope`, `--includes`, `--no-includes`, `--null`, `--name-only`, `-z`, and `--file`/`--blob`/`--type`/`--default` with a value) around the read keyword. Any other option leaves the segment un-exempted. A `-c`/`--config-env` naming hooksPath in the segment is never exempted, and a read in one segment does not exempt another segment. The legacy positional get `git config [--local|--global|--system|--worktree|--file X] core.hooksPath`, with nothing after the key, is also a read and is exempt on the same terms; the key must end the segment in the raw command text too, so `core.hooksPath ""` (an empty-value write that the lexer strips down to the same shape) stays refused, as do `--add`, `--replace-all`, `--unset`, `--unset-all`, `set` and `-c core.hooksPath=…`.

`hooks/tests/escape-hatch-cases.tsv` carries the reproducing cases for all four corrections, each verified to fail against the pre-fix rule before the fix landed.

---

# Approval Label Guard

Rule: an agent never applies `control-change/approved` or `size/approved`. Only the Director does. `block-escape-hatches.sh` refuses a command that would apply either label, case-insensitively, and the block message says so.

Refused: `gh pr|issue edit --add-label` and `gh pr|issue create --label|-l` naming either label (also inside a comma list, in the `=` form, in a repeated flag, or in a quoted list with spaces such as `--add-label "help wanted,size/approved"`, which is read from a second lexing of the command in which quoted regions are kept as single words, so a label flag that is really a flag has its quoted value read, while the text of a `--body`, a `--title`, a commit message or a heredoc body is never read as a flag, a `gh` command or an alias; `$'...'` quoting is read the same way); the same commands with a repo flag before or inside the subcommand (`gh -R o/r pr edit`, `gh pr --repo=o/r edit`) or as `gh.exe`; `gh api` writes (a POST/PUT/PATCH, or any `-f`/`-F`/`--field`/`--raw-field`/`--input`) that name either label, where a GET or DELETE method exempts the command only if no POST/PUT/PATCH method is also present; a `gh api` write with `--input` to a `labels` endpoint or to an issue or pull request endpoint (`issues/N`, `pulls/N`, with or without `/labels`), because the file cannot be read and unread input is refused; `gh label edit --name|-n` renaming another label into either name; `gh label create` of either name; `gh label clone --force`, for the same reason as create; `gh alias set|import` when the command text names either label. The whole rule is skipped, with no process spawned, for a command with no `gh` in it.

Allowed on purpose: every read (`gh pr view --json labels`, `gh label list`, `gh pr list --label …`, `gh api` with no write); **removing** either label (`--remove-label`, `gh api -X DELETE`, `gh label delete`), because removal only withdraws an approval and can never grant one; editing the label's colour or description; mentioning the name in a commit message, a comment, `grep`, or `echo`, since quoted text is stripped as for every other rule.

Creating the label is refused although it applies nothing: the Director creates these two labels, so an agent has no legitimate reason to, and `gh label create --force` would otherwise let it redefine the label the guard workflow trusts.

**This is a speed bump, not a boundary.** The pull-request guard cannot tell an agent from the Director when both act under the same GitHub identity, so this hook only interrupts the agent that reaches for the label by habit or by mistake. The Bash tool can build the command indirectly and none of that is seen here: a variable, `eval`, a script written to disk, a label name produced by a command substitution, `curl` against the API, a GraphQL `addLabelsToLabelable` mutation (its query text is quoted and its label ids are opaque, so REST `--input` on the labels, issue and pull request endpoints is refused but a GraphQL body is not), a `gh` extension, a `gh alias` defined outside this session or without the label name in its text (including `gh alias import -` with the label in a heredoc body, or an alias file whose content is not in the command), a label name split across a quote boundary (`"size/app"roved`), and a `gh` invoked through a fully quoted path. The real control is the server-side check of who applied the label, which only works once the Director's identity and the agent's are separate. Until then, treat a block from this rule as the Director's line, not a bug to route around.

---

# SESSION_STATE Freshness

Measured on this repository on 24 September 2026: `.ia-engineering/SESSION_STATE.md`'s `_Last updated:` header read "9 September" while the last commit was 24 September — the body had been edited many times in between, the header never — and `session-start.sh` prints exactly that header into every new session's context, so a resumed conversation would have believed the state was fifteen days old. The same file had grown to 224 lines / ~36,000 characters, loaded unabridged on every resume. Nothing enforced `Templates/SESSION_STATE.md`'s "always update at session end": `stop-gate.sh` mentioned the file only when tracked changes were left uncommitted, and a clean tree gave no reminder at all. This section is the Director-approved (24 Sep) fix.

**The primary signal is the file's mtime, not the header.** The header is exactly what went stale in the incident above — a free-text line a session can forget to touch even while rewriting everything around it. The file's own last-modified time cannot lie the same way. Both hooks compare `.ia-engineering/SESSION_STATE.md`'s mtime (`date -r`) against `HEAD`'s commit time (`git log -1 --format=%ct`); `lib.sh`'s `iaeng_file_mtime` and `iaeng_head_commit_time` fail safe (empty output, non-zero exit) on any missing file, unsupported `date` flag, or git error, and every caller treats "could not compute" as "do not block, do not warn falsely" — never as "behind".

**`session-start.sh` — non-blocking, three warnings** (it is context injection; it has no compliance action to force, only information to surface):

1. **Behind the repository.** `.ia-engineering/SESSION_STATE.md`'s mtime is older than `HEAD`'s commit time. Reports how many commits landed since, via `git rev-list --count --since=@<mtime> HEAD`.
2. **Header not refreshed.** The `_Last updated:` header's date (parsed defensively out of its free-text line — an unparsable header is reported as unparsable, never silently skipped) is earlier than the file's mtime date. This is the specific failure the measurement above found: the body moved, the header did not.
3. **Over budget.** The file exceeds 15,000 characters. `Core/CONTEXT_BUDGET.md` measures in characters (`wc -c`) and estimates tokens at ~4 characters each because no offline tokenizer ships with this repository; this hook does the same and says so. 15,000 characters (≈3,750 tokens estimated) is a little over twice this file's own healthy baseline as `CONTEXT_BUDGET.md` measured it (6,456 characters) and well under the ~36,000 characters this file had reached when the incident above was found — a threshold meant to catch "becoming a log" before it reaches "is one".

**`stop-gate.sh` — blocking when behind, reminder when missing, fail-safe when the comparison itself cannot be trusted.** Checked only after the pre-existing uncommitted-tracked-changes gate has passed (a clean tree) — a dirty tree still blocks for that reason first, unchanged. When `.ia-engineering/SESSION_STATE.md` exists and its mtime is older than `HEAD`'s commit time, the hook **blocks the stop** (`exit 2`) and tells the agent to update it now — an absolute date in the header, "Where the Project Stands" and "Next Step" rewritten as a snapshot, not appended to as a log — then stop. This cannot loop: updating `SESSION_STATE.md` creates no commit (it is gitignored and refused by the pre-commit Adapter), so the next stop attempt sees a fresh mtime; the pre-existing `stop_hook_active` loop guard is checked first and unchanged, and still yields on the one continuation Claude Code grants after any Stop-hook block. When the file does **not** exist, the hook does not block forever waiting for one — a project that has never created it is a different condition from one whose file went stale, and blocking every no-state project on every stop would be the wrong response to a state that has nothing to be behind. It leaves a non-blocking reminder pointing at `Templates/SESSION_STATE.md` instead. And when `HEAD`'s commit is dated **after** the system clock — clock skew, or a deliberately future-dated commit — the hook does not compare mtime against it at all: see the correction below for why, and what it does instead.

Both behaviours are exercised by throwaway git repositories built under `mktemp -d` in `tests/run.sh`'s "SESSION_STATE freshness" section — filesystem state, not just a JSON payload, is what this rule reads.

**Portability and correctness corrections, found in review.** Warning 2's header parse first went through `date -d "24 September 2026"` — a GNU extension BSD/macOS date does not have, where the header-staleness check would have silently never fired. `lib.sh`'s `iaeng_ymd_from_header_date` builds `YYYY-MM-DD` out of the extracted day/month-name/year with a plain month-name table (`iaeng_month_num`) instead, so the check needs nothing beyond the `date -r` this file already established as portable.

Separately, and found in a second review pass: a future-dated `HEAD` commit used to make an otherwise-fresh `SESSION_STATE.md` compare as "behind" with no way to clear it. The first fix tried was `iaeng_cap_at_now`, clamping `HEAD`'s commit time at `min(HEAD_TS, now)` before every comparison — which *looked* fixed (a file touched in the same second as the check passed) but was not: "now" is read live on every invocation while the file's mtime stays fixed at whatever moment it was actually touched, so real time moving forward alone — with no edit made — silently re-opened the block a second later. Reproduced in review: `stop-gate.sh` returned `0` immediately after `touch`, then `2` one second later with nothing changed. The fix that replaced it treats a future `HEAD_TS` as its own condition rather than a value to clamp and keep comparing: when `HEAD`'s commit time is after `iaeng_now`, both hooks skip the mtime comparison entirely and report that the comparison itself cannot be trusted — `stop-gate.sh` warns and does **not** block (the same fail-safe branch as a missing mtime or a git error), and `session-start.sh` prints that warning in place of the "behind the repository" one. `stop-gate.sh`'s messages also print `HEAD`'s commit date next to the system clock for diagnosability. This is stable regardless of how much real time passes or how old the file's mtime looks, which `tests/run.sh` proves with a fixture whose mtime is a fixed date in 2020 under a `HEAD` dated tomorrow, rather than by sleeping in the test.

**Limit.** Both gates read the file's mtime, so `touch` satisfies them without the content changing; a future-dated `HEAD` is deliberately treated as unverifiable and does not block. This is accepted: the gate is a reminder for the session's own hand-off, not a control against it — nothing server-side depends on this gitignored file, and no hook can judge whether its content is current. A touch without a header edit is still reported by `session-start.sh`'s header-not-refreshed warning at the next session start, unless the header already carries that day's date.

---

# Installation

From the project root, with the framework imported at `ia-engineering/` (or from the framework repository itself):

```bash
./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh
```

This writes `.claude/settings.json` from `settings.example.json`, substituting the framework's path. It never overwrites an existing `settings.json` — `--print` shows the block to merge by hand, `--force` replaces the file after you have reviewed what else it contained. Restart the session for the hooks to load.

`.claude/settings.json` is **committed**: Claude Code reads its hook configuration from the repository, so every session on every clone runs these hooks without a per-clone install step — the property git hooks cannot have. The corollary is that this file is reviewed like code, because it decides what the model is allowed to do.

`jq` is recommended. Without it the hooks still run, on the fallback described above.

---

# Verifying

There is a test suite, and it is the control:

```bash
./Adapters/ai-runtimes/claude-code/hooks/tests/run.sh          # 643 checks
./Adapters/ai-runtimes/claude-code/hooks/tests/run.sh --verbose
```

It feeds `tests/escape-hatch-cases.tsv` to the escape-hatch hook (one `block`/`allow` case per line), checks that every hook fails closed on unreadable input and ignores tool calls that are not its own, and runs `tests/lexer-cases.tsv` through `strip-quotes.awk` directly. The CI job **Hook Tests** runs it on every Pull Request.

It exists because shellcheck proves the hooks are valid shell and the validator proves the documents around them agree, and neither can say whether `git push --force` is actually refused. Feeding payloads by hand found seven real defects — a trailing `;`, a global option before the subcommand (`git -C . push --force`), the short `-n` form of `--no-verify`, a quoted lone flag (`git commit "--no-verify"`), a line continuation, the other argument order of a protected-branch deletion — and one false positive that refused `grep -rn -- --no-verify Standards/`, which is precisely how a hook teaches people to work around it. Adding a case is adding a line to a `.tsv`.

Cases live in data files, not in the runner, for two reasons: a corpus full of escape hatches typed into a terminal is refused by the hook under test, and a case containing a command substitution is then data that no shell ever parses.

Each hook can also be run by hand with a payload on stdin; exit code and stderr are the contract:

```bash
printf '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}' \
  | bash Adapters/ai-runtimes/claude-code/hooks/block-escape-hatches.sh; echo "rc=$?"     # rc=2

jq -n --arg c 'git commit -m "docs: never use --no-verify"' '{tool_name:"Bash",tool_input:{command:$c}}' \
  | bash Adapters/ai-runtimes/claude-code/hooks/block-escape-hatches.sh; echo "rc=$?"     # rc=0 — the flag is only inside quoted text, which the lexer strips

printf '{"tool_name":"Write","tool_input":{"file_path":"a.py","content":"x = 1  # noqa"}}' \
  | bash Adapters/ai-runtimes/claude-code/hooks/block-inline-suppression.sh; echo "rc=$?" # rc=2

printf '{"stop_hook_active":true}' \
  | bash Adapters/ai-runtimes/claude-code/hooks/stop-gate.sh; echo "rc=$?"                # rc=0 — loop guard
```

The Shellcheck Adapters CI job covers this directory with `shellcheck -x -P SCRIPTDIR …` — `-x` follows `source`, `-P SCRIPTDIR` resolves each hook's `# shellcheck source=lib.sh` directive relative to the hook's own directory. Run the same command locally before pushing; a portable ShellCheck binary is enough. The quote-stripping lexer lives in `strip-quotes.awk` rather than in a quoted string inside the hook, so no shell quoting applies to it and nothing in it needs a directive.

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Adapter — AI Runtime (Claude Code)

Severity: Recommended
