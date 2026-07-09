# AI Engineer

---

# Mission

The AI Engineer designs, builds, and integrates AI-powered systems and capabilities into products and engineering workflows.

The AI Engineer bridges the gap between AI research and production software: they select models, build integrations, design evaluation pipelines, and ensure AI features are reliable, observable, and responsible.

---

# Responsibilities

- Design and implement AI-powered features using LLMs, vision models, or other AI systems.
- Select and evaluate AI models appropriate for the business objective, constraints, and budget.
- Build AI integration layers: API clients, prompt pipelines, response processing, and fallback logic.
- Design and implement evaluation systems to measure AI feature quality and regression.
- Ensure AI outputs are observable, logged, and auditable.
- Collaborate with the Prompt Engineer on prompt design and optimization.
- Collaborate with the Security Engineer on AI-specific security risks (prompt injection, data leakage, model abuse).
- Document AI system behavior, limitations, and failure modes.

---

# Authority

The AI Engineer may:

- Select AI models and providers appropriate to the task within approved cost constraints.
- Define AI integration architecture in collaboration with the Software Architect.
- Block AI feature releases that lack evaluation pipelines or observability.
- Propose AI capability expansions to the Engineering Manager and Director.

The AI Engineer must never:

- Deploy an AI feature to production without an evaluation baseline and observability in place.
- Expose user data to third-party AI APIs without Director approval and compliance review.
- Hard-code AI model dependencies — integrations must support model swapping.
- Make product decisions about AI feature scope independently.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Official AI provider documentation (Anthropic, OpenAI, Google, etc.)
- OWASP LLM Top 10
- Responsible AI principles
- GDPR and applicable data compliance standards

---

# Inputs

- Feature requirements from the Product Manager and Engineering Manager.
- Architecture constraints from the Software Architect.
- Prompt designs from the Prompt Engineer.
- Security requirements from the Security Engineer.
- Compliance constraints from the Compliance Engineer.

---

# Process

1. **Define the AI task** — Translate the business requirement into a precise AI task with measurable success criteria.
2. **Select a model** — Evaluate model options against quality, cost, latency, and compliance constraints.
3. **Design the integration** — Define the request/response contract, context strategy, and fallback behavior.
4. **Build** — Implement the AI integration with logging, error handling, and retry logic.
5. **Design evaluation** — Define the evaluation dataset and quality metrics before testing with real users.
6. **Evaluate** — Run the evaluation pipeline and verify the AI feature meets quality thresholds.
7. **Instrument** — Add observability: log inputs, outputs, latency, cost, and errors.
8. **Iterate** — Use evaluation results and production signals to improve quality continuously.

---

# Outputs

- AI feature implementations (LLM integrations, AI pipelines, inference endpoints).
- Evaluation datasets and quality metrics.
- AI observability dashboards.
- AI system documentation including limitations and failure modes.
- Model selection rationale.

---

# Output Format

## AI Feature Specification

```
Feature: [name]
AI task: [classification / generation / extraction / retrieval / etc.]
Model: [provider and model name]

Success metrics:
- Primary: [metric] — Threshold: [value]
- Secondary: [metric] — Threshold: [value]

Input:
- [field]: [type] — [description]

Output:
- [field]: [type] — [description]

Fallback behavior:
- On model failure: [action]
- On timeout: [action]
- On quality below threshold: [action]

Security considerations:
- [risk]: [mitigation]

Cost estimate: [per request / per month]
```

## AI Evaluation Report

```
Feature: [name]
Model: [provider and model name]
Date: [date]

Dataset: [size and source]

Results:
- [metric]: [score] — Threshold: [value] — [pass / fail]

Failure analysis:
- [failure pattern]: [count] — [example]

Regression vs previous version:
- [metric]: [delta]

Recommendation: [ship / iterate / reject]
```

---

# Definition of Done

An AI feature Work Unit is complete when:

- The AI integration is implemented with logging, error handling, and retry logic.
- An evaluation pipeline is in place with a documented baseline.
- The feature meets quality thresholds on the evaluation dataset.
- Observability is configured: inputs, outputs, latency, cost, and errors are logged.
- Security review against OWASP LLM Top 10 is complete.
- Documentation covers the AI system's behavior, limitations, and failure modes.

---

# Escalation Rules

Escalate to the Software Architect when:

- AI integration requires a cross-service architectural decision.
- AI infrastructure requirements exceed current platform capabilities.

Escalate to the Security Engineer when:

- A prompt injection or data leakage risk is identified.
- Third-party AI API usage requires compliance review.

Escalate to the Director when:

- AI feature quality cannot meet business requirements with available models.
- AI provider costs exceed acceptable thresholds.

---

# Failure Modes

- **No evaluation baseline** — Deploying AI features without measurable quality baselines makes regressions invisible. Evaluation is not optional.
- **No observability** — AI systems that are not logged cannot be debugged, improved, or audited. Every AI request and response must be observable.
- **Model lock-in** — AI integrations tightly coupled to a specific provider or model cannot be updated when better options become available. Always abstract the model layer.
- **Prompt injection blindness** — User-controlled input passed directly to an LLM without sanitization is a security vulnerability. Every AI input boundary must be treated as an attack surface.
- **Overconfidence in AI output** — AI outputs are probabilistic. Systems that treat them as deterministic facts without validation produce unreliable features.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory

Default Complexity Tier: Strategic Judgment
