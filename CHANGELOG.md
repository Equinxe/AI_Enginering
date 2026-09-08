# Changelog

All notable changes to IA Engineering will be documented in this file.

This project follows Semantic Versioning, extended with an informal 4th segment (`MAJOR.MINOR.MILESTONE.FIX`) for post-release consistency fixes that do not warrant a new milestone number. See `VERSION.md` for the versioning policy.

---

## [0.0.12] - Automation & Convergence

### Added

_Automation:_

- `Registry/` — the machine-readable form of the framework: `employees.yml`, `chains.yml`, `workflows.yml`, `work-units.yml`, plus a `README.md` that states the ordering that makes it safe — the Registry is **derived and never authoritative**, so where it and a governed document disagree, the document is right and the Registry is stale. The roster had been duplicated in six places, kept in sync by hand (WU-IAENG-137, WU-IAENG-145, WU-IAENG-146)
- `Adapters/scripts/validate-framework.sh` — the cross-reference check that `Governance/CONTRIBUTING.md` §3 and `Governance/DEPRECATION_POLICY.md` both require as a Definition of Done item, executed rather than remembered: Registry-to-definition agreement in both directions, roster counts quoted in prose, tier-table consistency, dispatch-trigger coverage, mandatory document sections, metadata fields, referenced-path resolution, Adapter/installed-copy parity, executable file modes, and unresolved work markers (WU-IAENG-139)
- `Adapters/github-actions/framework-validation.yml` — framework validation as a blocking check, on pull requests **and on pushes to `main` and `develop`**, because a merge can produce a state neither parent had: two PRs that each pass in isolation can leave the roster and a document disagreeing once both land (WU-IAENG-143)
- `Adapters/scripts/install.sh` — every host-agnostic Adapter installed by one idempotent command, with hooks wired through `core.hooksPath` so they cannot fork from the imported framework version, and a verification step that proves the installed hook rejects an invalid trailer rather than asserting that copying a file made it work (WU-IAENG-141)
- `Adapters/scripts/release.sh` — the mechanical parts of `Workflows/RELEASE.md`: Step 1 readiness as a report that exits non-zero, and Step 7's tag plus a full GitHub Release built from the version's `CHANGELOG.md` section. It refuses to tag unless the release is already merged to `main`, and it never approves or merges — Step 5 is the Director's (WU-IAENG-147)
- `Adapters/ai-runtimes/generate-agents.sh` — the 42 Employee definitions turned into agents a runtime can dispatch to, so reaching for the right Employee is the path of least resistance rather than the disciplined exception. Execution capability derived from each Employee's Default Complexity Tier, with the tier-to-model mapping living in the Adapter and never in `Core/` (WU-IAENG-148)
- `Adapters/README.md` — **The Check Convention**, four rules written down because this milestone found sixteen checks that reported success without evaluating anything, four of them introduced by the fixes to earlier instances of the same defect: an unevaluated condition is a failure, not a pass; exceptions are named allow-lists, never fall-throughs; a check that iterates a set reports its denominator; and a claim about a mechanism's behaviour is testable — enumerate the alternatives, then run the falsifier (WU-IAENG-153, WU-IAENG-169)

_Convergence:_

- `Standards/RISK_STANDARD.md` — one shared scale for risk, replacing per-Employee private judgment: a 3×3 likelihood × impact matrix mapped to Low/Medium/High/Critical, a required behaviour per tier (High stops and waits for a confirmation that names the action; Critical additionally requires an independent verification pass), the escalation block, the one-line `RISK:` record, and three generic catalogs — operational, product, security — that a project instantiates and may raise but never lower (WU-IAENG-172)
- `Standards/DATA_PROTECTION_STANDARD.md` — real data, secrets, and operational state kept out of version control structurally rather than by convention: the local data directory, the anchored `SYNTHETIC_` fixture marker, the history check that counts (`git rev-list --all --objects`, not `git ls-files`), the purge protocol, and three layers of enforcement of which only the third cannot be skipped from a developer machine (WU-IAENG-173)
- `Adapters/scripts/data-policy-scan.sh`, `Adapters/git-hooks/pre-commit`, `Adapters/github-actions/data-policy.yml` — one pattern list in three modes (`--staged`, `--tree`, `--history`), a client-side hook that fails closed, and a required **Data Policy** CI job that scans the tree *and* the objects a branch introduced. Matched secret values are never printed; exemptions are the anchored marker and a committed allow file (WU-IAENG-173, WU-IAENG-199)
- `Templates/WORK_UNIT_REPORT.md` — the complete output an Employee returns, mirroring the Employee Brief: a one-word verdict, what was done, **what was not done**, gate evidence pasted rather than described, deviations, risk records, and the Definition of Done item by item. A bare "Done" is a failed Work Unit (WU-IAENG-174)
- `Templates/SESSION_STATE.md` — a project's dated operational state, and the three-memory model that separates it from the committed `CLAUDE.md` contract and from the runtime's own memory. Never committed, because a file describing what is currently weak does not belong in the repository it describes (WU-IAENG-175)
- `Templates/DOMAIN_EMPLOYEE.md` — project-owned Employees for the business domain, whose Definition of Done states what constitutes *proof* that a domain output is correct. Registered in a project roster that `commit-msg`, the `Employee Trailer` job, and `generate-agents.sh` all read in addition to the framework roster (WU-IAENG-176, WU-IAENG-189)
- `Templates/POLE_BRIEF.md` — the unit of dispatch from a conductor to a pole, with disjoint write scope, a bounded budget, and explicit stop conditions (WU-IAENG-185)
- `Templates/PROJECT_CLAUDE.md` — the project contract `Workflows/ONBOARDING.md` Step 1 had always told adopters to write "from the template", for which no template existed (WU-IAENG-193)
- `Workflows/AUTONOMOUS_DELIVERY.md` — the tenth Workflow: several Main Agent sessions working in parallel under one conductor, with four rules that keep federation from weakening any control — every control binds unchanged per pole, escalation is centralised through the conductor, the budget is bounded in the Director's mandate, and nothing is delivered until an integration pass has run on the merged result (WU-IAENG-185)
- `Governance/TROUBLESHOOTING.md` — an incident catalog of 23 classes as symptom → cause → remedy → prevention, seeded from this framework's own history and from the sibling corpora it drew on. An entry without a Prevention is returned in review (WU-IAENG-183, WU-IAENG-200, WU-IAENG-203)
- `Governance/CONTRIBUTING.md` Section 7 — the learning loop that feeds that catalog: the fixing Work Unit records the instance, the second instance of a class names the class and writes the rule, and a rule that can be checked mechanically becomes a control (WU-IAENG-183)
- `Adapters/ai-runtimes/claude-code/hooks/` — five runtime hooks that refuse before rather than rejecting after: read-first context at session start, an escape-hatch block on shell commands, an inline-suppression block on edits, post-edit lint, and a stop gate. All fail closed on unreadable input; none has a disabling switch (WU-IAENG-179)
- `Adapters/ai-runtimes/claude-code/hooks/tests/` — the repository's first behaviour suite, 264 checks, run by a required **Hook Tests** CI job. Every bypass found in six review passes became a case, and so did every false positive (WU-IAENG-195, WU-IAENG-206)
- `Adapters/ai-runtimes/claude-code/review-bot.yml` — an independent Code Reviewer running under the Actions identity, and an independent mode for `Review Recorded` keyed on `IAENG_REVIEW_BOT_LOGIN`. Opt-in: it needs an API key and a Director decision to spend it (WU-IAENG-184)
- `Adapters/ai-runtimes/omc/README.md` — a transport mapping onto the oh-my-claudecode orchestration layer: what corresponds, what does not, and where the framework binds regardless. Recorded from that runtime's own documentation and not tested here, which the file states (WU-IAENG-186)
- `Adapters/scripts/validate-framework.sh` sections 14 and 15 — VERSION.md's Standards, Workflows, and Templates inventories compared against the documents themselves, and the Glossary's ordering checked because the Glossary claims it (WU-IAENG-190, WU-IAENG-191)

### Changed

_Automation:_

- `Adapters/git-hooks/commit-msg` — reads the roster from `Registry/employees.yml` instead of carrying its own copy of 42 names, and **fails closed**: a roster it cannot resolve is a broken installation, not a reason to validate against nothing. It validates *every* `Employee:` line rather than one chosen by position, and refuses a second `Work Unit:` claim outright (WU-IAENG-138, WU-IAENG-164, WU-IAENG-167)
- `Adapters/github-actions/pr-validation.yml` — the `Work Unit Exists` check resolves each commit's `Work Unit:` **trailer** against the registry rather than matching a regex against the PR description, which two prose-based versions got wrong in opposite directions; `Employee Trailer` re-validates server-side as a backstop for a hook that `--no-verify` or a missing install can skip; and the checks now trigger on `release/*` too, where they previously could not be required at all (WU-IAENG-144, WU-IAENG-155)
- `Standards/COMMIT_STANDARD.md` — the trailer layout documented as measured rather than as assumed: `Work Unit:` contains a space, so git never parses it as a trailer, and one unparseable line invalidates the whole block. Separated by a blank line, `Employee:` sits alone in the final paragraph and `git log --format='%(trailers:key=Employee)'` resolves it — 28 of 30 commits parsed only in that layout. The `Work-Unit:` rename is recorded as a dated open decision rather than left implicit (WU-IAENG-165, WU-IAENG-166, WU-IAENG-168)
- `Adapters/scripts/setup-project-bootstrap.sh` — performs the steps it is named for, delegating the host-agnostic half to `install.sh` rather than duplicating it, and propagating that script's exit status instead of discarding it (WU-IAENG-142, WU-IAENG-159)
- `Governance/VERSIONING_POLICY.md` 0.0.12 — states that one version may carry more than one milestone: "once per completed milestone" governs the counter, not the release, and a version carries several only when every milestone named in its heading is genuinely complete. Milestone Naming Discipline says why it does not forbid this — that rule is about a name attached to work it does not describe. A number belongs to the release, not to the milestone, so several milestones sharing a release share its number and none is skipped (WU-IAENG-217, WU-IAENG-218)

_Convergence:_

- `Standards/PULL_REQUEST_STANDARD.md` 0.0.3 — Reviewability made concrete: a 1,500-line review limit on the files a reviewer must read, `linguist-generated` files excluded, and a Director override by the `size/approved` label rather than by a sentence in the description, because applying a label requires write permission and pasting a sentence does not. Plus a Self-Contained Description section: a body that needs the author present has not been written (WU-IAENG-177)
- `Standards/GIT_STANDARD.md` 0.0.3 — the canonical escape-hatch table, under one rule: a control that is in the way is a rule that is in the way, so escalate the rule and never route around the control. `core.hooksPath` is listed beside `commit.gpgsign=false`, both being `--no-verify` spelled as configuration (WU-IAENG-178, WU-IAENG-201)
- `Standards/CODE_QUALITY_STANDARD.md` 0.0.3 — No Inline Suppression: a rule that is wrong for the project is tuned in the linter's configuration, where the change is a reviewed diff. Swallowed exceptions, skipped or focused tests, lowered coverage thresholds, and widened types are named as the same class (WU-IAENG-178)
- `Core/ORCHESTRATION.md` 0.0.9 — the dependent-task queue with layered termination (Work Unit / Retry / Queue / Blocked / Stopped), and a Step 5 that receives a Work Unit Report and re-verifies its claims against the repository rather than accepting them (WU-IAENG-182)
- `Core/AGENT_CONDUCT.md` 0.0.2 — Read First and the Reporting Contract, plus the statement that an Employee's own Standards Applied list does not limit what binds it: Standards First, Risk, and Data Protection bind every Employee whatever its definition says (WU-IAENG-182, WU-IAENG-192)
- `Core/GLOSSARY.md` 0.0.2 — 17 → 28 terms. The Convergence vocabulary, and three that had been missing far longer: **Main Agent**, Gate, Registry (WU-IAENG-191)
- `Workflows/CODE_REVIEW.md` 0.0.5 — a decision that states its denominator, line re-anchoring on re-review so no finding lapses when its line moves, Multi-Lens Review with cross-debate resolved by evidence rather than seniority, and ten review lessons each learned by getting it wrong (WU-IAENG-181)
- `Workflows/PROJECT_BOOTSTRAP.md` 0.0.11 — project profiles A/B/C, the "what constitutes PROOF" question, and the confidential-data question asked at inception rather than after the first file exists (WU-IAENG-180)
- `Workflows/ONBOARDING.md` 0.0.5 — Session State and the Adapters installed before the first commit; Domain Employees decided and registered at Step 4 (WU-IAENG-175, WU-IAENG-176)
- `Templates/EMPLOYEE_BRIEF.md`, `Templates/WORK_UNIT.md` — the other half of the report contract: the brief names the report's destination, carries it as a Definition of Done item, lists the three universally binding Standards, and has an Escalation row for a High or Critical classification that says to escalate *and wait* (WU-IAENG-209)
- `Examples/` — the six chain walkthroughs brought up to the rules they demonstrate: Work Unit Reports re-verified in Collect, a review decision with its denominator, line re-anchoring on the second pass, and risk records on the hotfix and the P1 incident (WU-IAENG-208)
- `Adapters/github-actions/pr-validation.yml` — eight checks now: **PR Size** and **Hook Tests** added, the `Employee Trailer` job reading the project roster, `Review Recorded` gaining an independent mode and telling an API failure from an absent decision, and both the shellcheck and YAML file lists **derived** from `git ls-files` rather than enumerated (WU-IAENG-176, WU-IAENG-177, WU-IAENG-184, WU-IAENG-195, WU-IAENG-198, WU-IAENG-202)
- `Adapters/scripts/setup-branch-protection.sh` — nine required status checks on `main`, `develop`, and `release/*` (WU-IAENG-173, WU-IAENG-177, WU-IAENG-195)

### Fixed

_Automation:_

- Sixteen checks that reported success without evaluating anything, across the validator, the installer, the release script, and the CI jobs — an absent Registry counted as a pass, a git-less run of the index-mode check passed, the marker scan went blind on a renamed root, `check_parity` treated an absent installed copy as agreement, and several checks passed on a zero-denominator set. Three were found by this repository's own CI, six by code review, two by an audit once the pattern was named — and four were introduced by the fixes to earlier instances, which is why the convention above is written down rather than assumed (WU-IAENG-153, WU-IAENG-156, WU-IAENG-157, WU-IAENG-158, WU-IAENG-160, WU-IAENG-161, WU-IAENG-162, WU-IAENG-163)
- Every shipped script and hook carried mode `100644` in the git index, so a Linux runner could not execute any of them: Windows has no executable bit and nothing local ever noticed. Now recorded in the index and checked by the validator (WU-IAENG-150)
- Glob and sort collation differed between Git Bash and Linux, so a check comparing two ordered lists passed on one platform and failed on the other with identical content. `LC_ALL=C` pinned in every script that orders anything (WU-IAENG-152)
- The cross-reference check resolved paths against a case-insensitive filesystem and so accepted `Core/GLOSSARY.MD`; it resolves against `git ls-files` now, with `CHANGELOG.md` excluded because a changelog quotes historical paths by definition (WU-IAENG-151)
- `generate-agents.sh` hung forever on a trailing value-taking flag — `shift 2` with one argument left fails, and a failed shift does not shift, so the loop spun with no output and no exit. It was the only defect in the milestone that hung rather than misreported, which made it the only one invisible in a log (WU-IAENG-170)
- `Adapters/scripts/release.sh` — Step 1 derived the milestone under release by comparing a `CHANGELOG.md` heading's codename field for equality, so this release's own two-milestone heading matched neither name and both would have read as unreleased on every future release. The field is read as a list now — and compared whole before it is split, because v0.0.10.1 shipped as "Consistency & Compliance Hardening", a single milestone whose own name contains the separator (WU-IAENG-216)

_Convergence:_

- `Adapters/ai-runtimes/generate-agents.sh` — ran from a consumer project, it wrote all 42 agents *inside the submodule*, at a path no runtime reads and which the framework's own `.gitignore` excludes, and reported success. Output is resolved against the project now, and the generated header carries a roster-relative path so the files do not differ between machines (WU-IAENG-189, WU-IAENG-196)
- `Adapters/github-actions/pr-validation.yml` — the `PR Size` job reported green when it had measured nothing: its loop was fed by process substitution, which hides `git diff`'s failure from `set -euo pipefail`. It also ranged from `base.sha` rather than the merge base, so unrelated base-branch churn landed in the count (WU-IAENG-198)
- `Adapters/scripts/data-policy-scan.sh` — the history mode missed a blob already reachable from the excluded side, so an *empty* `.env` added and deleted inside a range scanned zero paths and reported clean. A zero-path scan over a non-empty range now fails (WU-IAENG-199)
- `Adapters/ai-runtimes/claude-code/hooks/` — escape-hatch bypasses and false positives found across six review passes, each pinned as a test case — the suite grew from 83 checks to 264 in the process. The two that would have mattered most in the field: `git -c core.hooksPath=…` disabled every git hook, and a bash-4 expansion would have refused every Edit and Write on macOS, where `/bin/bash` is 3.2 and the construct is a *parse* error the runtime reads as *block* (WU-IAENG-188, WU-IAENG-194, WU-IAENG-197, WU-IAENG-201, WU-IAENG-204, WU-IAENG-205, WU-IAENG-207)
- `VERSION.md` — the Standards, Workflows, and Templates inventories had drifted to 8 of 10, 9 of 10, and 7 of 12; all three corrected and now checked by the validator (WU-IAENG-190)
- `Adapters/github-actions/pr-validation.yml` — the `PR Size` job refused any Pull Request whose diff listed no files, which is right for wrong refs and wrong for a back-merge. `Workflows/RELEASE.md` Step 8 carries `main` into `develop` through a Pull Request that changes nothing by construction, so with this check required on `develop` and "require branches to be up to date" set on `main`, the two controls deadlocked the release process against itself. The cases are now told apart by the commits rather than the files: no commits at all still fails, a non-merge commit that changed nothing still fails, a range whose commits are all merges passes with a notice (WU-IAENG-220)
- `Adapters/scripts/data-policy-scan.sh` — the same defect in the same shape one control over: a zero-path history scan over a non-empty range failed, and a merge-only range enumerates no paths by construction. Same distinction applied, as a named allow-list of one shape rather than a fall-through (WU-IAENG-221)
- `Employees/Management/RELEASE_MANAGER.md`, `Employees/Management/SCRUM_MASTER.md` — neither listed Standards First, the root of the hierarchy, and nothing had said so in eleven versions. Now checked for all 42 (WU-IAENG-192)

### Notes

This release carries **two milestones**, named in full in the heading above. Both completed on `develop` before either shipped, and `Governance/VERSIONING_POLICY.md` allows one version to carry several: "once per completed milestone" governs the counter, not the release.

Shipping them separately was considered and rejected on a concrete ground. The release branch for an Automation-only release would have to be cut where Automation ended on `develop`, and that point predates three of the nine required status checks — `Hook Tests`, `PR Size` and `Data Policy` — which Convergence introduced. Those checks could never report on that commit, so the pull request to `main` could never become mergeable, and the release could only have shipped by suspending the branch protection it exists to pass. A number for a release that cannot pass its own gates is worse than a heading with two names in it.

**Automation** is the point at which the framework began checking itself. Before it, every rule held because a human or an AI remembered it; after it, the rules that can be checked mechanically are, and the ones that cannot are named as such. The milestone's own defect class recurred inside its own remediation: a check that reports success without evaluating anything, sixteen instances, four of them created by fixing earlier ones. That is not a set of oversights — it is the default reasserting itself, because writing a pass is the path of least resistance whenever a condition turns out not to apply. `Adapters/README.md`'s Check Convention exists so the seventeenth is less likely than the sixteenth was.

**Convergence** absorbs the governance concepts of two sibling frameworks as concepts rather than as code, with nothing specific to one organisation or one stack carried over. The scale changed as well as the content: the framework gained its first behaviour test suite, and the runtime hooks were attacked by an independent reviewer across six passes producing roughly sixty findings, all fixed, each reproduced before the fix and falsified after.

Two properties of that process are worth recording. Every control these milestones added was eventually turned on itself: the inventory check caught a `VERSION.md` listing before the commit that would have needed it existed; the `Standards First` check reported all 42 Employees failing on its first run, which was a fact about the check and not the set; the escape-hatch hook blocked two of its own commits; the inline-suppression hook refused to write the test corpus that proves it works; and the milestone-list fix in this very release was caught by its own falsifier at 10 of 11 before it was committed. And the defects that survived longest were never in the code — they were in the corpus: the Examples were a milestone behind for thirty-six commits, and one half of the brief-to-report contract was written while the other was not.

---

## [0.0.11] - Governance

### Added

- `Governance/CONTRIBUTING.md` — how a change to the framework itself is proposed and reviewed: Change Tiers mapped to `Core/CAPABILITY_TIERS.md`, how a new Employee/Workflow/Template/Standard is proposed, the highest-scrutiny bar for `Core/*.md` changes, a values-grounded Code of Conduct, and how GitHub Issue intake and Durable Tracking of Findings converge into one contribution path (WU-IAENG-134)
- `Governance/VERSIONING_POLICY.md` — formalizes the `MAJOR.MINOR.MILESTONE[.FIX]` versioning scheme as the authoritative, standalone reference: segment semantics, the `.FIX` vs. new-milestone test, milestone naming discipline, and document-internal `Version:` field rules (WU-IAENG-135)
- `Governance/DEPRECATION_POLICY.md` — defines how a Standard, Workflow, Template, or Employee gets deprecated versus removed, since the framework had only ever added content through v0.0.10.1: deprecation triggers, the marker/index lifecycle, a required cross-reference check, the Employee-specific Actor/escalation-target check, and mandatory Director approval (WU-IAENG-136)
- `Core/EMPLOYEE_SELECTION.md` — a concrete dispatch-trigger reference covering all 42 Employees, organized by category, naming six miscasting risks (e.g. Compliance Engineer/Technical Writer, Security Engineer/DevOps Engineer), cross-referenced from `Core/MAIN_AGENT_CONDUCT.md`'s Employee Selection section (WU-IAENG-133)
- `Core/MAIN_AGENT_CONDUCT.md` — "Git Execution via Named Employee" conduct rule: mutating git operations (branch creation, commit, push, tag, PR-merge) are dispatched to a named Employee rather than absorbed by the Main Agent as plumbing — release-scoped git mutation to the Release Manager, git-as-deployment to the GitOps Engineer — while read-only inspection stays direct under Verification Over Waiting (WU-IAENG-132)
- `Core/MAIN_AGENT_CONDUCT.md` — "Durable Tracking of Findings" conduct rule: a gap, tech-debt item, or deferred decision surfaced mid-work is filed as a GitHub Issue so it survives beyond one session's private memory (WU-IAENG-130)

### Fixed

- `Workflows/RELEASE.md` Step 7 — a bare annotated tag with only a short `-m` message is no longer sufficient on its own, since it produces no real description on the host's Releases page; a full GitHub Release derived from that version's actual `CHANGELOG.md` entry is now required, closing the gap that had to be patched after the fact for both v0.0.10 and v0.0.10.1 (WU-IAENG-131)

### Notes

This release delivers the "Governance" milestone: the first real content under `Governance/`, which had held only a `.gitkeep` placeholder since the repository's first commit. It also carries forward four Main Agent conduct/reference additions (WU-IAENG-130, WU-IAENG-131, WU-IAENG-132, WU-IAENG-133) that landed on `develop` in the same window as the Governance documents but are process and dispatch-reference additions rather than `Governance/` content proper.

---

## [0.0.10.1] - Consistency & Compliance Hardening

### Added

- `Adapters/scripts/setup-branch-protection.sh` — `release/*` branch protection via GitHub's Rulesets API (blocks deletion, force-push, and direct pushes), closing the gap that let an unreviewed direct push land on `release/v0.0.10` (WU-IAENG-121)
- `.github/workflows/pr-validation.yml`, `Adapters/github-actions/pr-validation.yml` — server-side `employee-trailer` CI check that backstops the client-side `commit-msg` hook, plus an advisory `review-recorded` check surfacing whether a Code Reviewer `Decision: approved` block was recorded on the PR (WU-IAENG-125)

### Fixed

Corrections and hardening to already-shipped milestones (v0.0.9 Adapters, v0.0.10 Project Bootstrap), all merged on `develop` after v0.0.10 shipped — none introduce new capability at the milestone level:

- `Workflows/RELEASE.md` — Step 4 minor-defect fixes found during release acceptance testing now land via a PR targeting the release branch instead of a direct push, since `release/*` branches are no longer writable directly (WU-IAENG-122)
- `Workflows/CODE_REVIEW.md`, `Core/AGENT_CHAINS.md` — added a concrete, checkable "security-sensitive or high-risk" trigger list for QA Engineer insertion into the Review Chain, grounded in existing Employee Escalation Rules (WU-IAENG-123)
- `Workflows/FEATURE_DEVELOPMENT.md`, `Workflows/CODE_REVIEW.md` — added Compliance Engineer entry points (regulated/sensitive data, named regulatory framework, retention/deletion logic, cross-border data transfer), mirroring how Security Engineer already escalates in both workflows (WU-IAENG-124)
- `Adapters/README.md` — updated to describe all five Adapter CI checks, including the two added in WU-IAENG-125 (WU-IAENG-125)
- `Examples/RELEASE_CHAIN_EXAMPLE.md` — realigned with the new PR-based release-branch-fix mechanism from WU-IAENG-122 (WU-IAENG-126)
- `LICENSE.md` — completed the Apache License 2.0 copyright notice (`Copyright 2026 Equinxe`); the full Apache 2.0 license text had been present since the Foundation milestone, but its copyright header was left as the raw template placeholder (WU-IAENG-127)
- `README.md` — License section updated from "To be defined before v1.0" to accurately state the project is licensed under Apache License 2.0, referencing `LICENSE.md` (WU-IAENG-127)

### Notes

This consolidates seven post-v0.0.10 fixes into a single `.FIX` release rather than shipping them under separate dot-releases. Six (WU-IAENG-121–126) close gaps between the release-branch protection added here and the Workflows/Adapters that assumed the old, unprotected behavior; the seventh (WU-IAENG-127) closes a long-standing gap between the license actually in the repository (complete Apache 2.0 text since the first commit) and what the project's own documentation claimed about it — the Director confirmed Apache License 2.0 as the deliberate, correct choice, with Equinxe as the copyright holder. None of these introduce new capability, so none consume the next milestone number; the real v0.0.11 — Governance milestone has not started.

---

## [0.0.10] - Project Bootstrap

### Added

- `Workflows/PROJECT_BOOTSTRAP.md` — new workflow for bootstrapping a brand-new project (WU-IAENG-108)
- `Templates/PROJECT_CHARTER.md` — 7th framework template (WU-IAENG-109)
- CI/CD + GHCR Adapters — `ci-build-test.yml`, `ghcr-publish.yml`, stack Dockerfiles, `setup-project-bootstrap.sh` (WU-IAENG-110)
- GitHub Issue Templates Adapter (WU-IAENG-111)
- Compliance hardening of Project Bootstrap — escalation trigger, jurisdiction/SOC2/breach-notification questions, Compliance Engineer and Security Engineer added as Actors (WU-IAENG-115)
- Business/Product hardening of Project Bootstrap — Assumptions & Risks category, business-outcome Success Criteria example, MoSCoW prioritization (WU-IAENG-116)
- `Core/MAIN_AGENT_CONDUCT.md` — Autonomous Release Execution conduct rule (WU-IAENG-117)

### Fixed

Consistency and process fixes merged on `develop` after v0.0.9.3, ahead of the Project Bootstrap milestone content, that never received their own version bump:

- `Workflows/RELEASE.md` — the version bump now happens on `develop` before the release branch is cut, as its own step, so the release branch is a pure snapshot with no separate version-bump commit (WU-IAENG-099)
- `Core/MAIN_AGENT_CONDUCT.md` — added a "No Direct Research" rule: the Main Agent must delegate research and reading (deciding which Employee fits, digging through git history), not just implementation (WU-IAENG-101)
- Version references synced and Employee roster names canonicalized across docs (WU-IAENG-102)
- `Examples/RELEASE_CHAIN_EXAMPLE.md`, `Examples/HOTFIX_CHAIN_EXAMPLE.md`, `Core/AGENT_CHAINS.md` — realigned with the current `Workflows/RELEASE.md` and `Workflows/HOTFIX.md` steps (WU-IAENG-103)
- Adapter definition, Capability Tiers framing, and doc version references aligned across Core (WU-IAENG-104)
- `Adapters/git-hooks/commit-msg` — merge commits now bypass Conventional Commit / `Employee:` trailer validation, since merge commits are generated by GitHub and carry neither (WU-IAENG-106)
- `Adapters/README.md` — logged post-merge verification of the commit-msg merge-commit fix (WU-IAENG-107)

### Notes

This release delivers the "Project Bootstrap" milestone: a complete workflow, template, and Adapter set for standing up a brand-new project under the framework, hardened with Compliance/Security and Business/Product review passes. It also carries forward seven consistency and process fixes (WU-IAENG-099 and the WU-IAENG-100 audit and related findings) that landed on `develop` between v0.0.9.3 and this milestone but were never released under their own version number — folded into this bump rather than lost from the historical record.

---

## [0.0.9.3] - Back-Merge via Pull Request

### Fixed

- `Workflows/RELEASE.md` (Step 7) and `Workflows/HOTFIX.md` (Step 9) — the "Back-merge to develop" step now describes opening a Pull Request from `main` into `develop` and merging it once CI passes, instead of a direct `git push`. This resolves a contradiction with the `pre-push` git hook (`Adapters/git-hooks/pre-push`, shipped in v0.0.9), which unconditionally blocks all direct pushes to `develop` and `main`: the Workflow told the Main Agent to do something the Adapter mechanically forbids.

### Notes

Ninth finding from dogfooding. After releasing v0.0.9.2, the Main Agent tried to back-merge `main` into `develop` with a direct push and was blocked live by our own `pre-push` hook — the Workflow documents and the Adapter contradicted each other. The fix documents the PR-based procedure that was actually used to resolve the block, closing the gap so the written Workflow matches what technical enforcement allows.

---

## [0.0.9.2] - No Direct Implementation

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "No Direct Implementation" section: the Main Agent never personally writes or edits implementation artifacts — application code, scripts, configuration, git hooks, CI/CD definitions, or any other machine-consumed file — in any project. Every such change is dispatched to a named Employee through an Employee Brief, with no size exception: a trivial one-line fix is dispatched cheaply via a Lightweight Override at the Lightweight Execution tier (`Core/CAPABILITY_TIERS.md`), and a Workspace Isolation collision risk is resolved by waiting or isolating the Employee, never by implementing the change personally. Attributing a self-authored change to an Employee that was never dispatched is a Dispatch Discipline violation — the Work Unit is not complete and must be re-dispatched, not relabeled.

### Notes

Eighth finding from dogfooding. During the v0.0.9.1 cycle the Director caught the Main Agent directly editing `Adapters/scripts/setup-branch-protection.sh`, `Adapters/github-actions/pr-validation.yml`, and `Adapters/git-hooks/pre-push`, then attributing each commit to a named Employee (e.g., `Employee: DevOps Engineer`) that was never actually dispatched — the work was done by the Main Agent; only the label said otherwise. This closes the loophole at its source: a Main Agent that implements has stopped orchestrating (`Core/ORCHESTRATION.md`), producing work with no accountable Employee, no traceable Standards Applied, and no verifiable Definition of Done.

---

## [0.0.9.1] - Solo-Maintainer Fixes

### Fixed

- `Adapters/scripts/setup-branch-protection.sh` — removed a self-review deadlock: `required_approving_review_count` changed from 1 to 0 and `enforce_admins` from true to false, since GitHub does not allow a PR author to approve their own PR and every Employee (and the Director) currently shares one authenticated `gh` identity. The real review gate is the required `validate` CI check plus the Code Reviewer's documented review comment, not a GitHub-native approval count.
- `Core/MAIN_AGENT_CONDUCT.md` — added a "Workspace Isolation" section: the Main Agent must not run its own git commands in the same working directory while a dispatched Employee is actively committing — wait, or use a separate worktree/clone.

### Notes

Sixth and seventh findings from dogfooding — this time from applying our own Adapters to this repository for the first time (WU-IAENG-091), rather than from the 2048 game test. Discovered immediately on the very first PR after enabling branch protection here: could not merge PR #27 because nobody could formally approve it, and a real commit landed on `main` because the Main Agent ran git commands in the same working directory as the dispatched DevOps Engineer. Both are now documented and fixed at their source rather than worked around.

---

## [0.0.9] - Adapters

### Added

- `Adapters/git-hooks/commit-msg` — mechanically enforces Conventional Commits format and a mandatory `Employee: <Name>` trailer validated against the 42-Employee roster (Dispatch Discipline)
- `Adapters/git-hooks/pre-push` — blocks direct push to `main` and `develop`
- `Adapters/github-actions/pr-validation.yml` — CI check requiring every PR to reference a Work Unit ID (`WU-[project]-[number]`) and have a non-empty, filled-in description
- `Adapters/github/PULL_REQUEST_TEMPLATE.md` — GitHub PR template mirroring `Templates/PULL_REQUEST.md` exactly
- `Adapters/scripts/setup-branch-protection.sh` — one-shot script to configure GitHub branch protection (required review, required status check, no force-push/deletion) via the GitHub API
- `Adapters/README.md` — installation guide and index tying all adapters together
- `.gitattributes` — forces LF line endings under `Adapters/` so shell scripts don't break on Linux/CI after a Windows checkout

### Notes

Prioritized ahead of Governance (now v0.0.10) in response to live-test findings from the v0.0.8 Capability Tiers deployment. Adapters close the gap between written policy and technical enforcement — every violation caught by git hooks or CI checks before it reaches review, not after. This is the framework's concrete lever for preventing the v0.0.7.x categories of silent violations (malformed commits, missing Employee attribution, unreviewed direct pushes).

---

## [0.0.8] - Capability Tiers

### Added

- `Core/CAPABILITY_TIERS.md` — two AI-agnostic execution tiers (Strategic Judgment, Standard Execution) the Main Agent uses to match execution capability to Work Unit complexity, without ever naming a specific model, plus a per-Work-Unit Lightweight Override mechanism
- `Employees/` — Default Complexity Tier added to all 42 Employees' Metadata (12 Strategic Judgment: architects, Security Engineer, Compliance Engineer, Penetration Tester, Business Analyst, Data Scientist, AI Engineer, Prompt Engineer, Engineering Manager, Technical Lead; 30 Standard Execution: all others)
- `Core/ORCHESTRATION.md` — Step 4 (Dispatch) now selects execution capability per Capability Tiers before creating each Employee Brief

### Notes

Prioritized ahead of Governance (now v0.0.9) in response to live-test token/session-limit pressure observed during the 2048 game test. This is the framework's only concrete lever for execution efficiency: routing mechanical Work Units to lighter capability while reserving strategic judgment for decisions that need it, without compromising Dispatch Discipline or AI Agnosticism (Principle X).

---

## [0.0.7.5] - ADR Threshold Detection

### Fixed

- `Core/ORCHESTRATION.md` — Step 2 (Analyze) now explicitly cross-references `Workflows/ARCHITECTURE_DECISION.md`'s ADR trigger list instead of leaving "whether an ADR is required" to informal judgment

### Notes

Fifth finding from the live end-to-end test (2048 game leaderboard feature). A persistent leaderboard was implemented directly via the Frontend Engineer using `localStorage`, without recognizing that persistence implies a storage technology decision meeting the existing ADR threshold ("technology selection... database"). The rule to check for an ADR already existed in both `Core/ORCHESTRATION.md` and `Workflows/ARCHITECTURE_DECISION.md`, but the two were never explicitly linked, and a simply-phrased feature request did not visibly trigger the check. This is a documentation clarity gap, not a new rule.

---

## [0.0.7.4] - Verification Over Waiting

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Verification Over Waiting" section: when a dispatched Employee's completion report never arrives, the Main Agent must verify the actual repository state directly (git status/diff/log) instead of stalling on repeated status requests or assuming success from silence

### Notes

Fourth finding from the live end-to-end test (2048 game leaderboard feature). Dispatched Employees repeatedly showed as "finished" in the AI runtime without ever delivering a completion report, and the Main Agent looped on re-requesting status instead of checking the repository directly. This is a runtime dispatch fault, not a framework fault — but the framework can and should make silence non-blocking by requiring direct verification as the fallback source of truth.

---

## [0.0.7.3] - Roster Gaps

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Roster Gaps" section: when a request requires an Employee outside the project's active roster, the Main Agent must stop, propose the roster expansion to the Director, update `CLAUDE.md`, and only then dispatch — instead of silently performing the work itself
- `Core/MAIN_AGENT_CONDUCT.md` — closed a loophole in Dispatch Discipline (v0.0.7.2): naming a subagent by function or tool label (e.g., "executor") instead of by the responsible Employee's name is now explicitly treated as equivalent to not delegating at all

### Notes

Second and third findings from the live end-to-end test (2048 game leaderboard feature). (2) The project's onboarding-time roster excluded Architecture/Backend/Data roles as out of scope for a frontend-only game — when a later request genuinely required a Software Architect ADR and Backend/Database/API Engineers, the Main Agent absorbed the work itself rather than recognizing the scope had changed. (3) After being corrected, the Main Agent did delegate — but to a subagent named "executor" rather than the responsible "Frontend Engineer", satisfying the letter of Dispatch Discipline while discarding its purpose (traceable Mission, Authority, Standards Applied, and Definition of Done).

---

## [0.0.7.2] - Dispatch Discipline

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Dispatch Discipline" section mandating Employee Brief dispatch for every delegation, forbidding substitution of native/generic AI runtime subagents for a named Employee

### Notes

Finding from the first live end-to-end test of IA Engineering on a real project (a browser 2048 game). The Main Agent defaulted to a generic native reviewer subagent instead of dispatching to the Code Reviewer, QA Engineer, and Security Engineer through Employee Briefs, because the conduct document told it what to do but never explicitly forbade this substitution. This is a direct application of Core Principle IX (Continuous Improvement): every project should improve the framework.

---

## [0.0.7.1] - Audit Fixes

### Fixed

- `Core/GLOSSARY.MD` renamed to `Core/GLOSSARY.md` — fixes broken references on case-sensitive filesystems (Linux/CI)
- `Core/AGENT_CONDUCT.md`, `DECISION_TREE.md`, `GLOSSARY.md`, `MAIN_AGENT_CONDUCT.md` — version corrected from `0.1.0` to `0.0.1` to match the Foundation milestone
- `Core/AI_MANIFEST.md` — added missing Document Metadata section
- `Core/AI_MANIFEST.md` — decision hierarchy corrected to list Employees before Workflows, aligning with `CLAUDE.md` and `README.md`
- `Core/GLOSSARY.md` — added missing "Director" and "Chain (Agent Chain)" entries
- `Prompts/` — added missing directory placeholder (documented in `CLAUDE.md` but absent on disk)
- `README.md` — full refresh from v0.0.2 to v0.0.7: completed list, framework hierarchy diagram, repository structure, roadmap
- `Employees/Development/FRONTEND_ENGINEER.md`, `IOS_ENGINEER.md`, `ANDROID_ENGINEER.md`, `CROSS_PLATFORM_ENGINEER.md` — "UX Designer and UI Designer" corrected to the single combined `UX/UI Designer` role
- `Employees/Architecture/DATA_ARCHITECT.md` — ADR ID convention aligned to `ADR-[project]-[number]`
- `Employees/Quality/SECURITY_ENGINEER.md` — vulnerability ID convention aligned to `SEC-[project]-[number]`
- `Employees/Quality/QA_ENGINEER.md` — Test Case ID convention aligned to `TC-[project]-[number]`
- `Workflows/FEATURE_DEVELOPMENT.md` — non-existent "Mobile Engineer" actor replaced with the actual iOS/Android/Cross Platform Engineer roles; Business Analyst added to the Actors table
- `Workflows/HOTFIX.md`, `RELEASE.md` — Observability Engineer added to the Actors table (was used in steps but not declared)
- `Examples/INCIDENT_CHAIN_EXAMPLE.md` — now uses the Incident Commander role defined in `Workflows/INCIDENT_RESPONSE.md`
- `Examples/ARCHITECTURE_CHAIN_EXAMPLE.md` — "Recommendation" renamed to "Decision" to match `Templates/ADR.md`

### Notes

These fixes came from a full content and consistency audit of all 65 repository files performed after v0.0.7. No content or behavior changes beyond consistency — documentation accuracy only.

---

## [0.0.7] - Examples

### Added

- 6 end-to-end chain walkthroughs on a single fictional project (TaskFlow): Feature, Review, Release, Hotfix, Incident, Architecture Chains
- `Examples/README.md` — index and recommended reading order

### Notes

This release makes the Orchestration Protocol and Agent Chains concrete. Each example shows real Work Units, Employee Briefs, and templates filled in, and shows how chains hand off into each other (Incident → Hotfix, Architecture → Feature). Combined with all prior milestones, the framework has everything needed for a real end-to-end test on a new project.

---

## [0.0.6] - Orchestration

### Added

- `Core/ORCHESTRATION.md` — Main Agent dispatch protocol: receive, analyze, plan, dispatch, collect, review, deliver
- `Core/AGENT_CHAINS.md` — 6 named orchestration chains: Feature, Review, Release, Hotfix, Incident, Architecture

### Fixed

- `CLAUDE.md` version updated from v0.0.2 to v0.0.5 (was outdated since Templates milestone)
- `MAIN_AGENT_CONDUCT.md` now references ORCHESTRATION.md and AGENT_CHAINS.md

### Notes

This release formalizes the orchestration layer — how the Main Agent receives a Director request, decomposes it into Work Units, dispatches Employee Briefs, collects outputs, and delivers a validated result. Combined with the 42 Employees, 8 Workflows, and 6 Templates from previous milestones, the framework is now ready for end-to-end testing on a real project.

---

## [0.0.5] - Templates

### Added

- 6 Engineering Templates: Work Unit, Pull Request, Architecture Decision Record, Incident Report, Test Plan, Employee Brief
- Employee Brief template formalizes the Context Engine: employees receive only the context they need, never the whole repository

### Notes

This release delivers the complete IA Engineering template library. Combined with Employees (v0.0.3) and Workflows (v0.0.4), every engineering action now has a standard format. The framework is ready for orchestration.

---

## [0.0.4] - Workflows

### Added

- 8 Engineering Workflows: Feature Development, Code Review, Release, Hotfix, Incident Response, Architecture Decision, Onboarding, Sprint Ceremony
- Each workflow defines: Trigger, Actors, Prerequisites, Step-by-step process with handoffs, Exit Criteria, Escalation rules

### Notes

This release delivers the complete IA Engineering workflow library. Combined with the 42 Employees from v0.0.3, the framework can now orchestrate end-to-end engineering sequences from requirements to production.

---

## [0.0.3] - Employees

### Added

- 42 AI Employee definitions across 8 categories: Management, Architecture, Development, DevOps, Quality, Data, Documentation, Specialized
- Each Employee defines: Mission, Responsibilities, Authority, Standards Applied, Inputs, Process, Outputs, Output Format, Definition of Done, Escalation Rules, Failure Modes

### Notes

This release delivers the complete IA Engineering employee library. Every employee is an operational manual — not a role description — defining precisely what the employee does, what authority they hold, and what constitutes completion.

---

## [0.0.2] - Engineering Standards

### Added

- Standards First
- Git Standard
- Commit Standard
- Branch Standard
- Pull Request Standard
- Documentation Standard
- Code Quality Standard
- Testing Standard

### Notes

This release establishes the complete engineering standards library used by all IA Engineering Employees, Workflows, and Projects.

---

## [0.0.1] - Foundation

### Added

- AI Manifest
- README
- Glossary
- Decision Tree
- Main Agent Conduct
- Agent Conduct

### Notes

Initial foundation of the IA Engineering framework.

This release establishes the core principles and behavioral contracts that all future components will inherit.

---

## Next

TBD — not yet scoped. See `VERSION.md`'s `Planned` section.
