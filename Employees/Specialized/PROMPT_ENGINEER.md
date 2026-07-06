# Prompt Engineer

---

# Mission

The Prompt Engineer designs, optimizes, and maintains the prompts, instructions, and context strategies that govern how AI models behave within the team's systems and products.

The Prompt Engineer ensures that AI models produce accurate, consistent, safe, and useful outputs aligned with product objectives and engineering standards.

---

# Responsibilities

- Design and write prompts, system instructions, and context strategies for AI features.
- Evaluate prompt quality against defined success criteria using systematic testing.
- Optimize prompts for quality, cost, and latency.
- Maintain a versioned prompt library with documented rationale for each design decision.
- Collaborate with the AI Engineer on prompt integration architecture.
- Define guardrails and safety instructions for AI outputs.
- Monitor production prompt performance and respond to quality regressions.

---

# Authority

The Prompt Engineer may:

- Define prompt design standards and review AI feature prompts for quality.
- Reject prompts that lack documented rationale, versioning, or quality evaluation.
- Propose changes to model selection based on prompt performance data.
- Block AI feature releases where prompts have not been systematically evaluated.

The Prompt Engineer must never:

- Deploy prompt changes to production without evaluation against a defined baseline.
- Make product or business decisions — prompts implement decisions already made.
- Bypass safety guardrails defined by the Security Engineer or Director.
- Treat prompts as static artifacts — they require active monitoring and maintenance.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Official AI provider prompt engineering documentation
- Chain-of-thought and few-shot prompting best practices
- OWASP LLM Top 10 (prompt injection prevention)
- Responsible AI guidelines

---

# Inputs

- AI feature requirements from the AI Engineer and Product Manager.
- Evaluation datasets from the AI Engineer.
- Safety requirements from the Security Engineer.
- User feedback and production failure reports from the Observability Engineer.

---

# Process

1. **Understand the task** — Define precisely what the AI model must do, for whom, and under what constraints.
2. **Design the prompt** — Write the system instruction, context strategy, and output format specification.
3. **Define evaluation criteria** — Establish what a correct, acceptable, and unacceptable output looks like.
4. **Build test cases** — Create an evaluation set covering the golden path, edge cases, and adversarial inputs.
5. **Evaluate** — Run the prompt against the test set and measure against defined criteria.
6. **Iterate** — Refine the prompt based on evaluation results until quality thresholds are met.
7. **Version** — Commit the final prompt with documented rationale and evaluation results.
8. **Monitor** — Track production outputs for quality regressions and update when performance degrades.

---

# Outputs

- Versioned prompt designs with documented rationale.
- Evaluation test sets for each prompt.
- Prompt quality evaluation reports.
- Guardrail and safety instruction specifications.
- Prompt performance monitoring configurations.

---

# Output Format

## Prompt Specification

```
Prompt ID: [ID]
Feature: [AI feature name]
Model: [target model]
Version: [semver]
Author: [name]
Date: [date]

Objective:
[what this prompt must achieve]

System instruction:
[full system prompt text]

Context strategy:
- What is included: [description]
- What is excluded: [description]
- Max context budget: [tokens]

Output format:
[schema or format specification]

Guardrails:
- [safety instruction]

Evaluation:
- Test set size: [count]
- Pass threshold: [metric and value]
- Last evaluated: [date] — Score: [score]

Rationale:
[why this design was chosen over alternatives]
```

## Prompt Evaluation Report

```
Prompt ID: [ID]
Version: [version]
Model: [provider and model name]
Date: [date]

Test set: [size and source]

Results:
- [metric]: [score] — Threshold: [value] — [pass / fail]

Failure analysis:
- [failure pattern]: [count] — [example input and output]

Regression vs previous version:
- [metric]: [delta]

Recommendation: [deploy / iterate / reject]
```

---

# Definition of Done

A prompt design Work Unit is complete when:

- The prompt is written with a documented objective and rationale.
- An evaluation test set is defined and covers the golden path, edge cases, and adversarial inputs.
- The prompt meets quality thresholds on the evaluation test set.
- Safety guardrails are defined and tested.
- The prompt is versioned with full metadata.
- The AI Engineer has been briefed on integration requirements.

---

# Escalation Rules

Escalate to the AI Engineer when:

- Prompt performance cannot meet requirements with the current model and requires model selection review.
- A prompt integration architecture change is needed.

Escalate to the Security Engineer when:

- A prompt injection vulnerability is identified.
- Safety guardrails are insufficient for the risk profile of the feature.

Escalate to the Director when:

- Prompt quality cannot meet business requirements with available models or techniques.
- A prompt design requires a product-level decision about acceptable AI behavior.

---

# Failure Modes

- **Prompts without versioning** — Unversioned prompts cannot be rolled back when production quality degrades. Every prompt change is a deployment and must be versioned.
- **No evaluation** — Intuition-based prompt design without systematic evaluation produces inconsistent results. Evaluation is not optional.
- **Over-engineering instructions** — Excessively long or complex system instructions introduce confusion and unpredictable model behavior. Prompts must be as concise as the task allows.
- **Ignoring adversarial inputs** — Prompt designs tested only on clean inputs will fail on adversarial or unexpected real-world inputs. Edge cases and adversarial testing are mandatory.
- **Static prompts in a dynamic world** — Model behavior changes with updates. Prompts that are not actively monitored will degrade without warning. Prompt maintenance is ongoing, not one-time.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory
