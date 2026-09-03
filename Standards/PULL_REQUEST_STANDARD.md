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

A Pull Request is reviewed by being **read**. Past a certain size it is skimmed instead, and a skim that approves what it did not read is worth less than no approval, because it is trusted.

The limit is **1,500 changed lines** — additions plus deletions — counted on the files a reviewer must read:

- files marked `linguist-generated` in `.gitattributes` are excluded. That is the hosting platform's own convention for content no human reads — lockfiles, snapshots, built assets, generated clients — and declaring it in a committed file means the exclusion list is itself reviewed;
- binary files are excluded; they have no line count.

Above the limit the Pull Request is **split** into Work Units that can each be read. When the size is genuinely irreducible — a mechanical rename across a codebase, a vendored dependency, a migration that must land atomically — the **Director** accepts it by applying the `size/approved` label. The override is a label rather than a sentence in the description because applying a label requires write permission on the repository, and pasting a sentence requires nothing.

The `PR Size` check in `Adapters/github-actions/pr-validation.yml` enforces this; `Adapters/scripts/setup-branch-protection.sh` makes it required.

---

## Self-Contained Description

The description is read by someone who has **none of the author's context**: not the conversation that produced the change, not the author's working directory, not the chat log of the AI session. It must therefore stand alone:

- "How to test" is executable by the reviewer from a fresh clone, with the commands written out;
- evidence is pasted — the final lines of the test run, the validator's result — not described;
- no reference points outside the Pull Request or the repository ("as discussed", "see my notes", a path on the author's machine);
- when the Work Unit produced a Work Unit Report (`Templates/WORK_UNIT_REPORT.md`), the description **is** that report's substance, not a summary of it.

A description that needs the author present to be understood has not been written yet.

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
- open Pull Requests for unfinished work;
- exceed the review limit without a Director `size/approved` label, or mark a hand-written file `linguist-generated` to slip under it;
- write a description that depends on context outside the Pull Request.

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

Version: 0.0.3

Status: Draft

Category: Engineering Standard

Severity: Mandatory
