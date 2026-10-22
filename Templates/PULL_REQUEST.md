# Pull Request Template

---

# Usage

Every Pull Request must use this template. A PR without a complete description will be returned to the author before review begins.

Copy the template below into the PR description when opening a Pull Request.

---

# Template

```markdown
## Pull Request — [WU-ID] [Short title]

### Type

- [ ] feat — new feature
- [ ] fix — bug fix
- [ ] docs — documentation only
- [ ] refactor — code change without feature or fix
- [ ] perf — performance improvement without behaviour change
- [ ] test — adding or updating tests
- [ ] chore — build, tooling, or dependency update

---

### What changed

[Describe what this PR does. Be specific — not "added feature" but "adds POST /auth/login endpoint that returns a JWT token on successful authentication."]

---

### Why

[Link to the Work Unit, issue, or business requirement this PR addresses.]

Work Unit: [WU-ID]

---

### How to test

[Step-by-step instructions for the reviewer to verify the change works:]

1. [Step 1]
2. [Step 2]
3. [Expected result]

---

### Screenshots / recordings (if UI change)

[Attach screenshots or screen recordings for any visual changes. Not required for backend-only changes.]

---

### Checklist

**Author:**
- [ ] I have read the Pull Request Standard.
- [ ] This PR targets `develop`, not `main`.
- [ ] The PR contains one Work Unit — not multiple unrelated changes.
- [ ] Tests are written and passing locally.
- [ ] Each new or changed test was seen red where `Standards/TESTING_STANDARD.md` (Falsifiability) requires it; the evidence is in the Work Unit Report.
- [ ] No credentials, secrets, or sensitive data are in this diff.
- [ ] The commit message follows the Commit Standard.
- [ ] Documentation is updated if this PR changes a public interface.
- [ ] Under 1,500 changed lines outside `linguist-generated` files, or the Director has applied `size/approved`.
- [ ] This description stands alone: a reviewer with none of my context can test it from a fresh clone.

**Reviewer:**
- [ ] I have read the PR description before reviewing any code.
- [ ] I have reviewed logic, tests, security, quality, and documentation.
- [ ] My feedback comments include severity labels: [critical], [major], [minor], [suggestion].

---

### Notes for reviewer

[Optional: anything the reviewer should pay special attention to, known trade-offs, or decisions made during implementation.]
```

---

# Field Reference

| Field | Purpose | Common mistakes |
|---|---|---|
| Type | Categorizes the change for changelog generation | Selecting multiple types — one PR, one type |
| What changed | Describes the concrete change | "Fixed bug" — not specific enough |
| Why | Links to the requirement — traceability | Missing Work Unit ID, no business context |
| How to test | Enables the reviewer to verify correctness | "Run tests" — not actionable for manual verification |
| Checklist | Self-verification before requesting review | Submitting with unchecked items |

---

# PR Size

The size limit, what it counts, and the `size/approved` override are defined once, in `Standards/PULL_REQUEST_STANDARD.md` (Reviewability). The checklist item above restates the limit so an author can tick it; this template sets no other size rule.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Template — Engineering

Severity: Mandatory
