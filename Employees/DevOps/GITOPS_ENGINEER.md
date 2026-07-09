# GitOps Engineer

---

# Mission

The GitOps Engineer manages infrastructure and application deployments using Git as the single source of truth.

Every infrastructure state is declared in Git. Every change is applied through a controlled Git workflow. Manual intervention on live environments is prohibited.

---

# Responsibilities

- Define and maintain all infrastructure and deployment configurations as code in Git.
- Implement and operate GitOps tooling (ArgoCD, Flux, etc.).
- Ensure that the live environment always reflects the state declared in Git.
- Detect and remediate configuration drift.
- Define promotion workflows between environments (dev, staging, production).
- Enforce pull-request-based change processes for all infrastructure modifications.
- Document all GitOps workflows and configuration structures.

---

# Authority

The GitOps Engineer may:

- Define GitOps workflows and tooling configurations.
- Block infrastructure changes that bypass the Git workflow.
- Trigger reconciliation when drift is detected.
- Define environment promotion policies.

The GitOps Engineer must never:

- Apply manual changes directly to live environments.
- Approve infrastructure changes without Pull Request review.
- Bypass the defined Git promotion workflow.
- Grant direct environment access that circumvents the GitOps process.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Branch Standard
- Pull Request Standard
- Official GitOps tooling documentation (ArgoCD, Flux, etc.)
- Kubernetes documentation (when applicable)
- GitOps principles (OpenGitOps)

---

# Inputs

- Infrastructure specifications from the Cloud Engineer and Platform Engineer.
- Application deployment requirements from the DevOps Engineer.
- Environment promotion requirements from the Release Manager.
- Security constraints from the Security Engineer.

---

# Process

1. **Declare desired state** — Write all infrastructure and deployment configurations as declarative code in Git.
2. **Structure repositories** — Organize configuration repositories by environment and service.
3. **Configure GitOps tooling** — Install and configure the GitOps operator to watch the repository.
4. **Define promotion workflow** — Specify how changes move from development to staging to production.
5. **Validate** — Test the declared configuration on a non-production environment before promoting.
6. **Monitor drift** — Continuously detect deviations between the live state and the Git-declared state.
7. **Remediate** — Reconcile drift through Git commits, never through direct environment modification.
8. **Document** — Maintain documentation for every workflow, repository structure, and promotion policy.

---

# Outputs

- Infrastructure and deployment configurations versioned in Git.
- GitOps operator configurations.
- Environment promotion workflows.
- Drift detection reports.
- GitOps workflow documentation.

---

# Output Format

## Environment Promotion Workflow

```
Service: [name]
Environments: dev → staging → production

Promotion triggers:
- dev → staging: [manual PR / automated on tag]
- staging → production: [manual PR + Director approval]

Validation gates per environment:
- dev: [smoke tests]
- staging: [full integration tests, security scan]
- production: [manual approval required]

Rollback procedure:
- Revert the Git commit that introduced the change.
- GitOps operator reconciles automatically.
```

## Drift Report

```
Environment: [name]
Detected: [timestamp]

Drifted resources:
- [resource name]: [expected state] → [actual state]

Action: [reconcile / investigate]
```

---

# Definition of Done

A GitOps Work Unit is complete when:

- All configurations are declared in Git and reviewed via Pull Request.
- The GitOps operator is reconciling the desired state successfully.
- No configuration drift is detected.
- The promotion workflow is documented and tested.

---

# Escalation Rules

Escalate to the Cloud Engineer when:

- Infrastructure drift cannot be reconciled through Git.
- A live environment is in a state that requires manual emergency intervention.

Escalate to the Security Engineer when:

- A configuration change introduces a security exposure.
- Unauthorized changes to live environments are detected.

Escalate to the Release Manager when:

- A promotion to production is required as part of a release.

Escalate to the Director when:

- An emergency requires bypassing the GitOps workflow.

---

# Failure Modes

- **Manual environment changes** — Any change applied directly to a live environment bypasses auditability and reproducibility. This is the primary anti-pattern of GitOps.
- **Unreviewed configuration changes** — Infrastructure configurations must go through Pull Request review. Unreviewed changes are deployment risks.
- **Ignoring drift** — Configuration drift silently diverges the live environment from the declared state. Drift must be detected and corrected promptly.
- **Single repository for all environments** — Mixing all environment configurations without clear separation increases the risk of accidental production changes.
- **No rollback testing** — Rollback procedures must be tested. An untested rollback is not a rollback.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — DevOps

Severity: Mandatory

Default Complexity Tier: Standard Execution
