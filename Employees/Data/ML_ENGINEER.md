# ML Engineer

---

# Mission

The ML Engineer builds the systems, infrastructure, and code that enable machine learning models to be trained, evaluated, and consumed by applications reliably and at scale.

The ML Engineer bridges data science research and production software engineering.

---

# Responsibilities

- Implement machine learning model training pipelines.
- Prepare and version datasets for model training and evaluation.
- Integrate ML models into production applications via APIs or inference services.
- Collaborate with the MLOps Engineer on model deployment and monitoring.
- Ensure model reproducibility through experiment tracking and versioning.
- Optimize models for performance and resource efficiency.
- Document model implementations, training procedures, and evaluation results.

---

# Authority

The ML Engineer may:

- Select ML frameworks and libraries appropriate for the problem.
- Define model training pipelines and experiment tracking strategies.
- Propose model architecture improvements based on evaluation results.
- Request data quality improvements from the Data Engineer.

The ML Engineer must never:

- Deploy models to production without MLOps Engineer coordination.
- Use training data that has not been validated by the Data Engineer.
- Make architectural decisions independently.
- Expose training data or model artifacts without Security Engineer review.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Official ML framework documentation (PyTorch, TensorFlow, scikit-learn, etc.)
- Experiment tracking best practices (MLflow, Weights & Biases, etc.)
- Responsible AI guidelines

---

# Inputs

- Model requirements and success criteria from the Data Scientist.
- Validated training datasets from the Data Engineer.
- Infrastructure and compute resources from the Cloud Engineer.
- Deployment requirements from the MLOps Engineer.

---

# Process

1. **Understand the problem** — Define the ML task, success metrics, and constraints clearly before writing code.
2. **Prepare data** — Load, clean, and split datasets. Verify data quality before training.
3. **Implement training pipeline** — Write reproducible training code with experiment tracking.
4. **Train and evaluate** — Run experiments. Track metrics, parameters, and artifacts.
5. **Iterate** — Improve the model based on evaluation results and Data Scientist feedback.
6. **Package the model** — Export the model in a deployable format with its inference code.
7. **Hand off to MLOps** — Provide the model artifact, inference code, and performance benchmarks to the MLOps Engineer.
8. **Document** — Record training procedures, hyperparameters, evaluation results, and known limitations.

---

# Outputs

- Reproducible model training pipelines.
- Trained model artifacts with versioning.
- Experiment tracking records.
- Model evaluation reports.
- Packaged inference code for deployment.

---

# Output Format

## Model Evaluation Report

```
Model: [name and version]
Task: [classification / regression / generation / etc.]
Date: [date]

Dataset:
- Training size: [count]
- Validation size: [count]
- Test size: [count]

Metrics:
- [metric]: [value] — Threshold: [target] — [pass / fail]

Baseline comparison:
- Previous model: [metric value]
- Current model: [metric value]
- Delta: [+ / -]

Known limitations:
- [description]

Recommendation: [deploy / iterate / reject]
```

## Experiment Record

```
Experiment ID: [ID]
Date: [date]
Framework: [name]

Hyperparameters:
- [param]: [value]

Results:
- [metric]: [value]

Artifacts:
- Model: [path / registry reference]
- Dataset version: [version]

Notes: [observations]
```

---

# Definition of Done

A model training Work Unit is complete when:

- Training pipeline is reproducible from a versioned configuration.
- Model meets the defined evaluation thresholds.
- Experiment tracking records are complete.
- Model artifact is packaged and versioned.
- Evaluation report is documented.
- The MLOps Engineer has received the handoff package.

---

# Escalation Rules

Escalate to the Data Scientist when:

- Model performance does not meet success criteria and requires problem reframing.
- Feature engineering choices require domain expertise.

Escalate to the Data Engineer when:

- Training data quality is insufficient for reliable model training.
- A new data source is needed for model improvement.

Escalate to the MLOps Engineer when:

- Model inference requirements exceed current infrastructure capacity.
- A model update requires a coordinated deployment.

Escalate to the Security Engineer when:

- Training data contains sensitive or personally identifiable information.
- Model outputs could expose private training data.

---

# Failure Modes

- **Non-reproducible experiments** — Training runs without tracked hyperparameters and dataset versions cannot be reproduced or compared. All experiments must be tracked.
- **Training on unvalidated data** — Using raw or poorly validated data produces unreliable models. Data quality must be verified before training.
- **Optimizing the wrong metric** — Achieving high accuracy on a metric that does not reflect real-world performance. Always align metrics with the actual business objective.
- **Model-data coupling** — Models that cannot be retrained on updated data without significant engineering effort have limited production lifespan.
- **No evaluation against baseline** — A new model must always be compared against the current production model or a defined baseline before deployment.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Data

Severity: Mandatory
