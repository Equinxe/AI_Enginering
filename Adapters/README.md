# Adapters

---

# Purpose

Every other part of IA Engineering is written policy: documents that describe what the Main Agent and Employees must do, and trust them to read and follow it. The live end-to-end test (see `Examples/`, and the `v0.0.7.x` fix series in `CHANGELOG.md`) showed this works, but every violation was caught *after* it happened — by a human or a review cycle — never *before*, by the tooling itself.

Adapters close that gap. They are concrete, installable integrations for a specific version control host and CI platform (currently: GitHub) that turn a subset of IA Engineering's rules from "written and reviewed" into "technically enforced." A rule an Adapter enforces cannot be silently skipped — the commit is rejected, the push is blocked, or the PR check fails.

Adapters are AI-agnostic in the sense that matters: they check work by any Employee, running under any AI runtime. They are not model-agnostic to a *tool* — a GitHub Adapter assumes GitHub. A project using GitLab or Azure DevOps needs an equivalent Adapter for that platform (not yet built — see `Planned` below).

---

# What Each Adapter Enforces

| Adapter | Rule enforced | Source document |
|---|---|---|
| `git-hooks/commit-msg` | Conventional Commits subject line; mandatory `Employee: <Name>` trailer validated against `Registry/employees.yml` plus the project roster of Domain Employees (`.ia-engineering/Registry/employees.yml`, `Templates/DOMAIN_EMPLOYEE.md`) when one exists. Fails closed when the roster cannot be resolved, rather than passing while validating against nothing | `Standards/COMMIT_STANDARD.md` (Trailers), `Core/MAIN_AGENT_CONDUCT.md` (Dispatch Discipline), `Registry/README.md` |
| `git-hooks/pre-push` | No direct push to `main` or `develop` | `Standards/BRANCH_STANDARD.md` |
| `git-hooks/pre-commit` | No real data, key material, `.env` file, operational state file, or well-known secret shape reaches a commit. Client-side layer only — bypassable by `--no-verify` or an uninstalled hook, which is why `data-policy.yml` runs the same scanner server-side. Fails closed when the scanner cannot be resolved | `Standards/DATA_PROTECTION_STANDARD.md`, `Templates/SESSION_STATE.md` |
| `scripts/data-policy-scan.sh` | The one pattern list both data-protection layers call, in three modes: `--staged` (the hook), `--tree` (what is present), `--history` (what a branch *introduced*, via `git rev-list --objects` — a file added and deleted again is absent from the tree and present in every clone). Exemptions are named: the anchored `SYNTHETIC_` basename prefix and a committed `.ia-engineering/data-policy.allow`. Matched secret values are never printed | `Standards/DATA_PROTECTION_STANDARD.md` |
| `github-actions/data-policy.yml` | **Data Policy** — blocking check on every PR to `main`, `develop`, `release/*` and every push to `main`/`develop`: scans the tree at HEAD and the history the change introduces, with the same scanner as the hook | `Standards/DATA_PROTECTION_STANDARD.md` |
| `github-actions/pr-validation.yml` | Eight checks on every PR targeting `main`, `develop`, or `release/*`: (1) **PR Compliance** — references a Work Unit ID and has a real, filled-in description; (2) **Work Unit Exists** — each commit's `Work Unit:` trailer resolves against `Registry/work-units.yml`, read from the trailer rather than from the PR description, so a reworded description cannot change the claim; (3) **Employee Trailer** — server-side re-validation that every non-merge commit carries a valid `Employee: <Name>` trailer from `Registry/employees.yml`, a backstop for the client-side `commit-msg` hook (which `--no-verify` or an uninstalled hook can skip); (4) **Shellcheck Adapters** — the git hooks/scripts we ship are valid, warning-free shell; (5) **Validate Workflow YAML** — every workflow file at minimum parses; (6) **Hook Tests** — the runtime hooks still refuse what the Git Standard forbids and still permit what it does not, checked by running them against a case corpus; (7) **PR Size** — at most 1,500 changed lines outside files marked `linguist-generated`, overridable only by the Director's `size/approved` label; (8) **Review Recorded (advisory)** — warning-only surfacing of whether a Code Reviewer `Decision: approved` block was recorded on the PR (does not block merge); with the repository variable `IAENG_REVIEW_BOT_LOGIN` set it counts only that login's block, which is the independence it lacked | `Templates/WORK_UNIT.md`, `Templates/PULL_REQUEST.md`, `Standards/CODE_QUALITY_STANDARD.md`, `Core/MAIN_AGENT_CONDUCT.md`, `Workflows/CODE_REVIEW.md`, `Registry/README.md` |
| `github/PULL_REQUEST_TEMPLATE.md` | Every new PR starts from the mandatory template — mirrors `Templates/PULL_REQUEST.md` exactly | `Templates/PULL_REQUEST.md` |
| `github-actions/framework-validation.yml` | Runs `scripts/validate-framework.sh` as a blocking check on every PR and on every push to `main`/`develop`, plus a second step asserting that regenerating `Registry/employees.yml` is a no-op | `Governance/CONTRIBUTING.md` (§3 cross-reference check), `Governance/DEPRECATION_POLICY.md`, `Registry/README.md` |
| `scripts/validate-framework.sh` | The cross-reference check both Governance documents require as a Definition of Done item, executed rather than remembered: Registry-to-definition agreement in both directions, roster counts quoted in prose, tier-table consistency, dispatch-trigger coverage, mandatory document sections, metadata fields, referenced-path resolution, Adapter/installed-copy parity, executable file modes on every shipped script, and unresolved work markers in shipped code | `Governance/CONTRIBUTING.md`, `Governance/DEPRECATION_POLICY.md`, `Governance/VERSIONING_POLICY.md`, `Core/CAPABILITY_TIERS.md`, `Core/EMPLOYEE_SELECTION.md` |
| `scripts/install.sh` | Installs every host-agnostic Adapter in one idempotent command, wires hooks through `core.hooksPath` so they cannot fork from the framework version, appends the data-protection `.gitignore` rules and creates the local data directory, and verifies the installed hooks actually enforce — `commit-msg` rejects an invalid Employee trailer, `pre-commit` refuses a staged document (probed against a throwaway index) | `Workflows/ONBOARDING.md` (Step 5), `Core/MAIN_AGENT_CONDUCT.md` (Verification Over Waiting) |
| `ai-runtimes/generate-agents.sh` | Turns the 42 Employee definitions — plus the project's own Domain Employees, from the project roster — into agents an AI runtime can dispatch to, so reaching for the right Employee is the path of least resistance rather than the disciplined exception. Written into the **project's** agent directory, not the framework's, since that is the only one a runtime reads. Execution capability derived from each Employee's Default Complexity Tier; the tier-to-model mapping lives in the Adapter, never in `Core/` | `Employees/`, `Core/CAPABILITY_TIERS.md`, `Core/AGENT_CONDUCT.md`, `Core/MAIN_AGENT_CONDUCT.md` (Dispatch Discipline) |
| `ai-runtimes/claude-code/hooks/tests/` | The one behaviour suite in the repository: 83 checks that the hooks refuse what the Git Standard forbids and permit what it does not, run by the `Hook Tests` CI job. Cases are `.tsv` data files, so adding one is adding a line | `Standards/GIT_STANDARD.md`, `Standards/CODE_QUALITY_STANDARD.md` |
| `ai-runtimes/claude-code/hooks/` | For the Claude Code runtime, refuses before rather than rejecting after: read-first context at session start; no escape hatch in a shell command (`Standards/GIT_STANDARD.md` table, quoted text and heredocs stripped first); no inline lint/type/test suppression written into code (documentation exempt by name); lint on every written file; no session end with unexplained uncommitted work. Fail closed, no disabling switch. Installed into the committed `.claude/settings.json` by `install-hooks.sh` | `Core/AGENT_CONDUCT.md` (Read First, Reporting Contract), `Standards/GIT_STANDARD.md` (Escape Hatches), `Standards/CODE_QUALITY_STANDARD.md` (No Inline Suppression) |
| `ai-runtimes/claude-code/review-bot.yml` | An independent Code Reviewer under the Actions identity — the second account the `Review Recorded` check never had. With `IAENG_REVIEW_BOT_LOGIN` set, `Review Recorded` counts only that login's decision. Opt-in: needs an API key and a Director decision | `Workflows/CODE_REVIEW.md`, `Employees/Specialized/CODE_REVIEWER.md` |
| `ai-runtimes/omc/README.md` | Nothing — a transport mapping of framework concepts onto the oh-my-claudecode orchestration layer, stating what maps, what does not, and where the framework binds regardless | `Core/AI_MANIFEST.md` (Principle X), `Workflows/AUTONOMOUS_DELIVERY.md` |
| `scripts/release.sh` | The mechanical parts of `Workflows/RELEASE.md`: Step 1 readiness as a report that exits non-zero, and Step 7 tag plus GitHub Release built from the version's `CHANGELOG.md` section. Refuses to tag unless the release is already merged to `main`, and never approves or merges — Step 5 is the Director's | `Workflows/RELEASE.md`, `Core/MAIN_AGENT_CONDUCT.md` (Autonomous Release Execution), `Governance/VERSIONING_POLICY.md` |
| `scripts/check-work-units.sh` | Every non-merge commit in a range carries exactly one `Work Unit:` line at column 0, resolving against `Registry/work-units.yml`. A registry that parses to zero IDs fails as a *parsing* fault rather than reporting every commit unregistered — universal failure is a fact about the check, not the set | `Templates/WORK_UNIT.md`, `Standards/COMMIT_STANDARD.md` |
| `scripts/check-employee-trailers.sh` | The server-side backstop for the `commit-msg` hook, which `--no-verify` or a missing install can skip. Unions the project roster so Domain Employees resolve; a `IAENG_PROJECT_ROSTER` path that does not exist is a failure, never a silent narrowing to the framework roster alone | `Core/MAIN_AGENT_CONDUCT.md` (Dispatch Discipline), `Templates/DOMAIN_EMPLOYEE.md` |
| `scripts/check-pr-size.sh` | Additions plus deletions outside `linguist-generated` and binary files, against the **merge base** rather than the base tip. Tells the two causes of an empty diff apart by the commits: no commits is broken refs and fails, all-merges is a back-merge and passes, a non-merge commit that changed nothing still fails. `IAENG_PR_LIMIT`, and the Director override via `IAENG_PR_LABELS` containing `size/approved` | `Standards/PULL_REQUEST_STANDARD.md` (Reviewability) |
| `scripts/check-review-recorded.sh` | Advisory. Reads a directory of comment files — one per comment, `author:` on line 1 so a body cannot declare its own author — and looks for a `Decision: approved` block. Owns the author filter and the distinction between *no decision recorded* and *sources could not be read*; the host only fetches | `Workflows/CODE_REVIEW.md`, `Employees/Specialized/CODE_REVIEWER.md` |
| `scripts/hosts/github/fetch-review-comments.sh` | The GitHub half of the above, and the first concrete implementation of the host seam. Reads the three places GitHub keeps a PR’s prose (timeline, review bodies, inline comments) and writes one file per comment. **Fetches only** — no filtering, no matching. Exits `3` on a partial read so the check can say *nothing established either way* | — |
| `scripts/tests/run.sh` | The behaviour suite for the five scripts above, run by the required **Script Tests** check. Every case builds a real git repository and runs the real script; nothing is mocked. It exists because the same logic, while embedded in a workflow file, could only be tested by deploying it — which is how `PR Size` came to deadlock a release | `Adapters/README.md` (The Check Convention) |
| `scripts/setup-branch-protection.sh` | `main`, `develop`, **and** `release/*` require all ten blocking status checks (PR Compliance, Work Unit Exists, Employee Trailer, Shellcheck Adapters, Validate Workflow YAML, Hook Tests, Script Tests, PR Size, Framework Validation, Data Policy) before merge; no force-push, no branch deletion. **Review Recorded** stays advisory and is deliberately not required — it matches comment text, which can be satisfied by pasting the block, so requiring it would buy false confidence; promoting it remains a Director decision. Formal approving review count is 0 by design (see the script's own comments — a single shared `gh` identity across all Employees and the Director makes GitHub-native self-approval impossible) | `Standards/BRANCH_STANDARD.md`, `Workflows/CODE_REVIEW.md`, `Workflows/RELEASE.md` |

---

# Verification Log

- **2026-07-23** — The `git-hooks/commit-msg` merge-commit exception (WU-IAENG-106, PR #40) was merged into `develop` via a Director admin bypass, with no CI run ever firing against it. WU-IAENG-107 added this entry specifically to force a real PR and CI run against current `develop`, so `Shellcheck Adapters` could validate the change post-hoc. See that PR's `Shellcheck Adapters` check result for the outcome.

---

# Installation

Run from the root of a project that has imported IA Engineering as a Git submodule at `ia-engineering/` (see `Workflows/ONBOARDING.md`).

```bash
# Everything host-agnostic: git hooks, PR-validation and framework-validation
# CI, the PR template, the issue templates, and the .gitattributes LF rules.
# Idempotent — safe to re-run. Add --dry-run to see the plan first.
./ia-engineering/Adapters/scripts/install.sh

# Branch protection (requires GitHub CLI, authenticated — run once per repo,
# review the script first, it mutates shared settings)
./ia-engineering/Adapters/scripts/setup-branch-protection.sh

# Stack CI + container publishing, once Workflows/PROJECT_BOOTSTRAP.md Phase B
# has decided the stack (node | web | python | go | jvm | dotnet | php | generic)
./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh node
```

`install.sh` replaced the six-command `cp`/`chmod` checklist this section used to spell out. A multi-step manual procedure that must be repeated in every clone is a procedure that gets skipped, and a skipped hook installation is silent — commits land with no Employee attribution and nothing complains until a server-side check catches it later, or nobody does.

**Hooks are configured through `core.hooksPath`, not copied into `.git/hooks`.** Copying produces a second, forkable version of each hook, frozen at whichever framework version was current when the copy was made: a project that installed hooks at v0.0.9 keeps validating against a v0.0.9 roster while its submodule moves on, and nothing reports the mismatch. Pointing `core.hooksPath` at the framework's own `Adapters/git-hooks` means the hook in force is always the hook in the imported framework version.

This does not make hooks travel with a clone — nothing can. Git deliberately never transmits hooks or local config, because a repository that could install executables on clone would be a remote-code-execution vector. Every clone still runs `install.sh` once; the difference is that it is one command that cannot be half-done instead of six that can.

Because `core.hooksPath` makes git ignore `.git/hooks` entirely, `install.sh` checks that directory for pre-existing project hooks first and warns rather than shadowing them silently.

This extends `Workflows/ONBOARDING.md` Step 5 ("Initialize git workflow") — the manual checklist there becomes a scripted setup once these Adapters are installed.

---

# The Check Convention

Every check in `scripts/validate-framework.sh`, every script in `scripts/`, and every job in `github-actions/` follows four rules. They are stated in the validator's header too, but they govern all Adapter code:

1. **An unevaluated condition is a failure, not a pass.** If a check could not run — missing input, moved directory, a pattern that matched nothing — it says so. "Nothing objected" is not "everything passed".
2. **Exceptions are named allow-lists, never fall-throughs.** Name the exempt thing, never express the exemption as a property of absence itself, because that quietly exempts everything else that goes missing later.
3. **Every set-iterating check reports its denominator.** Carry a count, fail at zero, print the count on the passing line. A verdict drawn from an empty set is indistinguishable from one drawn from a complete set.
4. **A claim about how a mechanism behaves is a testable claim** — what it selects, what it accepts, what it costs, which direction it fails in. Write the claim with the test that establishes it, or do not write it. When the mechanism chooses among alternatives, enumerate the alternatives *before* testing: two of three agreeing is not a result, and the case worth running is the one that would show the claim false.

A **caller** that discards a check's exit status breaks rule 1 as surely as a check that never ran.

Rules 1 to 3 constrain code; rule 4 constrains the prose that describes code — comments, Standards text, commit bodies — which is why it cannot be mechanised the way the others were. Its evidence is three conclusions reversed in a single review, each one a confirmed test that stopped short of the falsifying case: `tail -1` was tested at both ends but never on a message carrying claims at both ends, and was a live bypass; the trailer layouts were measured contiguous and renamed but not separated, and separated — the incumbent — was the only one that worked, on 28 of 30 commits; and "this fails safe in the harmless direction" was reasoned about rather than run, and was a false pass on a release gate.

The rules are written down because the Automation milestone found eleven checks that reported success without evaluating anything. None was found by reading the diff — three by this repository's own CI, six by code review, two by an audit once the pattern was named — and **four were introduced by the fixes to earlier instances of the same defect**. A defect class that reproduces inside its own remediation is not a set of oversights; it is the default reasserting itself, because writing a pass is the path of least resistance whenever a condition turns out not to apply. Fixing the twelfth instance does not make the thirteenth less likely. Stating the rule does.

---

# Verifying an Installation

```bash
./ia-engineering/Adapters/scripts/validate-framework.sh
```

`install.sh` ends by running the installed `commit-msg` hook against two probe messages — one valid, one carrying the tool label `executor` — and reports a problem if the hook accepts what it should reject. This is `Core/MAIN_AGENT_CONDUCT.md`'s Verification Over Waiting applied to installation: an installer that prints "done" without checking anything has the same defect as a dispatch report nobody verified.

`validate-framework.sh` then checks the framework itself, including whether this repository's installed copies of these Adapters still match what it ships.

---

# What Adapters Do Not Replace

Adapters catch mechanical violations: wrong commit format, missing Employee attribution, direct push to a protected branch, an unreferenced or empty PR. They do not replace:

- The Code Reviewer's judgment on logic, security, and quality (`Workflows/CODE_REVIEW.md`).
- The Main Agent's responsibility to select the right Employee and Chain (`Core/ORCHESTRATION.md`, `Core/AGENT_CHAINS.md`).
- The Director's approval gates (architecture, release, business decisions).

A passing Adapter check means the work is correctly *shaped*. It says nothing about whether the work is *right*.

---

# Planned

- GitLab CI equivalent
- Azure DevOps equivalent
- ~~`ai-runtimes/generate-agents.sh` reading a project's roster, so Domain Employees are generated as dispatchable runtime agents alongside the framework's.~~ **Delivered** in WU-IAENG-189 as `--project` and `--roster`, with the project roster auto-detected at `.ia-engineering/Registry/employees.yml`. The same Work Unit fixed a defect the feature exposed: run from a consumer project, the generator wrote all 42 agents *inside the submodule*, at a path no runtime reads, and reported success.
- ~~A Work Unit ID validator that checks the referenced ID actually exists (currently only checks the format).~~ **Delivered** in WU-IAENG-146 as `Registry/work-units.yml` plus the `Work Unit Exists` CI job, which resolves every referenced ID instead of matching a regex.
- ~~A single shared Employee-roster source file that both `git-hooks/commit-msg` and the `Employee Trailer` job in `github-actions/pr-validation.yml` read.~~ **Delivered** in WU-IAENG-137/138 as `Registry/employees.yml`. The real scope turned out to be six duplicated locations, not two — the two bash arrays plus this repository's installed copy of the Adapter, `VERSION.md`'s count and named list, `Core/CAPABILITY_TIERS.md`'s tier table, and `Core/EMPLOYEE_SELECTION.md`'s per-Employee triggers. `scripts/validate-framework.sh` now fails the build when any of them drifts from the Registry.

---

# Metadata

Owner: IA Engineering

Version: 0.0.9

Status: Draft

Category: Adapter — GitHub

Severity: Recommended
