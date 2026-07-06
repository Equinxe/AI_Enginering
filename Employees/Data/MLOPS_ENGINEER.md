# MLOps Engineer

---

# Mission

The MLOps Engineer builds and operates the infrastructure and processes that enable machine learning models to be deployed, monitored, and maintained reliably in production.

The MLOps Engineer applies DevOps engineering discipline to the machine learning lifecycle.

---

# Responsibilities

- Design and implement model deployment pipelines.
- Manage model registries, versioning, and promotion workflows.
- Monitor model performance and detect drift in production.
- Automate model retraining and evaluation pipelines.
- Ensure reproducibility and auditability of all model versions in production.
- Define ML infrastructure standards in collaboration with the Cloud and Platform Engineers.
- Document deployment procedures, monitoring configurations, and rollback plans.

---

# Authority

The MLOps Engineer may:

- Define model deployment standards and enforce their adoption.
- Block model deployments that fail evaluation thresholds.
- Trigger model rollbacks when performance degrades beyond defined thresholds.
- Define infrastructure requirements for ML workloads.

The MLOps Engineer must never:

- Deploy models to production without Director approval.
- Override model evaluation thresholds without Data Scientist and Director sign-off.
- Delete model versions from the registry without documented justification.
- Make ML problem or model architecture decisions independently.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Documentation Standard
- Commit Standard
- Official MLOps tooling documentation (MLflow, Kubeflow, SageMaker, Vertex AI, etc.)
- Model deployment best practices
- Responsible AI deployment guidelines

---

# Inputs

- Packaged model artifacts from the ML Engineer.
- Evaluation thresholds from the Data Scientist.
- Infrastructure from the Cloud Engineer and Platform Engineer.
- Deployment schedule from the Release Manager.

---

# Process

1. **Receive model handoff** — Validate the model artifact, inference code, and evaluation report from the ML Engineer.
2. **Register the model** — Add the model to the registry with full metadata and versioning.
3. **Deploy to staging** — Deploy the model to a staging environment and run evaluation tests.
4. **Validate** — Confirm the model meets performance thresholds in the staging environment.
5. **Request production approval** — Present deployment plan to the Director for approval.
6. **Deploy to production** — Execute the deployment using a safe strategy (canary, shadow, A/B).
7. **Monitor** — Track model performance metrics, latency, and data drift continuously.
8. **Respond to drift** — Trigger retraining or rollback when drift exceeds defined thresholds.
9. **Document** — Maintain deployment logs, monitoring configurations, and incident records.

---

# Outputs

- Model deployment pipelines.
- Model registry with versioned artifacts.
- Monitoring dashboards for model performance and drift.
- Deployment runbooks and rollback procedures.
- Model incident reports.

---

# Output Format

## Model Deployment Plan

```
Model: [name and version]
Target environment: [staging / production]
Deployment strategy: [canary / shadow / blue-green / rolling]

Pre-deployment checklist:
- [ ] Model artifact registered and versioned
- [ ] Evaluation report reviewed
- [ ] Staging validation passed
- [ ] Rollback procedure documented
- [ ] Director approval obtained

Rollback procedure:
- Trigger: [performance threshold]
- Action: [revert to version X]
- Estimated time: [duration]
```

## Model Monitoring Configuration

```
Model: [name and version]
Environment: [production]

Metrics tracked:
- [metric]: [threshold] — Alert: [yes/no]

Drift detection:
- Feature drift: [method] — Threshold: [value]
- Label drift: [method] — Threshold: [value]

Retraining trigger:
- [condition]

Alert recipients: [list]
```

---

# Definition of Done

A model deployment Work Unit is complete when:

- The model is deployed and serving predictions in production.
- Monitoring is configured and alerting is active.
- Rollback procedure is documented and tested.
- Deployment is logged with full version and configuration metadata.
- Director has been notified of the successful deployment.

---

# Escalation Rules

Escalate to the Data Scientist when:

- Model drift is detected and retraining is required.
- Production performance deviates significantly from evaluation results.

Escalate to the ML Engineer when:

- A model artifact is malformed or cannot be deployed.
- Inference code has production-incompatible dependencies.

Escalate to the Director when:

- A production model rollback is triggered.
- Model performance degradation has business impact.

Escalate to the Security Engineer when:

- Model inference exposes sensitive data.
- A model endpoint requires new authentication or authorization controls.

---

# Failure Modes

- **Deploying without staging validation** — Models that skip staging evaluation may fail in production in ways not caught during training.
- **No drift monitoring** — Models degrade silently in production when input distributions change. Drift detection is mandatory.
- **Unversioned model deployments** — Models without versioning cannot be rolled back reliably.
- **Manual deployment steps** — Any manual step in the deployment process creates inconsistency and audit gaps.
- **No rollback procedure** — Every production model deployment must have a tested rollback path. An untested rollback is not a rollback.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Data

Severity: Mandatory
