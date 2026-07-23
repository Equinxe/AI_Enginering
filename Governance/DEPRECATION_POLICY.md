# Deprecation Policy

---

# Purpose

Through v0.0.10.1, IA Engineering has only ever added content — Standards, Workflows, Templates, and Employees have been created, extended, and revised in place, but never marked as superseded or deleted.

This policy defines how a Standard, Workflow, Template, or Employee gets **deprecated** (marked as no longer the recommended approach, with a migration path, while it remains present) versus **removed** (deleted from the repository entirely) — and the required steps around both.

---

# Deprecation vs. Revision-in-Place

Not every change to a document is a deprecation. This project has already revised `Workflows/RELEASE.md` several times in a single session for exactly this reason — evolving a process based on real friction found through dogfooding (e.g., bumping the version on `develop` before creating the release branch, describing the back-merge as a Pull Request rather than a direct push). Those were **revisions-in-place**: the document's guidance was corrected, and the old guidance left no trace — it was simply overwritten.

A **deprecation** is different. It applies when the old approach itself — not just a detail of its wording — stops being current guidance, but some trace of it and a migration path to its replacement are deliberately kept rather than silently overwritten. Use revision-in-place when fixing or improving what a document says. Use deprecation when replacing what a document *is* (e.g., an entire Standard is superseded by a different one, a Workflow is replaced by a redesigned process, an Employee's Mission is superseded by a differently-scoped role).

---

# What Triggers a Deprecation Decision

A deprecation decision is triggered when:

- A Standard, Workflow, Template, or Employee is **superseded by a better approach** found through dogfooding — the framework's own live use surfaces a structurally better way to do something, not just a wording fix to the existing approach.
- A Standard, Workflow, Template, or Employee becomes **redundant** because its responsibility has been absorbed by another artifact (e.g., a Workflow step is generalized into a Core rule, per the pattern already seen when project-specific findings were generalized into `Core/MAIN_AGENT_CONDUCT.md`).
- An artifact is found to **conflict with a higher level of the Hierarchy** (`CLAUDE.md`) — Manifest, Standards, Employees, or Workflows — and cannot be reconciled by a revision-in-place.
- An artifact is confirmed to be **no longer applicable** to how the framework operates (e.g., a tool, mechanism, or process it depends on no longer exists).

A deprecation decision is never triggered by a single Employee's private judgment. It follows the escalation and approval requirements in `Who Decides`, below.

---

# The Deprecation Lifecycle

## 1. Marking as Deprecated

The artifact is marked deprecated with a visible, checkable callout at the top of the document, immediately below its title:

```
> **Deprecated as of vX.X.X.** Superseded by `<path/to/replacement>`. See `Governance/DEPRECATED.md` for the migration path and removal status.
```

This callout is the concrete marker. "We stop mentioning it elsewhere" is never sufficient on its own — the document itself must state its own deprecated status.

## 2. The Deprecation Index

`Governance/DEPRECATED.md` is the single index of every deprecated artifact in the framework. Each entry records:

```
## <Artifact name>

- Path: `<path to the deprecated file>`
- Deprecated as of: vX.X.X
- Superseded by: `<path to replacement, or "None — deprecated without replacement">`
- Migration path: <what an Employee or project must do instead, going forward>
- Removal status: <Scheduled for vX.X.X / Indefinite — kept for historical or compatibility reasons>
- Decided by: <Director approval reference — see Who Decides>
```

`Governance/DEPRECATED.md` is created the first time any artifact is deprecated. Until then, its absence itself indicates the framework has deprecated nothing.

## 3. Duration Before Removal

There is no fixed duration. A deprecated artifact remains in place until one of:

- A specific removal version is set at deprecation time (e.g., "Removal scheduled for v0.1.0"), recorded in `Governance/DEPRECATED.md`.
- The artifact is marked **Indefinite** — deprecated but deliberately kept in the repository for historical or compatibility reasons, with no planned removal date.

A deprecated artifact is never removed silently ahead of its recorded removal point, and an "Indefinite" artifact is never removed without first updating its `Governance/DEPRECATED.md` entry to reflect a new decision (see `Who Decides`).

## 4. What "Removed" Means

Removal means the file is **deleted from the working tree** (`git rm`), not moved to an archive folder within the live repository structure. Git history already preserves the full prior content and its deprecation trail — a separate in-repo archive location would duplicate what version control already provides, and would itself become another location requiring upkeep.

When an artifact is removed:

- Its `Governance/DEPRECATED.md` entry is updated from a removal date to **Removed as of vX.X.X**, and kept in the index rather than deleted from it — the index is a durable record of the framework's history, not only of what is currently deprecated.
- The file itself is deleted from the repository in the same commit or Work Unit that updates the index entry.

---

# Required Step: Cross-Reference Check

This project has repeatedly found "we changed X but forgot Y that references it" bugs in a single session — stale cross-references, stale Examples, stale counts in `VERSION.md` and `README.md`. A deprecation or removal is exactly this failure mode's highest-risk case, because it removes or redirects something other documents already point to.

A cross-reference check is therefore a **required step** of any deprecation or removal, not an afterthought:

1. **Search the full repository** for every reference to the artifact's path or name — in other Standards, Workflows, Templates, Employees, `Core/` documents, `Examples/`, `VERSION.md`, `README.md`, and `CLAUDE.md`.
2. **Update every reference found** to point to the replacement (if superseded) or to remove the reference cleanly (if deprecated/removed without replacement).
3. **Update any count or list that enumerates the artifact** — e.g., an Employee roster count in `VERSION.md` or `README.md`, a Standards list in `CLAUDE.md`, a Chain step list in `Core/AGENT_CHAINS.md`.
4. **Record the cross-reference check as complete** in the Work Unit's Definition of Done before the deprecation or removal is considered done — an artifact is not correctly deprecated or removed while any other document still references it as current guidance.

Skipping this step reproduces the exact class of bug this framework has already hit multiple times; it is not optional cleanup.

---

# Employee Deprecation (Special Case)

Deprecating or removing an Employee is distinct from deprecating a Standard, Workflow, or Template, because Employees are named individuals with a defined Mission that other documents route work to directly (`Core/EMPLOYEE_SELECTION.md`).

In addition to the general Cross-Reference Check above, deprecating or removing an Employee requires a **required, explicit check**:

- Every **Workflow** that names the Employee as an `Actor` (per the `Actor` field convention used throughout `Workflows/`) must be updated to name the correct replacement Employee, or to remove that step if no replacement applies.
- Every **Agent Chain** (`Core/AGENT_CHAINS.md`) that names the Employee in its sequence must be updated the same way.
- Every **escalation target** naming the Employee — including `Escalation Rules` sections in other Employee definitions, and escalation references in `Core/MAIN_AGENT_CONDUCT.md` — must be redirected to the correct replacement Employee.
- Every project's `CLAUDE.md` Active Employees roster (per `Workflows/ONBOARDING.md`) that includes the deprecated Employee should be flagged for review, since that project's active roster may depend on the deprecated Mission continuing to be fulfilled by a specific name.

An Employee deprecation is not complete until every Actor and escalation-target reference to it has been checked and, where necessary, redirected — a dangling Actor or escalation reference to a deprecated Employee is a broken dispatch waiting to happen, not a cosmetic gap.

---

# Who Decides

Deprecating or removing a Standard, Workflow, Template, or Employee changes what the whole framework recommends going forward — it is not a routine edit. It therefore requires the **Director's** explicit approval before it takes effect, consistent with:

- `CLAUDE.md`: *"Never merge, tag, release, or take irreversible actions without Director approval."* A deprecation changes framework-wide guidance, and a removal is irreversible in the sense that it deletes a file from the working tree — both fall under this rule.
- The general Escalation pattern in `Core/MAIN_AGENT_CONDUCT.md`: architecture changes, business decisions, and authority boundaries are escalated rather than assumed. Deciding that an existing Standard, Workflow, Template, or Employee is no longer the recommended approach for the framework is exactly this kind of decision.

No Employee — including the one identifying the need for deprecation — approves its own deprecation proposal. The Employee identifies the trigger and proposes the deprecation (marking mechanism, migration path, removal timing or "Indefinite" status, and the cross-reference check plan); the Director approves before the marker is committed, and before any scheduled removal is executed.

---

# Document Metadata

Owner: IA Engineering

Version: 0.0.1

Status: Draft

Category: Governance

Severity: Mandatory

Depends On:

- `CLAUDE.md`
- `Core/MAIN_AGENT_CONDUCT.md`
- `Core/EMPLOYEE_SELECTION.md`

Referenced By:

- All Standards, Workflows, Templates, and Employees (when deprecated or removed)
