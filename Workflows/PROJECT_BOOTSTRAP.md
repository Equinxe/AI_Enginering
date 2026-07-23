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

## Step 1 — Phase A: Project questions

**Actor:** Main Agent, with Business Analyst and Product Manager

The Main Agent asks the Director a set of business-before-tech questions, roughly twenty in number as an order of magnitude, not a fixed count. Use judgment: ask what is genuinely useful to define the project, skip what does not apply. Structure the questions into these categories:

1. **Business goal** — What problem does this solve? What is the one-sentence value proposition?
2. **Target users / consumers** — Who uses this? Are they internal, external, or another system?
3. **Scope & non-goals** — What is explicitly in scope for v1? What is explicitly out of scope?
4. **Success criteria** — How is "working" measured? What is the definition of done for launch?
5. **Constraints** — Is there a deadline, a budget, a team size, existing systems to integrate with?
6. **Compliance / regulatory** — Does GDPR, HIPAA, PCI, SOC 2, ISO 27001, data residency, or licensing apply? What is the jurisdiction / geography of users and data processing — this is upstream of every other question here, since "does GDPR apply" cannot be answered without knowing where data subjects and processing are located. What are the breach notification obligations (e.g., GDPR Art. 33/34's 72-hour window) and data subject rights (access/erasure/portability, Art. 15-20) — both drive architecture decisions (logging, export/delete capability) and belong at inception, not retrofitted later.
7. **Data sensitivity** — Will this handle PII or secrets? What are the retention needs?

> The frameworks and obligations named above (GDPR, HIPAA, PCI, SOC 2, ISO 27001, etc.) are engineering-discovery prompts to surface what needs architectural attention — not a statement of legal completeness, and not a substitute for qualified legal counsel. See the Compliance Engineer's Failure Modes for the same caveat applied to that Employee's own output.
8. **Scale expectations** — What is the expected user/request/data volume at launch, and at a future horizon?
9. **Lifecycle** — Is this a prototype, a product, a long-lived system? What maintenance is expected?
10. **Stakeholders & decision authority** — Who is the Director for this project? Who else must approve decisions?
11. **Assumptions & Risks** — What must be true for this to succeed? What is the biggest risk to delivery?

**Output:** Phase A answers captured. These become the durable **Project Charter** artifact (`Templates/PROJECT_CHARTER.md`), which records the business-requirements answers so they are not lost once implementation begins.

**Handoff to:** Step 2 — only after Phase A is fully answered.

---

## Step 2 — Phase B: Tech-stack questions

**Actor:** Software Architect

Only after Phase A is answered, the Software Architect asks the Director the technical questions needed to select a stack:

- **Language / runtime** — Node, Python, Go, JVM, or another choice. These four are the first-class stacks: they have ready-made CI/Dockerfile templates. Anything else uses a Generic fallback template as a starting point.
- **Primary framework** — the application framework within the chosen language/runtime.
- **Data store** — this is a persistence/technology selection. Per `Workflows/ARCHITECTURE_DECISION.md`, this decision requires an ADR before implementation begins; it is exactly the kind of choice that workflow already mandates one for.
- **API style** — REST, GraphQL, RPC, event-driven, or none (if not applicable).
- **Hosting / deployment target** — where the application will eventually run.
- **Containerization needs** — whether the project will be packaged as a container image.
- **CI host** — Adapters currently assume GitHub (see `Adapters/README.md`). A project targeting a different host needs an equivalent Adapter not yet built.
- **Observability / logging expectations** — what must be observable at launch.
- **Test tooling** — the testing framework(s) for the chosen stack.
- **Secrets management** — how credentials and secrets will be stored and accessed.

**Output:** Stack decided. The Software Architect drafts a **Stack Decision ADR** using `Templates/ADR.md`, following `Workflows/ARCHITECTURE_DECISION.md` end to end (research, draft, review, Director approval).

**Handoff to:** Step 3 — only after the Stack Decision ADR is Accepted.

---

## Step 3 — Scaffold the repository

**Actor:** Main Agent + DevOps Engineer

With the stack decided, generate the baseline repository content:

1. `README.md`, reflecting the project identity captured in the Phase A answers.
2. `.gitignore`, appropriate to the chosen stack.
3. `.gitattributes`, enforcing LF line endings — mirroring this framework's own repository.
4. `main` and `develop` branches created.

**Output:** Baseline repository scaffolded.

**Handoff to:** Step 4.

---

## Step 4 — Scaffold CI/CD and enforcement

**Actor:** DevOps Engineer

1. Apply branch protection using `Adapters/scripts/setup-branch-protection.sh`.
2. Install git hooks (`commit-msg`, `pre-push`) from `Adapters/git-hooks/`.
3. Add `.github/workflows/pr-validation.yml` from the existing Adapter.
4. Add `.github/workflows/ci-build-test.yml`, generated from `Adapters/github-actions/ci-build-test.yml` and a stack-appropriate `Dockerfile`, using `Adapters/scripts/setup-project-bootstrap.sh`.
5. Add `.github/PULL_REQUEST_TEMPLATE.md` from the existing Adapter.

**Output:** CI/CD Adapter scaffolded and enforcing.

**Handoff to:** Step 5.

---

## Step 5 — Scaffold GHCR publishing

**Actor:** DevOps Engineer, GitOps Engineer consulted

1. Add `.github/workflows/ghcr-publish.yml`, generated from `Adapters/github-actions/ghcr-publish.yml`.

**GHCR scope is build and publish only.** This step results in the container image being built and published to `ghcr.io/<owner>/<repo>`. It does not produce Kubernetes manifests, Compose files, or any environment configuration, and it does not run the image anywhere. Actually deploying that published image to an environment is out of scope for this milestone — it belongs to a future, separate Deployment milestone. Do not treat GHCR publishing as deployment.

**Output:** GHCR Adapter scaffolded. Image builds and publishes on the configured trigger.

**Handoff to:** Step 6.

---

## Step 6 — Scaffold issue templates

**Actor:** DevOps Engineer

1. Add `.github/ISSUE_TEMPLATE/` (bug report, feature request, config) from `Adapters/github/ISSUE_TEMPLATE/`.

Issue templates are an **independent external intake surface** — a way for anyone (not only the Director or active Employees) to file a bug report or feature request. They are deliberately **not** wired into the Work Unit/Pull Request flow: `Templates/WORK_UNIT.md` has no mandatory Issue ID field, and there is no procedural requirement to convert an Issue into a Work Unit before work can begin. This preserves the existing Work Unit model untouched. An Issue may inform a future Work Unit, at the Engineering Manager's discretion, but that is a judgment call, not a mandated handoff.

**Output:** Issue templates scaffolded, functioning independently of the Work Unit/PR flow.

**Handoff to:** Step 7 (handoff to Onboarding).

---

## Step 7 — Hand off to Onboarding

**Actor:** Main Agent

With the stack decided and the repository, CI/CD, GHCR, and issue templates all scaffolded, this workflow ends and control passes to `Workflows/ONBOARDING.md`, beginning at **Step 4 — Activate employees**. Onboarding Steps 1-3 (import the framework, define project context, architecture review) are already satisfied by this workflow's Phase A/Phase B work and do not need to be repeated. Onboarding's Step 5 (Initialize git workflow) is also already satisfied by Step 3 and Step 4 above — do not repeat it.

If Phase A question #6 or #7 (Step 1) was answered positively, the compliance flag and its follow-on Work Unit or handoff note (see the Escalation table below) must be carried into this handoff explicitly — it does not get dropped silently just because control is passing to a new document.

**Output:** Control handed to `Workflows/ONBOARDING.md` at Step 4.

**Handoff to:** `Workflows/ONBOARDING.md` Step 4 onward (roster activation, first Work Unit, readiness confirmation).

---

# Coverage Checklist (Definition of Done)

This workflow is not complete until every item below is checked. This is the explicit "check every place and thing to do" gate for Project Bootstrap:

- [ ] `README.md` (project identity from Phase A answers)
- [ ] `.gitignore` (stack-appropriate)
- [ ] `.gitattributes` (LF enforcement, mirroring this framework's own repo)
- [ ] `main` + `develop` branches created
- [ ] Branch protection applied (`Adapters/scripts/setup-branch-protection.sh`)
- [ ] Git hooks installed (`commit-msg`, `pre-push`)
- [ ] `.github/workflows/pr-validation.yml`
- [ ] `.github/workflows/ci-build-test.yml`
- [ ] `.github/workflows/ghcr-publish.yml`
- [ ] `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] `.github/ISSUE_TEMPLATE/` (bug report, feature request, config)
- [ ] `Dockerfile` (stack-appropriate)
- [ ] `CLAUDE.md` created + active roster (handoff to `ONBOARDING.md` Step 4)
- [ ] Project Charter artifact (Phase A answers)
- [ ] Stack Decision ADR (Phase B decision)
- [ ] First Work Unit created + Director-approved (`ONBOARDING.md` Step 6)
- [ ] Framework imported (submodule/reference)

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
| Desired stack is not Node, Python, Go, or JVM | Software Architect — use the Generic fallback template, document any gaps |
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

Version: 0.0.10

Status: Draft

Category: Workflow — Bootstrap

Severity: Mandatory

Depends On: `Workflows/ONBOARDING.md`, `Workflows/ARCHITECTURE_DECISION.md`, `Templates/ADR.md`, `Templates/PROJECT_CHARTER.md`, `Adapters/README.md`

Referenced By: `Workflows/ONBOARDING.md` (upstream handoff source, once linked)
