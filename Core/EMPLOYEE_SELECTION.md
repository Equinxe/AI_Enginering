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

- **Engineering Manager** — Dispatch when an objective must be decomposed into Work Units, assigned across Employees, and tracked to completion; when delivery coordination or unblocking across multiple Employees is needed. This is the orchestration-and-decomposition role, not an implementation role. See **Miscasting Risks** for the boundary with the Scrum Master.
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
- **Cloud Engineer** — Dispatch for designing and provisioning cloud infrastructure (compute, storage, networking, managed services) and cloud cost/security posture, aligned with the architecture. See **Miscasting Risks** for the boundary with the Infrastructure as Code Engineer.
- **Infrastructure as Code Engineer** (IaC Engineer) — Dispatch when infrastructure must be *defined as versioned, reviewable code* (Terraform, Pulumi, Ansible): modules, plans/dry-runs, state management.
- **GitOps Engineer** — Dispatch when git is the *declared source of truth for deployed infrastructure/application state*: GitOps operators (ArgoCD, Flux), drift detection/reconciliation, environment-promotion workflows. See **Miscasting Risks** for the boundary with DevOps/Release Manager.
- **Platform Engineer** — Dispatch to build the internal developer platform whose customer is the engineering team: container orchestration, standardized environments, service templates, developer self-service tooling. See **Miscasting Risks** for the boundary with the DevOps Engineer.
- **Observability Engineer** — Dispatch for logging, metrics, and distributed tracing instrumentation; dashboards; and actionable alerting with runbooks. See **Miscasting Risks** for the boundary with the SRE Engineer.
- **SRE Engineer** — Dispatch for production reliability: SLO/SLI definition, incident response and post-mortems, error-budget management, disaster-recovery/failover design.

## Quality

- **QA Engineer** — Dispatch to define and execute the testing strategy: functional/regression/acceptance testing, accessibility conformance verification (WCAG 2.2 AA for web content, or the applicable platform accessibility guidance for native iOS/Android), defect tracking, and quality sign-off against acceptance criteria.
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
- **Code Reviewer** — Dispatch to review a Pull Request for correctness, logic, tests, standards, and security awareness, and to render an approve/request-changes decision. Never self-reviews the author's own work. See **Miscasting Risks** for the boundary with the Technical Lead.
- **UX/UI Designer** — Dispatch for user research, user flows, wireframes, high-fidelity design, design systems, and accessibility (WCAG) — before UI code is written.
- **API Engineer** — Dispatch when the API *contract itself* is the deliverable: API design, schema/versioning strategy, contract-first design, and API lifecycle/deprecation, distinct from a Backend Engineer merely implementing an endpoint.
- **AI Engineer** — Dispatch to build AI-powered features: model selection, integration layers, evaluation pipelines, and AI observability. See **Miscasting Risks** for the AI/ML cluster boundary with the ML Engineer, MLOps Engineer, Prompt Engineer, and Data Scientist.
- **Prompt Engineer** — Dispatch when the deliverable is *itself a prompt or AI-instruction artifact*: prompt design, evaluation, guardrails, and versioned prompt libraries. See **Miscasting Risks** for the genuinely debatable AI-instruction-content case.
- **Compliance Engineer** — Dispatch for regulatory/legal/contractual obligations: translating GDPR, SOC 2, ISO 27001, HIPAA, PCI-DSS, etc. into engineering controls, gap analysis, and audit evidence, and open-source licence obligations of dependencies a Work Unit adds or updates. See **Miscasting Risks**.
- **Penetration Tester** — Dispatch for authorized offensive security testing within a Director-authorized scope: simulated attacks, CVSS-rated findings, and remediation verification — including adversarial passes on the framework's own controls (hooks, required checks, trailers) and on AI Employee behaviour. Distinct from the Security Engineer's defensive review role. See **Miscasting Risks**.

---

# Miscasting Risks

These are the pairs where a familiar generalist can superficially cover the same ground as a more specific Employee. Each is a concrete instance of the anti-pattern above. When the work matches one of these descriptions, the specific Employee is the right dispatch — do not default to the generalist.

## Compliance Engineer vs. Technical Writer

If the content's *purpose* is to satisfy a regulatory, legal, or contractual obligation — a GDPR data-processing record, a SOC 2 control description, a compliance policy — the owner is the **Compliance Engineer**, even though the deliverable is a document. The Technical Writer produces documentation content for a reader; they do not interpret regulations into controls. Routing compliance-adjacent content to the Technical Writer (as happened in the 2026-07-23 audit) produces prose without the regulatory grounding that is the entire point. The Technical Writer may later edit the Compliance Engineer's content for clarity, but the compliance substance is the Compliance Engineer's Work Unit.

## Business Analyst / Product Manager vs. Technical Writer

If the content *is* a business or requirements artifact — functional specifications, acceptance criteria, use cases, backlog definitions, requirements traceability — the owner is the **Business Analyst** (for eliciting and specifying requirements) or the **Product Manager** (for prioritization, scope, and what-to-build decisions). It is not a Technical Writer task merely because the output is written text. The 2026-07-23 audit found a document whose own RACI table named the Business Analyst and Product Manager as content co-owners, yet the Technical Writer wrote it alone. Authorship must match the content's substance, not its surface form.

## Security Engineer vs. DevOps Engineer

Anything touching **secrets, authentication, authorization, tokens, cryptography, PII, or infrastructure with production access** routes to the **Security Engineer** — not the DevOps Engineer, even when the work happens inside a pipeline or deployment config. The DevOps Engineer builds and operates pipelines; the moment the work is *about* the secret, the credential, the auth boundary, or production access rather than the pipeline mechanics, it is security work. The Security Engineer is the single most commonly under-dispatched Employee because so much security-relevant work is embedded in DevOps-shaped tasks. When both are needed, the Security Engineer defines the control and the DevOps Engineer wires it in — two Work Units, not one absorbed by the generalist. (`Core/AGENT_CHAINS.md`'s Review Chain already encodes the complementary rule: a security concern escalates to the Security Engineer immediately.)

## Penetration Tester vs. Security Engineer

If the work is *attacking* a control to find out whether it holds, the owner is the **Penetration Tester**, under Director authorization; if it is *reviewing* a design or change, or defining the control and its detection, the owner is the **Security Engineer**. A finding moves from the first to the second: the Penetration Tester hands it off, and the Security Engineer defines the regression check and the detection requirement that close it. The regression test is implemented by the QA Engineer or Test Automation Engineer and the detection by the Observability Engineer — separate Work Units, the same define/implement split as the Security Engineer vs. DevOps Engineer entry. Issue #112 shows the closing half: the escape-hatch bypass was found by an adversarial pass on the framework's own hook, and WU-IAENG-285 closed its printf-built-token class as regression cases in the hook's test suite. WU-IAENG-285 predates this split and combined both roles in one Security Engineer Work Unit, fixing the lexer and writing the regression cases; the split is the rule from here on.

## Penetration Tester vs. Prompt Engineer

If the work is *attacking* an AI Employee or its runtime to find out whether a control holds — prompt injection, hook or escape-hatch bypass, check gaming — the owner is the **Penetration Tester**, under Director authorization. If it is *designing* guardrails or *evaluating* how robust an instruction is to adversarial or ambiguous inputs, the owner is the **Prompt Engineer** (see Prompt Engineer vs. Software Architect below). When the control a finding defeats is a prompt or a guardrail, the finding hands off to the Prompt Engineer for the fix; the Security Engineer still defines how it stays closed.

## AI Engineer / ML Engineer / MLOps Engineer / Prompt Engineer / Data Scientist — the AI/ML cluster

Five Employees claim overlapping ground in AI/ML work, and four of them use the word "evaluation" as a Responsibility, Authority, or Process step — which reads as redundancy until the object of each evaluation is made explicit, because the files already state the hand-off. The **AI Engineer** owns the feature-level evaluation dataset and quality thresholds: "Design and implement evaluation systems to measure AI feature quality and regression" (`Employees/Specialized/AI_ENGINEER.md`). The **Prompt Engineer** receives "Evaluation datasets from the AI Engineer" as an Input and evaluates prompt *versions* against them: "Evaluate prompt quality against defined success criteria using systematic testing" (`Employees/Specialized/PROMPT_ENGINEER.md`). The **ML Engineer** evaluates the *trained model* against a baseline before handoff: its Outputs include "Model evaluation reports", checked "against the current production model or a defined baseline" (`Employees/Data/ML_ENGINEER.md`). The **MLOps Engineer** validates the model it is about to deploy against those same thresholds in staging: "Deploy to staging — Deploy the model to a staging environment and run evaluation tests" and may "Block model deployments that fail evaluation thresholds" (`Employees/Data/MLOPS_ENGINEER.md`). The Mission statements alone do not disambiguate this: the AI Engineer "bridges the gap between AI research and production software" in language nearly identical to the ML Engineer, who "bridges data science research and production software engineering" (`Employees/Specialized/AI_ENGINEER.md`, `Employees/Data/ML_ENGINEER.md`).

Ask what the work is actually about:

- **Integrating a hosted model API into the product** — calling a third-party LLM/vision endpoint, building the prompt pipeline and fallback logic around it, evaluating whether the *feature* meets quality thresholds — is the **AI Engineer**.
- **Producing new model weights** — a training dataset and its versioning, a fine-tune job, evaluating the result against the base model — is the **ML Engineer**, wherever the base model is hosted. Fine-tuning a hosted model is not an exception to AI Engineer ownership: if the Work Unit produces new weights, it is ML Engineer work; integrating the resulting endpoint into the product is a separate, AI Engineer Work Unit.
- **Running the training/serving pipeline in production** — registries, deployment pipelines, drift detection, retraining automation, rollback, staging validation against thresholds — is the **MLOps Engineer**, who "applies DevOps engineering discipline to the machine learning lifecycle" (`Employees/Data/MLOPS_ENGINEER.md`).
- **Designing the instruction or prompt itself** — system instruction, context strategy, and the prompt's own versioned evaluation against the AI Engineer's evaluation dataset — is the **Prompt Engineer**.
- **Deciding whether a model is worth building from the data at all** — problem formulation, exploratory analysis, and the success criteria a model must hit before an ML Engineer builds it — is the **Data Scientist**, whose own Mission draws the ML Engineer boundary explicitly: "The Data Scientist defines what to learn from data. The ML Engineer builds the systems to learn it at scale." (`Employees/Data/DATA_SCIENTIST.md`).

A related routing question, common enough to name directly: **retrieval-augmented generation and vector search**. The retrieval pipeline and context strategy — what gets retrieved, how it is assembled into the prompt — is AI Engineer work; *choosing* the vector store as a storage technology is the Data Architect's call: "Define data storage strategies: relational, document, key-value, time-series, or hybrid" (`Employees/Architecture/DATA_ARCHITECT.md`); its schema and indexes are the Database Engineer's implementation: "Implement indexes, constraints, and relationships defined in the data model" (`Employees/Development/DATABASE_ENGINEER.md`); and provisioning a managed vector database is Cloud Engineer / IaC Engineer work, per the entry below.

The hand-off runs Data Scientist (what to learn) → ML Engineer (train/package it) → MLOps Engineer (deploy/operate it in production), with the AI Engineer and Prompt Engineer as the adjacent pair that integrates a model — usually someone else's, reached via API — into a product feature. "Evaluation" is not redundant across the four that use the word: each evaluates a different object, at a different stage of the pipeline. Route by the object, not the word.

## Technical Lead vs. Software Architect

Both make technical decisions, but at different altitudes:

- **Software Architect** owns *architecture*: system structure, technology-stack selection, architectural patterns, and ADRs. If the decision would be recorded as an ADR or changes the system's structure, it is the Software Architect's.
- **Technical Lead** owns *cross-cutting consistency and convention within the established architecture*: applying architectural decisions, project-level conventions, pre-PR technical review, and resolving inconsistencies. The Technical Lead's own definition is explicit — *"Technical conventions are not architecture"* — and escalates to the Software Architect when a decision requires an architectural change.

The error to avoid: routing project-wide *consistency/convention* decisions to the Software Architect (over-weighting them as "architecture") or routing genuine *structural/technology* decisions to the Technical Lead (under-weighting them). Ask: does this set or change the architecture (Software Architect), or apply and keep it consistent (Technical Lead)?

## Code Reviewer vs. Technical Lead

Both review technical work, and both use the word "review" in their Mission, but they sit on opposite sides of the same event: the Pull Request being opened. The **Technical Lead** reviews *before* a PR exists — "Review technical deliverables before they reach the Pull Request stage" — and may "Request rework before a Pull Request is opened"; its Output is "Pre-PR technical review feedback", aimed at direction and cross-cutting convention, not a merge decision (`Employees/Management/TECHNICAL_LEAD.md`). The **Code Reviewer** is "the last quality gate before code reaches the shared codebase" (`Employees/Specialized/CODE_REVIEWER.md`), reviewing the opened Pull Request itself — "Review Pull Requests for correctness, logic, security, and adherence to standards" — with the Authority to "Request changes before approving a Pull Request" and to render the approve/request-changes decision, never approving "their own Pull Requests". That decision is the quality gate a Pull Request must clear to become mergeable — the Code Reviewer does not merge it: the merge is a separate step of the Workflow — `Workflows/FEATURE_DEVELOPMENT.md` Step 8 for a Pull Request into `develop`, and `Workflows/RELEASE.md` Step 5 for a merge to `main`, which needs explicit Director approval. If the work is guiding an implementation toward architectural and convention compliance before it is submitted, or resolving a codebase-wide inconsistency, it is the Technical Lead; if the work is rendering the approve/request-changes decision on a specific, already-opened Pull Request, it is the Code Reviewer. The two compose rather than compete: the Technical Lead's guidance is meant to make the Code Reviewer's job smaller, not to duplicate it.

## Engineering Manager vs. Scrum Master

Both coordinate the team, and both can look like "the person who tells Employees what to do," but only one has that authority. The **Engineering Manager** decomposes objectives into Work Units and assigns them — "Decompose objectives into Work Units", "Assign Work Units to the appropriate Employees", with the Authority to "Assign and reassign Work Units" — and "enables implementation" by owning delivery outcomes (`Employees/Management/ENGINEERING_MANAGER.md`). The **Scrum Master** "manages the process," not the people or the technical assignment (`Employees/Management/SCRUM_MASTER.md`): it facilitates ceremonies — "Facilitate Scrum ceremonies: Sprint Planning, Daily Standup, Sprint Review, Sprint Retrospective" — and removes impediments, but must never "Assign technical implementation to specific Employees" or "Make technical or architectural decisions". If the work is deciding *what* Work Unit exists and *who* does it, it is the Engineering Manager; if the work is facilitating the *ceremony* through which that work is planned, tracked, and reflected on — or removing a process impediment — it is the Scrum Master. A Scrum Master that starts assigning Work Units, or an Engineering Manager that starts running standups instead of unblocking them, has drifted into the other's role.

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

## Cloud Engineer vs. Infrastructure as Code Engineer

Both work on infrastructure and both name each other as collaborators, which can read as duplication. The split is design-vs-implementation, the same pattern as Data Architect vs. Database Engineer and Solution Architect vs. Integration Engineer elsewhere in this roster: the **Cloud Engineer** decides what to provision — "Design and provision cloud infrastructure aligned with the Software Architect's decisions", topology, and cost — and must never "Create cloud resources outside of Infrastructure as Code tooling in production" (`Employees/DevOps/CLOUD_ENGINEER.md`). The security requirement is not the Cloud Engineer's to originate: it takes "Security requirements from the Security Engineer" as an Input and designs the cloud controls — IAM policy, network segmentation, encryption — that meet them, the same define/implement split as Security Engineer vs. DevOps Engineer above, one layer lower in the stack. The **Infrastructure as Code Engineer** writes and maintains the declarative code for whatever the Cloud Engineer designs: "Write and maintain all infrastructure definitions using IaC tooling (Terraform, Pulumi, Ansible, etc.)" (`Employees/DevOps/IAC_ENGINEER.md`), taking "Infrastructure designs from the Cloud Engineer" as an Input, while the Cloud Engineer takes "IaC specifications from the Infrastructure as Code Engineer" as one of its own. If the work is deciding *what* infrastructure to provision, including the controls that meet the Security Engineer's requirements, it is the Cloud Engineer; if the work is writing or maintaining the *code that declares* it, it is the IaC Engineer. A Work Unit that does both is two Work Units, not one absorbed by whichever Employee is already active.

## Platform Engineer vs. DevOps Engineer

Their Missions read almost the same sentence twice: the DevOps Engineer "builds and maintains the pipelines, automation, and tooling that enable Employees to deliver software reliably and consistently"; the Platform Engineer "builds and maintains the internal developer platform that enables Employees to build, test, and deploy software efficiently and consistently" (`Employees/DevOps/DEVOPS_ENGINEER.md`, `Employees/DevOps/PLATFORM_ENGINEER.md`). The boundary is *pipeline* vs. *substrate*: the **DevOps Engineer** owns the CI/CD pipeline that moves a change through build, test, and deploy — "Design, implement, and maintain CI/CD pipelines", "Implement deployment strategies: blue-green, canary, rolling updates" — and takes "Infrastructure specifications from the Cloud Engineer and Platform Engineer" as an Input, escalating to the Cloud Engineer or Platform Engineer when "A pipeline requires infrastructure changes" (`Employees/DevOps/DEVOPS_ENGINEER.md`). The **Platform Engineer** owns the internal developer platform engineers consume — the orchestration substrate, standardized environments, templates, and shared or self-service tooling: "Manage container orchestration platforms (Kubernetes, etc.)", "Define and maintain platform standards: container images, service templates, environment configurations" — and its "customer is the engineering team itself" (`Employees/DevOps/PLATFORM_ENGINEER.md`), taking "Application requirements from Backend, Frontend, and DevOps Engineers" as an Input. If the work is *moving code through the pipeline*, it is DevOps; if the work is *the orchestration substrate, standardized environments, templates, or self-service tooling the pipeline and services build against*, it is Platform.

## Observability Engineer vs. SRE Engineer

Both sit on production reliability and both name each other, but they own different halves of the same feedback loop. The **Observability Engineer** builds the instrumentation — "Design and implement logging, metrics, and distributed tracing across all services" — and produces the signal the SRE Engineer measures against: it takes "SLO definitions from the SRE Engineer" as an Input while collaborating "with the SRE Engineer to align observability with SLO measurement" (`Employees/DevOps/OBSERVABILITY_ENGINEER.md`). The **SRE Engineer** defines the reliability target and owns the response when it is missed — "Define and track Service Level Objectives (SLOs) and Service Level Indicators (SLIs)", "Lead incident response, root cause analysis, and post-mortem processes" — taking "Observability data from the Observability Engineer" as an Input (`Employees/DevOps/SRE_ENGINEER.md`). Paging thresholds follow the same split: the SRE Engineer sets them from SLO burn rate and error-budget consumption, and the Observability Engineer configures the alert that fires on them.

`Core/AGENT_CHAINS.md`'s Incident Chain names the Engineering Manager at the post-mortem step, which is not a third claimant on this pair's work: the chain has the Engineering Manager *convene* the post-mortem as a delivery-coordination step, while the SRE Engineer owns its technical content — "Conduct post-mortems — Analyze root causes without blame" is the SRE Engineer's own Process step, and stays so inside the chain.

If the work is instrumenting a service so its behavior can be seen — logs, metrics, traces, dashboards, alerts — it is the Observability Engineer; if the work is setting the reliability target that data is measured against, SLO-derived paging thresholds, or running incident response and post-mortems, it is the SRE Engineer. This is the same define/implement complementary pattern as Security Engineer vs. DevOps Engineer above: the SRE Engineer defines what "reliable" means for a service, the Observability Engineer builds what makes that measurable.

## GitOps Engineer vs. DevOps Engineer / Release Manager

When the work treats **git as the declared source of truth for deployed state** — reconciling live infrastructure to what git declares, drift detection, GitOps operators, environment-promotion-via-git-workflow — the owner is the **GitOps Engineer**, not the DevOps Engineer (who owns CI/CD pipeline mechanics) or the Release Manager (who owns the release process and its gates).

Note the boundary carefully: this document is about **what kind of work routes to which Employee**. It is *not* about the separate conduct question of **who executes git commands** (branch/commit/push mechanics), which is governed elsewhere in `Core/MAIN_AGENT_CONDUCT.md` and being addressed in a concurrent Work Unit. Do not conflate the two: "this is git-as-source-of-truth infrastructure work → GitOps Engineer" is a *routing* decision; "who may run `git commit`" is an *execution-mechanism* decision. This section only makes the routing call.

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

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
