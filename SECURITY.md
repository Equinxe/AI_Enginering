# Security Policy

IA Engineering ships controls that other projects rely on — git hooks that refuse commits, a scanner that looks for secrets, CI checks that gate merges, and a script that configures branch protection. A defect in any of those is a security defect in every project that installed it, so this file exists before the first public release rather than after the first report.

---

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private vulnerability reporting on this repository — the *Security* tab, *Report a vulnerability*. It is private to the maintainers until a fix ships.

Please include:

- what the control was supposed to prevent, and what it let through
- the smallest input that reproduces it — a command line, a commit message, a file path
- whether an installed project is affected, or only this repository

A reproduction matters more than a severity rating. Every finding in this project's history was reproduced against the current head before being fixed and falsified after, and a report that comes with the reproducer skips the slowest part.

You will get an acknowledgement within **7 days** and an assessment within **30**. If a fix requires a release, it follows `Workflows/RELEASE.md` like any other change; if it cannot wait, `Workflows/HOTFIX.md` exists for that.

---

## What is in scope

Anything under `Adapters/` that runs on a developer machine or in CI:

| | |
|---|---|
| `Adapters/git-hooks/` | `commit-msg`, `pre-commit`, `pre-push` |
| `Adapters/ai-runtimes/claude-code/hooks/` | the five runtime hooks, and `strip-quotes.awk` |
| `Adapters/scripts/` | the check scripts, the data-policy scanner, the release and installation scripts, the host implementations |
| `Adapters/github-actions/` | the workflow definitions |

**The most valuable reports are bypasses.** A shell construction that gets an escape hatch past `block-escape-hatches.sh`, a secret shape that `data-policy-scan.sh` does not see, a way to satisfy a required check without meeting it. The runtime hooks have survived six independent adversarial passes and roughly sixty findings; each pass found a layer the previous one missed, so a seventh is expected to find something rather than hoped to find nothing.

A **false positive is also in scope**, and is treated as seriously. A control that refuses legitimate work teaches people to route around controls, and that costs more than the thing it blocked.

**Where the boundary is.** The runtime hooks (`Adapters/ai-runtimes/`) and the git hooks (`Adapters/git-hooks/`) run on the machine being governed and are guardrails: they stop an escape hatch reached for by habit, not one reached for on purpose. The boundary is server-side — branch protection and the required status checks. A bypass of a guardrail that a required check still catches is Low; a way to satisfy or skip a required check is in scope at full severity.

Two conditions bound that boundary, and both are part of it. Branch protection binds only the identities it is enforced on: in the single-identity configuration `Adapters/scripts/setup-branch-protection.sh` applies, the repository owner's role is exempt, so a session acting under that identity is held by the local guardrails and by the Director's review, not by branch protection. And a required check evaluates the definitions carried by the change under review, so a change to a check, a hook, or the workflow that runs them is reviewed as a change to the boundary itself. The two graders that read tool configuration, `shellcheck` and the workflow-YAML parser, are pinned against the change under review (`--norc`, a pinned `js-yaml` run from a fresh directory) so it cannot reconfigure them; that closes config-shadowing only, and the checks that execute the change's own scripts remain within the statement above.

---

## What is out of scope

- **The framework's prose.** `Core/`, `Standards/`, `Workflows/`, `Employees/` and `Templates/` are documents an AI reads as operating rules. A disagreement with a rule is a contribution, not a vulnerability — `Governance/CONTRIBUTING.md` is the path.
- **A model doing something unwise when the rules were not installed.** The controls only bind where they are installed and running; `Adapters/scripts/install.sh` verifies that, and a project that skipped it is unprotected by design rather than by defect.
- **Third-party infrastructure** — GitHub, your CI runner, your AI provider. Report those to their owners.

---

## Secrets and data, if you find them here

`Standards/DATA_PROTECTION_STANDARD.md` governs this repository as well as the projects that adopt it: real data lives only in an ignored local directory, secrets only in the environment, and fixtures carry an anchored `SYNTHETIC_` prefix.

If you find a real credential committed here, **treat it as live and report it privately**. Do not open an issue quoting it, and do not include the value in your report — the path and the commit are enough to find it. Rotation comes first and removal second; a secret that has been pushed is compromised whether or not the commit is later rewritten, which is why `data-policy-scan.sh --history` walks the objects a branch introduced rather than only the current tree.

---

## Supported versions

Only the latest release is supported. This is a pre-1.0 framework: version numbers move by milestone, structural changes happen between them, and there is no backward-compatibility commitment yet. `Governance/VERSIONING_POLICY.md` states what a version number means and when that changes.

| Version | Supported |
|---|---|
| latest release | ✅ |
| anything earlier | ❌ — upgrade |

---

## Metadata

Owner: IA Engineering

Version: 0.0.15

Status: Draft

Category: Governance — Security

Severity: Mandatory
