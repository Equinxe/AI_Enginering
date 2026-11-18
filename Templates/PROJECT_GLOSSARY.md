# Project Glossary Template

---

# Usage

A project's business domain has words that mean something precise there and something looser everywhere else: a "contract" that is only the signed framework agreement, an "active" customer that ordered in the last twelve months, a "lot" that is a tender lot and not a batch. On a real project this vocabulary is missing from the first session. Each Employee then reads the word its own way, and the specification, the tests and the code each carry a different meaning without anyone seeing the gap.

The project domain glossary is where those meanings are written down once they are settled, so every Employee uses the same one and can say where it came from.

## What it is, and what it is not

- **The project's domain vocabulary.** Words of the business the project serves, as its experts use them.
- **Not the framework's vocabulary.** "Work Unit", "Employee", "Director" and the other framework terms are defined in the framework's `Core/GLOSSARY.md`, which a project never edits. A project word that collides with a framework term (a "release" in a publishing business, say) gets its own entry here, and the entry says which meaning it is.
- **Not a technical glossary.** "API", "cache" or "queue" go in only when the domain gives them a meaning of its own on this project.
- **Not a source of rules.** An entry defines a word. It never instructs an Employee to do something: a rule belongs in `CLAUDE.md` or in a Standard. The glossary is read into Employees' context, so an entry worded as an instruction would act as one. This template makes that a check, with two owners: the Business Analyst does not write such an entry, and whoever reviews a Pull Request that changes the glossary rejects one, as a finding of this template.

## Where it lives

`.ia-engineering/DOMAIN_GLOSSARY.md`, committed.

- **`.ia-engineering/` is where a project keeps what is true of it.** The declared stack, the Risk Map, the Domain Employees (`Templates/DOMAIN_EMPLOYEE.md`) and the project roster already live there, and all of it is committed. Only local state is gitignored: `SESSION_STATE.md` and `usage/`. The Domain Employees are the glossary's closest readers and sit beside it.
- **One fixed path.** A brief, a review or a Domain Employee can name the file without asking where this project put it. `docs/` was considered and not chosen: the framework neither creates nor assumes a `docs/` tree, and an adopter's `docs/` often has its own conventions or feeds a published site.
- **`DOMAIN_GLOSSARY.md`, not `GLOSSARY.md`.** In an adopting project the framework's vocabulary is at `ia-engineering/Core/GLOSSARY.md`. A second `GLOSSARY.md` one character away (`.ia-engineering/` against `ia-engineering/`) would let a reader or a search open the wrong file.
- **A project that already keeps a domain glossary** keeps it where it is. Its `CLAUDE.md` names that path in place of this one, and the rules below apply to that file. A second copy here would be two copies of the same fact, which drift.

## When it is created

**When the first domain term is settled, and not before.** A term is settled when the Director, or the domain authority the Director names, has decided what it means on this project: a Phase A answer (`Workflows/PROJECT_BOOTSTRAP.md`), a Business Analyst clarification round (`Employees/Specialized/BUSINESS_ANALYST.md`), an ADR, or a named reference document.

An empty glossary, or one filled with guessed definitions, is a file nobody trusts. A term still under discussion is an open question in `CLAUDE.md` or in the next clarification round, never an entry.

The Work Unit whose answer settles a term adds the entry in its own commit. The first such Work Unit creates the file from the fenced block under **Template** below.

## Who keeps it

The Business Analyst writes and updates the entries: documenting domain vocabulary is already among its Responsibilities. Any Employee may propose an entry in its Work Unit Report. The Director, or the named domain authority, settles the meaning. The file changes through a reviewed Pull Request like any other committed file.

## How Employees use it

- **The meaning in the glossary is the meaning used.** A specification, an acceptance criterion, a test name, a code identifier or a report that uses a domain word uses it as the glossary defines it.
- **Cite the entry.** Where the meaning matters, name the file and the term, for example: (`.ia-engineering/DOMAIN_GLOSSARY.md`, "Active customer"). The Employee Brief lists the entries a Work Unit relies on (`Templates/EMPLOYEE_BRIEF.md`, What You Need to Know), so an Employee reads those entries rather than the whole file.
- **A missing or conflicting term is a question, not a guess.** A domain word the Work Unit needs that has no entry, or that the brief uses in another sense, is missing information: stop and request it (`Core/DECISION_TREE.md`). Never pick a meaning and carry on.

## Changing a meaning

A meaning that changes is edited in place, with the new source and date. The old definition moves to a **Previously** line with the date it stopped applying, because specifications, tests and data written before that date still carry it. The change is a requirement change: the Business Analyst assesses its impact (its Process, step 7) before the entry changes.

---

# Template

Copy only the contents of the fenced block below into `.ia-engineering/DOMAIN_GLOSSARY.md`. Keep one `###` section per term, in alphabetical order. Write the term as the domain's experts write it, in their language: a French domain term stays French.

```markdown
# [Project Name] — Domain Glossary

The meaning of this project's domain terms, as settled. Framework vocabulary
is in `ia-engineering/Core/GLOSSARY.md`, not here. Template and rules:
`ia-engineering/Templates/PROJECT_GLOSSARY.md`.

---

### [Term]

**Definition:** [What the term means on this project, in one to three
sentences. Specific enough to decide a borderline case: "a customer with at
least one paid order in the last 12 months", not "a customer who is active".
Any example is synthetic, never a real customer, person or record.]

**Source:** [What settled it: "Director, clarification round 2, question 3" /
"ADR-004" / "Project Charter, Phase A question 1" / a named reference
document with its version.]

**Settled:** [6 October 2026]

**Previously:** [Only when the meaning changed: the old definition, and the
date it stopped applying. Otherwise delete this line.]
```

---

# Field Reference

| Field | Purpose | Common mistakes |
|---|---|---|
| Term | The word exactly as the domain uses it | An engineering paraphrase of the domain word; a framework term with no note that the domain meaning differs |
| Definition | Decides a borderline case | Circular ("an active customer is a customer who is active"); a real customer's name as an example; an instruction to Employees instead of a definition |
| Source | Shows who decided and where | "Common sense", "standard usage", or blank: an entry with no source is a guess |
| Settled | Dates the meaning, so older work can be read in its own terms | A relative date ("yesterday"); the date the file was edited instead of the date the meaning was decided |
| Previously | Keeps older specifications and data readable | Deleting the old meaning, which leaves earlier tests and data unexplained |

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Core/GLOSSARY.md` | The framework's vocabulary. A project never edits it; this file holds the project's domain words instead |
| `Templates/PROJECT_CLAUDE.md` | The project's `CLAUDE.md` points to this file and says that its meanings are the ones used |
| `Workflows/PROJECT_BOOTSTRAP.md` | A Phase A answer that settles a domain term creates this file |
| `Workflows/ONBOARDING.md` | Step 2: a project context answer that settles a domain term creates this file |
| `Employees/Specialized/BUSINESS_ANALYST.md` | Writes and updates the entries; its clarification rounds settle most of them |
| `Templates/EMPLOYEE_BRIEF.md` | The brief lists the entries a Work Unit relies on |
| `Templates/DOMAIN_EMPLOYEE.md` | Domain Employees live beside this file and judge domain outputs in its terms |
| `Standards/DATA_PROTECTION_STANDARD.md` | Examples in definitions are synthetic |

---

# Metadata

Owner: IA Engineering

Version: 0.0.15

Status: Draft

Category: Template — Onboarding

Severity: Mandatory
