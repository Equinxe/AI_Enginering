# Git Standard

---

# Purpose

This standard defines how Git is used within IA Engineering.

Git is the mandatory version control system for every project.

IA Engineering follows official Git documentation and recognized Git workflows instead of defining its own version control rules.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- Git Documentation
- Pro Git Book

---

# Industry Best Practices

Projects should adopt a documented branching strategy appropriate for their needs.

Common strategies include:

- GitHub Flow
- Git Flow
- Trunk-Based Development

The selected workflow must be documented at project initialization.

---

# IA Engineering Additions

IA Engineering extends Git through complementary standards.

These include:

- Commit Standard
- Branch Standard
- Pull Request Standard

Git itself is never redefined.

## Escape Hatches

Every control in this framework — a hook, a signature requirement, a protected branch, a failing check — has a mechanism that bypasses it, because Git and the hosting platforms provide those mechanisms for legitimate emergencies. In an engineering session they have one shared property: each makes a control **stop applying without anything recording that it did**. The framework calls them escape hatches, and the rule is the same for all of them:

> A control that is in the way is a rule that is in the way. Escalate the rule; never route around the control.

The canonical list, enforced by `Adapters/ai-runtimes/*/hooks/` where the runtime supports it and reviewable everywhere:

| Escape hatch | What it silently disables | Do instead |
|---|---|---|
| `git commit --no-verify`, `git push --no-verify` | The `commit-msg` and `pre-commit` hooks — attribution, data protection, and any project hook, in one motion | Fix what the hook refuses. If the hook is wrong, that is a Work Unit against the hook. |
| `--no-gpg-sign`, `-c commit.gpgsign=false` | The signature the project decided to require | Fix the signing setup. |
| `git stash` as a way to make a check pass or to set work aside without a record | The work itself — a stash is local, unlabelled, and lost with the clone | Commit as work in progress on the feature branch, or open a second branch. |
| `git rebase -i`, `git add -i`, any interactive command in a non-interactive session | Nothing visible — it hangs or does nothing, and the session reports whatever it assumes happened | Non-interactive equivalents, with the result verified from `git log` / `git status`. |
| `git push --force` to a protected branch, `push --mirror`, `push --delete` on `main` / `develop` / `release/*` | Branch protection and every collaborator's history | Never. The single sanctioned rewrite is the data-purge protocol in `Standards/DATA_PROTECTION_STANDARD.md`, and it is a Director decision. |
| `git reset --hard`, `git checkout -- .`, `git clean -f` on work the Employee did not create | Uncommitted work belonging to someone else | Inspect first; surface anything unexpected instead of discarding it (`Standards/RISK_STANDARD.md`, operational catalog). |
| Editing a hook, a CI workflow, or `.gitattributes` in the same change that they would have refused | The control's independence — the change grades itself | The control change is its own Work Unit, reviewed on its own. |

Two consequences:

- a control an Employee cannot satisfy is **escalated with the refusal quoted**, per `Standards/RISK_STANDARD.md` (High: stop and wait);
- an escape hatch found in history is an incident, not a style issue — `Governance/TROUBLESHOOTING.md` records it and the Employee who used it is named in the record, because the point of attribution is that it survives the moment it becomes inconvenient.

---

# Repository Requirements

Every IA Engineering project must:

- use Git as its version control system;
- maintain a complete project history;
- ensure repository integrity;
- document the chosen Git workflow.

---

# Responsibilities

Every Employee must:

- work inside a Git repository;
- preserve project history;
- follow the project's documented Git workflow;
- comply with all Git-related IA Engineering standards.

---

# Forbidden Practices

Do not:

- develop outside version control;
- bypass the project's Git workflow;
- rewrite shared history without approval;
- remove project history without justification;
- use any escape hatch in the table above — `--no-verify`, `--no-gpg-sign`, a stash in place of a commit, an interactive command in a non-interactive session, a force-push to a protected branch, a discard of work that is not yours, or a self-grading change to a control;
- change a control in the same Pull Request as the work it would have refused.

---

# Rationale

Using Git consistently provides:

- traceability;
- collaboration;
- reproducibility;
- maintainability;
- reliable project history.

---

# Related Standards

- Standards First
- Commit Standard
- Branch Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Engineering Standard

Severity: Mandatory
