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

## Commit Types

A commit's `type` indicates the nature of the change. Valid types are:

- feat — new feature
- fix — bug fix
- docs — documentation only
- refactor — code change without feature or fix
- perf — a change that improves performance without changing behaviour
- test — adding or updating tests
- chore — build, tooling, or dependency update

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

`Employee:` identifies who produced the change. It is required by `Core/MAIN_AGENT_CONDUCT.md`'s Dispatch Discipline — *"Every Work Unit's output (commit, Pull Request, report) must identify which Employee produced it"* — and the name must match the roster exactly; a functional or tool label is not an Employee name. `Work Unit:` traces the commit to the Work Unit it performs, per `Templates/WORK_UNIT.md`. The ID it names must already be registered in `Registry/work-units.yml` — the `Work Unit Exists` CI check validates every commit's trailer against that file (see `Registry/README.md`).

Both are enforced mechanically, not by convention: `Adapters/git-hooks/commit-msg` rejects the commit locally, and the `Employee Trailer` and `Work Unit Exists` CI checks re-validate server-side in case the hook was bypassed or never installed.

A change that lands in a Sensitive change-zone additionally carries a one-line `RISK:` trailer in a commit of the same Pull Request — ideally the commit that makes the sensitive change. `Adapters/scripts/check-risk-map.sh --range` checks the whole Pull Request range, not a single commit, so a record forgotten on the commit that touched the zone is added by a follow-up commit in the same Pull Request, never by amending that commit and force-pushing, which `Standards/GIT_STANDARD.md`'s Forbidden Practices bar as rewriting shared history without approval. See `Standards/RISK_STANDARD.md`'s Risk Record for the exact line shape. Run `Adapters/scripts/check-risk-map.sh --explain` to find which zone a given file falls in.

### Layout: keep the blank line between them

Write the two trailers as shown above, **separated by a blank line**, with `Employee:` last — or immediately followed by an optional runtime attribution trailer (see Runtime attribution trailer below).

That looks like an accident of formatting and is not. Git defines a trailer block as the message's final paragraph when it consists entirely of trailer-shaped lines, and three facts follow from that definition, all measured directly rather than reasoned about:

| Layout | `%(trailers:key=Work Unit)` | `%(trailers:key=Employee)` |
|---|---|---|
| `Work Unit:` and `Employee:` **separated** by a blank line | empty | **resolves** |
| `Work Unit:` and `Employee:` **contiguous** | empty | empty |
| `Work-Unit:` and `Employee:` contiguous | resolves | resolves |

A git trailer token may not contain whitespace, so `Work Unit:` is never parsed as a trailer — and one unparseable line invalidates the **whole** block, which is why the contiguous form loses `Employee:` too. Separating them puts `Employee:` alone in the final paragraph, where it parses.

So the blank line is load-bearing: it is what makes `Employee:` readable by git today. An earlier revision of this section mandated contiguity on the reasoning that "splitting it buys nothing". That was wrong, and the repository measured it — 28 of 30 commits on the branch exposed `Employee:` through `%(trailers)`, and the only two that did not were the two written under the contiguity rule itself.

`Work Unit:` is not readable by git in any layout. The anchored `grep` in `Adapters/git-hooks/commit-msg` is therefore not a workaround for something formatting can fix; it is the only available mechanism while the token contains a space.

**The open decision, and when it must be answered.** Renaming the token to `Work-Unit:` and making the block contiguous is the only combination better than the current one on every axis — both trailers would parse, and readers could stop hand-rolling. It changes a mandatory trailer across the whole framework and makes every existing commit non-conforming, so it is a Director decision, recorded here and deliberately not taken. Until it is taken, the separated layout is correct.

This is written as a dated question rather than a standing note, because an open option with nothing scheduled to act on it is where a decision goes to sit — and this framework's own position is that an intention nobody is scheduled to act on is an intention it does not have. **The Director answers this before `v0.1.0`, or at the next revision of this Standard, whichever comes first.** If the answer is no, replace this block with the reasoning; leaving it open past that point is itself a decision and should be recorded as one.

The cost of hand-rolled parsing is not hypothetical. It produced a bypass that took three attempts to close: selecting a trailer line by position was defeatable from whichever end was not chosen, and a squash-concatenated message could carry an unvalidated `Employee:` line past the check entirely. `Adapters/git-hooks/commit-msg` and both CI checks now validate **every** matching line, which is what makes the ordinal irrelevant.

### Quoting a trailer inside the body — enforced

The second of this section's two enforced rules. The checks match `Employee:` and `Work Unit:` anchored at column 0, and validate **every** matching line rather than one, so an example quoted in a commit body must be indented:

```
The hook rejects this:

    Employee: executor
```

An unindented example is a claim the commit is making, and it is checked as one.

### Runtime attribution trailer — optional

A commit may additionally carry an attribution trailer naming the runtime model that actually executed the commit's authoring, in whatever form the runtime that produced the commit uses for that purpose.

Three rules govern it:

- **It names the model that ran, not the model a brief asked for.** The value comes from the runtime reporting on itself — the same source `Templates/WORK_UNIT_REPORT.md`'s "Executed at" field draws from — never a model specified in advance by `Templates/EMPLOYEE_BRIEF.md`. A brief written before execution cannot know which model will actually run the work; dictating one anyway produced mismatched trailers in this repository's own history.
- **It is not validated.** No hook or CI check can observe which model executed a given commit's authoring, so nothing in this framework enforces that this trailer is accurate. It is a courtesy record, not a gate — unlike `Work Unit:` and `Employee:`, both enforced mechanically per the Trailers section above.
- **It is not a substitute for `Employee:`.** `Employee:` identifies who is accountable for the Work Unit and is the trailer every mechanical check above validates. The attribution trailer, when present, supplements it and never replaces it — an Employee's accountability does not depend on which model happened to execute it.

When both are present, keep the attribution trailer contiguous with `Employee:` — no blank line between them — per the layout rule above: `Employee:` must be the trailer-shaped final paragraph for git to read it, and a line placed correctly alongside it stays inside that paragraph rather than starting a new one or (worse) rejoining `Work Unit:`'s unparseable block.

This rule stays AI-agnostic on principle: it names no runtime or vendor. A runtime that adds this trailer defines its own concrete form (for example, a token such as `Co-Authored-By:` followed by the model's name and a contact address) in its own Adapter documentation, not here.

---

## Merge Commits

A merge commit is exempt from the subject rule: its subject is generated by git and cannot carry the Conventional Commits format. `Adapters/git-hooks/commit-msg` detects this through `MERGE_HEAD` rather than by pattern-matching the message, since the wording varies.

A merge is exempt from the trailer rule only while it contains nothing of its own. A merge whose tree equals the automatic merge of its parents needs no `Employee:` trailer; one that resolves conflicts, adds changes, or has more than two parents is authored work and must carry one. `Adapters/scripts/check-employee-trailers.sh` enforces this in CI (historical exceptions are listed in `Registry/merge-attribution-exceptions.txt`), and the hook enforces it locally when it can classify the merge. Known friction: `-s ours`, `-X theirs`, and conflicts resolved in the GitHub web editor all yield a tree that differs from the automatic merge; resolve locally and add the trailer.

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

Version: 0.0.6

Status: Draft

Category: Engineering Standard

Severity: Mandatory
