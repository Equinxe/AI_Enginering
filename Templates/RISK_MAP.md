# Risk Map Template

---

# Usage

A Risk Map classifies **a project's own paths** into the three change-zone levels defined in `Standards/RISK_STANDARD.md`. It is written once per project, committed, and read by the controls that need to know whether a change lands somewhere that matters.

It lives at `.ia-engineering/risk-map.yml`.

**It must be committed.** `.ia-engineering/` is often ignored, and a map CI cannot read classifies nothing. If your `.gitignore` excludes the directory, add an exception for this one file — a colleague who clones must inherit the map, not rediscover it at their own expense.

**Do not copy another project's map.** The paths are the point, and they are yours.

---

# The file

```yaml
# .ia-engineering/risk-map.yml
#
# Change-zone levels per Standards/RISK_STANDARD.md: routine | standard | sensitive.
# Patterns are matched in order; the FIRST match wins, so specific comes before general.

version: 1

zones:
  - pattern: "src/auth/**"
    level: sensitive
    category: authentication
    reason: >
      Decides whether a caller is who they claim to be. A wrong change here
      authenticates the wrong person, and no unit test asserts the negative case
      for an identity that does not exist yet.

  - pattern: "migrations/**"
    level: sensitive
    category: migrations_and_data_integrity
    reason: >
      Runs once against real data and cannot be re-run. A defect is discovered
      after the data is already changed.

  - pattern: ".github/workflows/**"
    level: sensitive
    category: infrastructure_and_ci
    reason: >
      Decides which gates run. Weakening one is invisible in the diff of the
      thing it stops guarding.

  - pattern: "docs/**"
    level: routine
    reason: >
      No observable behaviour changes. Nothing here is read at runtime — checked,
      not assumed: see the verification commands below.

  - pattern: "**"
    level: standard
    reason: The default for everything not classified above.

# A category is either present above, with its paths, or declared absent here
# with a reason someone else can check. A FALSE declaration of absence is worse
# than an omission: it switches the category off.
absent:
  - category: payments_and_spend
    reason: >
      No billing, and no billed model call — verified with
      `grep -rn "api.anthropic\|api.openai\|stripe" --include='*.ts' .`
      which returns nothing.
```

---

# Field reference

| Field | Purpose | Common mistakes |
|---|---|---|
| `pattern` | A glob matched against tracked paths, **first match wins** | Writing the general pattern before the specific one, so `**` swallows everything |
| `level` | `routine`, `standard` or `sensitive` | Reading `routine` as "small". It means *no observable behaviour changes* |
| `category` | Required on `sensitive`, from the closed list in the Standard | Inventing a category name, which makes coverage uncheckable |
| `reason` | **What breaks if this path is changed wrongly, and why no test would catch it** | A restatement of the path. "Authentication code" is not a reason |
| `absent` | Categories that genuinely do not apply, each with a verifiable reason | Declaring absence from memory |

---

# The five ways a map goes wrong

All four are silent. A wrong Risk Map does not fail — it quietly classifies something
important as ordinary, and everything downstream behaves correctly on a false input.

**None of these is caught by re-reading the map.** Each has a command.

## 1. The glob that rakes wider than you think

`*.md` looks like "the markdown files at the root". In `fnmatch`, `*` crosses `/`, so it
matches **every** `.md` in the repository — including the one that turns out to be a data
source. Write the most specific patterns first, and check what each actually catches:

```bash
git ls-files | grep -E '^docs/'        # does this pattern catch what you meant?
```

## 2. The file that is not what its extension says

A `.md` whose values the code transcribes by hand **is a data source**, not documentation.
Look for what the code itself calls authoritative:

```bash
grep -rni "source of truth\|reference values\|derived from\|per the spec in" \
  --include='*.py' --include='*.ts' --include='*.js' --include='*.go' . | head -20
```

A file copied **by hand** into code carries the *opposite* risk of one read at runtime:
correcting it takes no effect, it desynchronises the code from the authority it cites, and
no test can see the divergence.

## 3. The central file missed because it is not in an expected folder

Verify by computing the level of **every tracked file**, never by re-reading your list. A
core module that fell through to `**` → standard is invisible any other way.

```bash
./ia-engineering/Adapters/scripts/check-risk-map.sh --explain | grep ' standard$'
```

## 4. The dead entry

A pattern matching no file reassures without protecting anything. Check against **the
reference you are classifying**, not a working tree that may be behind:

```bash
git ls-tree -r --name-only origin/main    # not git ls-files, which reads the local tree
```

A pattern matching a file that **exists but is not committed yet** is not this trap —
it is the state you are in the moment after bootstrap, before you stage the workflows,
the Dockerfile and this map. `check-risk-map.sh` tells the two apart: it says *stage and
commit it* for a present-but-untracked match, and *remove it* only when nothing on disk
matches at all. Commit the installed files; do not delete the entry the installer wrote.

## 5. The zone that is too wide

Over-classification is the trap the first four make you fall into. Marking a whole
directory sensitive feels safe; if one file in it is appended on every change, then
**every change** needs a Risk Record, and a record present everywhere records nothing.
The framework's own map did this on its first day: `Registry/*` was sensitive, the
Work Unit registry is appended on every Work Unit, and the first Pull Request after the
map merged was flagged for bookkeeping.

The question that separates them is not "is this file important" but **"what does a
wrong change here do — fail loudly, or misbehave silently?"** A roster that silently
accepts a new name is sensitive. A registry whose malformed entry is reported by name
by a check is not, however central it looks.

```bash
# how often does each sensitive path actually change? one that changes on every
# commit is almost certainly bookkeeping, not a trust boundary
git log --since='3 months ago' --name-only --format= | sort | uniq -c | sort -rn | head
```

---

# Writing one

1. **Inventory** the project: entry points, boundaries (HTTP, CLI, queues), external
   dependencies, what costs money, what produces the deliverable.
2. **Search for each of the eight categories.** Do not presume. Each is *present* with its
   paths, or *absent* with a reason that can be verified.
3. **Order patterns from most specific to `**` last.**
4. **Write the reason for every entry** — what breaks, and why no test would catch it. A
   map without reasons goes stale and nobody dares touch it.
5. **Run `check-risk-map.sh`.** It catches the first four traps mechanically. The fifth is a judgement — the command in its section shows you which paths change on every commit, but only you know whether that path is a trust boundary or bookkeeping.
6. **Have someone else read it.** A map is wrong easily and silently, and the person who
   wrote it is the person least able to see what it missed.

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Template — Risk

Severity: Mandatory
