# Troubleshooting Catalog

---

# Purpose

This catalog records the failures this framework has met — in its own repository and in the projects and sibling frameworks it learned from — as **symptom → cause → remedy → prevention**. It exists because a failure understood once and written nowhere is a failure paid for twice, and because the framework's own history shows that the same defect class reproduces inside its own remediation until the class, not the instance, is named.

An entry is worth writing when someone else could meet the same symptom and would not immediately know the cause. It is not a changelog: `CHANGELOG.md` says what changed; this says what went wrong, why, and what now stops it.

---

# Scope

Every incident that produced a Work Unit, a rejected review, a red check, or a rule. Entries are added by the Work Unit that fixes the incident (`Governance/CONTRIBUTING.md`, Section 7 — the learning loop), never later from memory.

Project-specific incidents belong in the project's own catalog (a `TROUBLESHOOTING.md` in the project, or the Errors and Traps section of `.ia-engineering/SESSION_STATE.md` while they are fresh). Entries here are the ones that generalise.

---

# How to Read an Entry

| Field | Meaning |
|---|---|
| **Symptom** | What was observed. What a person searching this file would type. |
| **Cause** | The mechanism, not the mistake. "The hook could not resolve the roster" — not "someone forgot". |
| **Remedy** | What fixed the instance. |
| **Prevention** | The control that now catches the class — a validator check, a CI job, a rule with a name. An entry with no Prevention is an entry whose incident will recur. |

---

# Catalog

## A. Checks that report success without evaluating anything

**Symptom.** A validator, installer, or CI step is green; the condition it names is not met. Discovered only when a downstream failure makes someone read the check.

**Cause.** When a condition turns out not to apply — the file is absent, the set is empty, the tool is not installed, git is unavailable — the path of least resistance is to print a pass and move on. Sixteen instances were found in one milestone; four were introduced by fixes to earlier instances.

**Remedy.** Each instance rewritten so the unevaluated condition fails, or is named in an allow-list with a reason.

**Prevention.** The Check Convention in `Adapters/README.md`: (1) an unevaluated condition is a failure, not a pass; (2) exceptions are named allow-lists, never fall-throughs; (3) a check that iterates a set reports its denominator; (4) a claim about a mechanism's behaviour is testable — enumerate the alternatives, then run the falsifier. `Standards/RISK_STANDARD.md` lists "a failure is swallowed and reported as success" as a High product hazard for the same reason.

---

## B. A hook is installed and enforces nothing

**Symptom.** Commits with `Employee: executor`, or with no trailer, land locally without complaint. The hook file is present and executable.

**Cause.** The hook could not resolve `Registry/employees.yml` (submodule not checked out, non-standard layout) and an earlier draft fell back to a hardcoded list — or to nothing.

**Remedy.** Fail closed: a roster that cannot be found is a rejection with the paths that were tried.

**Prevention.** `Adapters/git-hooks/commit-msg` fails closed; `install.sh` probes the installed hook with a valid and an invalid trailer and reports "installed but not enforcing" when both pass; the `Employee Trailer` CI job re-validates server-side, since a hook is skippable by `--no-verify` or by never being installed. The same shape applies to `pre-commit`: it fails closed when the scanner cannot be resolved, and `install.sh` probes it against a throwaway index.

---

## C. A CRLF checkout breaks the parsing contract

**Symptom.** On Windows, the hook rejects every valid Employee name; on a Linux runner, a shipped script fails with `bad interpreter`.

**Cause.** `core.autocrlf` rewrote line endings. Every roster name carried a trailing `\r`, so `grep -qxF` matched nothing; a shebang line ending in `\r` names an interpreter that does not exist.

**Remedy.** `.gitattributes` forces LF for `Adapters/**`, `Registry/**`, `.github/**`; consumers strip `\r` defensively as well.

**Prevention.** `install.sh` appends the same rules to an adopting project's `.gitattributes`; `Workflows/PROJECT_BOOTSTRAP.md` Step 3 writes them before the first commit. Probes that use `^X$` patterns on possibly-CRLF files are probe artefacts, not validator holes — verify with CRLF-aware patterns before concluding a check is blind.

---

## D. Scripts work locally and fail in CI with "permission denied"

**Symptom.** Every shipped script runs on the developer machine; the CI job cannot execute any of them.

**Cause.** All scripts were committed with mode `100644`. Windows filesystems have no executable bit, so nothing local ever noticed.

**Remedy.** `git update-index --chmod=+x` on every shipped script and hook.

**Prevention.** Validator section 11 fails when any shipped script or hook is not `100755` in the index; `install.sh` chmods hooks it wires. New scripts are added with the chmod in the same commit.

---

## E. The same glob sorts differently on Windows and Linux

**Symptom.** A check that compares two ordered lists passes locally and fails in CI, or the reverse, with identical content.

**Cause.** Shell glob and `sort` collation depend on the locale; case ordering differs between platforms.

**Remedy.** `export LC_ALL=C` at the top of every script that orders anything.

**Prevention.** Present in `validate-framework.sh`, `data-policy-scan.sh`, and required by review for any new script that sorts or globs.

---

## F. A path reference passes on Windows and fails on Linux

**Symptom.** The validator's cross-reference check is green locally; CI reports `Core/GLOSSARY.MD` does not exist.

**Cause.** A case-insensitive filesystem resolved the wrong-case path. The reference had been correct once and drifted.

**Remedy.** Resolve references against `git ls-files` (case-exact) rather than the filesystem; exclude `CHANGELOG.md` from the reference scan because it quotes historical paths on purpose.

**Prevention.** Validator section 9 resolves against tracked content; `KNOWN_ABSENT` names the deliberate exceptions with reasons.

---

## G. `git log --format='%(trailers:key=Work Unit)'` returns nothing

**Symptom.** Tooling that reads the `Work Unit:` trailer through git's trailer parser sees no trailer, on commits that visibly carry one.

**Cause.** A trailer token cannot contain a space; git never parses `Work Unit:` as a trailer, and one unparseable line in the final paragraph invalidates the whole block — including the valid `Employee:` line beside it. Measured: 28 of 30 commits parsed only in the separated layout.

**Remedy.** The separated layout — `Work Unit:` paragraph, blank line, `Employee:` paragraph — so the final paragraph is a valid trailer block. Readers of `Work Unit:` use `grep`, not `%(trailers)`.

**Prevention.** `Standards/COMMIT_STANDARD.md` documents the layout with the measurement, and records the rename to `Work-Unit:` as a dated Director question. The generated agent template emits the separated layout.

---

## H. A quoted example line at column 0 is validated as a claim

**Symptom.** The hook rejects a commit whose body quotes `Employee: executor` as an example of what not to write; or, before the fix, a quoted valid name masked a real invalid trailer and the commit was accepted.

**Cause.** Choosing one `Employee:` line by position (`head -1`, then `tail -1`) was bypassable from whichever end was not chosen. Both bypasses were reproduced.

**Remedy.** Validate **every** line beginning `Employee: `; refuse more than one `Work Unit:` line at column 0 (One Work Unit = One Commit makes a second claim malformed, not ambiguous).

**Prevention.** Rule 3 in `commit-msg`, mirrored in the `Work Unit Exists` job and in `release.sh` (a multi-claim commit gets no verdict). Quoted examples are indented — the hook's rejection text says so.

---

## I. A merge commit is rejected by the commit hook

**Symptom.** `git merge` fails at the commit step: "subject line does not follow the Commit Standard".

**Cause.** Git's auto-generated merge subject can never match Conventional Commits or carry an Employee trailer.

**Remedy.** The hook exits 0 when `MERGE_HEAD` exists (resolved via `git rev-parse --git-path`, so worktrees work). CI excludes merges with `--no-merges`.

**Prevention.** Documented in the hook. Corollary caught later: `install.sh`'s hook probes run *through* the exception during a merge and would report a correct hook as "not enforcing" — the probes are skipped during a merge, and the skip is announced.

---

## J. Setting `core.hooksPath` silently disables a project's own hooks

**Symptom.** After `install.sh`, a project's pre-existing `.git/hooks/*` stop running. Nothing reports it.

**Cause.** `core.hooksPath` makes git ignore `.git/hooks` entirely.

**Remedy.** Detect non-sample files in the real hooks directory — derived from `--absolute-git-dir`, not `--git-path hooks`, which resolves to the *configured* path once set — and warn before switching.

**Prevention.** In `install.sh`. The second-run trap (inspecting the framework's own hooks and reporting them as shadowed project hooks) is documented in the code.

---

## K. Two green PRs merge into a red `develop`

**Symptom.** Each PR passes every check; after both land, the roster and a document disagree.

**Cause.** A merge produces a state neither parent had. PR-only validation never sees it.

**Remedy.** `framework-validation.yml` runs on push to `main` and `develop`, not only on `pull_request`.

**Prevention.** Same. Also: `Registry/employees.yml` must be a regeneration no-op — a hand-edited roster that is self-consistent passes every check while breaking the `--regenerate-roster` path the next contributor is told to use.

---

## L. A bootstrap that did everything right exits 1

**Symptom.** `setup-project-bootstrap.sh` reports failure on a clean new project.

**Cause.** `install.sh` counted "replace the `OWNER/REPO` placeholders" as a problem, and the bootstrap had just started propagating `install.sh`'s exit status (previously discarded with `|| true`, which hid every real fault).

**Remedy.** Two counters: `warn()` for installation faults (fatal), `todo()` for actions the adopting project must take next (reported, exit 0).

**Prevention.** The distinction is documented in `install.sh`. The general rule: a caller that discards a check's exit status has turned the check into ceremony.

---

## M. Real data committed "temporarily" and found in history weeks later

**Symptom.** A client document appears in the hosting platform's history. It was `git rm`'d long ago and noted as "never pushed".

**Cause.** It was pushed in the meantime. `.gitignore` ignores untracked files only; `git ls-files` inspects the current tree only; the blob travelled with every clone.

**Remedy.** Revoke (if credential), bundle backup, `git filter-repo`, force-push every ref with protection lifted, re-create every clone, record the incident.

**Prevention.** `Standards/DATA_PROTECTION_STANDARD.md`: local data directory from the first commit, anchored `SYNTHETIC_` marker, the `pre-commit` hook, and the `Data Policy` CI job scanning the objects a branch *introduced* (`git rev-list --objects`), not only the tree. Three sub-lessons from the first hook's review, carried into `data-policy-scan.sh`: a non-ASCII filename escaped the pattern because git quoted it (`core.quotePath=false`); a `synthetic/` directory exempted its whole contents (the marker is anchored to the basename); a noisy content scan provoked `--no-verify`, which disarms every hook at once (high-confidence shapes only, values never printed).

---

## N. A count in prose drifts from the thing it counts

**Symptom.** A document says "three rules" or "six checks" after a fourth rule or seventh check was added. Usually found by a reviewer, sometimes by the same author two Work Units later.

**Cause.** Literal counts are a second copy of a fact. Two copies drift.

**Remedy.** Fix the count in the same Work Unit as the change; where possible, derive it (the validator checks roster counts quoted in prose against the Registry).

**Prevention.** Validator section 3 for roster counts. For everything else, the review habit: any change that adds to an enumerated set searches for the set's count. This catalog's own Work Unit fixed one ("the one `# shellcheck disable`" — there were two).

---

## O. A script hangs forever on a Windows machine

**Symptom.** A shell script that calls `python` blocks with no output and no error.

**Cause.** The Windows Store `python` stub reads stdin and waits; nothing is installed behind it.

**Remedy.** Kill it. Rewrite the step in `awk` or pure bash.

**Prevention.** Shipped scripts depend on POSIX tools and git only — `Registry/README.md`'s parsing contract exists so that hooks need nothing but `grep` and `sed`.

---

## P. A delegated Employee reports done; the work is not done

**Symptom.** "Done" returned. On inspection: a claim unverified, a step skipped, a finding reported that the evidence contradicts ("no attribution trailers" on four commits that each carried one).

**Cause.** No report format demanded evidence, so none was produced; the Main Agent accepted the word.

**Remedy.** Re-verify from the repository, not from the report.

**Prevention.** `Templates/WORK_UNIT_REPORT.md`: a bare "Done" is a failed Work Unit; gate evidence is pasted; "What was NOT done" is written explicitly. `Core/MAIN_AGENT_CONDUCT.md` Verification Over Waiting: the Main Agent re-verifies regardless.

---

## Q. A large heredoc or multi-command shell call fails opaquely

**Symptom.** In an AI-driven session on Git Bash for Windows, a command with a large heredoc, or several heredocs in one invocation, fails with "unexpected EOF" or writes a truncated file. A perl replacement containing `$(` produced a numeric group ID in the output.

**Cause.** Quoting and interpolation across the tool boundary: the shell expanded `$(...)` inside a double-quoted program; multiple heredocs in one call confused the terminator handling.

**Remedy.** One heredoc per call; large files via a file-writing tool rather than a heredoc; edits via a dedicated edit tool rather than `perl -pe` with `$` in the pattern.

**Prevention.** Recorded here and in the operator's runtime memory; a symptom class rather than a framework defect, but one every AI-driven session on Windows meets.

**The specific case that has now cost two commit messages:** a backtick inside a double-quoted `git commit -m "…"` is command substitution. The backticked text is *executed* and replaced by its output — usually empty — so the message is committed with a hole exactly where the code sample was, and the hole is only visible after the commit is pushed. Two commits in this repository carry one (`WU-IAENG-200`, `WU-IAENG-211`), and neither is worth a force-push to correct, so the rule is procedural:

> Write any commit message longer than a subject line to a **file** and use `git commit -F <file>`. Never pass prose containing backticks, `$(`, or `!` through `-m` in double quotes.

The same applies to `--body` on `gh pr create` and `gh pr comment`; `--body-file` is the equivalent. This is the one trap in this catalog with no mechanical guard: the `commit-msg` hook cannot tell a hole from an author who wrote nothing there.

---

## R. A guard blocks the command that documents it

**Symptom.** The escape-hatch hook refuses `git commit -m "..."` whose message *mentions* `--no-verify` in order to forbid it. The single-line case passed every test; the real commit did not.

**Cause.** Quoted-string stripping was a regex pass. Per line, it left the inner lines of a multi-line `-m "…"` unstripped. Over the whole text, it mis-paired the quotes of the shell idiom `'"'"'` (a literal apostrophe inside single quotes) and inverted every double-quoted region after it. Both shapes came from the same commit command — the one committing the hook.

**Remedy.** Replace the regex passes with a shell lexer: a state machine that walks the text once, tracking outside / single-quoted / double-quoted / heredoc-body, with backslash escapes where the shell honours them. Quoting is a state machine; only a state machine reads it.

**Prevention.** In `block-escape-hatches.sh` with the reason in its header. General rule for any text guard: do not approximate a grammar with a regex when the grammar has nesting or escapes, and make the test corpus include the multi-line and the `'"'"'` shapes of every construct the guard strips — the single-line shape is the one the author thinks of.

---

## S. A CI-only tool was never run locally

**Symptom.** Every local check is green; the `Shellcheck Adapters` job fails on the first CI run — or, on a stacked Pull Request whose base is not a protected branch, does not run at all, so the failure waits for the retarget.

**Cause.** The tool was not installed on the developer machine, and "no output" from a tool that is absent reads like a pass. On a stacked branch there is additionally no CI signal until the base changes.

**Remedy.** Fetch the tool's portable binary into a scratch directory and run **the exact command the CI job runs** — same flags, same globs — before pushing. Fix findings without directives: the two here were an awk program held in a quoted shell string (moved to its own `.awk` file, so no shell quoting applies) and a `source=` directive the tool could not resolve (`-P SCRIPTDIR` in the CI command, which is configuration, not suppression).

**Prevention.** `Adapters/ai-runtimes/claude-code/hooks/README.md`, Verifying, states the command. A check that a shipped script passes shellcheck locally is only evidence if shellcheck actually ran; `post-edit-lint.sh` says "shellcheck not installed" for the same reason.

---

## T. A check reports that everything fails

**Symptom.** A newly written check reports every item in a set as failing, on a set the author has just confirmed by hand is fine. `grep: unknown option` appears in the output, easy to miss among the failures.

**Cause.** The search pattern began with a hyphen — `grep -qxF '- Standards First'` — so grep parsed the pattern as an option bundle, exited 2 without searching, and the caller read the non-zero status as "not found". The check never looked at a single file.

**Remedy.** Anchor the pattern so it does not start with `-` (`grep -qE '^- Standards First'`), or pass `--` before it.

**Prevention.** Universal failure is a signal about the check, not about the set: when every item fails, verify the check runs at all before believing its verdict. This is class A wearing the opposite mask — instead of passing without evaluating, it failed without evaluating, and both come from reading an exit status whose meaning was assumed rather than checked.

---

## U. Process substitution hides the producer's failure

**Symptom.** A gate is green and reports a plausible-looking zero: "0 files changed", "0 lines to review", "scanned 0 paths — clean". Nothing in the log looks like an error, and `set -euo pipefail` is at the top of the script.

**Cause.** `while read …; do … done < <(producer)` puts the producer in a background process whose exit status the shell never inspects. When the producer fails — an unfetchable SHA, a missing ref, a permissions error — the loop simply receives no input and the counters stay at their initial values. `set -e` sees nothing; `pipefail` covers pipelines, not process substitution.

**Remedy.** Capture the producer's output first, in a variable or a file, and make its failure fatal; then feed the loop from that. Where the producer legitimately may be empty, decide explicitly what an empty set means and say it.

**Prevention.** This is class A with a specific mechanism, and the mechanism is worth naming because the code *looks* defended. Two rules: a set-iterating check treats a zero denominator as the absence of evidence, not as success (Check Convention, rule 3); and any `< <(...)` whose producer can fail is rewritten to capture-then-iterate. Found by review in the `PR Size` gate, where an unfetchable base SHA made a required check pass on every Pull Request it could not measure.

---

## V. An object walk is not a path walk

**Symptom.** A history scan reports clean on exactly the case it was written for — a protected file added and deleted again inside the range. The same file with different content is caught.

**Cause.** `git rev-list --objects` enumerates each **object** once, with one associated path. A blob already reachable from the excluded side of the range is never listed, so its path is never classified. An *empty* file hits this every time: the empty blob exists in almost every repository.

**Remedy.** Enumerate paths, not objects: `git log --name-only --diff-filter=ACMR <range>` lists what each commit touched regardless of whether the blob is new. Union the two rather than swapping one for the other, so a path reachable as an object but named by no diff is still seen.

**Prevention.** When a check's subject is *paths*, its enumeration must be over paths. The general form: verify that the thing being counted is the thing the claim is about — the same question that separates `git ls-files` from `git rev-list --all --objects` in entry M.

---

## W. A guard's first version matches everywhere

**Symptom.** A newly added rule in a text guard refuses a legitimate command — one that *mentions* the forbidden thing rather than doing it. Searching the documentation for a banned flag, or editing a file that names it, is blocked.

**Cause.** The rule was written as a bare substring match. The thing being forbidden is an *action in a context*; the pattern tested only for the *word*.

**Remedy.** Scope the pattern to the context that makes it an action — for a git escape hatch, `git[^|;&]*<thing>` rather than `<thing>`, which keeps the match inside a pipeline segment that actually starts with `git`.

**Prevention.** Two facts make this worth its own entry rather than a footnote to the rules it keeps appearing in. First, a noisy guard is a *defeated* guard: the response to a control that fires on reading about a rule is to stop running the control. Second, it recurred immediately — the same session that fixed this for `--no-verify`, after review flagged it, reintroduced it one rule later for `core.hooksPath`, and the new rule blocked the very commit that was recording the fix. **Every new rule in a text guard needs a paired allow-case in the corpus**, written at the same time: one command that does the forbidden thing and one that only names it. The corpus is where the pairing is enforced.

---

# Adding an Entry

1. The Work Unit that fixes the incident adds the entry — same commit, or the fix is not complete (`Governance/CONTRIBUTING.md`, Section 7).
2. Fill all four fields. An entry without a Prevention is returned.
3. Generalise: name the mechanism, not the person or the project. If it does not generalise, it belongs in the project's catalog.
4. If the entry is the second of its class, the class gets a name and a rule — the Check Convention was written after the eleventh instance of class A; the aim is to write the rule after the second.

---

# Related Documents

- `Governance/CONTRIBUTING.md` — Section 7, the learning loop that feeds this catalog
- `Adapters/README.md` — the Check Convention (class A)
- `Standards/DATA_PROTECTION_STANDARD.md` — class M
- `Standards/COMMIT_STANDARD.md` — classes G and H
- `Templates/WORK_UNIT_REPORT.md` — class P
- `Templates/SESSION_STATE.md` — where a project's fresh incidents live before they generalise

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Governance

Severity: Recommended

Depends On:

- `Governance/CONTRIBUTING.md`
- `Adapters/README.md`

Referenced By:

- `Standards/GIT_STANDARD.md`
- `Governance/CONTRIBUTING.md`
