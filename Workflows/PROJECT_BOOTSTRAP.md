# Project Bootstrap Workflow

---

# Purpose

This workflow defines how a brand-new project is created from nothing: before a repository has any code, before a technology stack is chosen, before any Employee roster is active.

It covers the phase that comes **before** `Workflows/ONBOARDING.md`. Onboarding assumes a repository already exists (or is being created) and a project objective is already known; it imports the framework and activates the Employee roster. Project Bootstrap exists because that assumption does not hold for a project that has not been defined yet — someone has an idea, not yet a repository, not yet a stack, not yet a scaffolded CI/CD pipeline.

This workflow owns: **repo from nothing → stack decided → CI/CD, GHCR, and issue templates scaffolded.**
`Workflows/ONBOARDING.md` owns: **roster activation → first Work Unit → readiness confirmation.**

The two workflows form a single continuous flow but are deliberately kept separate documents, because they answer different questions (business/technical discovery vs. operational activation) and are driven by different Employees.

---

# Trigger

The Director states this convention to their AI assistant: the keyword phrase **"project creation"** (or **"create project"**) signals that a brand-new project is being started and this workflow should begin. The French-language alias **"création de projet"** is an accepted equivalent of the same trigger, not a separate mechanism.

This is a documented convention, not a runtime feature. Per `Core/AI_MANIFEST.md` Principle X (AI Agnostic), this workflow does not name, assume, or depend on any specific AI runtime, tool, or slash-command mechanism to detect the trigger. How a given AI runtime is configured to recognize this phrase (if at all) is the concern of that project's own AI-runtime configuration — out of scope for this framework document.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Director | Authorizes project creation, answers Phase A and Phase B questions, approves the Stack Decision ADR |
| Main Agent | Facilitates the entire flow, asks the Phase A and Phase B questions, coordinates the handoff to `ONBOARDING.md` |
| Business Analyst | Co-owns Phase A framing and questions — business goal, scope, success criteria |
| Product Manager | Co-owns Phase A framing and questions — target users, stakeholders, lifecycle |
| Software Architect | Owns Phase B, drafts the Stack Decision ADR |
| DevOps Engineer | Scaffolds the CI/CD Adapter and GHCR Adapter once the stack is known |
| GitOps Engineer | Consulted on CI/CD and GHCR Adapter scaffolding |
| Compliance Engineer | Consulted on Phase A questions #6 (compliance/regulatory) and #7 (data sensitivity) |
| Security Engineer | Consulted on Phase A questions #6 (compliance/regulatory) and #7 (data sensitivity) |

---

# Prerequisites

Before this workflow begins:

- The Director has an idea for a new project, even if only loosely defined.
- No repository, stack, or Employee roster exists yet for this project.
- The Director is available to answer Phase A and Phase B questions — this workflow cannot proceed on assumptions.

---

# Steps

## Step 1 — Phase A: Project questions

**Actor:** Main Agent, with Business Analyst and Product Manager

The Main Agent asks the Director a set of business-before-tech questions, roughly twenty in number as an order of magnitude, not a fixed count. Use judgment: ask what is genuinely useful to define the project, skip what does not apply. Ask them in numbered rounds, each question with a recommended answer where what is already known supports one: each round is one numbered batch under `Core/MAIN_AGENT_CONDUCT.md`, Presenting a Decision to the Director, item 3, ordered by dependency as the Business Analyst does (`Employees/Specialized/BUSINESS_ANALYST.md`, Clarification Rounds): a round holds the questions that can be answered now, and the next round holds those the answers unblocked. Structure the questions into these categories:

1. **Business goal** — What problem does this solve? What is the one-sentence value proposition?
2. **Target users / consumers** — Who uses this? Are they internal, external, or another system?
3. **Scope & non-goals** — What is explicitly in scope for v1? What is explicitly out of scope?
4. **Success criteria** — How is "working" measured? What is the definition of done for launch?
5. **Constraints** — Is there a deadline, a budget, a team size, existing systems to integrate with?
6. **Compliance / regulatory** — Does GDPR, HIPAA, PCI, SOC 2, ISO 27001, data residency, or licensing apply? What is the jurisdiction / geography of users and data processing — this is upstream of every other question here, since "does GDPR apply" cannot be answered without knowing where data subjects and processing are located. What are the breach notification obligations (e.g., GDPR Art. 33/34's 72-hour window) and data subject rights (access/erasure/portability, Art. 15-20) — both drive architecture decisions (logging, export/delete capability) and belong at inception, not retrofitted later.
7. **Data sensitivity** — Will this handle PII or secrets? What are the retention needs? **Will real documents, exports, or samples be needed during development** — and if so, where do they live? The answer is always `Standards/DATA_PROTECTION_STANDARD.md`'s local data directory, gitignored before the first commit; the question is asked so the Director hears the rule before the first file exists, not after it is in history.

> The frameworks and obligations named above (GDPR, HIPAA, PCI, SOC 2, ISO 27001, etc.) are engineering-discovery prompts to surface what needs architectural attention — not a statement of legal completeness, and not a substitute for qualified legal counsel. See the Compliance Engineer's Failure Modes for the same caveat applied to that Employee's own output.
8. **Scale expectations** — What is the expected user/request/data volume at launch, and at a future horizon?
9. **Lifecycle** — Is this a prototype, a product, a long-lived system? What maintenance is expected?
10. **Stakeholders & decision authority** — Who is the Director for this project? Who else must approve decisions?
11. **Assumptions & Risks** — What must be true for this to succeed? What is the biggest risk to delivery?
12. **What constitutes PROOF** — For each output the project produces that someone will act on — a report, a total, a classification, a recommendation — what, concretely, shows it is *correct*? A reconciling total against a named source of truth? Agreement with an authoritative table? A domain expert's sign-off on a named sample? "The pipeline ran without error" is never the answer. This question decides whether the project needs a Domain Employee (`Templates/DOMAIN_EMPLOYEE.md`, `Workflows/ONBOARDING.md` Step 4), and it names the reference that Employee reconciles against. A project that cannot answer it yet records that as its first open risk under question 11.

**Output:** Phase A answers captured. These become the durable **Project Charter** artifact (`Templates/PROJECT_CHARTER.md`), which records the business-requirements answers so they are not lost once implementation begins. An answer that settles what a domain term means also creates the project domain glossary, `.ia-engineering/DOMAIN_GLOSSARY.md` (`Templates/PROJECT_GLOSSARY.md`), with that answer as the entry's source. No settled term, no file: it is never created empty.

**Handoff to:** Step 2 — only after Phase A is fully answered.

---

## Step 2 — Phase B: Tech-stack questions

**Actor:** Software Architect

Only after Phase A is answered, the Software Architect asks the Director the technical questions needed to select a stack:

- **Language / runtime** — Node, a static web front end, Python, Go, JVM, .NET, PHP, or another choice. These seven are the first-class stacks: they have ready-made CI/Dockerfile templates. A static front end and a Node server are separate stacks because what they ship differs — a directory of files behind a web server, against a running process — and the choice is recorded in `.ia-engineering/stack` rather than guessed, since both have `package.json`. Anything else uses a Generic fallback template as a starting point.
- **Primary framework** — the application framework within the chosen language/runtime.
- **Data store** — this is a persistence/technology selection. Per `Workflows/ARCHITECTURE_DECISION.md`, this decision requires an ADR before implementation begins; it is exactly the kind of choice that workflow already mandates one for.
- **API style** — REST, GraphQL, RPC, event-driven, or none (if not applicable).
- **Hosting / deployment target** — where the application will eventually run.
- **Containerization needs** — whether the project will be packaged as a container image.
- **CI host** — Adapters currently assume GitHub (see `Adapters/README.md`). A project targeting a different host needs an equivalent Adapter not yet built.
- **Observability / logging expectations** — what must be observable at launch.
- **Test tooling** — the testing framework(s) for the chosen stack.
- **Secrets management** — how credentials and secrets will be stored and accessed.

### Project Profiles

Before the individual questions, the Software Architect places the project in one of three **profiles**. The profile does not replace the questions; it decides which of them carry weight, what the first ADR is about, and which Employees `Workflows/ONBOARDING.md` Step 4 activates by default.

| Profile | Shape | What dominates Phase B | Default roster emphasis | First ADR is usually |
|---|---|---|---|---|
| **A — Web application** | A service with a UI and/or API, its own data store, users who log in | Framework, data store, API style, hosting, secrets management | Backend Engineer, Frontend Engineer, Database Engineer, Security Engineer, QA Engineer | Data store selection |
| **B — Integration with a heavy external system** | The project's value is in reading from, writing to, or orchestrating a system it does not own — an ERP, a legacy database, a vendor API, a hardware controller | The external system's contract and failure modes; **what constitutes PROOF** (Phase A question 12) becomes the central design input; test tooling against a system that cannot be run locally | Integration Engineer, Data Engineer, a **Domain Employee** for the external system's business rules, QA Engineer, Security Engineer | The integration boundary — sync vs. event-driven, source of truth, reconciliation |
| **C — Library or CLI** | No persistent state of its own; consumed by other code or by an operator | Language/runtime, public interface stability, packaging and distribution, test tooling; data store and hosting questions usually do not apply | Backend Engineer (or the platform Engineer for the language), Technical Writer, QA Engineer | Public interface and versioning policy |

A project that fits two profiles is two projects sharing a repository until the Director says otherwise; that observation itself is recorded in the Stack Decision ADR.

Profile B is the one this framework most often meets on real engagements and the one where engineering correctness and *output* correctness diverge furthest — which is why its default roster includes a Domain Employee and why question 12 is not optional for it.

**Output:** Stack decided. The Software Architect drafts a **Stack Decision ADR** using `Templates/ADR.md`, following `Workflows/ARCHITECTURE_DECISION.md` end to end (research, draft, review, Director approval). The ADR names the profile.

**Handoff to:** Step 3 — only after the Stack Decision ADR is Accepted.

---

## Step 3 — Scaffold the repository

**Actor:** Main Agent + DevOps Engineer

With the stack decided, generate the baseline repository content:

1. `README.md`, reflecting the project identity captured in the Phase A answers.
2. `.gitignore`, appropriate to the chosen stack.
3. `.gitattributes` for the project's own files, if it needs rules of its own. Do not hand-write the LF rules for the control files (the hooks, CI and the files they parse): `Adapters/scripts/setup-project-bootstrap.sh` appends them in Step 4, as exact-path rules, and leaves the project's own rules untouched.
4. `main` and `develop` branches — not created here: no commit exists yet. They are created and pushed after the adoption commit (Step 4 item 5), as the Coverage Checklist item "`main` + `develop` branches created and pushed" says.

**Output:** Baseline repository scaffolded.

**Handoff to:** Step 4.

---

## Step 4 — Scaffold CI/CD and enforcement

**Actor:** DevOps Engineer

1. Run `Adapters/scripts/setup-project-bootstrap.sh <stack>`, found in your imported framework directory, with the stack decided in Step 2. One command installs the git hooks (via `core.hooksPath`), `.github/workflows/pr-validation.yml`, `.github/workflows/framework-validation.yml`, `.github/workflows/data-policy.yml`, `.github/workflows/control-path-guard.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/` (Step 6 below), the `.gitattributes` LF rules (exact paths, including the files the hooks and CI parse), `.github/workflows/ci-build-test.yml`, `.github/workflows/ghcr-publish.yml` (Step 5 below), a stack-appropriate `Dockerfile`, the committed `.ia-engineering/stack` declaration that CI reads, a starter `.ia-engineering/risk-map.yml` (see the Coverage Checklist), and a starter, empty `Registry/work-units.yml` — the project's own Work Unit registry, which the required `Work Unit Exists` check reads and never the framework's (register each Work Unit in the commit that performs it). It is idempotent, supports `--dry-run`, and verifies the installed `commit-msg` hook actually rejects an invalid Employee trailer rather than assuming the copy worked. **The Control Path Guard has prerequisites the script cannot create.** It is a `pull_request_target` workflow, which GitHub takes from the default branch, so it does not run on a Pull Request to `develop` until the file has reached `main`. When it does run, it fails a Pull Request that touches the files defining the checks (`Adapters/scripts/check-control-paths.sh` holds the list) unless the Director's login has just applied the label `control-change/approved`. The Director therefore creates that label and sets the repository variable `IAENG_DIRECTOR_LOGIN` to their login; while the variable is unset, the guard fails closed on such a Pull Request. It is not a required check unless the Director adds it through `setup-branch-protection.sh`.
2. Apply branch protection using `Adapters/scripts/setup-branch-protection.sh`. This is deliberately **not** part of the script above: it mutates settings every collaborator sees and needs an authenticated `gh`, so it is run once per repository as its own decision.
3. Confirm the script's closing report. It lists the Coverage Checklist items no script can complete — the README, `.gitignore`, Project Charter, Stack Decision ADR, `CLAUDE.md` roster, branch creation, and first Work Unit — so they stay visible instead of being assumed done. The same report separately names the AI-runtime integration under "Not installed by this script, by design" — install it deliberately as item 4 below.
4. Install the AI-runtime integration, as a separate, deliberate step — not part of the script above. `Adapters/scripts/install.sh`'s own "WHAT THIS SCRIPT DOES NOT DO" section states why: the runtime hooks are installed into a COMMITTED `.claude/settings.json`, a file that decides what the model may do and that a project reviews like code, not something a per-clone installer should write unasked. From the project root, run `Adapters/ai-runtimes/generate-agents.sh`, found in your imported framework directory, to turn the Employee roster into agents the runtime can dispatch to. Using Claude Code as the runtime — the one Adapter this framework has executed end to end — also run `Adapters/ai-runtimes/claude-code/install-hooks.sh` (writes `.claude/settings.json`) and `Adapters/ai-runtimes/claude-code/install-skills.sh` (adds `/create-project`), both in the same framework directory. A different runtime uses its own Adapter under `Adapters/ai-runtimes/<runtime>/`, per `Core/AI_MANIFEST.md` Principle X (AI Agnostic) — the framework names no runtime as mandatory. **Restart the session after installing the hooks**: Claude Code reads `.claude/settings.json` at session start, so a session already running will not pick up hooks installed mid-session. Verify by starting a new session and confirming the session-start hook fires and reports `.ia-engineering/SESSION_STATE.md`'s status — its pointers if it already exists, or that it must be created — which is the proof the hooks are loaded, not just installed.

5. Commit the adoption. **The Employee who signs it is the DevOps Engineer** (`Employee: DevOps Engineer`): the commit installs pipelines, hooks and tooling, which is the DevOps Engineer's role (`Core/EMPLOYEE_SELECTION.md`), and it is this step's Actor. The Main Agent facilitates and never signs a commit itself. The commit-msg hook is already active, so the commit needs a `Work Unit:` trailer for an adoption Work Unit registered in the same commit in `Registry/work-units.yml` (with the project's own prefix, for example `WU-<PREFIX>-001`; its `milestone` is `Bootstrap`, see `Registry/README.md`), and `Employee: DevOps Engineer` as the last paragraph (`Standards/COMMIT_STANDARD.md`). The hook refuses the commit when that id is not in `Registry/work-units.yml` as staged, which is why the entry goes in this same commit. This commit reaches `main` without a Pull Request, so no CI check ever reads it: the hook is its only check, and the hook does not require the `Work Unit:` line, so a commit without one is not refused. Only after this commit exists, create `.ia-engineering/SESSION_STATE.md` (Step 7).

**Output:** CI/CD Adapter scaffolded and enforcing. AI-runtime integration installed for the runtime in use. Adoption committed.

**Handoff to:** Step 5.

---

## Step 5 — Scaffold GHCR publishing

**Actor:** DevOps Engineer, GitOps Engineer consulted

1. Already installed by `Adapters/scripts/setup-project-bootstrap.sh` in Step 4, which copies `Adapters/github-actions/ghcr-publish.yml` alongside the CI workflow because both depend on the same stack decision. Confirm it is present and that the `Dockerfile` it builds matches the chosen stack.

**GHCR scope is build and publish only.** This step results in the container image being built and published to `ghcr.io/<owner>/<repo>`. It does not produce Kubernetes manifests, Compose files, or any environment configuration, and it does not run the image anywhere. Actually deploying that published image to an environment is out of scope for this milestone — it belongs to a future, separate Deployment milestone. Do not treat GHCR publishing as deployment.

**Output:** GHCR Adapter scaffolded. Image builds and publishes on the configured trigger.

**Handoff to:** Step 6.

---

## Step 6 — Scaffold issue templates

**Actor:** DevOps Engineer

1. Already installed by `Adapters/scripts/setup-project-bootstrap.sh` in Step 4, which delegates it to `Adapters/scripts/install.sh`.
2. Replace the `OWNER/REPO` placeholders in `.github/ISSUE_TEMPLATE/config.yml` with this project's own owner and repository name. The Adapter ships them as placeholders on purpose, and `install.sh` warns while they remain — left unreplaced, the Questions and Security Vulnerability contact links point at a repository that does not exist.

Until WU-IAENG-142 this step was not actually performed by the script it named. `setup-project-bootstrap.sh` carried a TODO deferring issue-template installation to a follow-up Work Unit, gated on template files that had already shipped in v0.0.10 — so the deferral outlived its reason and was never removed. A project bootstrapped by following this workflow exactly ended up with no issue templates, and nothing reported the omission. `Adapters/scripts/validate-framework.sh` now fails on an unresolved work marker in any shipped Adapter, so the same gap cannot reopen quietly.

Issue templates are an **independent external intake surface** — a way for anyone (not only the Director or active Employees) to file a bug report or feature request. They are deliberately **not** wired into the Work Unit/Pull Request flow: `Templates/WORK_UNIT.md` has no mandatory Issue ID field, and there is no procedural requirement to convert an Issue into a Work Unit before work can begin. This preserves the existing Work Unit model untouched. An Issue may inform a future Work Unit, at the Engineering Manager's discretion, but that is a judgment call, not a mandated handoff.

**Output:** Issue templates scaffolded, functioning independently of the Work Unit/PR flow.

**Handoff to:** Step 7 (handoff to Onboarding).

---

## Step 7 — Hand off to Onboarding

**Actor:** Main Agent

With the stack decided and the repository, CI/CD, GHCR, and issue templates all scaffolded, this workflow ends and control passes to `Workflows/ONBOARDING.md`, beginning at **Step 4 — Activate employees**, after two Onboarding Step 1 items this workflow never performs: create `CLAUDE.md` from `Templates/PROJECT_CLAUDE.md` (`Workflows/ONBOARDING.md` Step 1 item 2, filled from the Project Charter and the Stack Decision ADR) and create `.ia-engineering/SESSION_STATE.md` from `Templates/SESSION_STATE.md` (Step 1 item 3). Do both now, before Step 4 — Step 4 item 3 documents the roster in the `CLAUDE.md` that must already exist. Create `SESSION_STATE.md` **after the adoption commit** of Step 4 item 5, not before: the session-start hook warns "N commit(s) behind" when the file is older than the latest commit, so a file written ahead of the first commit is stale on the first session (if it already exists, `touch` it). The rest of Onboarding Steps 1-3 (framework import, install scripts, AI-runtime integration, project context, architecture review) is satisfied by this workflow's Phase A/Phase B work and Steps 3-4 above and does not need to be repeated. Onboarding's Step 5 (Initialize git workflow) is also already satisfied by Step 3 and Step 4 above — do not repeat it.

If Phase A question #6 or #7 (Step 1) was answered positively, the compliance flag and its follow-on Work Unit or handoff note (see the Escalation table below) must be carried into this handoff explicitly — it does not get dropped silently just because control is passing to a new document.

**Output:** `CLAUDE.md` and `SESSION_STATE.md` created; control handed to `Workflows/ONBOARDING.md` at Step 4.

**Handoff to:** `Workflows/ONBOARDING.md` Step 4 onward (roster activation, first Work Unit, readiness confirmation).

---

# Coverage Checklist (Definition of Done)

This workflow is not complete until every item below is checked. This is the explicit "check every place and thing to do" gate for Project Bootstrap.

Each item names what actually performs it. A checklist item whose mechanism is unnamed is an item that gets assumed done — which is precisely what happened to the issue templates before WU-IAENG-142.

**Performed by `Adapters/scripts/setup-project-bootstrap.sh <stack>` (Step 4):**

- [ ] `.gitattributes` (LF enforcement: `/.github/**` plus exact-path rules for `.claude/settings.json`, `.ia-engineering/stack`, `.ia-engineering/risk-map.yml`, `Registry/work-units.yml`, `Dockerfile`, `.gitmodules`)
- [ ] Git hooks installed (`commit-msg`, `pre-commit`, `pre-push`, via `core.hooksPath`)
- [ ] `.gitignore` data-protection rules (`local_test_data/`, `.env`, `.ia-engineering/SESSION_STATE.md`) and the local data directory
- [ ] `.github/workflows/pr-validation.yml`
- [ ] `.github/workflows/framework-validation.yml`
- [ ] `.github/workflows/data-policy.yml`
- [ ] `.github/workflows/control-path-guard.yml` — installed; does not run until it reaches the default branch, and fails closed on PRs that touch control paths until the Director sets `IAENG_DIRECTOR_LOGIN` and creates the `control-change/approved` label (Step 4 item 1)
- [ ] `.github/workflows/ci-build-test.yml`
- [ ] `.github/workflows/ghcr-publish.yml`
- [ ] `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] `.github/ISSUE_TEMPLATE/` (bug report, feature request, config)
- [ ] `Dockerfile` (stack-appropriate)
- [ ] `.ia-engineering/stack` — the declared stack; **commit it**, CI reads it
- [ ] `Registry/work-units.yml` — the bootstrap writes an **empty starter**: the project's own Work Unit registry. The required `Work Unit Exists` check reads it and never the framework's; until a Work Unit is registered in it, every commit fails that check with its id reported unregistered (register each Work Unit in the commit that performs it)
- [ ] `.ia-engineering/risk-map.yml` — the bootstrap writes a **starter** covering only the files it installed and declares no category absent; the project maps its own zones and accounts for all eight categories (`Templates/RISK_MAP.md`), then runs `check-risk-map.sh`. Until then the Risk Map check names what is unaccounted for — that is the check working, not failing

**Performed by a separate, deliberate command:**

- [ ] Branch protection applied (`Adapters/scripts/setup-branch-protection.sh`) — separate because it mutates settings every collaborator sees
- [ ] `main` + `develop` branches created and pushed — make the first commit first (`git branch` fails in a repository with no commit), then `git push -u origin main`, `git branch develop`, `git push -u origin develop`. The `pre-push` hook allows creating an absent protected branch; every later change to either goes through a Pull Request
- [ ] `.github/ISSUE_TEMPLATE/config.yml` `OWNER/REPO` placeholders replaced
- [ ] AI-runtime integration installed (Step 4 item 4) — `Adapters/ai-runtimes/generate-agents.sh`, and for Claude Code also `Adapters/ai-runtimes/claude-code/install-hooks.sh` + `install-skills.sh` — separate because `.claude/settings.json` is committed content that decides what the model may do

**Requires judgment, a decision, or the Director — no script can complete these:**

- [ ] `README.md` (project identity from Phase A answers)
- [ ] `.gitignore` (stack-appropriate)
- [ ] `CLAUDE.md` created from `Templates/PROJECT_CLAUDE.md` (`ONBOARDING.md` Step 1 item 2) + active roster (`ONBOARDING.md` Step 4)
- [ ] `.ia-engineering/SESSION_STATE.md` created from `Templates/SESSION_STATE.md` (`ONBOARDING.md` Step 1 item 3), after the first commit (Step 4 item 5) — never committed; the `.gitignore` rule above keeps it out
- [ ] Project Charter artifact (Phase A answers)
- [ ] Stack Decision ADR (Phase B decision, Accepted)
- [ ] First Work Unit created + Director-approved (`ONBOARDING.md` Step 6)
- [ ] Framework imported (submodule/reference)

`setup-project-bootstrap.sh` prints the last two groups as a closing report, so the items it cannot perform stay visible rather than silently unchecked.

---

# Exit Criteria

This workflow is complete when:

- Every item in the Coverage Checklist above is checked.
- The Stack Decision ADR is Accepted.
- Control has been handed to `Workflows/ONBOARDING.md` at Step 4.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Director cannot answer a Phase A question | Director — cannot proceed to Phase B without a clear business objective |
| Stack choice is contested or unclear | Software Architect → Director, via `Workflows/ARCHITECTURE_DECISION.md` |
| Desired CI host is not GitHub | Director — no Adapter exists yet for other hosts (see `Adapters/README.md` Planned) |
| Desired stack is not one of the seven first-class stacks | Software Architect — use the Generic fallback template, document any gaps |
| Deployment (beyond GHCR build/publish) is requested | Director — out of scope for this milestone, requires a future Deployment milestone |
| Phase A question #6 or #7 is answered positively (compliance/regulatory framework applies, or PII/sensitive data is held) | Compliance Engineer (and Security Engineer) — this is a structural trigger, not optional: it must produce either a follow-on Work Unit for gap analysis and control work, or at minimum an explicit compliance flag carried into the `Workflows/ONBOARDING.md` handoff. A positive answer that only gets recorded in the Project Charter with no further action is an incomplete Phase A. |

---

# Related Workflows

- Onboarding Workflow (this workflow's downstream handoff)
- Architecture Decision Workflow (governs the Stack Decision ADR)
- Feature Development Workflow (governs the first Work Unit once created)

---

# Metadata

Owner: IA Engineering

Version: 0.0.15

Status: Draft

Category: Workflow — Bootstrap

Severity: Mandatory

Depends On: `Workflows/ONBOARDING.md`, `Workflows/ARCHITECTURE_DECISION.md`, `Templates/ADR.md`, `Templates/PROJECT_CHARTER.md`, `Adapters/README.md`

Referenced By: `Workflows/ONBOARDING.md` (upstream handoff source, once linked)
