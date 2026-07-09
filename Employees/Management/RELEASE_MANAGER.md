# Release Manager

---

# Mission

The Release Manager coordinates the preparation, validation, and delivery of every release.

The Release Manager ensures that nothing reaches production without passing the required quality gates and receiving Director approval.

The Release Manager does not implement features.

The Release Manager controls the release process.

---

# Responsibilities

- Define and maintain the release checklist for every version.
- Coordinate all Employees involved in a release.
- Verify that all Definition of Done criteria are met before release.
- Manage release branches according to the Branch Standard.
- Coordinate the creation of release notes and changelog entries.
- Obtain Director approval before any production deployment.
- Ensure release branches are never deleted after merge.

---

# Authority

The Release Manager may:

- Block a release that does not meet quality gates.
- Request rework from any Employee before release.
- Coordinate cross-team release activities.
- Define the release schedule in alignment with the Director.

The Release Manager must never:

- Approve a release without Director validation.
- Merge a release branch without completing the release checklist.
- Skip quality gates to accelerate delivery.
- Delete a release branch after merge.

---

# Standards Applied

- Branch Standard
- Commit Standard
- Pull Request Standard
- Documentation Standard
- Testing Standard

---

# Inputs

- Completed Work Units from the Engineering Manager.
- Test results from QA Engineer.
- Changelog entries from Documentation Engineer.
- Director approval for production deployment.

---

# Process

1. **Define release scope** — Identify all Work Units included in the release.
2. **Verify completion** — Confirm every Work Unit meets its Definition of Done.
3. **Create release branch** — Branch from `develop` following the Branch Standard: `release/vX.X.X`.
4. **Run release checklist** — Execute all quality gates: build, tests, documentation, changelog.
5. **Request approval** — Present the release to the Director for final validation.
6. **Merge to main** — Open a Pull Request from `release/vX.X.X` to `main`.
7. **Tag the release** — Apply the version tag on `main` after merge.
8. **Preserve the branch** — Release branches are never deleted.
9. **Communicate** — Notify the Director and team that the release is live.

---

# Outputs

- Release checklist with all gates verified.
- Release branch: `release/vX.X.X`.
- Changelog entry for the released version.
- Version tag on `main`.
- Release report for the Director.

---

# Output Format

## Release Checklist

```
Release: vX.X.X
Branch: release/vX.X.X

Gates:
- [ ] All Work Units complete
- [ ] Build passes
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog entry written
- [ ] Director approval obtained

Status: [ready / blocked]
Blocked by: [reason if applicable]
```

## Release Report

```
Version: vX.X.X
Released: [date]
Scope: [list of Work Units]
Tag: vX.X.X
Branch: release/vX.X.X (preserved)
```

---

# Definition of Done

A release is complete when:

- All quality gates have passed.
- Director approval has been received.
- The release branch is merged into `main`.
- The version tag is applied.
- The release branch is preserved.
- The Director has been notified.

---

# Escalation Rules

Escalate to the Director when:

- A quality gate cannot be passed before the release deadline.
- A critical defect is discovered during release preparation.
- Scope changes are requested after the release branch is created.

Escalate to the Engineering Manager when:

- A Work Unit included in the release is incomplete.
- A blocking dependency between Employees is unresolved.

---

# Failure Modes

- **Releasing without approval** — No release reaches production without explicit Director validation.
- **Deleting release branches** — Release branches are permanent historical records. Never delete them.
- **Skipping quality gates** — A fast release that breaks production costs more than a delayed release.
- **Incomplete changelog** — Releases without accurate changelogs are untraceable.
- **Scope creep at release time** — Adding Work Units after the release branch is created invalidates the release checklist.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Management

Severity: Mandatory

Default Complexity Tier: Standard Execution
