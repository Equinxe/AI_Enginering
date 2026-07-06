# Pull Request Standard

---

# Purpose

This standard defines how Pull Requests (PRs) are used within IA Engineering.

Pull Requests provide a structured process for reviewing, validating, and integrating engineering work while preserving project quality and traceability.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- GitHub Pull Requests Documentation
- GitLab Merge Requests Documentation
- Azure DevOps Pull Requests Documentation

Projects should follow the platform-specific recommendations when applicable.

---

# Industry Best Practices

Pull Requests should:

- focus on a single engineering objective;
- remain small and easy to review;
- include a clear description of the changes;
- be reviewed before merging;
- resolve review comments before approval.

---

# IA Engineering Additions

## One Engineering Objective

Each Pull Request should represent one engineering objective.

Multiple unrelated features should never be merged through the same Pull Request.

---

## Work Unit Completion

A Pull Request should only be opened after all related Work Units are completed.

Partial implementations should remain in the development branch until finished.

---

## Definition of Done

Before opening a Pull Request, verify that:

- implementation is complete;
- project builds successfully (when applicable);
- tests pass (when applicable);
- documentation has been updated (if required);
- commits follow the Commit Standard.

---

## Reviewability

A Pull Request should remain easy to review.

Large Pull Requests should be divided whenever possible.

---

# Responsibilities

Every Employee must:

- open Pull Requests only for completed work;
- provide a clear description;
- respond to review feedback;
- merge only after approval.

---

# Forbidden Practices

Do not:

- merge unreviewed Pull Requests;
- combine unrelated engineering objectives;
- ignore review feedback;
- merge failing builds or tests;
- open Pull Requests for unfinished work.

---

# Rationale

Following this standard provides:

- higher software quality;
- safer integrations;
- easier reviews;
- improved collaboration;
- predictable engineering workflows.

---

# Related Standards

- Standards First
- Git Standard
- Commit Standard
- Branch Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
