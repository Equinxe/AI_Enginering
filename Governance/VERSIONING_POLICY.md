# Versioning Policy

---

# Purpose

This document is the authoritative, standalone definition of how IA Engineering versions itself.

`VERSION.md` tracks the current version and what has shipped. This document defines the rules that decide what that version number *is* — when it changes, by how much, and why. Where the two might ever appear to disagree, this document governs; `VERSION.md`'s own footer is a short pointer here, not a second copy of the rules.

This document does not decide when a release happens (see `Workflows/RELEASE.md`), only how that release — or a smaller change — is numbered.

---

# Format

```
MAJOR.MINOR.MILESTONE[.FIX]
```

Four segments. The fourth is optional and only appears when a `.FIX` release is needed (see below).

---

# Segment Semantics

## MAJOR.MINOR

Both remain `0.0` until IA Engineering reaches a stable public release.

Before that point, every increment of version is expressed through `MILESTONE` (and, exceptionally, `FIX`). `MAJOR.MINOR` will begin moving once the framework has a defined stable release and public commitment to backward compatibility — a decision out of scope for this document (see `LICENSE.md` / the pending v1.0 backlog item for related, separately-decided groundwork).

## MILESTONE

Increments once per completed milestone: Foundation, Standards, Employees, Workflows, Templates, Orchestration, Examples, Capability Tiers, Adapters, Governance, and so on.

A milestone represents a coherent, named body of new capability delivered together — not a single Work Unit, and not an arbitrary batch of unrelated fixes.

### One version may carry more than one milestone

"Once per completed milestone" governs the **counter**, not the **release**. A version number is consumed by each milestone that completes; it is not required that each milestone reach `main` in a release of its own.

When two milestones both complete before either has shipped, they are released together under a single version number, and that version's `CHANGELOG.md` heading names both:

```
## [0.0.12] - Automation & Convergence
```

This is a release-packaging decision, not a naming shortcut, and the distinction is what keeps it clear of the Milestone Naming Discipline rule below. Both names appear in full. Neither is borrowed to describe the other's work, and neither is dropped. A reader of the heading sees exactly the two bodies of work the version contains, and the `CHANGELOG.md` section beneath it accounts for both.

**Rule:** a version carries several milestones only when every milestone named in its heading is genuinely complete. A milestone that is still in progress is not folded into a shipping version to avoid a second release — it waits and takes its own number.

The alternative was considered and rejected. Releasing them separately would mean cutting a release branch from the point in `develop` where the first milestone ended, and that point predates the required status checks the second milestone introduced — so the first release could never satisfy the branch protection now in force, and would have to ship by suspending it. A number for a release that cannot pass its own gates is worse than a heading with two names in it.

The mechanical consequence is recorded in `Adapters/scripts/release.sh`: Step 1 reads the codename field of a `CHANGELOG.md` heading as a list, so a milestone counts as released when it is named anywhere in that list. That function also compares the whole field before splitting it, because a single milestone's own name may contain the separator — v0.0.10.1 shipped as "Consistency & Compliance Hardening".

## FIX

An optional 4th segment used only for a **post-release consistency correction that introduces no new capability** and does not, on its own, justify consuming the next milestone number.

`.FIX` releases exist so that necessary hardening work does not either (a) sit unreleased waiting for the next real milestone, or (b) falsely inflate the `MILESTONE` counter for something that was not a new milestone at all.

---

# The FIX vs. New-Milestone Test

Before assigning a version number to a batch of merged work, ask:

> **Does this introduce a new capability category, or does it correct / harden something already shipped?**

- **New capability category → next `MILESTONE` number.** A new Workflow, a new Template, a new class of Adapter, a new Core concept — something the framework could not do before.
- **Correction or hardening of already-shipped capability → `.FIX` on the current `MILESTONE`.** Bugs, gaps, consistency corrections, and process hardening on capability that already exists and already shipped.

## Worked example: v0.0.10.1 (2026-07-23)

Seven Work Units had accumulated on `develop` after v0.0.10 (Project Bootstrap) shipped, grouped below into six lines (the QA and Compliance Engineer trigger-criteria Work Units share one line, since they landed as one combined change):

- Branch protection for `release/*` branches (closing a gap that let an unreviewed direct push land on a release branch).
- A `Workflows/RELEASE.md` correction so minor release-branch defect fixes go through a PR instead of a direct push, matching the new branch protection.
- Concrete QA Engineer and Compliance Engineer trigger criteria added to existing escalation rules in `Workflows/CODE_REVIEW.md`, `Workflows/FEATURE_DEVELOPMENT.md`, and `Core/AGENT_CHAINS.md` (two Work Units).
- Two CI checks added to the existing PR-validation Adapter.
- `Examples/RELEASE_CHAIN_EXAMPLE.md` realigned to the corrected mechanism.
- The Apache 2.0 license copyright notice completed (the license text itself had shipped earlier; only its header was incomplete).

None of these added a capability the framework did not already have — every one of them corrected or hardened something from the v0.0.9 (Adapters) or v0.0.10 (Project Bootstrap) milestones. Applying the test above, all seven were released together as **v0.0.10.1**, a single `.FIX` release, rather than as separate dot-releases or as a new milestone.

---

# Milestone Naming Discipline

A milestone name (e.g. "Governance") is reserved for the real, scoped body of work that milestone is defined to deliver. It must never be borrowed as a label of convenience for unrelated work merely because that milestone's number is next in line.

**Rule:** before labeling a batch of changes with an upcoming milestone's name, confirm those changes actually populate that milestone's declared scope. If they do not, they are a `.FIX` (or belong to whichever milestone they actually harden) — not the next milestone, even if the next milestone hasn't started yet and the number is otherwise unused.

This rule is about a name attached to work it does not describe. It is not violated by a version whose heading names two milestones that both really completed (see *One version may carry more than one milestone* above): there, no name stands in for anything it did not deliver.

## Cautionary example (2026-07-23)

During the same session that produced v0.0.10.1, six of its seven constituent fixes (branch protection, the release-workflow correction, the QA/Compliance trigger criteria, and the CI checks) were initially labeled as "v0.0.11 — Governance" work — simply because Governance was the next milestone on deck and no version had been assigned yet. On review, none of the six actually delivered anything within Governance's real scope (formal governance documents, of which this policy is the first); they were process-hardening corrections to the Adapters and Project Bootstrap milestones already shipped. They were reclassified and released as **v0.0.10.1** instead, and the real v0.0.11 — Governance milestone remained unstarted until this document.

This is the concrete failure mode the rule above exists to prevent: a milestone name attached to a version number before that milestone's actual scope has been checked.

---

# Document-Internal `Version:` Field Policy

Every governed document in this repository (Core, Standards, Employees, Workflows, Templates, Governance) carries its own `Version:` field in its `# Metadata` / `# Document Metadata` footer. This is independent of the framework-wide version in `VERSION.md` — it tracks that specific document's own revision history.

- **A document's internal `Version` bumps on every substantive new capability it receives** — a new rule, a new section that changes what the document governs, a materially new mechanism — whether that addition lands within the same milestone/session it was last touched in, or in a later one. Wording fixes, typo corrections, cross-reference updates, and other non-substantive edits do not bump it.
- **A brand-new document's initial internal `Version` is seeded at the milestone it is created in.** It does not start at an arbitrary baseline unrelated to when it was authored.

The field is a **per-document revision counter**, seeded at the creation milestone, not a live mirror of the framework's own `MILESTONE` segment. The two will diverge quickly by design: a document created at milestone 11 that later receives two more substantive additions becomes `0.0.13` — a revision count of three substantive changes, not a claim that "milestone 13" exists anywhere in `VERSION.md`. `Core/MAIN_AGENT_CONDUCT.md` is the concrete example: its `Version` field advanced `0.0.1` → `0.0.5` across five substantive rule additions made within the same v0.0.10 / v0.0.10.1 window, not across five separate framework milestones.

This document is itself the first application of the seeding rule: it is created during the **v0.0.11 — Governance** milestone, so its initial `Version:` (see Metadata below) is `0.0.11`, not `0.0.1`.

---

# Versioning and Release Completeness

A version number is only meaningful once the release it names is actually complete. Per `Workflows/RELEASE.md` Step 7, tagging a release requires more than a bare annotated git tag: it requires a full GitHub Release (or equivalent host mechanism) whose notes are derived from that version's `CHANGELOG.md` entry. A tag with no corresponding release notes is an incomplete release, regardless of what version number it carries.

Versioning policy and release completeness are related for this reason: assigning the correct version number (this document) and completing the release properly once that number is decided (`Workflows/RELEASE.md` Step 7) are both required for a release to count as done.

---

# Pre-Release Status Signaling

`VERSION.md` carries a `Status` field — currently `🟢 Active Development` — signaling that IA Engineering is pre-release and unstable: version numbers under `0.0.x.x` may still involve structural changes between milestones, and no backward-compatibility guarantee applies.

When the framework reaches a stable public release, two things change together, not independently:

- `MAJOR.MINOR` begins incrementing (see Segment Semantics above), replacing the `0.0` placeholder.
- The `Status` field moves off `Active Development` to reflect a supported, stable state.

The conditions and process for reaching that point (including the pending `LICENSE.md`-adjacent v1.0 backlog item) are a separate decision, out of scope for this document. This policy only defines how the version number and status field behave once that transition happens.

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Governance — Versioning

Severity: Mandatory
