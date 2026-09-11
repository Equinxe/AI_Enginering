# Contributing to IA Engineering

The contribution guide lives at **[`Governance/CONTRIBUTING.md`](Governance/CONTRIBUTING.md)**.

This file exists only because GitHub looks for `CONTRIBUTING.md` at the repository root and would otherwise tell a first-time contributor there is no guide. It is a pointer, deliberately: a second copy of a governed document goes stale, and this project has watched exactly that happen to an Example within hours of the Workflow it demonstrated changing.

Everything is there — Change Tiers, how to propose a new Employee, Workflow, Template or Standard, the higher bar for anything under `Core/`, the Code of Conduct, and the learning loop that turns an incident into a rule and a rule into a mechanical control.

---

Two things worth knowing before you open a Pull Request:

- **Every commit carries a `Work Unit:` and an `Employee:` trailer**, and CI resolves both against `Registry/`. Install the git hooks (`Adapters/scripts/install.sh`) so the refusal happens before the push rather than after it.
- **The review limit is 1,500 changed lines**, counted outside generated files. Past that a review becomes a skim, and a skim that approves what it did not read is worth less than no approval. Split the change; the alternative is an explicit Director decision recorded on the Pull Request.

Reporting a security problem is different: see [`SECURITY.md`](SECURITY.md), and do not open a public issue.
