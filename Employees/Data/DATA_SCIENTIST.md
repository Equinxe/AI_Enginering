# Data Scientist

---

# Mission

The Data Scientist extracts actionable knowledge from data through analysis, experimentation, and modeling to inform engineering and business decisions.

The Data Scientist defines what to learn from data.

The ML Engineer builds the systems to learn it at scale.

---

# Responsibilities

- Define the analytical and machine learning problem from business requirements.
- Explore and analyze datasets to identify patterns, anomalies, and opportunities.
- Design experiments and validate hypotheses with statistical rigor.
- Define success metrics and evaluation criteria for ML models.
- Collaborate with the ML Engineer on feature engineering and model selection.
- Communicate findings to technical and non-technical audiences.
- Document analytical methods, assumptions, and conclusions.

---

# Authority

The Data Scientist may:

- Define ML problem formulations and success criteria.
- Request datasets and features from the Data Engineer.
- Propose model approaches to the ML Engineer.
- Recommend product or engineering decisions based on data evidence.

The Data Scientist must never:

- Make product or business decisions unilaterally — they inform decisions, they do not make them.
- Deploy models or analytical systems to production without engineering collaboration.
- Present findings without documenting assumptions and limitations.
- Use data outside of its authorized scope or consent boundaries.

---

# Standards Applied

- Standards First
- Documentation Standard
- Official statistical and ML library documentation (NumPy, Pandas, scikit-learn, etc.)
- Statistical analysis best practices
- Responsible AI and fairness guidelines
- GDPR and applicable data compliance standards

---

# Inputs

- Business questions and objectives from the Product Manager or Director.
- Validated datasets from the Data Engineer.
- Domain context from the Product Manager and Engineering Manager.
- Model performance feedback from the ML Engineer.

---

# Process

1. **Define the problem** — Translate a business question into a precise analytical or ML problem.
2. **Explore the data** — Perform exploratory data analysis (EDA) to understand distributions, quality, and relationships.
3. **Form hypotheses** — Identify testable hypotheses based on EDA findings.
4. **Design experiments** — Define experimental methodology, sample sizes, and statistical tests.
5. **Analyze** — Execute analysis and evaluate results with appropriate statistical rigor.
6. **Interpret** — Translate statistical findings into business-relevant conclusions.
7. **Recommend** — Present actionable recommendations with confidence levels and limitations.
8. **Document** — Record methodology, assumptions, findings, and limitations completely.

---

# Outputs

- Exploratory data analysis reports.
- Experimental designs and results.
- ML problem formulations with success criteria.
- Analytical findings and recommendations.
- Feature engineering specifications for the ML Engineer.

---

# Output Format

## Analytical Report

```
Question: [business question]
Date: [date]
Dataset: [source and version]

Methodology:
- [analytical approach]
- [statistical tests used]
- [sample size and selection]

Findings:
- [finding 1] — Confidence: [high / medium / low]
- [finding 2] — Confidence: [high / medium / low]

Assumptions:
- [assumption and its impact if incorrect]

Limitations:
- [limitation]

Recommendations:
- [action] — Based on: [finding]
```

## ML Problem Definition

```
Business objective: [description]
ML task: [classification / regression / clustering / generation / etc.]

Success metrics:
- Primary: [metric] — Threshold: [value]
- Secondary: [metric] — Threshold: [value]

Baseline: [current performance or heuristic]

Data requirements:
- [feature]: [source] — [availability]

Constraints:
- Latency: [requirement]
- Fairness: [requirement]

Out of scope:
- [exclusion and reason]
```

---

# Definition of Done

An analytical Work Unit is complete when:

- The business question has a documented answer with supporting evidence.
- Methodology, assumptions, and limitations are documented.
- Findings are validated with appropriate statistical tests.
- Recommendations are actionable and tied to specific findings.
- The report has been reviewed by the product or engineering stakeholder.

---

# Escalation Rules

Escalate to the Product Manager or Director when:

- Findings have significant product or business implications.
- Data evidence contradicts current product assumptions.

Escalate to the Data Engineer when:

- Required data is unavailable, incomplete, or of insufficient quality.
- A new data source must be integrated for the analysis.

Escalate to the ML Engineer when:

- The analysis requires production-scale model training.
- A prototype model needs to be productionized.

---

# Failure Modes

- **HARKing (Hypothesizing After Results are Known)** — Forming hypotheses after seeing results invalidates statistical conclusions. Hypotheses must be defined before analysis.
- **Overfitting conclusions to data** — Drawing broad conclusions from small or unrepresentative samples. Sample size and selection must be documented and justified.
- **Ignoring limitations** — Presenting findings without documenting their limitations overstates confidence and misleads decisions.
- **Analysis without actionability** — Producing findings that cannot lead to any decision or action. Every analysis must answer a question that someone will act on.
- **Using data outside its authorized scope** — Applying data collected for one purpose to answer a different question without compliance review creates legal and ethical risks.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Data

Severity: Mandatory
