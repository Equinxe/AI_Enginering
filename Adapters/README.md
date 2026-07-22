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
| `github-actions/pr-validation.yml` | Three checks on every PR targeting `main` or `develop`: (1) **PR Compliance** — references a Work Unit ID and has a real, filled-in description; (2) **Shellcheck Adapters** — the git hooks/scripts we ship are valid, warning-free shell; (3) **Validate Workflow YAML** — every workflow file at minimum parses | `Templates/WORK_UNIT.md`, `Templates/PULL_REQUEST.md`, `Standards/CODE_QUALITY_STANDARD.md` |
| `github/PULL_REQUEST_TEMPLATE.md` | Every new PR starts from the mandatory template — mirrors `Templates/PULL_REQUEST.md` exactly | `Templates/PULL_REQUEST.md` |
| `scripts/setup-branch-protection.sh` | `main`/`develop` require the three status checks above before merge; no force-push, no branch deletion. Formal approving review count is 0 by design (see the script's own comments — a single shared `gh` identity across all Employees and the Director makes GitHub-native self-approval impossible) | `Standards/BRANCH_STANDARD.md`, `Workflows/CODE_REVIEW.md` |

---

# Installation

Run from the root of a project that has imported IA Engineering as a Git submodule at `ia-engineering/` (see `Workflows/ONBOARDING.md`).

```bash
# Git hooks (local enforcement, every clone must repeat this — hooks are not
# transmitted by git itself)
cp ia-engineering/Adapters/git-hooks/commit-msg .git/hooks/commit-msg
cp ia-engineering/Adapters/git-hooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/commit-msg .git/hooks/pre-push

# GitHub Actions CI check
mkdir -p .github/workflows
cp ia-engineering/Adapters/github-actions/pr-validation.yml .github/workflows/

# GitHub PR template
cp ia-engineering/Adapters/github/PULL_REQUEST_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE.md

# Branch protection (requires GitHub CLI, authenticated — run once per repo,
# review the script first, it mutates shared settings)
./ia-engineering/Adapters/scripts/setup-branch-protection.sh
```

This extends `Workflows/ONBOARDING.md` Step 5 ("Initialize git workflow") — the manual checklist there becomes a scripted setup once these Adapters are installed.

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

---

# Metadata

Owner: IA Engineering

Version: 0.0.9

Status: Draft

Category: Adapter — GitHub

Severity: Recommended
