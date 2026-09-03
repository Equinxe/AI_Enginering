# Commit Standard

---

# Purpose

This standard defines how commits are created within IA Engineering.

IA Engineering adopts the Conventional Commits specification and extends it with engineering practices that improve traceability, collaboration, and AI-assisted development.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- Conventional Commits Specification
- Git Documentation

---

# Industry Best Practices

Projects should:

- create small, focused commits;
- write meaningful commit messages;
- keep commits atomic;
- maintain a readable Git history.

---

# IA Engineering Additions

## One Work Unit = One Commit

A completed Work Unit should produce one commit.

A commit represents one engineering objective.

---

## Commit Readiness

Before creating a commit, verify that:

- the Work Unit is complete;
- the project builds (when applicable);
- tests pass (when applicable);
- no temporary or generated files are included;
- documentation has been updated if required.

---

## Engineering Intent

Every commit should clearly answer:

> Why does this change exist?

If the answer cannot be expressed in one sentence, the Work Unit should probably be divided.

---

## Trailers

Every commit carries two trailers:

```
type(scope): description

[body — why this change exists]

Work Unit: WU-<project>-<number>

Employee: <Exact Employee Name>
```

**Exactly one `Work Unit:` line, at column 0.** One Work Unit is one commit, so a second claim is malformed rather than something a reader should resolve by position. `Adapters/git-hooks/commit-msg` rejects it and the `Work Unit Exists` CI check fails it.

This one is worth understanding rather than just obeying, because it is what lets `Adapters/scripts/release.sh` attribute a Work Unit to a commit at all. Ranking two claims by position produced a false pass on the release gate: a commit conforming to everything else in this section, with a deferral note quoting an id after the trailer block, made an unmerged Work Unit count as merged. Refusing the second claim removes the choice instead of choosing a better end, and moves the failure to commit time for the author rather than Step 1 for the Release Manager.

It assumes merge commits rather than squashes — a squash-merged commit legitimately carries one trailer block per squashed part. This project uses merge commits. If squashing is ever adopted, attribution changes shape and this rule should be reopened deliberately.

Of the rules in this section, two are enforced mechanically: **exactly one `Work Unit:` line** (above) and **quoted examples must be indented** (below). The layout rule and the ordering of the two trailers are conventions — nothing rejects a commit for getting them wrong. That distinction is stated because this framework's own position is that a rule only a careful human applies is a rule the framework does not have; those two are documented as guidance, not presented as gates.

`Employee:` identifies who produced the change. It is required by `Core/MAIN_AGENT_CONDUCT.md`'s Dispatch Discipline — *"Every Work Unit's output (commit, Pull Request, report) must identify which Employee produced it"* — and the name must match the roster exactly; a functional or tool label is not an Employee name. `Work Unit:` traces the commit to the Work Unit it performs, per `Templates/WORK_UNIT.md`.

Both are enforced mechanically, not by convention: `Adapters/git-hooks/commit-msg` rejects the commit locally, and the `Employee Trailer` and `Work Unit Exists` CI checks re-validate server-side in case the hook was bypassed or never installed.

### Layout: keep the blank line between them

Write the two trailers as shown above, **separated by a blank line**, with `Employee:` last.

That looks like an accident of formatting and is not. Git defines a trailer block as the message's final paragraph when it consists entirely of trailer-shaped lines, and three facts follow from that definition, all measured directly rather than reasoned about:

| Layout | `%(trailers:key=Work Unit)` | `%(trailers:key=Employee)` |
|---|---|---|
| `Work Unit:` and `Employee:` **separated** by a blank line | empty | **resolves** |
| `Work Unit:` and `Employee:` **contiguous** | empty | empty |
| `Work-Unit:` and `Employee:` contiguous | resolves | resolves |

A git trailer token may not contain whitespace, so `Work Unit:` is never parsed as a trailer — and one unparseable line invalidates the **whole** block, which is why the contiguous form loses `Employee:` too. Separating them puts `Employee:` alone in the final paragraph, where it parses.

So the blank line is load-bearing: it is what makes `Employee:` readable by git today. An earlier revision of this section mandated contiguity on the reasoning that "splitting it buys nothing". That was wrong, and the repository measured it — 28 of 30 commits on the branch exposed `Employee:` through `%(trailers)`, and the only two that did not were the two written under the contiguity rule itself.

`Work Unit:` is not readable by git in any layout. The anchored `grep` in `Adapters/git-hooks/commit-msg` is therefore not a workaround for something formatting can fix; it is the only available mechanism while the token contains a space.

**The open decision.** Renaming the token to `Work-Unit:` and making the block contiguous is the only combination better than the current one on every axis — both trailers would parse, and readers could stop hand-rolling. It changes a mandatory trailer across the whole framework and makes every existing commit non-conforming, so it is a Director decision, recorded here and deliberately not taken. Until it is taken, the separated layout is correct.

The cost of hand-rolled parsing is not hypothetical. It produced a bypass that took three attempts to close: selecting a trailer line by position was defeatable from whichever end was not chosen, and a squash-concatenated message could carry an unvalidated `Employee:` line past the check entirely. `Adapters/git-hooks/commit-msg` and both CI checks now validate **every** matching line, which is what makes the ordinal irrelevant.

### Quoting a trailer inside the body — enforced

This is the rule in this section with teeth. The checks match `Employee:` and `Work Unit:` anchored at column 0, and validate **every** matching line rather than one, so an example quoted in a commit body must be indented:

```
The hook rejects this:

    Employee: executor
```

An unindented example is a claim the commit is making, and it is checked as one.

---

## Merge Commits

A merge commit is exempt from every rule above. Its subject is generated by git and can carry neither the Conventional Commits format nor a trailer. `Adapters/git-hooks/commit-msg` detects this through `MERGE_HEAD` rather than by pattern-matching the message, since the wording varies.

---

# Responsibilities

Every Employee must:

- follow the Conventional Commits specification;
- create small and reviewable commits;
- avoid mixing unrelated changes;
- commit only completed Work Units.

---

# Forbidden Practices

Do not:

- create meaningless commit messages;
- commit unfinished work on shared branches;
- mix multiple engineering objectives;
- use commits as temporary backups;
- commit debugging artifacts or temporary files.

---

# Rationale

Following this standard provides:

- better code reviews;
- clearer project history;
- easier debugging;
- improved collaboration;
- predictable AI-generated commits.

---

# Related Standards

- Standards First
- Git Standard
- Branch Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Engineering Standard

Severity: Mandatory
