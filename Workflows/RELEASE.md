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
- In an adopting project's first release, `develop` carries a `CHANGELOG.md` (An Adopting Project's First Release, below).

---

# An Adopting Project's First Release

**Applies to:** a project that adopted IA Engineering (`Workflows/ONBOARDING.md`), for its first release under the framework. Every later release follows the Steps below with nothing added.

An existing repository receives the adoption on `develop`, and `main` only at this release (`Workflows/ONBOARDING.md`, The adoption route). The Director may cut it as soon as the adoption is merged. The release runs the Steps below, from the project's root, with the framework's script at its imported path: `./ia-engineering/Adapters/scripts/release.sh`. Run from there, the script releases the project, not the framework: it reads the project's `develop`, `VERSION.md`, `CHANGELOG.md` and `Registry/work-units.yml`, and the project's CI. It runs `validate-framework.sh` inside `ia-engineering/`, as the project's Framework Validation check does.

The adoption installs neither `VERSION.md` nor `CHANGELOG.md`, and the script reads both. They are created in this order:

1. **Before Step 1, one Work Unit creates `CHANGELOG.md`**, merged into `develop` through a Pull Request like any other change. It accounts for every Work Unit the release will carry, its own included:

   ```
   # Changelog

   ## [Unreleased] - Bootstrap

   ### Added

   - IA Engineering adopted: the framework in ia-engineering/, its CI checks, git hooks and agents (WU-<PREFIX>-001)
   - CLAUDE.md, the contract every session reads first (WU-<PREFIX>-002)
   - This changelog, which the release reads (WU-<PREFIX>-003)
   ```

   - The heading is `## [Unreleased] - <milestone>`, and `<milestone>` is spelled exactly as the `milestone:` field of `Registry/work-units.yml`. The adoption's Work Units are registered against `Bootstrap` (`Registry/README.md`). Register every Work Unit merged before the first release against `Bootstrap` too: the release then carries one milestone, and Step 1 finds it on its own.
   - Each Work Unit is named in the final parenthesised group of its bullet, on the bullet's last line, as above. A Work Unit with nothing to record is named by the line `<!-- No changelog entry (WU-<PREFIX>-003): <reason> -->` in the section instead. Step 1 condition 5 counts nothing else: a Work Unit that is not named fails it.
   - The subsections are Keep a Changelog's: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`, and `### Notes` after them for upgrade notes.
   - From this Work Unit on, each Work Unit adds its own bullet to the section in its own commit. A project that prefers the framework's fragments creates `changelog.d/` instead (`changelog.d/README.md`). Step 2 item 3 then folds them in.
   - `VERSION.md` is not created yet. Step 1 reads "no `VERSION.md`, and no version section in `CHANGELOG.md`" as a first release, which Step 2 completes. Created now, `VERSION.md` would name a version with no section, and Step 1 fails on it.
2. **Step 1** runs as written. Its version line reads `no version released yet`, and it closes on `Ready for Step 2, the first release's`.
3. **Step 2 creates `VERSION.md`** in the bump Work Unit, with the version the Director decided:

   ```
   # Version

   **v0.1.0**

   Codename

   **Bootstrap**
   ```

   The script reads the first line that is exactly `**vX.Y.Z**`, and nothing else in the file. In the same commit, Step 2 renames `## [Unreleased] - Bootstrap` to `## [0.1.0] - Bootstrap`. Step 7 takes the release title from that heading. The bump Work Unit is registered against `Bootstrap` and named in the section, by a bullet or by the exemption line. Step 1 run again as `release.sh check --milestone Bootstrap` reads `VERSION.md says v0.1.0`, confirms conditions 1 and 5 against the versioned section, and closes on `Ready for Step 3`. Without `--milestone`, the versioned section marks `Bootstrap` released, and those two conditions report nothing left to confirm, as after any bump.

**A project that already has a `CHANGELOG.md`** keeps it. The Work Unit of item 1 adds the `## [Unreleased] - Bootstrap` section above the latest version, or, where the file already has an `## [Unreleased]` heading, adds ` - Bootstrap` to it. It leaves the existing sections as they are: a date where this workflow puts the milestone, as in `## [1.4.2] - 2026-05-01`, is read as a milestone name that no Work Unit uses. Because the file already has a version section, that Work Unit also creates `VERSION.md`, naming the latest version in it (`**v1.4.2**`), and Step 1 reads it as it reads a previous release. That includes the size of its section: a section of fewer than four non-empty lines, its heading counted, fails with `the CHANGELOG.md section for v1.4.2 looks too thin (3 lines)`. That section shipped before the adoption, so nobody pads it to pass. The Release Manager brings the failure to the Director with the rest of Step 1's report, as for any condition that cannot be met (`Employees/Management/RELEASE_MANAGER.md`, Escalation Rules), and the Director decides whether the release goes on to Step 2. After Step 2, Step 1 reads the new version's section instead (issue #494). Step 1 knows a version has shipped from its tag, `v1.4.2`. If the project never tagged it so, Step 1's closing line reads `Step 2 is already on this branch`, which is not true here: the conditions above that line still hold, and the release goes on to Step 2 (issue #494).

**A first release that carries more than one milestone** names them all in the heading, `## [Unreleased] - Bootstrap & v1.0`. Step 1 then cannot tell which one is released and fails with "cannot determine which milestone is being released". Run it once per milestone, `release.sh check --milestone Bootstrap`, then `release.sh check --milestone v1.0`.

**What the first release changes, beyond the Steps:**

- The Pull Request to `main` (Step 6) carries the whole adoption, so it is usually larger than the 1,500-line review limit. Where it is, `PR Size` fails until the Director applies `size/approved` to it, as on the adoption's Pull Request (`Standards/PULL_REQUEST_STANDARD.md`, Reviewability).
- The merge into `main` is the first change `main` receives since the adoption began. Whatever deploys from `main` deploys the adopted code from then on. The framework's `ghcr-publish.yml`, unless the project declined it (`README.md`, The steps that are not commands), runs for the first time, on that merge and again on the tag.
- Where `main` is the default branch, the Control Path Guard also starts at that merge. It is a `pull_request_target` workflow, which GitHub takes from the default branch, so it has run on no Pull Request so far (`Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 1). From then on it fails any Pull Request to `develop`, `main` or a release branch that touches a control path, the framework's pin `ia-engineering` included, unless the Director's login has just applied `control-change/approved` to it. While the repository variable `IAENG_DIRECTOR_LOGIN` is unset, it fails such a Pull Request closed. The next framework upgrade is such a Pull Request, so the Director sets the variable and creates the label before it.
- At Step 7, the local `main` still has no `ia-engineering/` until the pull brings the merge in, so `git switch main` prints `warning: unable to rmdir 'ia-engineering': Directory not empty`. Nothing needs doing.
- On a host other than GitHub, the `none` host cannot read CI or create a Release: Step 1 fails condition 2, and Step 7 pushes the tag and stops. Confirm CI by hand, and publish the notes that `release.sh notes vX.X.X` prints (`Adapters/scripts/hosts/README.md`).
- From this release on, `main` has the Work Unit registry, so `Workflows/HOTFIX.md` can be followed.

---

# Steps

## Step 1 — Release readiness review

**Actor:** Release Manager + Engineering Manager

Run `Adapters/scripts/release.sh check` from `develop`. It is read-only. In an adopting project, run `./ia-engineering/Adapters/scripts/release.sh check` from the project's root: it reviews the project (An Adopting Project's First Release, above).

| # | Condition | Mechanically checked? |
|---|---|---|
| 1 | All planned Work Units are merged into `develop` | **Yes** — every Work Unit registered against this milestone in `Registry/work-units.yml` must have a commit reachable from `develop` carrying its `Work Unit:` trailer. The milestone is derived as the one registry milestone with no `CHANGELOG.md` section yet, so this works at Step 1, *before* the Step 2 bump; pass `--milestone <name>` when more than one is unreleased |
| 2 | CI/CD is green on `develop` | **Yes** — the latest run's conclusion |
| 3 | No open critical or high defects remain | **Reported, not failed** — see below |
| 4 | The release version number and codename are agreed | **Partly** — `VERSION.md`'s version is read and compared against the one being asked about; whether that version and codename are the *agreed* ones is a Director judgment no script can make |
| 5 | Pending changelog entries account for every significant change | **Partly** — every Work Unit registered against the milestone must be named in the final parenthesised group of a bullet of the milestone's `CHANGELOG.md` section (the group on the bullet's last line; any id in that group counts) or in an exemption comment with its reason, or, in a repository that keeps changelog fragments as the framework repository does, have a fragment in `changelog.d/` (an entry, or `No changelog entry: <reason>`); after Step 2, a fragment still in `changelog.d/` fails. A repository without `changelog.d/` is held to the section alone. The section's presence and size are checked too. Whether each entry says the right thing is a reading task |

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
2. Update VERSION.md to the new version number and codename. An adopting project's first release creates it (An Adopting Project's First Release, above).
3. **If the repository keeps changelog fragments** (it has a `changelog.d/` directory, as the IA Engineering framework repository does), run `Adapters/scripts/release.sh assemble`. It folds every fragment in `changelog.d/` into the `## [Unreleased]` section of CHANGELOG.md, by category then Work Unit id, below the entries already there, and deletes the fragments. It refuses, changing nothing, if a fragment is malformed or CHANGELOG.md cannot be written. `changelog.d/README.md` describes the fragments. A repository without `changelog.d/` skips this item.
4. Update CHANGELOG.md to finalize the entries for this release, and rename `## [Unreleased]` to the version.
5. Commit following the Commit Standard: VERSION.md, CHANGELOG.md and, where item 3 ran, the fragment deletions, in the one bump commit.
6. Open a Pull Request to `develop`.
7. Merge the PR once CI passes.

This is why the release branch created in Step 3 needs no separate version-bump commit: the bump already lives on `develop`.

In a repository that keeps changelog fragments, Work Units do not edit CHANGELOG.md: each adds its fragment, `changelog.d/<Work Unit id>.md`, so two Pull Requests never conflict on the same category, and this step is the one place the fragments become CHANGELOG.md. In a repository without `changelog.d/`, Work Units keep editing CHANGELOG.md directly.

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

**Do not open the Pull Request with `main` as its head.** That is the obvious shape, and it cannot work wherever `develop` requires branches to be up to date. By default `develop` does not: `setup-branch-protection.sh` requires it on `main` and `release/*` only (Director, 22 Oct 2026). `develop` requires it where a project turns the setting on. It also does where a run of the script from a version before v0.0.15 turned it on and no run from v0.0.15 has turned it off since. From v0.0.16 a run keeps the value it finds, and never lowers it. "Up to date" compares the *head* against the *base*: a Pull Request whose head is `main` would have to contain `develop`'s tip to be mergeable, which is the opposite of what a back-merge does and would put unreleased work on `main` outside this workflow. GitHub reports it as `the head branch is not up to date with the base branch`, and no amount of waiting clears it. A branch cut from `develop` that merges `main` contains both tips, so it satisfies the rule wherever the rule is on, while carrying exactly the same history. That is why this step uses it whatever `develop`'s setting.

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

Version: 0.0.15

Status: Draft

Category: Workflow — Release

Severity: Mandatory
