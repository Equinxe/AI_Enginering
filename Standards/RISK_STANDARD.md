# Risk Standard

---

# Purpose

This standard defines how risk is weighed, classified, and escalated within IA Engineering.

Every Employee definition already carries Escalation Rules, and `Core/DECISION_TREE.md` already requires an Employee to stop when authority is exceeded. What neither provides is a **shared scale**. Without one, "this is risky" means something different to the Backend Engineer, the Release Manager, and the Main Agent, and the decision to stop or proceed rests on each Employee's private judgment — which is precisely the kind of unchecked rule this framework has repeatedly found to fail.

This standard supplies the scale. It does not replace any Employee's Escalation Rules; it gives them a common vocabulary and a common threshold.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

It covers any action carrying operational, product, or security risk — whether the Employee performs the action, plans it, or delegates it.

---

# Official References

The following references are considered authoritative:

- ISO 31000:2018 — Risk management: guidelines (risk assessment as likelihood × consequence; treatment; recording)
- NIST SP 800-30 Rev. 1 — Guide for Conducting Risk Assessments
- OWASP Risk Rating Methodology (likelihood and impact factors for software risk)
- ISO/IEC 27005 — Information security risk management

IA Engineering orchestrates these; it does not redefine them. The matrix below is a deliberately small instance of the likelihood × impact model those references share.

---

# Industry Best Practices

Risk-aware engineering:

- scores an action on **likelihood** and **impact** separately, then combines them;
- states the **blast radius** — what is lost if the action is wrong — before an irreversible step;
- prefers the **reversible path** when one exists at comparable cost;
- **records** risk decisions so they can be audited later;
- treats "the test passed" and "probably fine" as observations, not assessments.

---

# IA Engineering Additions

## The Classification Model

Every risk-bearing action is scored on two axes, then mapped to a tier.

### Likelihood

| Level | Meaning |
|---|---|
| **Rare** | Requires an unusual combination of conditions. |
| **Possible** | Could plausibly occur in normal operation. |
| **Likely** | Expected to occur if the action is repeated. |

### Impact

| Level | Meaning |
|---|---|
| **Minor** | Recoverable within the Work Unit; no data, trust, or history loss. |
| **Serious** | Lost work, a regression, or an incorrect output reaching review. |
| **Severe** | Irreversible data or history loss, a leaked secret, or an incorrect output reaching a user who acts on it. |

### Tier Matrix

|              | Minor  | Serious | Severe   |
|--------------|--------|---------|----------|
| **Rare**     | Low    | Low     | High     |
| **Possible** | Low    | Medium  | Critical |
| **Likely**   | Medium | High    | Critical |

### Tier → Required Behaviour

| Tier | Behaviour |
|---|---|
| **Low** | Proceed. Note the risk in the Work Unit Report. |
| **Medium** | Proceed **only with a stated mitigation** — a test, a backup, a verifier pass, a reversible path. Record the mitigation. |
| **High** | **Stop.** Escalate to the Director with the escalation block below and wait for explicit confirmation before acting or delegating. |
| **Critical** | **Stop.** Never proceed on Employee judgment alone. Requires an explicit Director decision naming the action, the artifact, and the scope, **and** an independent verification pass by an Employee other than the one performing the action. |

A **High** or **Critical** tier is never lowered to avoid a gate. If a tier looks wrong, the assessment is revisited with its reasoning written down — the tier is not adjusted to fit the desired outcome.

## The Escalation Block

When an action lands at High or Critical, the escalating Employee states, in one block:

```
RISK ESCALATION — <tier>

Action:      <what, on which artifact, in which scope>
Hazard:      <what goes wrong, and which catalog row it maps to>
Likelihood:  <Rare | Possible | Likely> — <why>
Impact:      <Minor | Serious | Severe> — <why>
Mitigation:  <what would reduce likelihood or impact, and whether it is applied>
Reversible:  <yes — how | no — what is lost>
```

Then the Employee **waits**. "Looks fine", silence, or a general go-ahead from an earlier, unrelated exchange is not confirmation. Confirmation names the action.

## The Risk Record

Any **Medium or higher** action that proceeds leaves a one-line record in the Work Unit Report:

```
RISK: <hazard> | tier=<Low|Medium|High|Critical> | mitigation=<...> | decided_by=<Director|self>
```

`decided_by=self` is valid for Low and Medium only. For High and Critical it names the Director and the confirmation is quoted.

## Three Scales, and Saying Which One

Three different things in this framework are scored, and all three use words like "high".
Confusing them is the easiest mistake a reader or an Employee can make, so the rule is
simply: **always name the scale.**

| Scale | Values | What it qualifies |
|---|---|---|
| **Action risk** | Low / Medium / High / Critical | *one action an Employee is about to take* — the Classification Model above |
| **Finding severity** | Blocker / High / Medium / Low / Nit | *one remark in a review* (`Workflows/CODE_REVIEW.md`) |
| **Change zone** | Routine / Standard / Sensitive | *the part of the repository a change touches* — the Risk Map below |

A "High" action and a "High" finding are unrelated measurements of unrelated things. Write
`tier=High` or `severity=High`, never a bare "high".

---

## The Risk Map

The Classification Model scores an **action**. It says nothing about **where** in a
repository that action lands, and every control in this framework treats `README.md` and an
authentication module identically until something says otherwise.

A project's **Risk Map** is what says otherwise. It classifies the project's own paths, and
it is the project's, not the framework's — only the project knows which of its directories
decide whether a user is who they claim to be.

### The three levels

| Level | The single criterion |
|---|---|
| **Routine** | **No observable behaviour changes.** This is not a synonym for "small" — a one-character change to a permission check is not Routine, and a thousand-line documentation rewrite is |
| **Standard** | Everything not covered by the other two. The default |
| **Sensitive** | The path falls in one of the categories below |

### The sensitive categories — a closed list

A Sensitive entry that names no category is not acceptable. The list is closed so that a
map can be checked for coverage: a category is either **present**, with its paths, or
**declared absent**, with a reason that can be verified. **A false declaration of absence is
worse than an omission, because it switches the category off.**

| Category | What it covers |
|---|---|
| `authentication` | login, session, password, token, OAuth, SSO |
| `authorization` | access control, roles, CSRF, CORS, route guards |
| `personal_data` | identity, contact, health, anything nominative |
| `payments_and_spend` | billing and payment — **and any real expenditure. A billed model call is one** |
| `cryptography_and_secrets` | encryption, signing, reading secrets from the environment |
| `migrations_and_data_integrity` | schema, migrations, persistent writes, backups |
| `infrastructure_and_ci` | CI, deployment, containers, lint and gate configuration — **and the Employee and agent definitions themselves** |
| `core_architecture` | whatever correctness the deliverable depends on; trust boundaries |

Two of those are easy to miss and are spelled out for that reason. **A billed model call is
a real expense**, so whatever decides to make one belongs under `payments_and_spend`. And
**an Employee definition is infrastructure**: it decides what an agent is allowed to do, so
editing one is closer to editing a CI gate than to editing documentation.

### An unmapped project is unclassified, not safe

Without a Risk Map every path falls back to Standard. That is not a neutral default — it is
the sensitive paths silently losing whatever the project requires of Sensitive changes, with
nothing reporting the loss. A project with no map is **unclassified**, and a control that
meets that state says so rather than passing.

### Writing one

`Templates/RISK_MAP.md` carries the shape, the five ways a map goes wrong, and the commands
that catch each. The short version: **a Risk Map is wrong easily and silently**, so it is
verified by computing the level of every tracked file, never by re-reading the list.

---

## Generic Catalogs

Three catalogs give default tiers for hazards every project meets. They are **starting points**: a project instantiates them in its own `CLAUDE.md` or project memory with its concrete modules, outputs, and paths, and may raise (never lower) a default.

### Operational — the Employee's own action damages the repository or working state

| Hazard | Default tier | Control |
|---|---|---|
| Force-push to a protected branch | **Critical** | Forbidden by `Standards/GIT_STANDARD.md`; the `pre-push` Adapter blocks it. Confirm even with `--force-with-lease`. |
| History rewrite, `reset --hard`, `clean -f`, branch deletion, discarding uncommitted work | **High** | Forbidden without explicit Director instruction. Prefer a new branch or a single-path checkout. |
| Deleting tracked content | **High** | Inspect the target first. If it contradicts how it was described, or the Employee did not create it, surface it instead of deleting. |
| Destructive schema migration | **Critical** | Requires a proven rollback path before applying. |
| A commit that may carry a secret or real data | **Critical** | Never commit. `Standards/DATA_PROTECTION_STANDARD.md` governs; the `pre-commit` Adapter refuses. |
| Bypassing a hook or a signing requirement | **High** | Forbidden by `Standards/GIT_STANDARD.md`. A hook that is in the way is a rule that is in the way — escalate, do not route around. |
| The Main Agent implementing directly | **High** | Dispatch per `Core/MAIN_AGENT_CONDUCT.md`, No Direct Implementation. |

### Product — the deliverable produces an incorrect output the user relies on

| Hazard | Default tier | Control |
|---|---|---|
| Output is **incorrect but presented as reliable** | **High** | An Employee declares that the pipeline ran and produced a result; correctness is a human sign-off, never an Employee's claim. |
| A **source of truth is silently degraded** — stale, partial, wrong — yet reported healthy | **Critical** | Surface the degraded state explicitly. Never let an unverified base pass as success. |
| A **single upstream parameter silently scales every output** | **Critical** | Surface the parameter to the Director before it propagates; test the propagation path. |
| A **secondary source overrides the primary** without flagging the conflict | **High** | A secondary source (including an AI suggestion) is review-only by default; a contradiction is a conflict to surface, not a value to prefer. |
| A **failure is swallowed and reported as success** | **High** | Distinguish "no result" from "an empty result". A failure is surfaced, never reported clean. This is the same defect class this framework's own validator spent a milestone removing from itself. |
| An **export or transform drops or rounds** inconsistently with what the user saw | **Medium** | Cross-check one case per change against the source-of-truth totals. |

### Security — a change introduces an exploitable weakness

| Hazard | Default tier | Control |
|---|---|---|
| Secret in plain text or as a real default value | **Critical** | Secrets only via environment; never a real default. `Standards/DATA_PROTECTION_STANDARD.md`. |
| A resource resolved by a user-supplied identifier without an ownership check (IDOR) | **Critical** | Every data access scoped to the authenticated principal. |
| Query built by string concatenation | **Critical** | Parameterised queries only. |
| Authentication, session, or cookie-attribute change | **High** | Security Engineer review is mandatory — `Workflows/CODE_REVIEW.md`, security-sensitive triggers. |
| Input validation at a trust boundary weakened | **High** | Boundary checks are never relaxed in a cleanup pass. |
| Broad exception handling that hides a security failure | **Medium** | Specify exception types. |

The security catalog overlaps with `Workflows/CODE_REVIEW.md`'s security-sensitive trigger list on purpose: that list decides **whether** the QA Engineer and Security Engineer are inserted; this catalog decides **how loudly** the Employee who first notices must stop.

## Relationship to Escalation Rules

Each Employee's Escalation Rules say **to whom** that Employee escalates. This standard says **when** stopping is mandatory regardless of Employee, and **what** the escalation must contain. Where an Employee's own rules are stricter, the stricter rule holds.

## Relationship to Autonomous Execution

`Core/MAIN_AGENT_CONDUCT.md`'s Autonomous Release Execution lets the Main Agent run between gates without prompting. This standard adds gates, it does not remove them: a High or Critical action inside an otherwise autonomous sequence is a stop, exactly as a Workflow's mandatory Director gate is. Autonomy governs pacing; it never governs tier.

---

# Responsibilities

Every Employee must:

- classify an action before performing, planning, or delegating it;
- state the blast radius before any irreversible step;
- escalate High and Critical with the escalation block, and wait;
- record every Medium-or-higher decision in the Work Unit Report;
- raise a default tier when the project context warrants it, never lower it.

The Main Agent must additionally:

- confirm High and Critical actions with the Director **before** dispatching an Employee who would perform them;
- never treat a Low tier assigned by the performing Employee as final when the Main Agent's own view of blast radius says otherwise.

---

# Forbidden Practices

Do not:

- proceed on a High or Critical action on Employee judgment alone;
- lower a tier to avoid a gate;
- treat "the test passed", "probably fine", or "it worked last time" as a risk assessment;
- accept implicit confirmation, or a confirmation given for a different action;
- route around a blocking control instead of escalating it;
- tune a parameter until one case looks right without checking what it did to the others.

---

# Rationale

A shared scale converts a family of private judgments into one checkable question — *which cell of the matrix is this?* — and attaches a required behaviour to the answer. That is the same move this framework made when it replaced "pick the most appropriate Employee" with `Core/EMPLOYEE_SELECTION.md`'s concrete triggers: a rule that sounds right but gives the reader nothing to check against is a rule that gets applied by habit.

The product catalog is included because the most expensive failures in software assisted by AI are not crashes. They are confident, well-formatted, wrong outputs that a user acts on. Naming that hazard, giving it a tier, and requiring that correctness be a human sign-off rather than an Employee's assertion is what keeps the framework's own Transparency principle (`Core/AI_MANIFEST.md`) from being merely aspirational.

**Provenance.** The likelihood × impact matrix and the four-tier behaviour scale are adapted from a sibling governance corpus in use on production projects, where they were built from incidents rather than theory. The catalogs are generalised from that corpus; anything specific to one organisation or one stack was removed so the standard applies to any project.

---

# Related Standards

- Standards First
- Git Standard
- Data Protection Standard
- Code Quality Standard
- Testing Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Engineering Standard

Severity: Mandatory

Depends On:

- STANDARDS_FIRST.md
- GIT_STANDARD.md
- DATA_PROTECTION_STANDARD.md

Referenced By:

- `Core/DECISION_TREE.md`
- `Core/ORCHESTRATION.md`
- `Core/MAIN_AGENT_CONDUCT.md`
- `Templates/WORK_UNIT_REPORT.md`
