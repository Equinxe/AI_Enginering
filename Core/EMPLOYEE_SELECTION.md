# Employee Selection

This document turns "the Main Agent always assigns work to the most appropriate Employee" (`Core/MAIN_AGENT_CONDUCT.md`, `Employee Selection`) from a vague aspiration into a concrete, checkable reference.

For every one of the 42 Employees in the IA Engineering roster (`Employees/`), it gives a short "dispatch this Employee when…" trigger grounded in that Employee's actual Mission and Responsibilities. Before the Main Agent defaults to a familiar Employee out of convenience, it checks this document for a better-fit match.

---

# The Incident This Prevents

A roster-utilization audit on 2026-07-23 found that **96% of all credited commits in this project's history went to just 4 of the 42 Employees**: Release Manager, DevOps Engineer, Technical Writer, and Software Architect. Work that a more specifically-matched Employee should have owned was instead absorbed by whichever familiar generalist was already in motion. Concretely:

- Compliance-adjacent content was written by the Technical Writer instead of the Compliance Engineer.
- A document whose own RACI table named the Business Analyst and Product Manager as co-owners of its content was written by the Technical Writer alone.

This is the same bug class already found and fixed twice this session for other vague triggers: the ADR trigger list (fixed in v0.0.7.5, cross-referenced from `Core/ORCHESTRATION.md` Step 2) and the "security-sensitive or high-risk" QA trigger (fixed in WU-IAENG-123, cross-referenced from `Core/AGENT_CHAINS.md`'s Review Chain). A rule that *sounds* right — "pick the most appropriate Employee" — gives the Main Agent nothing concrete to check itself against, so it silently defaults to convenience. This document is the concrete check.

---

# The Anti-Pattern to Guard Against

**Defaulting to the same familiar 3–4 generalist Employees regardless of fit.** The 96%-concentration finding is what this looks like in practice: a small handful of Employees carry nearly all the work not because they were the right fit each time, but because they were already active and familiar.

The Main Agent must actively guard against this. Familiarity, momentum, and "this Employee is already working" are **not** selection criteria. Fit is. Before dispatching, the Main Agent asks: *is there an Employee whose Mission is more specifically about this work than the one I am about to reach for?* If yes, that Employee is dispatched — even if it means activating an Employee that has not yet been used in the project.

This document exists so that "the most appropriate Employee" is decided by reading a trigger, not by reaching for a habit.

---

# How to Use This Document

1. Identify the *kind of work* the Work Unit actually is — not the deliverable's surface form. "Write a document" is not a kind of work; "define compliance controls," "specify business requirements," or "produce user-facing content" are.
2. Find the category below that matches, then the Employee whose trigger fits most specifically.
3. If two Employees plausibly fit, read the **Miscasting Risks** section — it exists precisely for the hard, easy-to-get-wrong pairs.
4. Dispatch through an Employee Brief per `Core/ORCHESTRATION.md`, carrying that Employee's Mission, Authority, Standards Applied, and Definition of Done.

**This document is portable.** Its triggers are written from each Employee's definition, not from IA Engineering's own history, so they apply in *any* project that uses this framework — not only this documentation-heavy repository. An Employee that has no natural fit for the current project still has a real trigger here for the projects where it does.

---

# Relationship to Roster Gaps

This document is **not** `Core/MAIN_AGENT_CONDUCT.md`'s `Roster Gaps` section, and the two solve different problems:

- **`Roster Gaps`** is about an Employee type not being *active* in a project's `CLAUDE.md` roster at all. Its question is: *"the right Employee for this work is not activated in this project — do I propose activating it?"* The answer is a roster-expansion proposal to the Director.
- **This document (`Employee Selection`)** is about choosing correctly *among* Employees. Its question is: *"given the roster, which Employee is the best fit for this Work Unit?"* The answer is a dispatch decision.

They compose: use this document to identify the best-fit Employee; if that Employee is not in the active roster, follow `Roster Gaps` to propose activating it before dispatching.

---

# Dispatch Triggers by Category

## Management

- **Engineering Manager** — Dispatch when an objective must be decomposed into Work Units, assigned across Employees, and tracked to completion; when delivery coordination or unblocking across multiple Employees is needed. This is the orchestration-and-decomposition role, not an implementation role.
- **Product Manager** — Dispatch when the question is *what to build and in what order*: backlog prioritization, translating business objectives into requirements with acceptance criteria, defining release scope, or accepting/rejecting delivered features against acceptance criteria.
- **Release Manager** — Dispatch when preparing, validating, or delivering a release: release checklist, version bump coordination, release-branch management, changelog coordination, and driving the release to the Director-approval gate. **Not** a catch-all for any git or documentation task that happens near a release.
- **Scrum Master** — Dispatch for process facilitation: sprint planning, standups, reviews, retrospectives, impediment removal, and protecting the team from mid-sprint scope change. This is process, not people management and not technical decisions.
- **Technical Lead** — Dispatch for cross-cutting *technical consistency and convention* work: translating architecture into implementation guidance, pre-PR technical review, defining project-level conventions, resolving technical inconsistencies across the codebase. See **Miscasting Risks** for the boundary with Software Architect.

## Architecture

- **Software Architect** — Dispatch for system-level architecture: defining the technical structure, selecting technology stacks, establishing architectural patterns, and producing ADRs for significant decisions. The owner of *what the architecture is*.
- **Solution Architect** — Dispatch when the work is about *how systems connect*: integration design across internal/external systems, communication protocols, third-party service evaluation, and integration contracts. Cross-system, where Software Architect is intra-system.
- **Data Architect** — Dispatch when the work is about *how data is structured and stored*: data models, schema design, storage-technology selection, data flow patterns, retention/deletion policies, and data contracts for cross-system exchange.

## Development

- **Backend Engineer** — Dispatch for server-side business logic, API implementation, and data-processing implementation within a defined architecture.
- **Frontend Engineer** — Dispatch for user-interface and client-side logic implementation from validated design specs, including accessibility and API integration on the client.
- **iOS Engineer** — Dispatch for native iOS implementation in Swift against Apple platform guidelines.
- **Android Engineer** — Dispatch for native Android implementation in Kotlin against Google platform guidelines.
- **Cross-Platform Engineer** — Dispatch when one shared codebase must target both iOS and Android (React Native, Flutter, etc.) with platform-appropriate behavior.
- **Database Engineer** — Dispatch to *implement* the data model the Data Architect defined: schemas, migrations, query optimization, indexes, constraints. Implementation, not data-model definition.
- **Event-Driven Engineer** — Dispatch for asynchronous/message-based implementation: producers, consumers, event schemas, brokers, dead-letter queues, delivery guarantees.
- **Integration Engineer** — Dispatch to *implement* integrations the Solution Architect designed: external API clients, auth, resilience (timeouts, retries, circuit breakers), against integration contracts.

## DevOps

- **DevOps Engineer** — Dispatch for CI/CD pipelines, build/test/deploy automation, and deployment strategies. **Not** the default owner of anything security-, secrets-, or git-mechanics-related merely because those things touch pipelines — see **Miscasting Risks**.
- **Cloud Engineer** — Dispatch for designing and provisioning cloud infrastructure (compute, storage, networking, managed services) and cloud cost/security posture, aligned with the architecture.
- **Infrastructure as Code Engineer** (IaC Engineer) — Dispatch when infrastructure must be *defined as versioned, reviewable code* (Terraform, Pulumi, Ansible): modules, plans/dry-runs, state management.
- **GitOps Engineer** — Dispatch when git is the *declared source of truth for deployed infrastructure/application state*: GitOps operators (ArgoCD, Flux), drift detection/reconciliation, environment-promotion workflows. See **Miscasting Risks** for the boundary with DevOps/Release Manager.
- **Platform Engineer** — Dispatch to build the internal developer platform whose customer is the engineering team: container orchestration, standardized environments, service templates, developer self-service tooling.
- **Observability Engineer** — Dispatch for logging, metrics, and distributed tracing instrumentation; dashboards; and actionable alerting with runbooks.
- **SRE Engineer** — Dispatch for production reliability: SLO/SLI definition, incident response and post-mortems, error-budget management, disaster-recovery/failover design.

## Quality

- **QA Engineer** — Dispatch to define and execute the testing strategy: functional/regression/acceptance testing, defect tracking, and quality sign-off against acceptance criteria.
- **Test Automation Engineer** — Dispatch to *build the automated test infrastructure* (frameworks, CI integration, flaky-test remediation, coverage), where QA defines *what* to test and this Employee builds the systems that test it.
- **Security Engineer** — Dispatch for anything touching secrets, authentication, authorization, tokens, cryptography, PII, threat modeling, vulnerability review, or infrastructure with production access. See **Miscasting Risks** — this is the single most commonly under-dispatched Employee.
- **Performance Engineer** — Dispatch for load/stress/endurance testing, bottleneck analysis, performance baselines, and performance-regression gates.

## Data

- **Data Engineer** — Dispatch to build data pipelines (ETL/ELT), ingestion, transformation, and data-quality validation at scale.
- **Analytics Engineer** — Dispatch for the semantic/transformation layer between raw data and analytical consumers (SQL/dbt models, tested and documented analytical datasets, dashboards).
- **Data Scientist** — Dispatch to define *what to learn from data*: problem formulation, exploratory analysis, experiment design, statistical validation, and ML success criteria.
- **ML Engineer** — Dispatch to build ML training pipelines, dataset versioning, model packaging, and model integration — bridging research and production.
- **MLOps Engineer** — Dispatch to deploy, monitor, and maintain models in production: registries, deployment pipelines, drift detection, retraining automation, rollback.

## Documentation

- **Technical Writer** — Dispatch to produce *documentation content* aimed at a reader: API references, guides, runbooks, changelogs, release notes, READMEs. **Content only** — see **Miscasting Risks** for the frequent error of routing compliance, business-requirements, or design content here.
- **Documentation Engineer** — Dispatch to build the documentation *system*: tooling, doc-as-code pipelines, information architecture, templates, and CI integration. The platform, not the prose.

## Specialized

- **Business Analyst** — Dispatch to elicit and specify *business/functional requirements*: stakeholder analysis, functional specifications, use cases, acceptance criteria, requirements traceability. See **Miscasting Risks**.
- **Code Reviewer** — Dispatch to review a Pull Request for correctness, logic, tests, standards, and security awareness, and to render an approve/request-changes decision. Never self-reviews the author's own work.
- **UX/UI Designer** — Dispatch for user research, user flows, wireframes, high-fidelity design, design systems, and accessibility (WCAG) — before UI code is written.
- **API Engineer** — Dispatch when the API *contract itself* is the deliverable: API design, schema/versioning strategy, contract-first design, and API lifecycle/deprecation, distinct from a Backend Engineer merely implementing an endpoint.
- **AI Engineer** — Dispatch to build AI-powered features: model selection, integration layers, evaluation pipelines, and AI observability.
- **Prompt Engineer** — Dispatch when the deliverable is *itself a prompt or AI-instruction artifact*: prompt design, evaluation, guardrails, and versioned prompt libraries. See **Miscasting Risks** for the genuinely debatable AI-instruction-content case.
- **Compliance Engineer** — Dispatch for regulatory/legal/contractual obligations: translating GDPR, SOC 2, ISO 27001, HIPAA, PCI-DSS, etc. into engineering controls, gap analysis, and audit evidence. See **Miscasting Risks**.
- **Penetration Tester** — Dispatch for authorized offensive security testing within a Director-authorized scope: simulated attacks, CVSS-rated findings, and remediation verification. Distinct from the Security Engineer's defensive review role.

---

# Miscasting Risks

These are the pairs where a familiar generalist can superficially cover the same ground as a more specific Employee. Each is a concrete instance of the anti-pattern above. When the work matches one of these descriptions, the specific Employee is the right dispatch — do not default to the generalist.

## Compliance Engineer vs. Technical Writer

If the content's *purpose* is to satisfy a regulatory, legal, or contractual obligation — a GDPR data-processing record, a SOC 2 control description, a compliance policy — the owner is the **Compliance Engineer**, even though the deliverable is a document. The Technical Writer produces documentation content for a reader; they do not interpret regulations into controls. Routing compliance-adjacent content to the Technical Writer (as happened in the 2026-07-23 audit) produces prose without the regulatory grounding that is the entire point. The Technical Writer may later edit the Compliance Engineer's content for clarity, but the compliance substance is the Compliance Engineer's Work Unit.

## Business Analyst / Product Manager vs. Technical Writer

If the content *is* a business or requirements artifact — functional specifications, acceptance criteria, use cases, backlog definitions, requirements traceability — the owner is the **Business Analyst** (for eliciting and specifying requirements) or the **Product Manager** (for prioritization, scope, and what-to-build decisions). It is not a Technical Writer task merely because the output is written text. The 2026-07-23 audit found a document whose own RACI table named the Business Analyst and Product Manager as content co-owners, yet the Technical Writer wrote it alone. Authorship must match the content's substance, not its surface form.

## Security Engineer vs. DevOps Engineer

Anything touching **secrets, authentication, authorization, tokens, cryptography, PII, or infrastructure with production access** routes to the **Security Engineer** — not the DevOps Engineer, even when the work happens inside a pipeline or deployment config. The DevOps Engineer builds and operates pipelines; the moment the work is *about* the secret, the credential, the auth boundary, or production access rather than the pipeline mechanics, it is security work. The Security Engineer is the single most commonly under-dispatched Employee because so much security-relevant work is embedded in DevOps-shaped tasks. When both are needed, the Security Engineer defines the control and the DevOps Engineer wires it in — two Work Units, not one absorbed by the generalist. (`Core/AGENT_CHAINS.md`'s Review Chain already encodes the complementary rule: a security concern escalates to the Security Engineer immediately.)

## Technical Lead vs. Software Architect

Both make technical decisions, but at different altitudes:

- **Software Architect** owns *architecture*: system structure, technology-stack selection, architectural patterns, and ADRs. If the decision would be recorded as an ADR or changes the system's structure, it is the Software Architect's.
- **Technical Lead** owns *cross-cutting consistency and convention within the established architecture*: applying architectural decisions, project-level conventions, pre-PR technical review, and resolving inconsistencies. The Technical Lead's own definition is explicit — *"Technical conventions are not architecture"* — and escalates to the Software Architect when a decision requires an architectural change.

The error to avoid: routing project-wide *consistency/convention* decisions to the Software Architect (over-weighting them as "architecture") or routing genuine *structural/technology* decisions to the Technical Lead (under-weighting them). Ask: does this set or change the architecture (Software Architect), or apply and keep it consistent (Technical Lead)?

## Prompt Engineer vs. Software Architect — an open question

This one does not have a clean, false-confident answer, and the Main Agent should reason about it rather than apply a fixed rule.

Consider content that is *itself an AI-agent instruction or prompt artifact* — for example, this framework's own Employee definitions and Core conduct documents. Such content is genuinely two things at once:

- It is **architecture**: these documents define the structure, roles, and decision flow of the system. That is the **Software Architect's** domain.
- It is **literally a prompt**: these documents are instructions consumed by an AI model to govern its behavior. That is the **Prompt Engineer's** domain (prompt design, evaluation against a baseline, guardrails, versioning).

Neither claim is wrong, so this document does not assert a hard winner. Instead, reason about which *aspect dominates the specific Work Unit*:

- If the Work Unit is about **what the role/structure/decision-flow should be** (defining a new Employee's Mission and Authority, changing how orchestration works), the architectural aspect dominates → lean **Software Architect**.
- If the Work Unit is about **how the instruction performs as a prompt** (does the wording produce the intended model behavior, is it robust to adversarial or ambiguous inputs, is it evaluated and versioned as a prompt), the prompt aspect dominates → lean **Prompt Engineer**.
- When both aspects are substantial and inseparable, treat it as a collaboration (two Work Units or an explicitly shared one) and, if the split is genuinely unclear, **escalate to the Director** rather than forcing a false-certain assignment.

The point is not to resolve the ambiguity by fiat, but to give the Main Agent a way to *reason* about it — and to prevent the ambiguity from silently collapsing into "whoever is already active," which is the anti-pattern this whole document exists to stop.

## GitOps Engineer vs. DevOps Engineer / Release Manager

When the work treats **git as the declared source of truth for deployed state** — reconciling live infrastructure to what git declares, drift detection, GitOps operators, environment-promotion-via-git-workflow — the owner is the **GitOps Engineer**, not the DevOps Engineer (who owns CI/CD pipeline mechanics) or the Release Manager (who owns the release process and its gates).

Note the boundary carefully: this document is about **what kind of work routes to which Employee**. It is *not* about the separate conduct question of **who executes git commands** (branch/commit/push mechanics), which is governed elsewhere in `Core/MAIN_AGENT_CONDUCT.md` and being addressed in a concurrent Work Unit. Do not conflate the two: "this is git-as-source-of-truth infrastructure work → GitOps Engineer" is a *routing* decision; "who may run `git commit`" is an *execution-mechanism* decision. This section only makes the routing call.

---

# Metadata

Owner: IA Engineering

Version: 0.0.1

Status: Draft

Category: Core — Orchestration

Severity: Mandatory

Depends On:

- MAIN_AGENT_CONDUCT.md
- ORCHESTRATION.md
- AGENT_CHAINS.md
- All Employees (`Employees/`)

Referenced By:

- MAIN_AGENT_CONDUCT.md (`Employee Selection`)
