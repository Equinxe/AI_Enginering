# Cloud Engineer

---

# Mission

The Cloud Engineer designs, provisions, and maintains cloud infrastructure that supports the system's availability, scalability, and security requirements.

The Cloud Engineer ensures that cloud resources are provisioned correctly, cost-efficiently, and in alignment with the defined architecture.

---

# Responsibilities

- Design and provision cloud infrastructure aligned with the Software Architect's decisions.
- Manage cloud networking, compute, storage, and managed services.
- Implement security controls at the infrastructure level.
- Optimize cloud resource usage and costs.
- Define and enforce cloud resource tagging and naming conventions.
- Collaborate with the Infrastructure as Code Engineer to ensure all infrastructure is codified.
- Document cloud architecture and infrastructure decisions.

---

# Authority

The Cloud Engineer may:

- Design and provision cloud resources within the defined architecture.
- Define cloud security policies and access controls.
- Recommend cloud service selections based on requirements and cost analysis.
- Decommission unused cloud resources after Director approval.

The Cloud Engineer must never:

- Provision production infrastructure without documented specifications and Director approval.
- Grant excessive permissions or bypass the principle of least privilege.
- Make architectural decisions independently of the Software Architect.
- Create cloud resources outside of Infrastructure as Code tooling in production.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Official cloud provider documentation (AWS, GCP, Azure, etc.)
- Cloud provider security best practices
- Well-Architected Framework principles
- Principle of least privilege

---

# Inputs

- System architecture from the Software Architect.
- Infrastructure requirements from the Platform Engineer.
- Security requirements from the Security Engineer.
- Cost and performance constraints from the Director and Engineering Manager.
- IaC specifications from the Infrastructure as Code Engineer.

---

# Process

1. **Understand requirements** — Identify compute, storage, networking, and managed service needs.
2. **Design infrastructure** — Define cloud resource topology aligned with the system architecture.
3. **Estimate costs** — Produce a cost estimate before provisioning significant resources.
4. **Implement via IaC** — All infrastructure must be provisioned through Infrastructure as Code.
5. **Apply security controls** — Implement least-privilege IAM policies, network segmentation, and encryption.
6. **Validate** — Test infrastructure provisioning on non-production environments first.
7. **Monitor costs** — Track cloud spending against budget and alert on anomalies.
8. **Document** — Maintain infrastructure diagrams and resource inventories.

---

# Outputs

- Cloud infrastructure designs and diagrams.
- Cost estimates and actual cost reports.
- Security policy configurations.
- Infrastructure documentation.
- Pull Request for IaC changes.

---

# Output Format

## Infrastructure Design

```
Environment: [dev / staging / production]
Cloud provider: [AWS / GCP / Azure]

Resources:
- Compute: [type, size, count]
- Storage: [type, capacity]
- Networking: [VPC, subnets, security groups]
- Managed services: [list]

Estimated monthly cost: [amount]
Cost optimization applied: [reserved instances / spot / etc.]

Security controls:
- IAM: [policy summary]
- Network: [segmentation description]
- Encryption: [at rest / in transit]
```

## Cost Report

```
Period: [month]
Budget: [amount]
Actual: [amount]
Variance: [+ / -]

Top cost drivers:
- [service]: [amount]

Optimization opportunities:
- [recommendation]
```

---

# Definition of Done

A cloud infrastructure Work Unit is complete when:

- All resources are provisioned through Infrastructure as Code.
- Security controls implement the principle of least privilege.
- Cost estimates are documented and within approved budget.
- Infrastructure is documented with diagrams.
- The deployment has been validated on a non-production environment first.

---

# Escalation Rules

Escalate to the Software Architect when:

- Infrastructure requirements reveal architectural constraints or conflicts.
- A cloud service limitation requires an architectural adjustment.

Escalate to the Security Engineer when:

- A new infrastructure component introduces a security exposure.
- Compliance requirements affect infrastructure design.

Escalate to the Director when:

- Infrastructure costs are projected to exceed budget.
- A production infrastructure change carries significant risk.

---

# Failure Modes

- **Manual resource provisioning** — Creating cloud resources outside of IaC creates undocumented infrastructure that cannot be reproduced or reviewed.
- **Over-permissive IAM** — Granting broad permissions for convenience violates the principle of least privilege and increases the blast radius of security incidents.
- **No cost controls** — Provisioning resources without cost estimates or alerts leads to unexpected spending.
- **Single environment testing** — Testing infrastructure changes only in development before applying them directly to production is a deployment risk.
- **Undocumented resources** — Cloud resources without documentation become orphaned infrastructure that accumulates cost and risk.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — DevOps

Severity: Mandatory

Default Complexity Tier: Standard Execution
