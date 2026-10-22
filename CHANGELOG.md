# Changelog

All notable changes to IA Engineering will be documented in this file.

This project follows Semantic Versioning, extended with an informal 4th segment (`MAJOR.MINOR.MILESTONE.FIX`) for post-release consistency fixes that do not warrant a new milestone number. See `VERSION.md` for the versioning policy.

---

## [Unreleased] - Adoption

### Added

- `install.sh --check` and `setup-project-bootstrap.sh --check` — the installers' own decisions, reported instead of applied: one tab-separated record per managed file (`current`, `absent`, `differs`, `customized`), `.gitattributes` and `.gitignore` rule, the local data directory and each project-owned file, a closing count line with the remedy for each kind, exit 0 nothing to act on / 3 drift / 1 a fault / 2 usage, and `--quiet`, silent when there is nothing to do. Strictly read-only, proven by a before/after snapshot of the working tree, every file under `.git`, status, local config, refs and object count; the git hooks section and the commit probes are reported `unchecked`, never left out. A building block for the upcoming drift check, not a flag to type (WU-IAENG-353)
- `install.sh --check` now checks the git hooks it used to report `unchecked`: `core.hooksPath` (`current`, `absent`, or `differs`, with the value found), each framework hook (`current` or `not-executable`), and project hooks in `.git/hooks` that `core.hooksPath` would stop git from running (`shadowed`). These are the decisions a real run makes, read and never applied: no `git config` write, no `chmod`, and no probe. The commit probes stay `unchecked`. A test proves that every git command under `--check` carries `GIT_OPTIONAL_LOCKS=0`. The OWNER/REPO placeholder in the issue-template config is now a `todo` record, which never counts as drift (#274) (WU-IAENG-355)
- `install-hooks.sh --check` and `install-skills.sh --check`: the runtime installers' own decisions, reported instead of applied. They use `install.sh --check`'s records, closing count line, exit codes (0/3/1/2) and `--quiet`. install-hooks.sh reports `settings.json` as `current`, `absent`, `customized` or `fault`. It reports each framework hook entry as `present`, `absent` or `near-miss`, from the same jq computation a merge uses, so "present exactly" has one definition. It also reports `"disableAllHooks": true` in `settings.json` or `settings.local.json` as `disabled`, and its `.gitattributes` LF rule. install-skills.sh reports each skill as `current`, `absent`, `differs` or `not-applicable`, using the same `diff -r` as a run. A near miss is information, never drift. A command read from the project's settings cannot split a record: TAB, LF and CR become spaces. `settings.json` is parsed with jq and never evaluated. Both scripts are proven read-only by a before/after snapshot (WU-IAENG-357)
- `Adapters/scripts/check-framework-drift.sh`: how far an adopting project has drifted from the framework it imports, and what to do about each item. It runs the four installer `--check` modes and reads their records, so the list of managed files is install.sh's own. It adds the framework version (the commit and its tag, the last tag known locally, the number of tags behind, the gitlink `+` or `-`; with `--remote`, the remote's last tag through `git ls-remote`, which writes no ref). Each file or skill the installers call `differs` is classified `stale` (an earlier version of the template, never edited: the exact `cp` is given) or `modified` (edited by the project: review the diff, never `--force`), by hashing the copy with `git hash-object --stdin`, without `-w`, against every blob the template has had. A shallow or copied framework gives `indeterminate`. Every command in `.claude/settings.json` and `settings.local.json`, the project's own included, has its script path resolved and checked, never executed, and `core.hooksPath` too: a hook whose script is gone exits 127 and its guard disappears silently. Output in text or `--format tsv` (family, status, path, remedy), with a summary line carrying each family's denominator. Exit 0 by default; `--strict` gives 1 on drift and 2 when something is indeterminate. In the framework repository it says "not applicable". No jq and an absent `settings.json` are reported, never clean (#282). Read-only, proven by a before/after snapshot and by a logging git wrapper: no fetch, no object or config write, `GIT_OPTIONAL_LOCKS=0` on every git command. The DEF-IAENG-REL014-01 upgrade replayed (v0.0.13 to v0.0.14 shape) names the absent registry, the absent `control-path-guard.yml` and the stale `pr-validation.yml` (WU-IAENG-358)
- Framework drift at session start, with no flag to type. `session-start.sh` runs `check-framework-drift.sh --quick` and prints nothing when the project is current. Otherwise it prints at most three lines, one per family, each naming what to act on and the command to run: the framework version (tags behind, an upgrade not committed), the managed files absent or differing (from the installers' plain diff; the full check tells stale from modified), and the hook commands whose script is missing. `--quick` reads no history and leaves the configuration items to the full check, and says so. Its result is kept in a user-level cache (`$XDG_CACHE_HOME` or `~/.cache`, else a per-user directory in `$TMPDIR`; never in the project, whatever the spelling, `..` or link). It is replayed while the framework commit, the recorded gitlink and every file it was read from are unchanged, by mtime and by inode change time, so content copied under an old mtime or a mode change is seen. The cache is trusted only when the user alone can write it (directory 0700, owner and mode checked). Every path read back from it is validated before it reaches `find`. A row about a file it did not watch is not replayed. No text from it reaches the version line, and every other field is cut at 160 bytes (SEC-IAENG-359-01 to -04). On an idle Windows machine (Git Bash) that costs 472 ms warm against 1622 ms cold. The installers' records, most of the cold cost, are kept on their own as soon as they are complete, so a run cut by the time limit still leaves them and the next session finishes. The check is cut at 2.8 s and killed 0.2 s later. On a machine loaded enough that even the warm check takes longer, nothing is reported and that is said once. An overrun, a fault or an incomplete check is said once, then not again until it changes. It never runs in the framework repository, the hook always exits 0, and snapshots prove nothing in the project is written (WU-IAENG-359)

### Changed

- `Standards/TESTING_STANDARD.md` requires every test to be seen to fail (Falsifiability, 0.0.3): each acceptance criterion states "This fails if ___" against an observable behaviour; each new or changed test that guards a criterion or a fix is seen red once — against the base commit, a hand mutant in a disposable copy, or a mutation-testing tool — and the red run must fail on the behaviour the criterion names, so a test already red for another reason does not count; the evidence is pasted in the Work Unit Report. A run stopped by its time limit is red only when the criterion names termination or time; an equivalent mutant is replaced or the criterion declared not falsifiable. No mutation-score threshold, not retroactive. `Workflows/CODE_REVIEW.md` Step 3 makes missing, tautological or over-determined red-run evidence a blocking finding; `Workflows/FEATURE_DEVELOPMENT.md` Step 7 has QA replay one red run per criterion (WU-IAENG-354)
- The templates ask for what Falsifiability requires and point to it rather than restate it: `Templates/WORK_UNIT.md` and `Templates/EMPLOYEE_BRIEF.md` write each criterion as "fails if: ___" or "not falsifiable: <reason>" and the brief's test item adds "and each was seen red"; `Templates/TEST_PLAN.md` gives each test case **Fails if** and **Seen red by**; `Templates/WORK_UNIT_REPORT.md` adds a **Falsification** block to Gate Evidence; the three Pull Request templates, still identical, gain a seen-red checklist item. `Adapters/README.md` Check Convention rule 4 points to the Standard instead of restating the practice (#277, WU-IAENG-356)
- The Control Path Guard's decision is a script: `Adapters/scripts/check-control-path-approval.sh` holds what was inline shell in `control-path-guard.yml` — the head checked before and after the file listing, the listing reconciled with `changed_files`, the matcher's verdict, the Director's label as the last event on this head — so shellcheck reads it and `Adapters/scripts/tests/run.sh` tests it against a stubbed `gh`. The workflow runs it from the base checkout, beside `check-control-paths.sh`, never from the PR head; inputs come through `env:` and every verdict prints the message it printed before. Its locate step now also requires the new script, so a base that predates it fails closed. A `CHANGED_FILES` that is not a count, or an empty `REPO`, `PR_NUMBER` or `APPROVAL_LABEL`, fails closed: the inline version skipped its size and count guards on a non-integer count. No GitHub event carries such values (WU-IAENG-361)

### Fixed

- The bootstrap's closing message names its cause from install.sh's records: the installed files that differ from the Adapter, each with its `diff` command and why `--force` is the wrong tool for one file, and the git hook wording only when a hook check really failed — a re-run whose only problem was two differing Adapters was blamed on the hooks (#262, WU-IAENG-353)
- An installed copy that differs from its Adapter only by CRLF line endings is `already current`, not `differs from the Adapter` (WU-IAENG-353)
- install-hooks.sh calls a CRLF checkout of the template's `settings.json` `already current`. Before, it merged it and found every entry present; the file is left byte-identical either way. Both runtime installers now find their `.gitattributes` LF rule with only a line-ending CR dropped, never a CR inside a line (SEC-IAENG-353-01) (WU-IAENG-357)
- `Templates/PULL_REQUEST.md` no longer blocks a Pull Request above 800 changed lines. Its size table contradicted the 1,500-line limit of `Standards/PULL_REQUEST_STANDARD.md` (Reviewability) and the template's own checklist; the section now points to the Standard, which alone defines the limit, what it counts and the `size/approved` override. The two installed Pull Request templates had no table and are unchanged (WU-IAENG-360)
- install.sh no longer installs the framework repository as an adopter when it is invoked through another spelling of its path: a differently-cased one on Windows (`/c/developpement/...`) or a symlinked one. It decided "this is the framework repository" by comparing the two paths as strings; it now reads the answer from the device-and-inode walk it already used to find the framework inside a project. The framework repository gets its `/Adapters/**` and `/Registry/**` line-ending rules and no adopter next steps; an adopting project is unchanged (WU-IAENG-362)
- `Adapters/scripts/tests/run.sh` counts what it runs (#275 items 1, 2, 3, 5). Each block that runs only where `ln -s` works now declares its size with `block_begin <n>` … `block_end`. Its skip path takes the count from that declaration. If the path that ran accounts for a different number of checks, the suite records a failed check on every platform, CI included. A block still open at the verdict fails too. The install.sh adopter block no longer holds a framework-only check that its `skip 5` forgot; that check now runs everywhere. On MSYS, the symlinked-path case of install-hooks.sh is now counted as skipped; it used to vanish. On Linux, the case-folded-path case is counted as not applicable; it used to vanish there. Its premise now requires the upper-cased path to be the same directory (`-ef`). Not-applicable is reported apart from skipped in the Result line. Only a key on the runner's closed `NA_ALLOWED` list (today: the case-folded path) may be not applicable; any other key is a failed check on every platform, CI included. The workflow guard's "names the offending job" case is counted when it passes, not only when it fails. The `IAENG_REGISTRY_WORK_UNITS` case now says what it tests: a missing file with nothing to fall back to. Three new cases cover an existing file being read, that file taking precedence over `Registry/work-units.yml`, and the fallback when the variable names a missing file. No script under test changed (WU-IAENG-363)

### Notes

**Upgrading from v0.0.14.** The Testing Standard's Falsifiability section applies to Work Units opened after WU-IAENG-354 is merged; existing tests need no red run. It adds no tool and no CI change (WU-IAENG-354). The Pull Request template gains one checklist item: an installed `.github/PULL_REQUEST_TEMPLATE.md` now differs from its Adapter; copy the Adapter over it by hand (WU-IAENG-356).

## [0.0.14] - Precision

### Added

- `Adapters/github-actions/control-path-guard.yml`, `Adapters/scripts/check-control-paths.sh` — a `pull_request_target` check that never runs PR code: it lists a Pull Request's files through the API and fails when a control path is touched, unless the Director applies `control-change/approved` after the last push (and `IAENG_DIRECTOR_LOGIN` names the sender). **Not a required check yet**, and GitHub runs the workflow from `main`, so it first reports on the release that carries it (WU-IAENG-309)
- A refusal in the escape-hatch hook for an agent applying the Director-only labels `control-change/approved` and `size/approved` — a local speed bump, not a boundary (WU-IAENG-311)
- An advisory inline-suppression scan of a Pull Request's added lines — one shared pattern file read by the runtime hook and a new server-side check, so a directive written through the Bash tool, by a human or by another runtime is reported (WU-IAENG-308)
- Attribution required on merges that **author content**: merges are classified by comparing their tree to the automatic merge of their parents, an authored merge needs an `Employee:` trailer in CI and in `commit-msg` and a registered Work Unit trailer, historical ones grandfathered in a closed constant (WU-IAENG-307, WU-IAENG-313)
- `.ia-engineering/tier-map` — a project records its tier-to-model mapping (`map=`, `effort-map=`, same syntax as the flags) so `generate-agents.sh` honours it on every regeneration; flags beat the file beats the target defaults, a malformed file is refused with exit 2, and `--check` reports a mapping-only drift as one. This repository records the Director's 5 Oct 2026 decision (WU-IAENG-327)
- `Adapters/scripts/usage-dashboard.sh` and `usage-dashboard.cmd` — a local, self-contained, gitignored HTML page from git trailers, the rosters and the chain and Work Unit registries plus a Claude Code collector, for roster and chain tuning: never-used Employees and unexercised chain steps are marked, aggregates only, pinned by a privacy test. The Windows launcher runs it through Git for Windows' own `bash.exe`, never the PATH's (WSL there) (WU-IAENG-326, WU-IAENG-329). Then live and per project: `--watch [SECONDS]` rebuilds the page until Ctrl-C and the page reloads itself, run from inside a framework submodule it measures the including project (WU-IAENG-330); a persistent, shape-checked, refuse-if-linked cache under `.ia-engineering/usage/cache/` plus `--refresh`, `--refresh-in-background` and `--open --no-wait` so a current page opens at once (WU-IAENG-341); a caret in the adopting project's path no longer makes the launcher measure the framework instead (WU-IAENG-338)
- `session-start.sh` and `stop-gate.sh` keep `.ia-engineering/SESSION_STATE.md` in step with the repository — a warning when it is behind HEAD, stale in its header or over its budget, and a block on ending a session whose state is behind (WU-IAENG-287); the snapshot discipline, a 15,000-character budget and a *Handoff to a New Conversation* checklist (WU-IAENG-288)
- Execution tier chosen **per Work Unit** rather than per Employee, plus a Director-approved, override-only **Frontier** tier reachable only by upgrading from Strategic Judgment; `generate-agents.sh` gains a Frontier key in `--map`, a per-tier effort field with `--effort-map`, and the review bot's model and effort pinned explicitly (WU-IAENG-292, WU-IAENG-293)
- Open-source licence compliance given an owner — the Compliance Engineer extended with dependency licence inventory, compatibility and obligation tracking (SPDX, OpenChain, CycloneDX), and the Security Engineer's dependency scan split into a report/adjudicate hand-off (WU-IAENG-294)
- The Penetration Tester extended to threat-led adversary emulation including the AI-runtime attack surface; every resolved adversarial finding ends as a regression test or a detection; the Observability Engineer gains the implementation half of security-event detection. Three existing Employees extended, no new Employee, no new chain (WU-IAENG-290)
- Accessibility conformance as an explicit verified quality gate — WCAG 2.2 AA in the QA and automation scopes, stale 2.1 references updated, iOS and Android platform guidelines (WU-IAENG-291)
- Miscasting Risks for the AI/ML and infrastructure clusters and three further pairs, and accessibility named in the QA Engineer's dispatch trigger (WU-IAENG-295); the optional runtime attribution trailer defined — it names the model that actually ran, is never dictated by a brief, is not validated (WU-IAENG-299)
- A *Main Agent* section in `Templates/PROJECT_CLAUDE.md` and a pointer from the session-start hook — blindfolded dogfood cycle 4 found adopters' Main Agents implementing inline under a false Employee trailer and skipping plan approval (WU-IAENG-323)
- The authoring path documented: Work Unit registration (WU-IAENG-275), the express path for trivial changes as lighter execution of every existing step rather than fewer steps (WU-IAENG-278), the AI-runtime install step in Project Bootstrap and Onboarding (WU-IAENG-289), a README note for a reader handed the repository to work on the framework itself (WU-IAENG-279), a correspondence table between Conduct's 7 steps and Orchestration (WU-IAENG-274), and the four operating-critical Core documents missing from CLAUDE.md's list (WU-IAENG-277)
- Front-door guards in `Adapters/scripts/validate-framework.sh` — README's current version against `VERSION.md` (WU-IAENG-261), CLAUDE.md (WU-IAENG-262), the README front-page counts (WU-IAENG-263), the Core/Templates and Standards enumerations, Agent Chains and Examples counts (WU-IAENG-265, WU-IAENG-266), and the in-progress milestone (WU-IAENG-284)
- Tests: the legitimate-command corpus behind the escape-hatch hook as committed allow cases (WU-IAENG-286); first behaviour cases for the `pre-push` hook through its real stdin protocol and real pushes into throwaway remotes (WU-IAENG-315); a skip counter in `Adapters/scripts/tests/run.sh` (WU-IAENG-300); the `perf` commit type (WU-IAENG-304)
- `Adapters/scripts/check-approval-carry-over.sh` — decides mechanically whether Code Reviewer, QA and Prompt Engineer approvals survive an update merge of `develop` into a Pull Request: the approved head must start the new head's first-parent line, every commit on it must be a two-parent merge of `develop`, each merge must equal git's own automatic merge outside `Registry/work-units.yml`, and the registry must hold exactly git's own entries with the PR's own entry byte-identical. Exit 0 prints the one-line record to paste; `merge-classify.sh` gains `merge_classify_automatic`, the one automatic merge both use (WU-IAENG-344, WU-IAENG-343)
- `validate-framework.sh` section 22 — every chain diagram in `Core/AGENT_CHAINS.md` compared step for step with its `Registry/chains.yml` entry (kind, name, condition, parallel marker, review loop), so the drift WU-IAENG-334 repaired fails the build instead of waiting for an audit (WU-IAENG-335)
- `generate-agents.sh --print-tier-map`, and `session-start.sh` printing the tier map in force with the rule that a Tier Override takes its model from it — never one of the Main Agent's choosing (WU-IAENG-336)
- Role absorption made visible at dispatch: the Employee Brief quotes the `Core/EMPLOYEE_SELECTION.md` trigger it relies on and the closest Miscasting pair rejected; `Governance/DISPATCH_IN_PRACTICE.md` states the only two cases where a non-Employee agent is acceptable; the Director's standing develop-merge exception recorded in `Core/MAIN_AGENT_CONDUCT.md` (Director, 6 Oct 2026) (WU-IAENG-331)
- `Core/EMPLOYEE_SELECTION.md` role boundaries sharpened — 92 of the 120 trailer-attributed commits since v0.0.13 went to two Employees; documentation-system work, project conventions, developer-tooling platform work, tier mapping, token cost, adapters, dashboards and usability studies now route to their owners, and every `Employees/` or `Core/*.md` change requires a Prompt Engineer review (WU-IAENG-333, WU-IAENG-340)
- `Core/AGENT_CHAINS.md` and `Registry/chains.yml` aligned step for step; Work Unit decomposition is the Main Agent's own Orchestration Step 3, the Engineering Manager dispatched only on multi-pole work (Director, 6 Oct 2026) (WU-IAENG-334)
- `Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh` and the `/dashboard` skill — in Claude Code the usage dashboard is kept fresh at the end of every turn by a `Stop` hook that never blocks, prints or fails a turn, and `/dashboard` opens the page at once. To turn the refresh off, create `.ia-engineering/usage-auto-refresh.off` (the reliable switch) or set `IAENG_USAGE_AUTO_REFRESH=off`; do not delete the hook entry (WU-IAENG-342)

### Changed

- `Core/` and `Governance/` precision: one answer for project convention vs framework Standard, via a governed tie-break on Documented Deviations (WU-IAENG-273); four normative-doc defects — Agent Chains' overbroad claim, the Branch Standard's lifecycle exception, stale Risk Standard cross-references, Agent Conduct's citation form (WU-IAENG-272); how the Critical tier interacts with the Incident Chain's one non-pausing gate (WU-IAENG-269) and the chain's true order (WU-IAENG-270); merge-approval scope — `main`, tags and releases always need the Director, merging an approved PR into `develop` is delegable — stated identically everywhere (WU-IAENG-303); the RISK record aligned on the Pull Request range (WU-IAENG-298)
- `Workflows/HOTFIX.md` Step 9 receives `RELEASE.md` Step 8's back-merge PR shape, closing the `head = main` deadlock it never inherited (WU-IAENG-271); `Examples/RELEASE_CHAIN_EXAMPLE.md` closing bullet corrected (WU-IAENG-268)
- Pre-push: **one rule** for `main`, `develop` and `release/*` — creating an absent branch is allowed, any update or reported deletion is refused; the mirror-push limit stated and pinned (WU-IAENG-315)
- `pr-validation.yml` graders hardened against reconfiguration by the change they grade — `shellcheck --norc`, workflow YAML parsed by a pinned js-yaml from a fresh directory (WU-IAENG-310)
- Root docs tiered like other doc types in `Governance/CONTRIBUTING.md` §1 (WU-IAENG-281); five cycle-2 dogfood frictions (WU-IAENG-280); the README's stale self-validation and test counts corrected against the tools' own output (WU-IAENG-276); the Miscasting pairs list replaced by a pointer (WU-IAENG-297)
- The security enforcement boundary stated: local guardrails (`pre-push`, hooks) are skipped by the same `--no-verify` / `core.hooksPath` they back up; the server-side required checks are the boundary. `SECURITY.md` and the hooks README say so; two limits of `block-inline-suppression.sh` documented (WU-IAENG-305)
- Adoption-path and dogfood documentation: Work Unit line enforcement stated as at most one locally and exactly one in CI, the bootstrap handoff, README hook and skill installs required (WU-IAENG-321); `git init`, the ref to pin, TROUBLESHOOTING Y and Z, the signer of the adoption commit (WU-IAENG-324); the bootstrap closing report (WU-IAENG-325)
- `Adapters/scripts/setup-*`, `install.sh` — a project's own Registry is read, never the framework's, and a missing one fails naming the file to create; the bootstrap writes an empty starter registry; exact-path LF rules for the files hooks and CI parse (WU-IAENG-320)
- `Adapters/ai-runtimes/claude-code/install-hooks.sh` now **merges** the template's missing entries into an existing `.claude/settings.json` (exit 0) instead of refusing it (exit 1); a framework hook entry a project deleted **comes back** on the next run, and a command that only resembles a framework guard (another matcher, `|| true`, a decoy, a same-named project script) does not count — the real entry is added beside it and the near miss reported. It refuses untouched without `jq`, on invalid JSON or on a symlink. `install-skills.sh` installs `/dashboard` in the framework repository too and reports an identical skill as current. **Adopters upgrading: after re-running `setup-project-bootstrap.sh <stack>` (Notes, Upgrading from v0.0.13), re-run `install-hooks.sh`** (it merges the new `Stop` hook into an existing `.claude/settings.json` and lists what it added) **and then `install-skills.sh`** (it installs the new `/dashboard` skill and leaves a skill the project edited untouched). Add `--force` only to replace a skill the project has **not** edited: it overwrites project edits (WU-IAENG-342)

### Fixed

- `Adapters/ai-runtimes/claude-code/hooks/block-escape-hatches.sh` — printf's runtime escapes decoded (WU-IAENG-285); case-insensitive `core.hooksPath`, `GIT_CONFIG_PARAMETERS` / `GIT_CONFIG_KEY_<n>`, a widened git global-options prefix, and a read exemption anchored to a real config read (WU-IAENG-306); `GIT_CONFIG_PARAMETERS` set through an assigning builtin (WU-IAENG-316); `pre-push` refuses case variants of protected branch names, the legacy-read refusal names the `--get` read, `data-policy-scan` no longer warns on NUL bytes (WU-IAENG-328), and the case-variant refusal names the branch the user probably meant (WU-IAENG-339)
- `block-inline-suppression.sh` — an unparseable payload with `jq` present left the text empty and the write was **allowed**; it now fails closed through a shared `iaeng_require_object`. The no-`jq` fallback gap is stated, not hidden (WU-IAENG-318)
- The required **Data Policy** check — scans what a merge itself authored and reads added lines as text, so a `-diff` or binary-classified path is no longer skipped (WU-IAENG-312); the required **Work Unit Exists** check classifies merges with the shared merge-tree classifier (WU-IAENG-313); the advisory **Risk Map** check diffs from the merge base and requires a column-0 `RISK:` record carrying `tier=`, `mitigation=` and `decided_by=` (WU-IAENG-314)
- The advisory **Review Recorded** job failed at `actions/checkout` (issue #180) — `contents: read` granted, with a content guard on every shipped job (WU-IAENG-317)
- `validate-framework.sh`, hooks and scripts — `producer | grep -q` read SIGPIPE as a missing path again (the same family as v0.0.13), failing intermittently on CI; membership tests over captured variables use a here-string and a 100 KB case makes the failure deterministic (WU-IAENG-319)
- `Adapters/scripts/release.sh publish` closing text said the Step 8 back-merge was conditional; `Workflows/RELEASE.md` says it is always required (WU-IAENG-322)
- `generate-agents.sh` — twelve process substitutions per Employee collapsed into one `awk` pass, removing a multi-minute MSYS fork-emulation stall with byte-identical output across all 42 agents (WU-IAENG-301)
- `session-start.sh` — reported a CLAUDE.md that did not exist (WU-IAENG-302)
- The SESSION_STATE adoption instruction produced an unreadable file — the README now says to copy only the fenced block under the template's *Template* heading, with an absolute `_Last updated` date (WU-IAENG-337)
- Four measured adopter-install defects: derived and runtime artifacts ignored by default, framework-only `.gitattributes` EOL rules restricted to the framework, a symlink/junction-safe branch-protection hint (WU-IAENG-296); the README Core/Templates drift and a false `EMPLOYEE_BRIEF` cross-reference (WU-IAENG-264); the hooks README's `rc` example (WU-IAENG-267)

### Notes

This release makes the framework exact, and it came from two directions that met in the same files.

**A front door nobody guards drifts.** Every drift found after v0.0.13 — the README naming the old version (WU-IAENG-260), `VERSION.md` leaving the in-progress milestone `TBD` while its Work Units were already registered (WU-IAENG-282), CLAUDE.md and README still reading `TBD` after Precision was declared (WU-IAENG-283), a count that was true once — was cleared and then pinned by a validator section, so the same class cannot reappear unseen.

**The controls that grade a change can be rewritten by the change.** Issue #112 and two Purple exercises attacked the hooks and CI from inside; each finding closed as a check, a hook rule, or a stated limit. Two limits are stated rather than hidden: the local guardrails are not the security boundary (the server-side required checks are), and the Control Path Guard is **not yet a required check**.

The recurring lesson of v0.0.13 held: nearly every defect above was found by executing something — an adoption, a dogfood cycle, a pen test — not by reading it.

**Scope moved out.** WU-IAENG-332 (usage dashboard measurement fixes) and the open follow-ups go to the next milestone, **Adoption** (v0.0.15), so this release carries only work that is merged.

**First reports of the Control Path Guard.** Because GitHub reads a `pull_request_target` workflow from the default branch, the guard has never run on a Pull Request here. It starts when this release reaches `main`; the Director creates the `control-change/approved` label and the `IAENG_DIRECTOR_LOGIN` variable before the first Pull Request that touches a control path afterwards.

**Upgrading from v0.0.13.** After moving the submodule, first re-run `setup-project-bootstrap.sh <stack>` **without `--force`**, with `<stack>` the value in `.ia-engineering/stack`. It adds `Registry/work-units.yml`, without which the required Work Unit Exists check now fails (WU-IAENG-320), and `control-path-guard.yml`, and appends missing rules to `.gitattributes` (including `/Registry/work-units.yml text eol=lf`) and `.gitignore`: commit those additions with the upgrade. It overwrites no file it installs. It marks with `!` each existing file it left alone. The `already exists` lines (`ci-build-test.yml`, `ghcr-publish.yml`, `.ia-engineering/stack`, `risk-map.yml`, `Dockerfile`) are your stack files, printed even when unchanged: leave them as they are. Only the two `differs from the Adapter` lines changed upstream, `pr-validation.yml` (the inline-suppression job and the grader hardening) and `PULL_REQUEST_TEMPLATE.md`, and it exits 1 for them even when nothing else is wrong. Review each diff, and if you never edited the file, copy the Adapter over it by hand (`cp ia-engineering/Adapters/github-actions/pr-validation.yml .github/workflows/`, `cp ia-engineering/Adapters/github/PULL_REQUEST_TEMPLATE.md .github/`). Do not re-run with `--force`: it replaces every existing file it manages at once, including your Dockerfile, Risk Map, stack declaration, issue-template config and Work Unit registry. Then re-run `install-hooks.sh` and `install-skills.sh` as the WU-IAENG-342 entry under Changed describes (WU-IAENG-352).

---

## [0.0.13] - Portability

### Added

- `Adapters/scripts/check-work-units.sh`, `check-employee-trailers.sh`, `check-pr-size.sh`, `check-review-recorded.sh` — the four Pull Request checks, previously 262 lines of shell embedded in `pr-validation.yml`, now scripts an adopting project can run before pushing and any CI host can invoke. The workflow drops from roughly 750 lines to 382 (WU-IAENG-224, WU-IAENG-225, WU-IAENG-226, WU-IAENG-227, WU-IAENG-228)
- `Adapters/scripts/tests/run.sh` — a behaviour suite for those scripts, run by a new required **Script Tests** check. Every case builds a real git repository and runs the real script; nothing is mocked. Created at 140 checks (WU-IAENG-224, WU-IAENG-229)
- `Adapters/scripts/hosts/` — the four operations no amount of git can answer, one directory per forge: creating a release, reading the CI conclusion, listing open defects, fetching review comments. `hosts/README.md` states the contract — **the host fetches and acts, it never decides** — and `none` is a real host whose implementations print what a human must do by hand rather than pretending (WU-IAENG-237)
- `Adapters/scripts/resolve-host.sh`, `resolve-stack.sh` — a declaration in `.ia-engineering/host` and `.ia-engineering/stack` beats a guess, and an unrecognised declaration fails rather than silently falling back to detection (WU-IAENG-230, WU-IAENG-237)
- `Adapters/dockerfiles/web.Dockerfile`, `dotnet.Dockerfile`, `php.Dockerfile` — four first-class stacks become seven. `web` is a static front end: it builds with Node and ships files behind a web server, with no Node in the runtime image (WU-IAENG-231)
- `Adapters/ai-runtimes/claude-code/skills/create-project/` and `install-skills.sh` — a `/create-project` command that runs `Workflows/PROJECT_BOOTSTRAP.md`. The skill **points at the Workflow and does not restate it**, and the installer refuses to run inside the framework checkout, because installing there would make a runtime-specific file part of the framework's own content (WU-IAENG-242)
- `Adapters/scripts/validate-framework.sh` section 16 — every `CHANGELOG.md` version has a tag, with the version being prepared exempt as a named allow-list of exactly one, and only while its tag is genuinely absent (WU-IAENG-233)
- `SECURITY.md`, root `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` — the files a public repository is judged on. The two root files are pointers, never copies (WU-IAENG-243)
- `Standards/RISK_STANDARD.md` — **the Risk Map**: a project classifies its own paths into Routine / Standard / Sensitive, with a closed list of eight sensitive categories, so a control can tell an authentication module from a README. Routine means *no observable behaviour changes*, not "small". An unmapped project is **unclassified, not safe**. The same section names the three scales that all use the word "high" — action risk, finding severity, change zone — and requires saying which. Absorbed as a concept from a sibling framework (WU-IAENG-245)
- `Templates/RISK_MAP.md` — the shape of a map, and **the five ways one goes wrong**, each with the command that catches it. All five were found by running commands, none by re-reading a map; the fifth — a zone drawn too wide, so a Risk Record is demanded on every commit and stops meaning anything — was found on the first Pull Request after this repository's own map merged (WU-IAENG-245, WU-IAENG-248)
- `Adapters/scripts/check-risk-map.sh` — verifies a map by computing the level of **every tracked file** rather than re-reading the list, and with `--range` requires a `RISK:` record when a change touches a sensitive zone. The record already existed in the Standard; the mechanical trigger did not. Runs from git alone, so every forge gets it. Reported by a new advisory **Risk Map** check (WU-IAENG-245, WU-IAENG-246)
- `.ia-engineering/risk-map.yml` — this repository's own map: 27 zones over 185 tracked files. Writing it applied two borrowed definitions on the first pass: a billed model call is a real expense, so `review-bot.yml` is `payments_and_spend`; and an Employee definition is infrastructure, not documentation (WU-IAENG-245, WU-IAENG-248)
- `Core/CONTEXT_BUDGET.md` — the first measurement of what the framework itself loads before a Work Unit begins: a Main Agent session reads ≈ 14 k tokens before acting, 61 % of it one document; an Employee dispatch loads ≈ 15 k, so **re-brief before you re-dispatch**. Measured in characters with the command beside each figure; tokens stated as an estimate with its margin. Absorbed as a discipline from a sibling framework, whose figures are listed as theirs and unreproduced (WU-IAENG-249)
- `Governance/DISPATCH_IN_PRACTICE.md` — what the dispatch pipeline does in use, recorded only where it differs from `Core/ORCHESTRATION.md`. Leads with a measured number: 13 of 42 Employees dispatched, 63 dispatches, **zero** Employee definitions changed as a result (WU-IAENG-247)
- `Adapters/scripts/setup-project-bootstrap.sh` — writes a **starter Risk Map** for the files it installs (workflows, Dockerfile, the map itself → sensitive) and declares **no category absent**, so `check-risk-map.sh` names what the project must still account for rather than the bootstrap guessing. Maps only the stack half's guaranteed outputs, never `install.sh`'s, which would create dead entries (WU-IAENG-250)
- `Adapters/scripts/validate-framework.sh` section 17 — every stack in `VALID_STACKS` ships a non-empty `Adapters/dockerfiles/<stack>.Dockerfile`, and every Dockerfile matches a declared stack. Without it, a stack added without its Dockerfile fails only on an adopter's machine; the universality claim is now a checked fact both directions (WU-IAENG-255)
- `Adapters/scripts/tests/run.sh` — the suite grows to 185 checks, pinning the existing-file bootstrap guard, the untracked-vs-dead Risk Map message, and that the trailer checks judge the change set under review rather than prior history (WU-IAENG-253, WU-IAENG-254, WU-IAENG-257)

### Changed

- `Workflows/FEATURE_DEVELOPMENT.md` 0.0.5 — the Security Engineer is consulted during implementation, in parallel with the Compliance Engineer, and not only at review. A review can only find what the design already committed to: an authentication scheme, where a secret lives, which side of a trust boundary a component sits on are settled while the Work Unit is built (WU-IAENG-241)
- `Adapters/github-actions/ci-build-test.yml` — resolves the stack through `resolve-stack.sh` instead of inferring it inline, and **reports an ambiguous project instead of ranking it**. A Laravel application has `composer.json` and `package.json` and both are true; first-match-wins built one and never said so (WU-IAENG-230, WU-IAENG-231)
- `Adapters/scripts/setup-branch-protection.sh` — ten required checks, and on any forge it cannot configure it changes nothing, exits non-zero, and prints the equivalent as a checklist including what is deliberately excluded from it (WU-IAENG-229, WU-IAENG-239)
- `README.md` — a Getting Started before the philosophy, a *What this is not*, and a *What is proven, and what is not* that states on the front page that the framework has only ever been used on itself and that 29 of the 42 Employees have never been dispatched (WU-IAENG-243)
- `Examples/RELEASE_CHAIN_EXAMPLE.md` 0.0.9 — brought up to the rules it demonstrates: the GitHub Release Step 7 has required since v0.0.11, and the back-merge as it actually works (WU-IAENG-236)
- `.gitattributes` — the installed copies under `.github/` are marked `linguist-generated`, so a change to an Adapter and its byte-identical installed copy costs the review limit once rather than twice (WU-IAENG-240)
- `Adapters/scripts/setup-project-bootstrap.sh` — an existing file at a path the framework would install (a CI workflow, a Dockerfile) is left untouched without `--force`, like its three siblings in the script. Adopting into an **already-started project** no longer risks discarding real work; greenfield is unchanged (WU-IAENG-253)
- `Workflows/ONBOARDING.md` — a section **"Adopting into an already-started project"** names the four realities greenfield never meets: own files never overwritten (both CIs run), the checks judge the change set under review not prior history, pre-existing inline suppressions are grandfathered until a whole-file rewrite, and the starter Risk Map covers only installed files. Each is host-neutral and verified on a real adoption (WU-IAENG-256)

### Fixed

- `Adapters/scripts/setup-branch-protection.sh` — the `release/*` ruleset carries a `deletion` rule and a release merge deleted `release/v0.0.12` anyway: GitHub's automatic head-branch deletion is performed by the platform and is not evaluated against rulesets. The setting is turned off and verified. **Every project that had run this script inherited the same hole** (WU-IAENG-232)
- `Adapters/scripts/release.sh` — three defects found by running it. It offered to cut a release for a version already tagged and on `main`, which is the normal state of `develop` between releases; it named Step 2 as next after Step 2 had merged; and it reported the CI conclusion through `gh` directly rather than through the host seam (WU-IAENG-234, WU-IAENG-235, WU-IAENG-237)
- `resolve-stack.sh` — .NET was undetectable. `ls a b c` exits non-zero as soon as *any* operand is missing, so a project with a `.csproj` and no `.sln` matched nothing and would have built as `generic`, silently (WU-IAENG-231)
- `hosts/none/open-bugs.sh` — exiting 0 with nothing on stdout made the readiness report say *"no open issues labelled bug"*, asserting an absence nobody had established. A host that cannot see the tracker has not found zero bugs; it has found nothing (WU-IAENG-237)
- Three defects the inline checks had shipped, none findable by reading: a mis-indented registry would have blamed 92 commits instead of the parser, a roster parsing to zero would have refused every commit, and `IAENG_PROJECT_ROSTER` pointing at a missing file degraded silently to the framework roster — refusing every Domain Employee while reporting a clean configuration (WU-IAENG-224, WU-IAENG-225)
- `README.md` — its Contributing section said guidelines would exist "before the first public release" while `Governance/CONTRIBUTING.md` had existed for two milestones (WU-IAENG-243)
- `Adapters/scripts/install.sh` — refused a correct installation because one path was spelled `C--…` and the other `c--…`. `core.hooksPath` was never set, so **no git hook ran at all**, and the installer said so — the failure was upstream of the controls that reported it. Containment is established by walking parents and comparing device and inode, not by comparing spellings; the second fix in the same place, the first having handled the native-vs-shell path form. Found by re-running the end-to-end adoption test at HEAD an hour before a live test session (WU-IAENG-244)
- `.gitignore` — a `!` exception cannot re-include a file whose parent directory is excluded. `.ia-engineering/` was excluded as a directory, so git never descended and both exceptions were silently inert. The risk map and the stack declaration are project knowledge a clone must inherit; the pattern is now `.ia-engineering/*`, and each path was verified with `git check-ignore` rather than assumed (WU-IAENG-245)
- `Adapters/scripts/check-work-units.sh`, `check-employee-trailers.sh`, `check-review-recorded.sh`, `check-risk-map.sh` — `producer | grep -q` under `set -o pipefail` reads the producer's SIGPIPE as the pipeline's result: once the producer exceeds the ~64 KB pipe buffer, a matched pattern reads as a miss. Two adopter-facing checks were wrong on a real repository — `--range` reporting no `RISK:` record while one was present, and trap 4 calling a live zone dead. Fixed with a here-string, the threshold **measured** not guessed (TROUBLESHOOTING X, WU-IAENG-251)
- `Adapters/ai-runtimes/claude-code/hooks/block-inline-suppression.sh`, `block-escape-hatches.sh` — the runtime hooks had the same `grep -q` + `pipefail` bug: a code file whose first line was `# noqa` was **allowed** once its body passed the ~64 KB buffer — no obfuscation, just size. Both gating hooks fixed with a here-string; a >64 KB case added to the hook suite (WU-IAENG-252)
- `Adapters/scripts/check-risk-map.sh` — right after bootstrap it reported its own freshly-installed zones as "dead entry, trap 4, remove it", because the files exist on disk but are not committed yet — the state every adopter is in on first run. It now tells a **present-but-untracked** zone ("stage and commit it") from a genuinely dead one, keeping the same strictness with a truthful diagnosis (WU-IAENG-254)

### Notes

This release makes the framework runnable somewhere other than where it was written, and the work divided into two halves that turned out to be the same problem.

**Logic that lives inside a CI workflow can only be tested by deploying it.** That is not a style objection: it is how `PR Size` came to refuse every Pull Request with an empty diff — correct for wrong refs, wrong for a back-merge — and deadlock the v0.0.12 release against `Workflows/RELEASE.md` Step 8. Diagnosing it required writing a separate program to lift the `run:` block out of the YAML so it could be executed at all. Extracting the four checks was therefore portability and testability in one move, and the suite immediately found three more defects of the same family.

**A guess that happens to be right is still a guess.** CI inferred the project's stack from whichever manifest it found first, which works only while one manifest means one stack. A React site and a Node server both have `package.json`, so a `web` stack was not merely absent — it was unreachable. Recording the choice is what made three new stacks possible, and it turned an unanswerable question into one the project answers once.

Seven of the ten required checks now need no host API at all. The remaining three are behind a seam whose second implementation, `none`, does not pretend: an adopter on an unsupported forge gets a checklist rather than a crash. **No GitLab implementation ships here** — one never executed against its forge belongs in an issue, not in the tree, and this repository already carries two adapters written and never run.

The milestone's own recurring lesson is narrower than the previous one's and worth stating: every defect above was found by **executing something or reading its output**. None was found by reading code. The corpus is checked by seventeen mechanical sections and none of them can read a sentence — which is also why `Examples/RELEASE_CHAIN_EXAMPLE.md` went stale within hours of the Workflow it demonstrates changing, twice in one morning, and had to be repaired by hand.

---

## [0.0.12] - Automation & Convergence

### Added

_Automation:_

- `Registry/` — the machine-readable form of the framework: `employees.yml`, `chains.yml`, `workflows.yml`, `work-units.yml`, plus a `README.md` that states the ordering that makes it safe — the Registry is **derived and never authoritative**, so where it and a governed document disagree, the document is right and the Registry is stale. The roster had been duplicated in six places, kept in sync by hand (WU-IAENG-137, WU-IAENG-145, WU-IAENG-146)
- `Adapters/scripts/validate-framework.sh` — the cross-reference check that `Governance/CONTRIBUTING.md` §3 and `Governance/DEPRECATION_POLICY.md` both require as a Definition of Done item, executed rather than remembered: Registry-to-definition agreement in both directions, roster counts quoted in prose, tier-table consistency, dispatch-trigger coverage, mandatory document sections, metadata fields, referenced-path resolution, Adapter/installed-copy parity, executable file modes, and unresolved work markers (WU-IAENG-139)
- `Adapters/github-actions/framework-validation.yml` — framework validation as a blocking check, on pull requests **and on pushes to `main` and `develop`**, because a merge can produce a state neither parent had: two PRs that each pass in isolation can leave the roster and a document disagreeing once both land (WU-IAENG-143)
- `Adapters/scripts/install.sh` — every host-agnostic Adapter installed by one idempotent command, with hooks wired through `core.hooksPath` so they cannot fork from the imported framework version, and a verification step that proves the installed hook rejects an invalid trailer rather than asserting that copying a file made it work (WU-IAENG-141)
- `Adapters/scripts/release.sh` — the mechanical parts of `Workflows/RELEASE.md`: Step 1 readiness as a report that exits non-zero, and Step 7's tag plus a full GitHub Release built from the version's `CHANGELOG.md` section. It refuses to tag unless the release is already merged to `main`, and it never approves or merges — Step 5 is the Director's (WU-IAENG-147)
- `Adapters/ai-runtimes/generate-agents.sh` — the 42 Employee definitions turned into agents a runtime can dispatch to, so reaching for the right Employee is the path of least resistance rather than the disciplined exception. Execution capability derived from each Employee's Default Complexity Tier, with the tier-to-model mapping living in the Adapter and never in `Core/` (WU-IAENG-148)
- `Adapters/README.md` — **The Check Convention**, four rules written down because this milestone found sixteen checks that reported success without evaluating anything, four of them introduced by the fixes to earlier instances of the same defect: an unevaluated condition is a failure, not a pass; exceptions are named allow-lists, never fall-throughs; a check that iterates a set reports its denominator; and a claim about a mechanism's behaviour is testable — enumerate the alternatives, then run the falsifier (WU-IAENG-153, WU-IAENG-169)

_Convergence:_

- `Standards/RISK_STANDARD.md` — one shared scale for risk, replacing per-Employee private judgment: a 3×3 likelihood × impact matrix mapped to Low/Medium/High/Critical, a required behaviour per tier (High stops and waits for a confirmation that names the action; Critical additionally requires an independent verification pass), the escalation block, the one-line `RISK:` record, and three generic catalogs — operational, product, security — that a project instantiates and may raise but never lower (WU-IAENG-172)
- `Standards/DATA_PROTECTION_STANDARD.md` — real data, secrets, and operational state kept out of version control structurally rather than by convention: the local data directory, the anchored `SYNTHETIC_` fixture marker, the history check that counts (`git rev-list --all --objects`, not `git ls-files`), the purge protocol, and three layers of enforcement of which only the third cannot be skipped from a developer machine (WU-IAENG-173)
- `Adapters/scripts/data-policy-scan.sh`, `Adapters/git-hooks/pre-commit`, `Adapters/github-actions/data-policy.yml` — one pattern list in three modes (`--staged`, `--tree`, `--history`), a client-side hook that fails closed, and a required **Data Policy** CI job that scans the tree *and* the objects a branch introduced. Matched secret values are never printed; exemptions are the anchored marker and a committed allow file (WU-IAENG-173, WU-IAENG-199)
- `Templates/WORK_UNIT_REPORT.md` — the complete output an Employee returns, mirroring the Employee Brief: a one-word verdict, what was done, **what was not done**, gate evidence pasted rather than described, deviations, risk records, and the Definition of Done item by item. A bare "Done" is a failed Work Unit (WU-IAENG-174)
- `Templates/SESSION_STATE.md` — a project's dated operational state, and the three-memory model that separates it from the committed `CLAUDE.md` contract and from the runtime's own memory. Never committed, because a file describing what is currently weak does not belong in the repository it describes (WU-IAENG-175)
- `Templates/DOMAIN_EMPLOYEE.md` — project-owned Employees for the business domain, whose Definition of Done states what constitutes *proof* that a domain output is correct. Registered in a project roster that `commit-msg`, the `Employee Trailer` job, and `generate-agents.sh` all read in addition to the framework roster (WU-IAENG-176, WU-IAENG-189)
- `Templates/POLE_BRIEF.md` — the unit of dispatch from a conductor to a pole, with disjoint write scope, a bounded budget, and explicit stop conditions (WU-IAENG-185)
- `Templates/PROJECT_CLAUDE.md` — the project contract `Workflows/ONBOARDING.md` Step 1 had always told adopters to write "from the template", for which no template existed (WU-IAENG-193)
- `Workflows/AUTONOMOUS_DELIVERY.md` — the tenth Workflow: several Main Agent sessions working in parallel under one conductor, with four rules that keep federation from weakening any control — every control binds unchanged per pole, escalation is centralised through the conductor, the budget is bounded in the Director's mandate, and nothing is delivered until an integration pass has run on the merged result (WU-IAENG-185)
- `Governance/TROUBLESHOOTING.md` — an incident catalog of 23 classes as symptom → cause → remedy → prevention, seeded from this framework's own history and from the sibling corpora it drew on. An entry without a Prevention is returned in review (WU-IAENG-183, WU-IAENG-200, WU-IAENG-203)
- `Governance/CONTRIBUTING.md` Section 7 — the learning loop that feeds that catalog: the fixing Work Unit records the instance, the second instance of a class names the class and writes the rule, and a rule that can be checked mechanically becomes a control (WU-IAENG-183)
- `Adapters/ai-runtimes/claude-code/hooks/` — five runtime hooks that refuse before rather than rejecting after: read-first context at session start, an escape-hatch block on shell commands, an inline-suppression block on edits, post-edit lint, and a stop gate. All fail closed on unreadable input; none has a disabling switch (WU-IAENG-179)
- `Adapters/ai-runtimes/claude-code/hooks/tests/` — the repository's first behaviour suite, 264 checks, run by a required **Hook Tests** CI job. Every bypass found in six review passes became a case, and so did every false positive (WU-IAENG-195, WU-IAENG-206)
- `Adapters/ai-runtimes/claude-code/review-bot.yml` — an independent Code Reviewer running under the Actions identity, and an independent mode for `Review Recorded` keyed on `IAENG_REVIEW_BOT_LOGIN`. Opt-in: it needs an API key and a Director decision to spend it (WU-IAENG-184)
- `Adapters/ai-runtimes/omc/README.md` — a transport mapping onto the oh-my-claudecode orchestration layer: what corresponds, what does not, and where the framework binds regardless. Recorded from that runtime's own documentation and not tested here, which the file states (WU-IAENG-186)
- `Adapters/scripts/validate-framework.sh` sections 14 and 15 — VERSION.md's Standards, Workflows, and Templates inventories compared against the documents themselves, and the Glossary's ordering checked because the Glossary claims it (WU-IAENG-190, WU-IAENG-191)

### Changed

_Automation:_

- `Adapters/git-hooks/commit-msg` — reads the roster from `Registry/employees.yml` instead of carrying its own copy of 42 names, and **fails closed**: a roster it cannot resolve is a broken installation, not a reason to validate against nothing. It validates *every* `Employee:` line rather than one chosen by position, and refuses a second `Work Unit:` claim outright (WU-IAENG-138, WU-IAENG-164, WU-IAENG-167)
- `Adapters/github-actions/pr-validation.yml` — the `Work Unit Exists` check resolves each commit's `Work Unit:` **trailer** against the registry rather than matching a regex against the PR description, which two prose-based versions got wrong in opposite directions; `Employee Trailer` re-validates server-side as a backstop for a hook that `--no-verify` or a missing install can skip; and the checks now trigger on `release/*` too, where they previously could not be required at all (WU-IAENG-144, WU-IAENG-155)
- `Standards/COMMIT_STANDARD.md` — the trailer layout documented as measured rather than as assumed: `Work Unit:` contains a space, so git never parses it as a trailer, and one unparseable line invalidates the whole block. Separated by a blank line, `Employee:` sits alone in the final paragraph and `git log --format='%(trailers:key=Employee)'` resolves it — 28 of 30 commits parsed only in that layout. The `Work-Unit:` rename is recorded as a dated open decision rather than left implicit (WU-IAENG-165, WU-IAENG-166, WU-IAENG-168)
- `Adapters/scripts/setup-project-bootstrap.sh` — performs the steps it is named for, delegating the host-agnostic half to `install.sh` rather than duplicating it, and propagating that script's exit status instead of discarding it (WU-IAENG-142, WU-IAENG-159)
- `Governance/VERSIONING_POLICY.md` 0.0.12 — states that one version may carry more than one milestone: "once per completed milestone" governs the counter, not the release, and a version carries several only when every milestone named in its heading is genuinely complete. Milestone Naming Discipline says why it does not forbid this — that rule is about a name attached to work it does not describe. A number belongs to the release, not to the milestone, so several milestones sharing a release share its number and none is skipped (WU-IAENG-217, WU-IAENG-218)

_Convergence:_

- `Standards/PULL_REQUEST_STANDARD.md` 0.0.3 — Reviewability made concrete: a 1,500-line review limit on the files a reviewer must read, `linguist-generated` files excluded, and a Director override by the `size/approved` label rather than by a sentence in the description, because applying a label requires write permission and pasting a sentence does not. Plus a Self-Contained Description section: a body that needs the author present has not been written (WU-IAENG-177)
- `Standards/GIT_STANDARD.md` 0.0.3 — the canonical escape-hatch table, under one rule: a control that is in the way is a rule that is in the way, so escalate the rule and never route around the control. `core.hooksPath` is listed beside `commit.gpgsign=false`, both being `--no-verify` spelled as configuration (WU-IAENG-178, WU-IAENG-201)
- `Standards/CODE_QUALITY_STANDARD.md` 0.0.3 — No Inline Suppression: a rule that is wrong for the project is tuned in the linter's configuration, where the change is a reviewed diff. Swallowed exceptions, skipped or focused tests, lowered coverage thresholds, and widened types are named as the same class (WU-IAENG-178)
- `Core/ORCHESTRATION.md` 0.0.9 — the dependent-task queue with layered termination (Work Unit / Retry / Queue / Blocked / Stopped), and a Step 5 that receives a Work Unit Report and re-verifies its claims against the repository rather than accepting them (WU-IAENG-182)
- `Core/AGENT_CONDUCT.md` 0.0.2 — Read First and the Reporting Contract, plus the statement that an Employee's own Standards Applied list does not limit what binds it: Standards First, Risk, and Data Protection bind every Employee whatever its definition says (WU-IAENG-182, WU-IAENG-192)
- `Core/GLOSSARY.md` 0.0.2 — 17 → 28 terms. The Convergence vocabulary, and three that had been missing far longer: **Main Agent**, Gate, Registry (WU-IAENG-191)
- `Workflows/CODE_REVIEW.md` 0.0.5 — a decision that states its denominator, line re-anchoring on re-review so no finding lapses when its line moves, Multi-Lens Review with cross-debate resolved by evidence rather than seniority, and ten review lessons each learned by getting it wrong (WU-IAENG-181)
- `Workflows/PROJECT_BOOTSTRAP.md` 0.0.11 — project profiles A/B/C, the "what constitutes PROOF" question, and the confidential-data question asked at inception rather than after the first file exists (WU-IAENG-180)
- `Workflows/ONBOARDING.md` 0.0.5 — Session State and the Adapters installed before the first commit; Domain Employees decided and registered at Step 4 (WU-IAENG-175, WU-IAENG-176)
- `Templates/EMPLOYEE_BRIEF.md`, `Templates/WORK_UNIT.md` — the other half of the report contract: the brief names the report's destination, carries it as a Definition of Done item, lists the three universally binding Standards, and has an Escalation row for a High or Critical classification that says to escalate *and wait* (WU-IAENG-209)
- `Examples/` — the six chain walkthroughs brought up to the rules they demonstrate: Work Unit Reports re-verified in Collect, a review decision with its denominator, line re-anchoring on the second pass, and risk records on the hotfix and the P1 incident (WU-IAENG-208)
- `Adapters/github-actions/pr-validation.yml` — eight checks now: **PR Size** and **Hook Tests** added, the `Employee Trailer` job reading the project roster, `Review Recorded` gaining an independent mode and telling an API failure from an absent decision, and both the shellcheck and YAML file lists **derived** from `git ls-files` rather than enumerated (WU-IAENG-176, WU-IAENG-177, WU-IAENG-184, WU-IAENG-195, WU-IAENG-198, WU-IAENG-202)
- `Adapters/scripts/setup-branch-protection.sh` — nine required status checks on `main`, `develop`, and `release/*` (WU-IAENG-173, WU-IAENG-177, WU-IAENG-195)

### Fixed

_Automation:_

- Sixteen checks that reported success without evaluating anything, across the validator, the installer, the release script, and the CI jobs — an absent Registry counted as a pass, a git-less run of the index-mode check passed, the marker scan went blind on a renamed root, `check_parity` treated an absent installed copy as agreement, and several checks passed on a zero-denominator set. Three were found by this repository's own CI, six by code review, two by an audit once the pattern was named — and four were introduced by the fixes to earlier instances, which is why the convention above is written down rather than assumed (WU-IAENG-153, WU-IAENG-156, WU-IAENG-157, WU-IAENG-158, WU-IAENG-160, WU-IAENG-161, WU-IAENG-162, WU-IAENG-163)
- Every shipped script and hook carried mode `100644` in the git index, so a Linux runner could not execute any of them: Windows has no executable bit and nothing local ever noticed. Now recorded in the index and checked by the validator (WU-IAENG-150)
- Glob and sort collation differed between Git Bash and Linux, so a check comparing two ordered lists passed on one platform and failed on the other with identical content. `LC_ALL=C` pinned in every script that orders anything (WU-IAENG-152)
- The cross-reference check resolved paths against a case-insensitive filesystem and so accepted `Core/GLOSSARY.MD`; it resolves against `git ls-files` now, with `CHANGELOG.md` excluded because a changelog quotes historical paths by definition (WU-IAENG-151)
- `generate-agents.sh` hung forever on a trailing value-taking flag — `shift 2` with one argument left fails, and a failed shift does not shift, so the loop spun with no output and no exit. It was the only defect in the milestone that hung rather than misreported, which made it the only one invisible in a log (WU-IAENG-170)
- `Adapters/scripts/release.sh` — Step 1 derived the milestone under release by comparing a `CHANGELOG.md` heading's codename field for equality, so this release's own two-milestone heading matched neither name and both would have read as unreleased on every future release. The field is read as a list now — and compared whole before it is split, because v0.0.10.1 shipped as "Consistency & Compliance Hardening", a single milestone whose own name contains the separator (WU-IAENG-216)

_Convergence:_

- `Adapters/ai-runtimes/generate-agents.sh` — ran from a consumer project, it wrote all 42 agents *inside the submodule*, at a path no runtime reads and which the framework's own `.gitignore` excludes, and reported success. Output is resolved against the project now, and the generated header carries a roster-relative path so the files do not differ between machines (WU-IAENG-189, WU-IAENG-196)
- `Adapters/github-actions/pr-validation.yml` — the `PR Size` job reported green when it had measured nothing: its loop was fed by process substitution, which hides `git diff`'s failure from `set -euo pipefail`. It also ranged from `base.sha` rather than the merge base, so unrelated base-branch churn landed in the count (WU-IAENG-198)
- `Adapters/scripts/data-policy-scan.sh` — the history mode missed a blob already reachable from the excluded side, so an *empty* `.env` added and deleted inside a range scanned zero paths and reported clean. A zero-path scan over a non-empty range now fails (WU-IAENG-199)
- `Adapters/ai-runtimes/claude-code/hooks/` — escape-hatch bypasses and false positives found across six review passes, each pinned as a test case — the suite grew from 83 checks to 264 in the process. The two that would have mattered most in the field: `git -c core.hooksPath=…` disabled every git hook, and a bash-4 expansion would have refused every Edit and Write on macOS, where `/bin/bash` is 3.2 and the construct is a *parse* error the runtime reads as *block* (WU-IAENG-188, WU-IAENG-194, WU-IAENG-197, WU-IAENG-201, WU-IAENG-204, WU-IAENG-205, WU-IAENG-207)
- `VERSION.md` — the Standards, Workflows, and Templates inventories had drifted to 8 of 10, 9 of 10, and 7 of 12; all three corrected and now checked by the validator (WU-IAENG-190)
- `Adapters/github-actions/pr-validation.yml` — the `PR Size` job refused any Pull Request whose diff listed no files, which is right for wrong refs and wrong for a back-merge. `Workflows/RELEASE.md` Step 8 carries `main` into `develop` through a Pull Request that changes nothing by construction, so with this check required on `develop` and "require branches to be up to date" set on `main`, the two controls deadlocked the release process against itself. The cases are now told apart by the commits rather than the files: no commits at all still fails, a non-merge commit that changed nothing still fails, a range whose commits are all merges passes with a notice (WU-IAENG-220)
- `Adapters/scripts/data-policy-scan.sh` — the same defect in the same shape one control over: a zero-path history scan over a non-empty range failed, and a merge-only range enumerates no paths by construction. Same distinction applied, as a named allow-list of one shape rather than a fall-through (WU-IAENG-221)
- `Employees/Management/RELEASE_MANAGER.md`, `Employees/Management/SCRUM_MASTER.md` — neither listed Standards First, the root of the hierarchy, and nothing had said so in eleven versions. Now checked for all 42 (WU-IAENG-192)

### Notes

This release carries **two milestones**, named in full in the heading above. Both completed on `develop` before either shipped, and `Governance/VERSIONING_POLICY.md` allows one version to carry several: "once per completed milestone" governs the counter, not the release.

Shipping them separately was considered and rejected on a concrete ground. The release branch for an Automation-only release would have to be cut where Automation ended on `develop`, and that point predates three of the nine required status checks — `Hook Tests`, `PR Size` and `Data Policy` — which Convergence introduced. Those checks could never report on that commit, so the pull request to `main` could never become mergeable, and the release could only have shipped by suspending the branch protection it exists to pass. A number for a release that cannot pass its own gates is worse than a heading with two names in it.

**Automation** is the point at which the framework began checking itself. Before it, every rule held because a human or an AI remembered it; after it, the rules that can be checked mechanically are, and the ones that cannot are named as such. The milestone's own defect class recurred inside its own remediation: a check that reports success without evaluating anything, sixteen instances, four of them created by fixing earlier ones. That is not a set of oversights — it is the default reasserting itself, because writing a pass is the path of least resistance whenever a condition turns out not to apply. `Adapters/README.md`'s Check Convention exists so the seventeenth is less likely than the sixteenth was.

**Convergence** absorbs the governance concepts of two sibling frameworks as concepts rather than as code, with nothing specific to one organisation or one stack carried over. The scale changed as well as the content: the framework gained its first behaviour test suite, and the runtime hooks were attacked by an independent reviewer across six passes producing roughly sixty findings, all fixed, each reproduced before the fix and falsified after.

Two properties of that process are worth recording. Every control these milestones added was eventually turned on itself: the inventory check caught a `VERSION.md` listing before the commit that would have needed it existed; the `Standards First` check reported all 42 Employees failing on its first run, which was a fact about the check and not the set; the escape-hatch hook blocked two of its own commits; the inline-suppression hook refused to write the test corpus that proves it works; and the milestone-list fix in this very release was caught by its own falsifier at 10 of 11 before it was committed. And the defects that survived longest were never in the code — they were in the corpus: the Examples were a milestone behind for thirty-six commits, and one half of the brief-to-report contract was written while the other was not.

---

## [0.0.11] - Governance

### Added

- `Governance/CONTRIBUTING.md` — how a change to the framework itself is proposed and reviewed: Change Tiers mapped to `Core/CAPABILITY_TIERS.md`, how a new Employee/Workflow/Template/Standard is proposed, the highest-scrutiny bar for `Core/*.md` changes, a values-grounded Code of Conduct, and how GitHub Issue intake and Durable Tracking of Findings converge into one contribution path (WU-IAENG-134)
- `Governance/VERSIONING_POLICY.md` — formalizes the `MAJOR.MINOR.MILESTONE[.FIX]` versioning scheme as the authoritative, standalone reference: segment semantics, the `.FIX` vs. new-milestone test, milestone naming discipline, and document-internal `Version:` field rules (WU-IAENG-135)
- `Governance/DEPRECATION_POLICY.md` — defines how a Standard, Workflow, Template, or Employee gets deprecated versus removed, since the framework had only ever added content through v0.0.10.1: deprecation triggers, the marker/index lifecycle, a required cross-reference check, the Employee-specific Actor/escalation-target check, and mandatory Director approval (WU-IAENG-136)
- `Core/EMPLOYEE_SELECTION.md` — a concrete dispatch-trigger reference covering all 42 Employees, organized by category, naming six miscasting risks (e.g. Compliance Engineer/Technical Writer, Security Engineer/DevOps Engineer), cross-referenced from `Core/MAIN_AGENT_CONDUCT.md`'s Employee Selection section (WU-IAENG-133)
- `Core/MAIN_AGENT_CONDUCT.md` — "Git Execution via Named Employee" conduct rule: mutating git operations (branch creation, commit, push, tag, PR-merge) are dispatched to a named Employee rather than absorbed by the Main Agent as plumbing — release-scoped git mutation to the Release Manager, git-as-deployment to the GitOps Engineer — while read-only inspection stays direct under Verification Over Waiting (WU-IAENG-132)
- `Core/MAIN_AGENT_CONDUCT.md` — "Durable Tracking of Findings" conduct rule: a gap, tech-debt item, or deferred decision surfaced mid-work is filed as a GitHub Issue so it survives beyond one session's private memory (WU-IAENG-130)

### Fixed

- `Workflows/RELEASE.md` Step 7 — a bare annotated tag with only a short `-m` message is no longer sufficient on its own, since it produces no real description on the host's Releases page; a full GitHub Release derived from that version's actual `CHANGELOG.md` entry is now required, closing the gap that had to be patched after the fact for both v0.0.10 and v0.0.10.1 (WU-IAENG-131)

### Notes

This release delivers the "Governance" milestone: the first real content under `Governance/`, which had held only a `.gitkeep` placeholder since the repository's first commit. It also carries forward four Main Agent conduct/reference additions (WU-IAENG-130, WU-IAENG-131, WU-IAENG-132, WU-IAENG-133) that landed on `develop` in the same window as the Governance documents but are process and dispatch-reference additions rather than `Governance/` content proper.

---

## [0.0.10.1] - Consistency & Compliance Hardening

### Added

- `Adapters/scripts/setup-branch-protection.sh` — `release/*` branch protection via GitHub's Rulesets API (blocks deletion, force-push, and direct pushes), closing the gap that let an unreviewed direct push land on `release/v0.0.10` (WU-IAENG-121)
- `.github/workflows/pr-validation.yml`, `Adapters/github-actions/pr-validation.yml` — server-side `employee-trailer` CI check that backstops the client-side `commit-msg` hook, plus an advisory `review-recorded` check surfacing whether a Code Reviewer `Decision: approved` block was recorded on the PR (WU-IAENG-125)

### Fixed

Corrections and hardening to already-shipped milestones (v0.0.9 Adapters, v0.0.10 Project Bootstrap), all merged on `develop` after v0.0.10 shipped — none introduce new capability at the milestone level:

- `Workflows/RELEASE.md` — Step 4 minor-defect fixes found during release acceptance testing now land via a PR targeting the release branch instead of a direct push, since `release/*` branches are no longer writable directly (WU-IAENG-122)
- `Workflows/CODE_REVIEW.md`, `Core/AGENT_CHAINS.md` — added a concrete, checkable "security-sensitive or high-risk" trigger list for QA Engineer insertion into the Review Chain, grounded in existing Employee Escalation Rules (WU-IAENG-123)
- `Workflows/FEATURE_DEVELOPMENT.md`, `Workflows/CODE_REVIEW.md` — added Compliance Engineer entry points (regulated/sensitive data, named regulatory framework, retention/deletion logic, cross-border data transfer), mirroring how Security Engineer already escalates in both workflows (WU-IAENG-124)
- `Adapters/README.md` — updated to describe all five Adapter CI checks, including the two added in WU-IAENG-125 (WU-IAENG-125)
- `Examples/RELEASE_CHAIN_EXAMPLE.md` — realigned with the new PR-based release-branch-fix mechanism from WU-IAENG-122 (WU-IAENG-126)
- `LICENSE.md` — completed the Apache License 2.0 copyright notice (`Copyright 2026 Equinxe`); the full Apache 2.0 license text had been present since the Foundation milestone, but its copyright header was left as the raw template placeholder (WU-IAENG-127)
- `README.md` — License section updated from "To be defined before v1.0" to accurately state the project is licensed under Apache License 2.0, referencing `LICENSE.md` (WU-IAENG-127)

### Notes

This consolidates seven post-v0.0.10 fixes into a single `.FIX` release rather than shipping them under separate dot-releases. Six (WU-IAENG-121–126) close gaps between the release-branch protection added here and the Workflows/Adapters that assumed the old, unprotected behavior; the seventh (WU-IAENG-127) closes a long-standing gap between the license actually in the repository (complete Apache 2.0 text since the first commit) and what the project's own documentation claimed about it — the Director confirmed Apache License 2.0 as the deliberate, correct choice, with Equinxe as the copyright holder. None of these introduce new capability, so none consume the next milestone number; the real v0.0.11 — Governance milestone has not started.

---

## [0.0.10] - Project Bootstrap

### Added

- `Workflows/PROJECT_BOOTSTRAP.md` — new workflow for bootstrapping a brand-new project (WU-IAENG-108)
- `Templates/PROJECT_CHARTER.md` — 7th framework template (WU-IAENG-109)
- CI/CD + GHCR Adapters — `ci-build-test.yml`, `ghcr-publish.yml`, stack Dockerfiles, `setup-project-bootstrap.sh` (WU-IAENG-110)
- GitHub Issue Templates Adapter (WU-IAENG-111)
- Compliance hardening of Project Bootstrap — escalation trigger, jurisdiction/SOC2/breach-notification questions, Compliance Engineer and Security Engineer added as Actors (WU-IAENG-115)
- Business/Product hardening of Project Bootstrap — Assumptions & Risks category, business-outcome Success Criteria example, MoSCoW prioritization (WU-IAENG-116)
- `Core/MAIN_AGENT_CONDUCT.md` — Autonomous Release Execution conduct rule (WU-IAENG-117)

### Fixed

Consistency and process fixes merged on `develop` after v0.0.9.3, ahead of the Project Bootstrap milestone content, that never received their own version bump:

- `Workflows/RELEASE.md` — the version bump now happens on `develop` before the release branch is cut, as its own step, so the release branch is a pure snapshot with no separate version-bump commit (WU-IAENG-099)
- `Core/MAIN_AGENT_CONDUCT.md` — added a "No Direct Research" rule: the Main Agent must delegate research and reading (deciding which Employee fits, digging through git history), not just implementation (WU-IAENG-101)
- Version references synced and Employee roster names canonicalized across docs (WU-IAENG-102)
- `Examples/RELEASE_CHAIN_EXAMPLE.md`, `Examples/HOTFIX_CHAIN_EXAMPLE.md`, `Core/AGENT_CHAINS.md` — realigned with the current `Workflows/RELEASE.md` and `Workflows/HOTFIX.md` steps (WU-IAENG-103)
- Adapter definition, Capability Tiers framing, and doc version references aligned across Core (WU-IAENG-104)
- `Adapters/git-hooks/commit-msg` — merge commits now bypass Conventional Commit / `Employee:` trailer validation, since merge commits are generated by GitHub and carry neither (WU-IAENG-106)
- `Adapters/README.md` — logged post-merge verification of the commit-msg merge-commit fix (WU-IAENG-107)

### Notes

This release delivers the "Project Bootstrap" milestone: a complete workflow, template, and Adapter set for standing up a brand-new project under the framework, hardened with Compliance/Security and Business/Product review passes. It also carries forward seven consistency and process fixes (WU-IAENG-099 and the WU-IAENG-100 audit and related findings) that landed on `develop` between v0.0.9.3 and this milestone but were never released under their own version number — folded into this bump rather than lost from the historical record.

---

## [0.0.9.3] - Back-Merge via Pull Request

### Fixed

- `Workflows/RELEASE.md` (Step 7) and `Workflows/HOTFIX.md` (Step 9) — the "Back-merge to develop" step now describes opening a Pull Request from `main` into `develop` and merging it once CI passes, instead of a direct `git push`. This resolves a contradiction with the `pre-push` git hook (`Adapters/git-hooks/pre-push`, shipped in v0.0.9), which unconditionally blocks all direct pushes to `develop` and `main`: the Workflow told the Main Agent to do something the Adapter mechanically forbids.

### Notes

Ninth finding from dogfooding. After releasing v0.0.9.2, the Main Agent tried to back-merge `main` into `develop` with a direct push and was blocked live by our own `pre-push` hook — the Workflow documents and the Adapter contradicted each other. The fix documents the PR-based procedure that was actually used to resolve the block, closing the gap so the written Workflow matches what technical enforcement allows.

---

## [0.0.9.2] - No Direct Implementation

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "No Direct Implementation" section: the Main Agent never personally writes or edits implementation artifacts — application code, scripts, configuration, git hooks, CI/CD definitions, or any other machine-consumed file — in any project. Every such change is dispatched to a named Employee through an Employee Brief, with no size exception: a trivial one-line fix is dispatched cheaply via a Lightweight Override at the Lightweight Execution tier (`Core/CAPABILITY_TIERS.md`), and a Workspace Isolation collision risk is resolved by waiting or isolating the Employee, never by implementing the change personally. Attributing a self-authored change to an Employee that was never dispatched is a Dispatch Discipline violation — the Work Unit is not complete and must be re-dispatched, not relabeled.

### Notes

Eighth finding from dogfooding. During the v0.0.9.1 cycle the Director caught the Main Agent directly editing `Adapters/scripts/setup-branch-protection.sh`, `Adapters/github-actions/pr-validation.yml`, and `Adapters/git-hooks/pre-push`, then attributing each commit to a named Employee (e.g., `Employee: DevOps Engineer`) that was never actually dispatched — the work was done by the Main Agent; only the label said otherwise. This closes the loophole at its source: a Main Agent that implements has stopped orchestrating (`Core/ORCHESTRATION.md`), producing work with no accountable Employee, no traceable Standards Applied, and no verifiable Definition of Done.

---

## [0.0.9.1] - Solo-Maintainer Fixes

### Fixed

- `Adapters/scripts/setup-branch-protection.sh` — removed a self-review deadlock: `required_approving_review_count` changed from 1 to 0 and `enforce_admins` from true to false, since GitHub does not allow a PR author to approve their own PR and every Employee (and the Director) currently shares one authenticated `gh` identity. The real review gate is the required `validate` CI check plus the Code Reviewer's documented review comment, not a GitHub-native approval count.
- `Core/MAIN_AGENT_CONDUCT.md` — added a "Workspace Isolation" section: the Main Agent must not run its own git commands in the same working directory while a dispatched Employee is actively committing — wait, or use a separate worktree/clone.

### Notes

Sixth and seventh findings from dogfooding — this time from applying our own Adapters to this repository for the first time (WU-IAENG-091), rather than from the 2048 game test. Discovered immediately on the very first PR after enabling branch protection here: could not merge PR #27 because nobody could formally approve it, and a real commit landed on `main` because the Main Agent ran git commands in the same working directory as the dispatched DevOps Engineer. Both are now documented and fixed at their source rather than worked around.

---

## [0.0.9] - Adapters

### Added

- `Adapters/git-hooks/commit-msg` — mechanically enforces Conventional Commits format and a mandatory `Employee: <Name>` trailer validated against the 42-Employee roster (Dispatch Discipline)
- `Adapters/git-hooks/pre-push` — blocks direct push to `main` and `develop`
- `Adapters/github-actions/pr-validation.yml` — CI check requiring every PR to reference a Work Unit ID (`WU-[project]-[number]`) and have a non-empty, filled-in description
- `Adapters/github/PULL_REQUEST_TEMPLATE.md` — GitHub PR template mirroring `Templates/PULL_REQUEST.md` exactly
- `Adapters/scripts/setup-branch-protection.sh` — one-shot script to configure GitHub branch protection (required review, required status check, no force-push/deletion) via the GitHub API
- `Adapters/README.md` — installation guide and index tying all adapters together
- `.gitattributes` — forces LF line endings under `Adapters/` so shell scripts don't break on Linux/CI after a Windows checkout

### Notes

Prioritized ahead of Governance (now v0.0.10) in response to live-test findings from the v0.0.8 Capability Tiers deployment. Adapters close the gap between written policy and technical enforcement — every violation caught by git hooks or CI checks before it reaches review, not after. This is the framework's concrete lever for preventing the v0.0.7.x categories of silent violations (malformed commits, missing Employee attribution, unreviewed direct pushes).

---

## [0.0.8] - Capability Tiers

### Added

- `Core/CAPABILITY_TIERS.md` — two AI-agnostic execution tiers (Strategic Judgment, Standard Execution) the Main Agent uses to match execution capability to Work Unit complexity, without ever naming a specific model, plus a per-Work-Unit Lightweight Override mechanism
- `Employees/` — Default Complexity Tier added to all 42 Employees' Metadata (12 Strategic Judgment: architects, Security Engineer, Compliance Engineer, Penetration Tester, Business Analyst, Data Scientist, AI Engineer, Prompt Engineer, Engineering Manager, Technical Lead; 30 Standard Execution: all others)
- `Core/ORCHESTRATION.md` — Step 4 (Dispatch) now selects execution capability per Capability Tiers before creating each Employee Brief

### Notes

Prioritized ahead of Governance (now v0.0.9) in response to live-test token/session-limit pressure observed during the 2048 game test. This is the framework's only concrete lever for execution efficiency: routing mechanical Work Units to lighter capability while reserving strategic judgment for decisions that need it, without compromising Dispatch Discipline or AI Agnosticism (Principle X).

---

## [0.0.7.5] - ADR Threshold Detection

### Fixed

- `Core/ORCHESTRATION.md` — Step 2 (Analyze) now explicitly cross-references `Workflows/ARCHITECTURE_DECISION.md`'s ADR trigger list instead of leaving "whether an ADR is required" to informal judgment

### Notes

Fifth finding from the live end-to-end test (2048 game leaderboard feature). A persistent leaderboard was implemented directly via the Frontend Engineer using `localStorage`, without recognizing that persistence implies a storage technology decision meeting the existing ADR threshold ("technology selection... database"). The rule to check for an ADR already existed in both `Core/ORCHESTRATION.md` and `Workflows/ARCHITECTURE_DECISION.md`, but the two were never explicitly linked, and a simply-phrased feature request did not visibly trigger the check. This is a documentation clarity gap, not a new rule.

---

## [0.0.7.4] - Verification Over Waiting

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Verification Over Waiting" section: when a dispatched Employee's completion report never arrives, the Main Agent must verify the actual repository state directly (git status/diff/log) instead of stalling on repeated status requests or assuming success from silence

### Notes

Fourth finding from the live end-to-end test (2048 game leaderboard feature). Dispatched Employees repeatedly showed as "finished" in the AI runtime without ever delivering a completion report, and the Main Agent looped on re-requesting status instead of checking the repository directly. This is a runtime dispatch fault, not a framework fault — but the framework can and should make silence non-blocking by requiring direct verification as the fallback source of truth.

---

## [0.0.7.3] - Roster Gaps

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Roster Gaps" section: when a request requires an Employee outside the project's active roster, the Main Agent must stop, propose the roster expansion to the Director, update `CLAUDE.md`, and only then dispatch — instead of silently performing the work itself
- `Core/MAIN_AGENT_CONDUCT.md` — closed a loophole in Dispatch Discipline (v0.0.7.2): naming a subagent by function or tool label (e.g., "executor") instead of by the responsible Employee's name is now explicitly treated as equivalent to not delegating at all

### Notes

Second and third findings from the live end-to-end test (2048 game leaderboard feature). (2) The project's onboarding-time roster excluded Architecture/Backend/Data roles as out of scope for a frontend-only game — when a later request genuinely required a Software Architect ADR and Backend/Database/API Engineers, the Main Agent absorbed the work itself rather than recognizing the scope had changed. (3) After being corrected, the Main Agent did delegate — but to a subagent named "executor" rather than the responsible "Frontend Engineer", satisfying the letter of Dispatch Discipline while discarding its purpose (traceable Mission, Authority, Standards Applied, and Definition of Done).

---

## [0.0.7.2] - Dispatch Discipline

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Dispatch Discipline" section mandating Employee Brief dispatch for every delegation, forbidding substitution of native/generic AI runtime subagents for a named Employee

### Notes

Finding from the first live end-to-end test of IA Engineering on a real project (a browser 2048 game). The Main Agent defaulted to a generic native reviewer subagent instead of dispatching to the Code Reviewer, QA Engineer, and Security Engineer through Employee Briefs, because the conduct document told it what to do but never explicitly forbade this substitution. This is a direct application of Core Principle IX (Continuous Improvement): every project should improve the framework.

---

## [0.0.7.1] - Audit Fixes

### Fixed

- `Core/GLOSSARY.MD` renamed to `Core/GLOSSARY.md` — fixes broken references on case-sensitive filesystems (Linux/CI)
- `Core/AGENT_CONDUCT.md`, `DECISION_TREE.md`, `GLOSSARY.md`, `MAIN_AGENT_CONDUCT.md` — version corrected from `0.1.0` to `0.0.1` to match the Foundation milestone
- `Core/AI_MANIFEST.md` — added missing Document Metadata section
- `Core/AI_MANIFEST.md` — decision hierarchy corrected to list Employees before Workflows, aligning with `CLAUDE.md` and `README.md`
- `Core/GLOSSARY.md` — added missing "Director" and "Chain (Agent Chain)" entries
- `Prompts/` — added missing directory placeholder (documented in `CLAUDE.md` but absent on disk)
- `README.md` — full refresh from v0.0.2 to v0.0.7: completed list, framework hierarchy diagram, repository structure, roadmap
- `Employees/Development/FRONTEND_ENGINEER.md`, `IOS_ENGINEER.md`, `ANDROID_ENGINEER.md`, `CROSS_PLATFORM_ENGINEER.md` — "UX Designer and UI Designer" corrected to the single combined `UX/UI Designer` role
- `Employees/Architecture/DATA_ARCHITECT.md` — ADR ID convention aligned to `ADR-[project]-[number]`
- `Employees/Quality/SECURITY_ENGINEER.md` — vulnerability ID convention aligned to `SEC-[project]-[number]`
- `Employees/Quality/QA_ENGINEER.md` — Test Case ID convention aligned to `TC-[project]-[number]`
- `Workflows/FEATURE_DEVELOPMENT.md` — non-existent "Mobile Engineer" actor replaced with the actual iOS/Android/Cross Platform Engineer roles; Business Analyst added to the Actors table
- `Workflows/HOTFIX.md`, `RELEASE.md` — Observability Engineer added to the Actors table (was used in steps but not declared)
- `Examples/INCIDENT_CHAIN_EXAMPLE.md` — now uses the Incident Commander role defined in `Workflows/INCIDENT_RESPONSE.md`
- `Examples/ARCHITECTURE_CHAIN_EXAMPLE.md` — "Recommendation" renamed to "Decision" to match `Templates/ADR.md`

### Notes

These fixes came from a full content and consistency audit of all 65 repository files performed after v0.0.7. No content or behavior changes beyond consistency — documentation accuracy only.

---

## [0.0.7] - Examples

### Added

- 6 end-to-end chain walkthroughs on a single fictional project (TaskFlow): Feature, Review, Release, Hotfix, Incident, Architecture Chains
- `Examples/README.md` — index and recommended reading order

### Notes

This release makes the Orchestration Protocol and Agent Chains concrete. Each example shows real Work Units, Employee Briefs, and templates filled in, and shows how chains hand off into each other (Incident → Hotfix, Architecture → Feature). Combined with all prior milestones, the framework has everything needed for a real end-to-end test on a new project.

---

## [0.0.6] - Orchestration

### Added

- `Core/ORCHESTRATION.md` — Main Agent dispatch protocol: receive, analyze, plan, dispatch, collect, review, deliver
- `Core/AGENT_CHAINS.md` — 6 named orchestration chains: Feature, Review, Release, Hotfix, Incident, Architecture

### Fixed

- `CLAUDE.md` version updated from v0.0.2 to v0.0.5 (was outdated since Templates milestone)
- `MAIN_AGENT_CONDUCT.md` now references ORCHESTRATION.md and AGENT_CHAINS.md

### Notes

This release formalizes the orchestration layer — how the Main Agent receives a Director request, decomposes it into Work Units, dispatches Employee Briefs, collects outputs, and delivers a validated result. Combined with the 42 Employees, 8 Workflows, and 6 Templates from previous milestones, the framework is now ready for end-to-end testing on a real project.

---

## [0.0.5] - Templates

### Added

- 6 Engineering Templates: Work Unit, Pull Request, Architecture Decision Record, Incident Report, Test Plan, Employee Brief
- Employee Brief template formalizes the Context Engine: employees receive only the context they need, never the whole repository

### Notes

This release delivers the complete IA Engineering template library. Combined with Employees (v0.0.3) and Workflows (v0.0.4), every engineering action now has a standard format. The framework is ready for orchestration.

---

## [0.0.4] - Workflows

### Added

- 8 Engineering Workflows: Feature Development, Code Review, Release, Hotfix, Incident Response, Architecture Decision, Onboarding, Sprint Ceremony
- Each workflow defines: Trigger, Actors, Prerequisites, Step-by-step process with handoffs, Exit Criteria, Escalation rules

### Notes

This release delivers the complete IA Engineering workflow library. Combined with the 42 Employees from v0.0.3, the framework can now orchestrate end-to-end engineering sequences from requirements to production.

---

## [0.0.3] - Employees

### Added

- 42 AI Employee definitions across 8 categories: Management, Architecture, Development, DevOps, Quality, Data, Documentation, Specialized
- Each Employee defines: Mission, Responsibilities, Authority, Standards Applied, Inputs, Process, Outputs, Output Format, Definition of Done, Escalation Rules, Failure Modes

### Notes

This release delivers the complete IA Engineering employee library. Every employee is an operational manual — not a role description — defining precisely what the employee does, what authority they hold, and what constitutes completion.

---

## [0.0.2] - Engineering Standards

### Added

- Standards First
- Git Standard
- Commit Standard
- Branch Standard
- Pull Request Standard
- Documentation Standard
- Code Quality Standard
- Testing Standard

### Notes

This release establishes the complete engineering standards library used by all IA Engineering Employees, Workflows, and Projects.

---

## [0.0.1] - Foundation

### Added

- AI Manifest
- README
- Glossary
- Decision Tree
- Main Agent Conduct
- Agent Conduct

### Notes

Initial foundation of the IA Engineering framework.

This release establishes the core principles and behavioral contracts that all future components will inherit.

---

## Next

TBD — not yet scoped. See `VERSION.md`'s `Planned` section.
