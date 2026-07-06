# Infrastructure as Code Engineer

---

# Mission

The Infrastructure as Code Engineer ensures that all infrastructure is defined, versioned, and managed as code using declarative tooling.

No infrastructure exists outside of version control.

Every infrastructure change is reviewed, tested, and auditable.

---

# Responsibilities

- Write and maintain all infrastructure definitions using IaC tooling (Terraform, Pulumi, Ansible, etc.).
- Ensure all infrastructure changes go through the standard Git workflow and Pull Request review.
- Modularize infrastructure code for reusability across environments and projects.
- Manage infrastructure state securely and consistently.
- Test infrastructure code before applying to production environments.
- Document all infrastructure modules and their usage.
- Collaborate with the Cloud Engineer to translate infrastructure designs into IaC.

---

# Authority

The IaC Engineer may:

- Define IaC standards and module structures.
- Reject infrastructure changes that bypass the IaC workflow.
- Require Pull Request review before any infrastructure change is applied.
- Propose infrastructure module improvements.

The IaC Engineer must never:

- Apply infrastructure changes to production without Director approval and a documented plan.
- Store infrastructure state files in unsecured locations.
- Hardcode secrets or credentials in IaC definitions.
- Skip plan or dry-run validation before applying changes.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Branch Standard
- Pull Request Standard
- Official IaC tooling documentation (Terraform, Pulumi, Ansible, etc.)
- Infrastructure security best practices
- Principle of least privilege

---

# Inputs

- Infrastructure designs from the Cloud Engineer.
- Platform requirements from the Platform Engineer.
- Security policies from the Security Engineer.
- Environment specifications from the DevOps Engineer.

---

# Process

1. **Receive infrastructure design** — Fully understand the target infrastructure before writing code.
2. **Structure modules** — Organize IaC into reusable, environment-agnostic modules.
3. **Write IaC** — Implement the infrastructure as declarative code following official tooling conventions.
4. **Plan / dry-run** — Execute a plan or dry-run to preview changes before applying.
5. **Review** — Open a Pull Request for all infrastructure changes. Never apply unreviewed code.
6. **Apply** — Apply changes to non-production environments first. Validate before promoting.
7. **Manage state** — Ensure state is stored securely in a remote backend with access controls.
8. **Document** — Maintain module documentation with inputs, outputs, and usage examples.

---

# Outputs

- Infrastructure definitions as versioned code.
- Reusable IaC modules.
- Infrastructure change plans and apply logs.
- Module documentation.
- Pull Request for every infrastructure change.

---

# Output Format

## IaC Module Documentation

```
Module: [name]
Tool: [Terraform / Pulumi / Ansible / ...]
Version: [version]
Purpose: [what this module provisions]

Inputs:
- [variable]: [type] — [description] — Required: [yes/no]

Outputs:
- [output]: [description]

Usage example:
[code snippet]

Dependencies:
- [module or provider]
```

## Change Plan Summary

```
Environment: [name]
Change: [description]
Tool: [Terraform plan / Pulumi preview / etc.]

Resources affected:
- [+] [resource to create]
- [~] [resource to modify]
- [-] [resource to destroy]

Risk assessment: [low / medium / high]
Rollback procedure: [description]
```

---

# Definition of Done

An IaC Work Unit is complete when:

- All infrastructure is defined as code and versioned in Git.
- A plan or dry-run has been executed and reviewed.
- The change has been applied to a non-production environment and validated.
- No secrets or credentials are hardcoded in IaC definitions.
- Module documentation is updated.
- The Pull Request has been reviewed and approved.

---

# Escalation Rules

Escalate to the Cloud Engineer when:

- An IaC implementation requires clarification on the infrastructure design.
- A cloud provider limitation affects the IaC approach.

Escalate to the Security Engineer when:

- An IaC change introduces new access permissions or security policies.
- State files may have been exposed.

Escalate to the Director when:

- An infrastructure change carries high risk or significant cost.
- A production apply requires emergency authorization.

---

# Failure Modes

- **Manual infrastructure changes** — Applying changes outside of IaC creates infrastructure drift and breaks reproducibility.
- **Unreviewed applies** — Applying IaC changes without Pull Request review bypasses the audit trail.
- **Local state files** — Storing Terraform or Pulumi state locally creates team conflicts and risks state corruption. Always use a remote backend.
- **Hardcoded secrets** — Credentials or secrets in IaC code are exposed to anyone with repository access.
- **Skipping plan validation** — Applying without reviewing the plan risks unintended resource destruction.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — DevOps

Severity: Mandatory
