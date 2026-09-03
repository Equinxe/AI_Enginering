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
| `git-hooks/commit-msg` | Conventional Commits subject line; mandatory `Employee: <Name>` trailer validated against `Registry/employees.yml`. Fails closed when the roster cannot be resolved, rather than passing while validating against nothing | `Standards/COMMIT_STANDARD.md`, `Core/MAIN_AGENT_CONDUCT.md` (Dispatch Discipline), `Registry/README.md` |
| `git-hooks/pre-push` | No direct push to `main` or `develop` | `Standards/BRANCH_STANDARD.md` |
| `github-actions/pr-validation.yml` | Six checks on every PR targeting `main`, `develop`, or `release/*`: (1) **PR Compliance** — references a Work Unit ID and has a real, filled-in description; (2) **Work Unit Exists** — the referenced ID resolves against `Registry/work-units.yml` rather than merely matching a format regex; (3) **Employee Trailer** — server-side re-validation that every non-merge commit carries a valid `Employee: <Name>` trailer from `Registry/employees.yml`, a backstop for the client-side `commit-msg` hook (which `--no-verify` or an uninstalled hook can skip); (4) **Shellcheck Adapters** — the git hooks/scripts we ship are valid, warning-free shell; (5) **Validate Workflow YAML** — every workflow file at minimum parses; (6) **Review Recorded (advisory)** — warning-only surfacing of whether a Code Reviewer `Decision: approved` block was recorded on the PR (does not block merge) | `Templates/WORK_UNIT.md`, `Templates/PULL_REQUEST.md`, `Standards/CODE_QUALITY_STANDARD.md`, `Core/MAIN_AGENT_CONDUCT.md`, `Workflows/CODE_REVIEW.md`, `Registry/README.md` |
| `github/PULL_REQUEST_TEMPLATE.md` | Every new PR starts from the mandatory template — mirrors `Templates/PULL_REQUEST.md` exactly | `Templates/PULL_REQUEST.md` |
| `github-actions/framework-validation.yml` | Runs `scripts/validate-framework.sh` as a blocking check on every PR and on every push to `main`/`develop`, plus a second step asserting that regenerating `Registry/employees.yml` is a no-op | `Governance/CONTRIBUTING.md` (§3 cross-reference check), `Governance/DEPRECATION_POLICY.md`, `Registry/README.md` |
| `scripts/validate-framework.sh` | The cross-reference check both Governance documents require as a Definition of Done item, executed rather than remembered: Registry-to-definition agreement in both directions, roster counts quoted in prose, tier-table consistency, dispatch-trigger coverage, mandatory document sections, metadata fields, referenced-path resolution, Adapter/installed-copy parity, and unresolved work markers in shipped code | `Governance/CONTRIBUTING.md`, `Governance/DEPRECATION_POLICY.md`, `Governance/VERSIONING_POLICY.md`, `Core/CAPABILITY_TIERS.md`, `Core/EMPLOYEE_SELECTION.md` |
| `scripts/install.sh` | Installs every host-agnostic Adapter in one idempotent command, wires hooks through `core.hooksPath` so they cannot fork from the framework version, and verifies the installed hook actually rejects an invalid Employee trailer | `Workflows/ONBOARDING.md` (Step 5), `Core/MAIN_AGENT_CONDUCT.md` (Verification Over Waiting) |
| `scripts/release.sh` | The mechanical parts of `Workflows/RELEASE.md`: Step 1 readiness as a report that exits non-zero, and Step 7 tag plus GitHub Release built from the version's `CHANGELOG.md` section. Refuses to tag unless the release is already merged to `main`, and never approves or merges — Step 5 is the Director's | `Workflows/RELEASE.md`, `Core/MAIN_AGENT_CONDUCT.md` (Autonomous Release Execution), `Governance/VERSIONING_POLICY.md` |
| `scripts/setup-branch-protection.sh` | `main`, `develop`, **and** `release/*` require all six blocking status checks (PR Compliance, Work Unit Exists, Employee Trailer, Shellcheck Adapters, Validate Workflow YAML, Framework Validation) before merge; no force-push, no branch deletion. **Review Recorded** stays advisory and is deliberately not required — it matches comment text, which can be satisfied by pasting the block, so requiring it would buy false confidence; promoting it remains a Director decision. Formal approving review count is 0 by design (see the script's own comments — a single shared `gh` identity across all Employees and the Director makes GitHub-native self-approval impossible) | `Standards/BRANCH_STANDARD.md`, `Workflows/CODE_REVIEW.md`, `Workflows/RELEASE.md` |

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
# has decided the stack (node | python | go | jvm | generic)
./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh node
```

`install.sh` replaced the six-command `cp`/`chmod` checklist this section used to spell out. A multi-step manual procedure that must be repeated in every clone is a procedure that gets skipped, and a skipped hook installation is silent — commits land with no Employee attribution and nothing complains until a server-side check catches it later, or nobody does.

**Hooks are configured through `core.hooksPath`, not copied into `.git/hooks`.** Copying produces a second, forkable version of each hook, frozen at whichever framework version was current when the copy was made: a project that installed hooks at v0.0.9 keeps validating against a v0.0.9 roster while its submodule moves on, and nothing reports the mismatch. Pointing `core.hooksPath` at the framework's own `Adapters/git-hooks` means the hook in force is always the hook in the imported framework version.

This does not make hooks travel with a clone — nothing can. Git deliberately never transmits hooks or local config, because a repository that could install executables on clone would be a remote-code-execution vector. Every clone still runs `install.sh` once; the difference is that it is one command that cannot be half-done instead of six that can.

Because `core.hooksPath` makes git ignore `.git/hooks` entirely, `install.sh` checks that directory for pre-existing project hooks first and warns rather than shadowing them silently.

This extends `Workflows/ONBOARDING.md` Step 5 ("Initialize git workflow") — the manual checklist there becomes a scripted setup once these Adapters are installed.

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
- ~~A Work Unit ID validator that checks the referenced ID actually exists (currently only checks the format).~~ **Delivered** in WU-IAENG-146 as `Registry/work-units.yml` plus the `Work Unit Exists` CI job, which resolves every referenced ID instead of matching a regex.
- ~~A single shared Employee-roster source file that both `git-hooks/commit-msg` and the `Employee Trailer` job in `github-actions/pr-validation.yml` read.~~ **Delivered** in WU-IAENG-137/138 as `Registry/employees.yml`. The real scope turned out to be six duplicated locations, not two — the two bash arrays plus this repository's installed copy of the Adapter, `VERSION.md`'s count and named list, `Core/CAPABILITY_TIERS.md`'s tier table, and `Core/EMPLOYEE_SELECTION.md`'s per-Employee triggers. `scripts/validate-framework.sh` now fails the build when any of them drifts from the Registry.

---

# Metadata

Owner: IA Engineering

Version: 0.0.9

Status: Draft

Category: Adapter — GitHub

Severity: Recommended
