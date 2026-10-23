# Release Workflow

---

# Purpose

This workflow defines the process for creating a production release from a stable `develop` branch.

It governs every step from the version bump through release branch creation, tagging, and post-release verification, ensuring that every release is traceable, tested, and approved by the Director before reaching `main`.

---

# Trigger

- Director or Engineering Manager initiates a release cycle.
- `develop` contains a set of features and fixes that are ready for production.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Release Manager | Orchestrates the release, owns the release branch |
| Engineering Manager | Confirms `develop` is in a releasable state |
| QA Engineer | Executes release acceptance testing |
| Director | Final approval to merge release into `main` |
| Technical Lead | Resolves last-minute technical issues found during release testing |
| Observability Engineer | Confirms production health during post-release verification |
| Scrum Master | Runs the release retrospective (Step 11) |

---

# Prerequisites

Before this workflow begins:

- All features and fixes intended for this release are merged into `develop`.
- No open critical or high defects on `develop`.
- The release version number and codename have been decided. (The version bump itself is performed inside this workflow, in Step 2, not before it.)
- Director has approved the release scope.

---

# Steps

## Step 1 — Release readiness review

**Actor:** Release Manager + Engineering Manager

Run `Adapters/scripts/release.sh check` from `develop`. It is read-only.

| # | Condition | Mechanically checked? |
|---|---|---|
| 1 | All planned Work Units are merged into `develop` | **Yes** — every Work Unit registered against this milestone in `Registry/work-units.yml` must have a commit reachable from `develop` carrying its `Work Unit:` trailer. The milestone is derived as the one registry milestone with no `CHANGELOG.md` section yet, so this works at Step 1, *before* the Step 2 bump; pass `--milestone <name>` when more than one is unreleased |
| 2 | CI/CD is green on `develop` | **Yes** — the latest run's conclusion |
| 3 | No open critical or high defects remain | **Reported, not failed** — see below |
| 4 | The release version number and codename are agreed | **Partly** — `VERSION.md`'s version is read and compared against the one being asked about; whether that version and codename are the *agreed* ones is a Director judgment no script can make |
| 5 | Pending changelog entries account for every significant change | **Partly** — every Work Unit registered against the milestone must have a fragment in `changelog.d/` (an entry, or `No changelog entry: <reason>`), or be named in the final parenthesised group of a line of the milestone's `CHANGELOG.md` section; after Step 2, a fragment still in `changelog.d/` fails. The section's presence and size are checked too. Whether each entry says the right thing is a reading task |

The script additionally checks the current branch, working-tree cleanliness, sync with the remote, and `Adapters/scripts/validate-framework.sh`.

Condition 3 is **reported, not failed** on purpose: whether an open issue is critical or high is a judgment call, and a script that guessed would either block real releases or wave through real blockers. It lists them and leaves the assessment to the reviewer.

This table replaced a single sentence claiming the script "reports every condition below". It did not — condition 1 had no mechanical form at all, and the paragraph beneath the list correctly enumerated a narrower set, so one Step made two incompatible claims about the strength of the same gate. A reader stopping at the lead-in, which is where the instruction to run the command lives, would have concluded condition 1 was covered. Condition 1 is now implemented; conditions 4 and 5 are marked partial rather than described as fully enforced.

If any condition is not met: block the release. Do not proceed until `develop` is ready.

**Output:** Release readiness confirmation.

---

## Step 2 — Bump version on `develop`

**Actor:** Release Manager

The version bump is a normal Work Unit merged into `develop` through the standard branch → commit → PR → merge cycle, subject to the same CI and hooks as any other change. It happens **before** the release branch is created, so that `develop` already carries the final `VERSION.md` and CHANGELOG.md for this release.

1. Branch from the latest `develop` (for example `chore/release-vX.X.X-bump`).
2. Update VERSION.md to the new version number and codename.
3. Run `Adapters/scripts/release.sh assemble`. It folds every changelog fragment in `changelog.d/` into the `## [Unreleased]` section of CHANGELOG.md, by category then Work Unit id, below the entries already there, and deletes the fragments. It refuses, changing nothing, if a fragment is malformed. `changelog.d/README.md` describes the fragments.
4. Update CHANGELOG.md to finalize the entries for this release, and rename `## [Unreleased]` to the version.
5. Commit following the Commit Standard: VERSION.md, CHANGELOG.md and the fragment deletions in the one bump commit.
6. Open a Pull Request to `develop`.
7. Merge the PR once CI passes.

This is why the release branch created in Step 3 needs no separate version-bump commit: the bump already lives on `develop`.

Work Units do not edit CHANGELOG.md: each adds its fragment, `changelog.d/<Work Unit id>.md`, so two Pull Requests never conflict on the same category. This step is the one place the fragments become CHANGELOG.md.

**Output:** `develop` carries the final VERSION.md and CHANGELOG.md for this release.

---

## Step 3 — Create release branch

**Actor:** Release Manager

1. Checkout the latest `develop` (now including the version bump from Step 2).
2. Create a release branch: `release/vX.X.X`.
3. Push the release branch to remote.

At creation the release branch is an exact snapshot of `develop`, version bump included. No separate version-bump or changelog commit happens on this branch. Only bug fixes found during release acceptance testing (Step 4) are allowed here. No new features.

**Output:** `release/vX.X.X` branch created and pushed.

---

## Step 4 — Release acceptance testing

**Actor:** QA Engineer

1. Pull the release branch.
2. Execute the release acceptance test plan covering all features in this release.
3. Verify critical user flows end-to-end.
4. Document results: pass/fail for each test case.

If a defect is found:
- Minor defect: branch protection blocks direct pushes to `release/vX.X.X`, so the fix goes through a Pull Request like any other change, the same way the back-merge in Step 8 already does. Branch from the release branch (for example `fix/release-vX.X.X-short-description`), commit the fix following the Commit Standard, open a Pull Request targeting the release branch (`release/vX.X.X`, not `develop`), wait for CI to pass, have the Code Reviewer review it, then merge into the release branch. This causes the release branch to diverge from `develop`, which makes the back-merge in Step 8 necessary.
- Critical or high defect: escalate to the Director. The release may be blocked or the defect deferred.

**Output:** Release acceptance test report.

---

## Step 5 — Director approval

**Actor:** Director

1. Review the release scope (CHANGELOG.md).
2. Review the QA acceptance test report.
3. Approve or block the release.

No merge to `main` happens without explicit Director approval.

**Output:** Director approval documented.

---

## Step 6 — Merge to main

**Actor:** Release Manager

1. Open a Pull Request from `release/vX.X.X` to `main`.
2. PR description includes: version, release scope summary, QA sign-off reference, Director approval reference.
3. Director or designated approver merges the PR.

**Output:** Release merged into `main`.

---

## Step 7 — Tag

**Actor:** Release Manager

1. Pull the latest `main`.
2. Create an annotated tag: `git tag -a vX.X.X -m "vX.X.X — <codename>"`.
3. Push the tag: `git push origin vX.X.X`.
Steps 1 to 3 above are performed by `Adapters/scripts/release.sh publish vX.X.X --confirm`, which extracts this version's `CHANGELOG.md` section itself, creates the annotated tag, pushes it, and creates the GitHub Release from that section. It refuses to run unless `HEAD` is `main`, the tree is clean, local `main` matches `origin/main`, the tag does not already exist, and the `CHANGELOG.md` section is present — so it cannot tag a commit that never passed Step 5, and it cannot produce the bare tag this step forbids. Without `--confirm` it prints the plan and stops, because publishing a release is externally visible and effectively irreversible.

4. A bare annotated tag with only a short `-m` message is **not sufficient on its own** — it produces no real description on the host's Releases page. Create a full GitHub Release from that tag, with a description derived from this version's actual `CHANGELOG.md` entry (its `### Added`, `### Fixed`, and `### Notes` sections), not a one-line summary:
   - Current Adapter mechanism (GitHub): `gh release create vX.X.X --title "vX.X.X — <codename>" --notes-file <path-to-extracted-changelog-section>` (extract this version's `## [X.X.X]` section from `CHANGELOG.md` into a temp file first, or pass the same content inline via `--notes`). A non-GitHub host must use its equivalent release-creation mechanism (e.g., the GitLab Releases API), following the same content requirement.
   - The Release description must reproduce the `CHANGELOG.md` entry for this version, verbatim or near-verbatim, so anyone browsing the Releases page sees the full changelog content without needing to open the repository.

**Output:** Release tagged on `main`, with a corresponding GitHub Release whose notes are derived from `CHANGELOG.md`.

---

## Step 8 — Back-merge to develop

**Actor:** Release Manager

This step is **always required**, on every release, including one where the release branch never diverged from `develop`.

Earlier versions of this step called it "normally unnecessary", reasoning that the release branch is an exact snapshot of `develop` so `main` and `develop` hold the same release *content*. The content claim is true. The conclusion drawn from it is wrong, and the difference is history rather than content.

Merging the release branch into `main` in Step 6 creates a **merge commit on `main`**. That commit exists on `main` and on no other branch. `develop` never receives it, because nothing else merges `main` anywhere. So every release leaves `main` exactly one commit ahead of `develop`, carrying no content, and the gap accumulates one commit per release.

That gap is invisible until `main` requires branches to be up to date before merging. From then on it is a hard block: the next release's Pull Request to `main` cannot merge, because its head does not contain `main`'s tip, and it cannot be made to contain it without performing the back-merge that was skipped. The block appears on the release *after* the one that skipped the step, which is what made the omission survive two releases here — v0.0.10.1 and v0.0.11 both skipped it, and v0.0.12 was the first release cut after "require branches to be up to date" was turned on. Its Pull Request to `main` was blocked by two content-free merge commits from releases three months earlier.

Two consequences to check for, not one:

- **Always** — the merge commit Step 6 created on `main`.
- **Additionally**, whenever a defect fix was applied directly to the release branch during Step 4 acceptance testing: the release branch diverged from `develop` by those fix commits, and they carry real content that must be brought back.

How:

1. The `pre-push` hook (`Adapters/git-hooks/pre-push`) blocks direct pushes to `develop`, so the back-merge goes through a Pull Request like any other change.
2. **Branch from `develop`** (for example `chore/back-merge-main`) and merge `main` into it: `git merge --no-ff origin/main`. Push that branch.
3. Open the Pull Request from **that branch** to `develop`, not from `main` itself.
4. Merge it once CI passes. The content already went through review on its way into `main`, so no new conflicts are expected.

**Do not open the Pull Request with `main` as its head.** That is the obvious shape and it cannot work once `develop` requires branches to be up to date. "Up to date" compares the *head* against the *base*: a Pull Request whose head is `main` would have to contain `develop`'s tip to be mergeable, which is the opposite of what a back-merge does and would put unreleased work on `main` outside this workflow. GitHub reports it as `the head branch is not up to date with the base branch`, and no amount of waiting clears it. A branch cut from `develop` that merges `main` contains both tips, so it satisfies the rule while carrying exactly the same history.

In the normal case that Pull Request **changes no files** — it carries only the merge commit from Step 6. That is expected and is not a reason to skip it. The `PR Size` check recognises a range whose commits are all merges and passes it with a notice; a range with no commits at all, or one holding a non-merge commit that changed nothing, still fails. Do not close a zero-file back-merge Pull Request as pointless: the commit it carries is the whole point, and skipping it is what blocks the next release.

**Output:** `develop` contains `main`'s tip, so the next release's Pull Request to `main` can satisfy "require branches to be up to date".

---

## Step 9 — Post-release verification

**Actor:** QA Engineer + Observability Engineer

1. Verify the production deployment is healthy (if automated deployment is configured).
2. Confirm no critical errors in logs or monitoring dashboards within 30 minutes of release.
3. Report status to the Director.

**Output:** Post-release health confirmation.

---

## Step 10 — Preserve the release branch

**Actor:** Release Manager

The release branch `release/vX.X.X` is **never deleted**. It serves as a permanent snapshot of the exact state released to production.

**Output:** Release branch preserved on remote.

---

## Step 11 — Release retrospective

**Actor:** Scrum Master, dispatched by the Main Agent once the release is tagged. The Director decides on every line, in one pass.

**Bound:** one run per release, one list, recorded before the next milestone's first Work Unit is planned. The retrospective feeds that planning; recorded after it, it feeds nothing.

A release is the point where the lessons of a whole milestone can be seen together. Read one report at a time, a missing check looks like bad luck; read across a release, the same friction shows up in four Work Units. This step collects both and sends each one to the place that owns its fix.

1. **Collect from named sources only.** The same release read twice must produce the same list, so the Scrum Master reads these, and nothing else:
   - the `LESSON:` lines of the Work Unit Reports — the Pull Request descriptions of the Work Units registered against this milestone in `Registry/work-units.yml` (`Templates/WORK_UNIT_REPORT.md`, Lessons → Location);
   - the review threads and the failed CI runs of the release's merged Pull Requests;
   - the findings Issues opened during the milestone by adopting projects (in this repository, the `adoption-finding` Issues);
   - the Director's corrections and escalations made during the milestone, as recorded in the Pull Requests, the Issues, and the session state.
2. **Keep only what has evidence.** A friction is something that cost the release time or a correction: a check that failed for a reason the author could have known earlier, a review that went more than one round on the same point, a Director correction, an escalation, a brief that lacked what the Employee needed, a step done by hand that could have been run. Each one cites its evidence from the sources above. A friction no one can point to is an opinion, and stays out of the record. Merge duplicates and count them: each friction line says in how many Work Units it appeared, because a friction seen in four is worth more than one seen once. Note, too, what worked — a check or a practice that saved this release time — so it is kept rather than lost in a later clean-up.
3. **Name the surface that owns each friction's fix.** One of four:

   | Surface | When it owns the fix | Example |
   |---|---|---|
   | Deterministic check | A script, hook, or CI job could have refused the mistake before review | a validator section, a commit-msg rule |
   | Instruction | The rule exists nowhere an Employee reads, or is worded two ways — an Employee definition, a Standard, a Workflow, a Template | a missing Definition of Done item |
   | Tool | The runtime, an Adapter, or the host got in the way | an installer that cannot be re-run |
   | Missing information | The rule was right but the Employee did not have the fact — the brief, the session state, the project context | a brief that omitted the base branch |

   Where a check and an instruction could both fix it, propose the check: an instruction can be skipped, a check cannot. Where the owning surface is unclear, the line says so and the Director decides it; the Scrum Master does not guess. The Scrum Master classifies; it does not choose the fix's design, which stays with the Employee that owns the surface.
4. **Record the list, then the Director decides in one pass.** Open one Issue titled `Release retrospective vX.X.X` holding every lesson line, every friction line with its evidence, recurrence count and surface, and the "what worked" lines. The Director accepts or refuses each line in that Issue. A conversation is not a record.
5. **File only what was accepted.** For each accepted line, open one Issue naming its surface and evidence, and link it from the line (`Core/MAIN_AGENT_CONDUCT.md`, Durable Tracking of Findings); it becomes a Work Unit when the next milestone is planned. A refused line opens no Issue: it stays in the retrospective record with the Director's reason, so the next retrospective does not raise it again without saying what changed.

This step does not replace the Sprint Retrospective (`Workflows/SPRINT_CEREMONY.md`, Ceremony 4), which commits the team to one improvement for the next sprint. The release retrospective lists every friction it can evidence; which of them become work is the Director's choice in item 4.

**Output:** The `Release retrospective vX.X.X` Issue, with the Director's decision on each line, one linked Issue per accepted line, recorded before the next milestone's first Work Unit is planned.

---

# Exit Criteria

This workflow is complete when:

- The version bump is merged into `develop` (Step 2).
- `release/vX.X.X` is merged into `main`.
- Tag `vX.X.X` is on `main`, with a corresponding GitHub Release whose notes are derived from `CHANGELOG.md`.
- `develop` contains `main`'s tip, carried back by the Step 8 Pull Request. This is required on every release, not only when a defect fix was applied directly to the release branch — Step 6 always leaves a merge commit on `main` that `develop` would otherwise never see.
- `release/vX.X.X` branch is preserved on remote.
- Post-release health is confirmed.
- The release retrospective is recorded, with the Director's decision on each line and an Issue for each accepted line, before the next milestone's first Work Unit is planned (Step 11).

---

# Escalation

| Situation | Escalate to |
|---|---|
| Critical defect found during release testing | Director — release decision required |
| Director approval is delayed and blocking the release | Engineering Manager → Director |
| Post-release critical failure | Director + full incident response via Incident Response Workflow |

---

# Related Workflows

- Feature Development Workflow
- Hotfix Workflow
- Incident Response Workflow
- Sprint Ceremony Workflow
- Architecture Decision Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Workflow — Release

Severity: Mandatory
