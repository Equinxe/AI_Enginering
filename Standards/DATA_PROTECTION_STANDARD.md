# Data Protection Standard

---

# Purpose

This standard defines how real, confidential, or personal data — and secrets — are kept out of version control within IA Engineering.

It exists because of a failure shape that recurs across organisations: a real document is committed "temporarily" as a test fixture, untracked afterward, noted as "never pushed" — and found weeks later in the repository's history on the hosting platform, pushed in the meantime. Recovery means a history rewrite, a force-push of every branch, and every clone re-created. The data was exposed for the whole interval.

`.gitignore` does not prevent this. It ignores untracked files; it does nothing for a file that was ever added. The protection has to be structural.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

It covers client documents, personal data, production exports, credentials, keys, tokens, and any file whose disclosure would harm a person, a client, or the project.

---

# Official References

The following references are considered authoritative:

- GDPR, Articles 5(1)(f) and 32 — integrity, confidentiality, and security of processing
- NIST SP 800-122 — Guide to Protecting the Confidentiality of Personally Identifiable Information
- ISO/IEC 27001, Annex A.8 — asset management and information classification
- OWASP Secrets Management Cheat Sheet
- The hosting platform's secret-scanning and push-protection documentation (GitHub, GitLab, Azure DevOps)

Projects subject to a named regulatory framework (HIPAA, PCI-DSS, SOC 2, ISO 27001) follow that framework's specific controls in addition; the Compliance Engineer owns that instantiation (`Workflows/PROJECT_BOOTSTRAP.md`, Phase A questions 6 and 7).

---

# Industry Best Practices

- Real data never enters a repository. Test fixtures are synthetic and visibly marked as such.
- Secrets live in the environment or a secrets manager, never in tracked files, never as default values in code.
- Protection is layered: local convention, a client-side hook, and a server-side check that cannot be bypassed from a developer machine.
- The check that matters inspects **history**, not the current tree.
- A leaked secret is revoked before anything else is done.

---

# IA Engineering Additions

## The Local Data Directory

Every project designates one directory for real data used during development — by convention `local_test_data/`, configurable per project in `CLAUDE.md`. It is:

- listed in `.gitignore` from the first commit, before any file exists;
- the **only** place real documents, exports, and samples may live on a developer machine;
- still client data on a workstation: encrypted disk, no onward distribution, purged at project end. Keeping it out of git does not discharge the responsibility for it.

A file whose sensitivity is in doubt goes there. Never "temporarily" anywhere else.

## Synthetic Fixtures

Fixtures committed under `tests/` are exclusively synthetic. A synthetic file that would otherwise match a protected pattern carries the marker **`SYNTHETIC_`** at the **start of its filename** — `SYNTHETIC_invoice.pdf`, not `invoice_synthetic.pdf` and not a `synthetic/` directory.

The anchor is deliberate. An earlier convention that exempted "synthetic anywhere in the path" was defeated in practice by a directory named `synthetic/` that exempted its entire contents, and by real files renamed to include the word. A marker at the head of the filename is visible, intentional, and cannot exempt more than one file.

## The Check That Counts

```sh
git rev-list --all --objects | grep -iE '\.(xlsx?|pdf|docx?|csv)$'
```

This inspects every object reachable from every ref — the whole history. `git ls-files` inspects the current index only and will report clean while the blob still travels with every clone. Any audit, any "is the repository clean" claim, and the CI job below use the history form.

## Three Layers of Enforcement

| Layer | Mechanism | Property |
|---|---|---|
| Convention | `.gitignore` + this standard | Advisory. Ignores untracked files only. |
| Client-side | `Adapters/git-hooks/pre-commit` | Refuses a commit staging a protected pattern. **Bypassable** with `--no-verify` or an uninstalled hook. |
| Server-side | `Adapters/github-actions/data-policy.yml` | Scans the tree **and the objects introduced by the branch** on every Pull Request. Not bypassable from a developer machine. |

The client-side hook is the fast, local signal. The server-side job is the control. A rule enforced only by a hook a developer can skip is a rule the framework does not have — the same reasoning that made the `Employee Trailer` CI check a backstop for the `commit-msg` hook.

Both layers call one scanner, `Adapters/scripts/data-policy-scan.sh`, so there is exactly one pattern list — two lists drift, and the developer learns which one is authoritative by being surprised. The scanner **cleans nothing and flags only high-confidence shapes**: document, dump, and key-material extensions; `.env` files; the operational state file; and text data formats (`csv`, `json`, `sql`, …) whose **name** reads like a real export (`dump`, `export`, `backup`, `client`, `customer`, `patient`, `payroll`, `invoice`). Plain source files are never flagged by name — `src/export.ts` passes — because a hook that fires on ordinary code is a hook developers learn to bypass. For content it matches a short list of well-known secret shapes (private key blocks, cloud and platform tokens) on **added lines only**, and never prints the matched value. It does not attempt entropy-based detection; a project that wants it adds a dedicated secret scanner to CI, next to this one, with its own allowlist.

Exemptions are named, never fall-throughs: the anchored `SYNTHETIC_` marker, and a **committed** allow file, `.ia-engineering/data-policy.allow` — one anchored regular expression per line, `content:`-prefixed lines for content — shared by the hook and CI because it is committed.

## Secrets

- Local secrets live in `.env`, gitignored from the first commit; a committed `.env.example` lists the variable **names** with empty or dummy values.
- CI secrets live in the platform's secret store, referenced by name in workflows, never written into them.
- No secret ever appears as a default value in code (`getenv("KEY", "sk-live-...")` is a committed secret).
- Every environment has its own secrets. No value is reused across dev, staging, and production.

## When Real Data Reaches History Anyway

1. **Revoke first**, if it is a credential. Rotation before investigation.
2. **Back up** the repository as a bundle, outside the repository.
3. **Purge** with a history-rewriting tool (`git filter-repo` or equivalent) **before** branch protection is enabled or with protection temporarily lifted — protection blocks the force-push the purge requires. Re-enable immediately after.
4. **Force-push every branch and tag.** This is the one sanctioned force-push, and it is a Director decision (`Standards/RISK_STANDARD.md`, Critical).
5. **Every clone is re-created.** An old clone that pushes reintroduces the objects. Deleting local branches is not sufficient.
6. **Record the incident** — what, when, for how long, who could have read it — and file it durably (`Core/MAIN_AGENT_CONDUCT.md`, Durable Tracking of Findings). If personal data was exposed, the regulatory notification clock may already be running; the Compliance Engineer assesses.

## Operational State Is Also Sensitive

A file that describes what is currently **weak** in a project — a temporarily relaxed branch protection, a known vulnerability class not yet fixed everywhere, a governance deviation in force — is itself sensitive, and does not belong in the repository it describes. `Templates/SESSION_STATE.md` is the home for that content and is never committed. `CLAUDE.md`, which **is** committed, carries the project's stable contract and nothing about its current defences.

---

# Responsibilities

Every Employee must:

- keep real data in the local data directory and nowhere else;
- mark synthetic fixtures with the anchored `SYNTHETIC_` prefix;
- verify cleanliness with the history form of the check, never `git ls-files` alone;
- treat any file of doubtful sensitivity as real until shown otherwise;
- surface a suspected leak immediately rather than quietly removing the file.

The Main Agent must additionally:

- ensure `.gitignore`, the local data directory, and the `pre-commit` hook exist **before** the first commit of a new project (`Workflows/PROJECT_BOOTSTRAP.md`);
- confirm the `data-policy` CI job is installed and required.

---

# Forbidden Practices

Do not:

- commit real data "temporarily", for any duration;
- bypass the `pre-commit` hook with `--no-verify` — it disarms every other check too;
- exempt a directory or a substring; exemptions are per-file, by the anchored marker;
- claim a repository is clean on the strength of `git ls-files`;
- store a secret as a default value, in a comment, in a test, or in a commit message;
- record current defensive weaknesses in a committed file;
- push from a clone that predates a history purge.

---

# Rationale

The layers exist because each one fails in a different way. `.gitignore` fails for anything already tracked. The hook fails when skipped or never installed, and git deliberately never transmits hooks. The CI job fails only if nobody made it a required check — and `Adapters/scripts/setup-branch-protection.sh` makes it one.

The history check exists because the current tree is the wrong question. A file added and removed within one branch is absent from the tree and present in every object store that fetched the branch. The rule asks whether the data can be read; only history answers that.

**Provenance.** This standard generalises a protocol developed in a sibling governance kit after the incident described in Purpose, including the corrections found by adversarial review of its first hook — a non-ASCII filename that escaped the pattern because `git` quoted it, a `synthetic` exemption that exempted a whole directory, and a content scan noisy enough to provoke `--no-verify`. Those corrections are carried into the Adapter, not rediscovered.

---

# Related Standards

- Standards First
- Git Standard
- Risk Standard
- Code Quality Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Engineering Standard

Severity: Mandatory

Depends On:

- STANDARDS_FIRST.md
- GIT_STANDARD.md
- RISK_STANDARD.md

Referenced By:

- `Workflows/PROJECT_BOOTSTRAP.md`
- `Workflows/ONBOARDING.md`
- `Adapters/git-hooks/pre-commit`
- `Adapters/github-actions/data-policy.yml`
- `Templates/SESSION_STATE.md`
