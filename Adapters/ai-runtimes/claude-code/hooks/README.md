# Claude Code Hooks

---

# Purpose

`Adapters/git-hooks/` and `Adapters/github-actions/` enforce framework rules at commit time and at merge time. Both are late: by then the model has already run the command, written the file, or ended the session. Claude Code exposes **hooks** — shell commands it runs at fixed points of its own loop (session start, before and after a tool call, at stop) — and those points are early enough to refuse an action instead of rejecting its result.

These hooks make five rules mechanical for the one runtime that currently exposes the points to do it:

| Hook | Event | Rule enforced | Source |
|---|---|---|---|
| `session-start.sh` | `SessionStart` (startup, resume, compact) | Read first: `CLAUDE.md`, then `.ia-engineering/SESSION_STATE.md`, then the brief — printed into context with the *current* state (last update, next step, blockers) so the reading order is seen, not remembered | `Core/AGENT_CONDUCT.md`, Read First |
| `block-escape-hatches.sh` | `PreToolUse`, matcher `Bash` | No `--no-verify`, no `--no-gpg-sign`, no `stash` in place of a commit, no interactive git in a non-interactive session, no force/mirror push, no deletion of a protected branch, no `reset --hard` / `clean -f` / `checkout -- .` / `branch -D`, no history rewrite, no `rm -rf` of `.git` or `/` | `Standards/GIT_STANDARD.md`, Escape Hatches |
| `block-inline-suppression.sh` | `PreToolUse`, matcher `Edit\|Write\|MultiEdit` | No inline linter / type-checker / test-runner disable written into code; no skipped or focused test; no swallowed exception. Documentation files are the named exemption — the Standard has to be able to quote what it forbids | `Standards/CODE_QUALITY_STANDARD.md`, No Inline Suppression |
| `post-edit-lint.sh` | `PostToolUse`, matcher `Edit\|Write\|MultiEdit` | The file just written passes `bash -n` and `shellcheck` (shell), and the project's own `.ia-engineering/lint.sh` when it exists; a failure returns to the model immediately. When nothing applicable ran, it says so | `Standards/CODE_QUALITY_STANDARD.md`, Automated Quality |
| `stop-gate.sh` | `Stop` | The session does not end with tracked files changed and uncommitted, unexplained. One continuation is granted (`stop_hook_active` guard) to commit or to state why not | `Core/AGENT_CONDUCT.md`, Reporting Contract |

---

# What They Are Not

- **Not a substitute for the git hooks or CI.** A model can be run without these hooks; a commit cannot reach `main` without the CI checks. These hooks remove the *first* opportunity to break a rule; `Adapters/git-hooks/` removes the second; `Adapters/github-actions/` removes the last.
- **Not the framework's policy.** Every rule here is stated in a Standard or a Core document first; the hook is the executable form, and where they disagree the document wins (`Registry/README.md`, Authority). A rule that exists only in a hook is a rule the framework does not have — see `Adapters/README.md`, the Check Convention.
- **Not configurable around.** There is no environment variable that disables a block. The exception path is the one the Standards define: a human applies the action by hand after the Director decides, and the decision is recorded (`Standards/RISK_STANDARD.md`). A hook that can be told to look away is a suggestion.

**Not an adversary boundary.** The escape-hatch hook reads the command text. It models the shell's own constructions — quoting, ANSI-C `$'\x2d'`, brace expansion, command substitution, and `printf`'s backslash escapes (`git push origin $(printf '\x2b')…` and `$(printf '\x2d\x2dforce')` are decoded like the quoted forms, because printf's decoding is a deterministic shell mechanic). It cannot see a flag whose *value* is produced at runtime: a token an external program prints (`$(python -c …)`, `$(base64 -d …)`, `$(echo .. | tr . -)`), a flag a variable carries (`F=--force; git push $F`) or one split across two variables, `eval "$CMD"`, or a flag read from a file. Recovering those would mean evaluating the command, which is the thing the hook exists to happen *before*, and each is one keystroke from the next — so the honest line is "shell mechanics, yes; runtime values, no." It stops an escape hatch reached for by habit — which is the realistic failure — and the server side stops the rest: the `pre-push` hook, branch protection, and the required CI checks, none of which a developer machine can skip. Claiming more than that would be the false confidence this framework refuses elsewhere.
- **Not AI-agnostic.** They target Claude Code's hook contract (JSON on stdin; exit 0 allow, exit 2 block with stderr to the model; `stop_hook_active` on Stop). Another runtime with equivalent points gets its own directory under `Adapters/ai-runtimes/`; the Standards they enforce are the same. This is the same boundary `generate-agents.sh` draws: runtime-specific mechanics live in the Adapter, never in `Core/` or `Standards/`.

---

# Design Rules

**Fail closed.** A hook that cannot read its input — `jq` missing and the fallback extraction finding nothing — blocks with the reason, rather than allowing what it could not inspect. The `lib.sh` helpers read with `jq` when present and with a sed extraction of the flat fields otherwise; the fallback can over-block (it matches the whole payload for suppression patterns), never under-block.

**Strip before matching.** `block-escape-hatches.sh` removes single-quoted strings, double-quoted strings, and heredoc bodies before applying its patterns. A commit message that *mentions* `--no-verify` is not a use of it, and this framework's own Standards mention every pattern the hook blocks. A sibling kit's first version blocked its own documentation commits for this reason.

**Name the exemption.** Documentation files are exempt from the suppression hook, by extension, in the script. `git stash list` and `git stash show` are exempt from the stash rule. `git push --delete` of a non-protected branch is allowed. Each exemption is a line a reviewer can read; none is a fall-through.

**Say what did not run.** `post-edit-lint.sh` reports "no linter ran for this file" rather than exiting silently, because silence reads as a pass.

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
./Adapters/ai-runtimes/claude-code/hooks/tests/run.sh          # 265 checks
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

Version: 0.0.12

Status: Draft

Category: Adapter — AI Runtime (Claude Code)

Severity: Recommended
