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
| `git-hooks/commit-msg` | Conventional Commits subject line; mandatory `Employee: <Name>` trailer validated against the 42-Employee roster | `Standards/COMMIT_STANDARD.md`, `Core/MAIN_AGENT_CONDUCT.md` (Dispatch Discipline) |
| `git-hooks/pre-push` | No direct push to `main` or `develop` | `Standards/BRANCH_STANDARD.md` |
| `github-actions/pr-validation.yml` | Five checks on every PR targeting `main` or `develop`: (1) **PR Compliance** — references a Work Unit ID and has a real, filled-in description; (2) **Employee Trailer** — server-side re-validation that every non-merge commit in the PR carries a valid `Employee: <Name>` trailer from the 42-Employee roster, a backstop for the client-side `commit-msg` hook (which `--no-verify` or an uninstalled hook can skip); (3) **Shellcheck Adapters** — the git hooks/scripts we ship are valid, warning-free shell; (4) **Validate Workflow YAML** — every workflow file at minimum parses; (5) **Review Recorded (advisory)** — warning-only surfacing of whether a Code Reviewer `Decision: approved` block was recorded on the PR (does not block merge) | `Templates/WORK_UNIT.md`, `Templates/PULL_REQUEST.md`, `Standards/CODE_QUALITY_STANDARD.md`, `Core/MAIN_AGENT_CONDUCT.md`, `Workflows/CODE_REVIEW.md` |
| `github/PULL_REQUEST_TEMPLATE.md` | Every new PR starts from the mandatory template — mirrors `Templates/PULL_REQUEST.md` exactly | `Templates/PULL_REQUEST.md` |
| `scripts/setup-branch-protection.sh` | `main`/`develop` require the original three status checks above (PR Compliance, Shellcheck Adapters, Validate Workflow YAML) before merge; no force-push, no branch deletion. The newer **Employee Trailer** check is a candidate for the required set and **Review Recorded** is advisory-only — whether either is added to `required_status_checks.contexts` is a pending Director/Main Agent decision, tracked separately from this file. Formal approving review count is 0 by design (see the script's own comments — a single shared `gh` identity across all Employees and the Director makes GitHub-native self-approval impossible) | `Standards/BRANCH_STANDARD.md`, `Workflows/CODE_REVIEW.md` |

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
- A Work Unit ID validator that checks the referenced ID actually exists (currently only checks the format)
- A single shared Employee-roster source file that both `git-hooks/commit-msg` and the `Employee Trailer` job in `github-actions/pr-validation.yml` read, instead of the 42-name array being duplicated in both. Duplication is an accepted tradeoff today (the two lists must be kept in sync by hand); extracting a shared list is a larger change deferred to keep individual Work Units scoped.

---

# Metadata

Owner: IA Engineering

Version: 0.0.9

Status: Draft

Category: Adapter — GitHub

Severity: Recommended
