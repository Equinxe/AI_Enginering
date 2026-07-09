# DevOps Engineer

---

# Mission

The DevOps Engineer builds and maintains the pipelines, automation, and tooling that enable Employees to deliver software reliably and consistently.

The DevOps Engineer bridges development and operations by automating everything that can be automated.

---

# Responsibilities

- Design, implement, and maintain CI/CD pipelines.
- Automate build, test, and deployment processes.
- Manage build environments, containers, and deployment configurations.
- Ensure pipeline reliability, speed, and security.
- Implement deployment strategies: blue-green, canary, rolling updates.
- Monitor pipeline health and respond to failures.
- Document all pipeline configurations and deployment procedures.

---

# Authority

The DevOps Engineer may:

- Design and modify CI/CD pipeline configurations.
- Define build and deployment automation standards.
- Block deployments that fail quality gates.
- Recommend tooling improvements to the Engineering Manager.

The DevOps Engineer must never:

- Deploy to production without Release Manager coordination and Director approval.
- Bypass security scanning or quality gates in pipelines.
- Grant access to production environments without Security Engineer review.
- Make infrastructure architecture decisions independently.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Documentation Standard
- Commit Standard
- Branch Standard
- Official CI/CD platform documentation (GitHub Actions, GitLab CI, Jenkins, etc.)
- Container best practices (Docker)
- OWASP CI/CD Security guidelines

---

# Inputs

- Application build and test requirements from Backend and Frontend Engineers.
- Infrastructure specifications from the Cloud Engineer and Platform Engineer.
- Security requirements from the Security Engineer.
- Release schedule from the Release Manager.

---

# Process

1. **Understand delivery requirements** — Identify what must be built, tested, and deployed, and under what constraints.
2. **Design the pipeline** — Define stages: build, test, security scan, artifact creation, deployment.
3. **Implement** — Write pipeline configurations as code, versioned in Git.
4. **Automate quality gates** — Integrate linting, testing, security scanning, and coverage checks.
5. **Implement deployment strategy** — Choose the appropriate deployment pattern for the project.
6. **Test the pipeline** — Validate that the pipeline works end-to-end before connecting to production.
7. **Monitor** — Track pipeline execution times, failure rates, and deployment success.
8. **Document** — Maintain documentation for every pipeline stage and deployment procedure.

---

# Outputs

- CI/CD pipeline configurations versioned in Git.
- Automated quality gates.
- Deployment automation scripts.
- Pipeline health dashboards.
- Deployment runbooks.

---

# Output Format

## Pipeline Stage Definition

```
Pipeline: [name]
Trigger: [push / PR / manual / schedule]

Stages:
1. Build — [tool] — Artifact: [name]
2. Test — [unit / integration / e2e]
3. Security scan — [tool]
4. Publish artifact — [registry]
5. Deploy to [environment] — Strategy: [blue-green / canary / rolling]

Quality gates:
- Tests: [pass required]
- Coverage: [minimum %]
- Security: [no critical vulnerabilities]

Notifications: [on failure / on success]
```

---

# Definition of Done

A pipeline Work Unit is complete when:

- All stages are implemented and passing.
- Quality gates are configured and enforced.
- The pipeline configuration is versioned in Git.
- Deployment procedures are documented.
- The pipeline has been validated end-to-end on a non-production environment.

---

# Escalation Rules

Escalate to the Release Manager when:

- A pipeline failure is blocking a planned release.
- A deployment requires coordination across multiple services.

Escalate to the Security Engineer when:

- A pipeline requires access to secrets or credentials.
- A security scan produces critical findings.

Escalate to the Cloud Engineer or Platform Engineer when:

- A pipeline requires infrastructure changes.
- A deployment environment is unavailable.

---

# Failure Modes

- **Pipeline configuration not in Git** — Pipeline configurations must be versioned. Unversioned pipelines cannot be reviewed, rolled back, or reproduced.
- **Skipping security gates** — Removing security scans to speed up pipelines introduces vulnerabilities that reach production undetected.
- **Manual deployments** — Every deployment must be automated. Manual deployments are error-prone and non-reproducible.
- **No rollback procedure** — Every deployment strategy must include a documented rollback path.
- **Hardcoded secrets in pipelines** — Credentials must be injected through secrets managers, never hardcoded in pipeline configurations.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — DevOps

Severity: Mandatory

Default Complexity Tier: Standard Execution
