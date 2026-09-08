# Host Adapters

Almost everything IA Engineering checks is host-free: it reads git, the Registry, and the files in the tree. Four things are not, because no amount of git can answer them.

| Operation | Why it cannot be answered from git |
|---|---|
| `create-release.sh` | the forge owns the Releases page |
| `ci-conclusion.sh` | the forge owns the run history |
| `open-bugs.sh` | the forge owns the issue tracker |
| `fetch-review-comments.sh` | the forge owns the conversation |

Each forge implements those four in `Adapters/scripts/hosts/<host>/`. `Adapters/scripts/resolve-host.sh` decides which directory is called.

---

# The contract

**The host fetches and acts. It never decides.**

A host implementation knows one thing: how to talk to its own API. It does not know what a recorded review decision looks like, which authors count, what a release note should contain, or whether an absent answer is a finding. Those belong to the caller — `check-review-recorded.sh`, `release.sh` — and they are the same for every forge.

This is not tidiness. If each host owned the rules as well as the API calls, the second forge would reimplement them slightly differently, the two would drift on the first fix applied to one of them, and the "seam" would be a fork with a shared name. The author filter in `check-review-recorded.sh` is the worked example: it lives in the check, so a fetcher that forgot to filter cannot leave the check announcing a rule it is not applying.

---

# Exit codes

| Code | Meaning |
|---|---|
| `0` | the operation completed |
| `1` | it failed, or this host cannot perform it |
| `3` | **partial** — some of the work was done and some source could not be read |

`3` exists because a partial result is a real state with its own required behaviour, and collapsing it into success or failure destroys the distinction the caller needs. A review-comment fetch that read two sources of three must let the check say *nothing was established either way* rather than *no decision was recorded*.

---

# `none` is a real host

It is what an unsupported forge, an air-gapped mirror, or a plain bare repository resolves to. Its implementations **do not pretend**: each prints exactly what a human has to do by hand, naming the artefact and the standard that requires it, and exits non-zero so nothing downstream mistakes silence for success.

That is the difference between a framework that cannot be adopted off its original forge and one that can be adopted with effort: an adopter on an unsupported forge gets a checklist, not a crash.

`open-bugs.sh` is the one that exits **`3`** rather than `1`. `Workflows/RELEASE.md` Step 1 condition 3 is *reported, not failed* by design — whether an open issue is critical is a judgment no script makes — so a host that cannot list issues must not turn that into a blocking condition the workflow never had.

It must not exit `0` either, and that was a real defect before it was a rule: exiting `0` with nothing on stdout made `release.sh` report *"no open issues labelled bug"*, asserting an absence nobody had established. **A host that cannot see the tracker has not found zero bugs; it has found nothing.**

---

# Adding a forge

1. Create `Adapters/scripts/hosts/<name>/` and implement the four operations above. A missing file is visibly missing, which is why this is a directory per host rather than one file with a dispatch table.
2. Add `<name>` to `KNOWN_HOSTS` in `Adapters/scripts/resolve-host.sh`.
3. Extend detection **only** for a hosted domain that is unambiguous. A self-hosted instance is not guessed from its URL — `github.example.com` may be a GitHub Enterprise server or a GitLab named unhelpfully, and calling the wrong API against a real server is worse than saying nothing. Self-hosted projects declare their host in `.ia-engineering/host`.
4. Add cases to `Adapters/scripts/tests/run.sh`.

**Do not ship a forge implementation that has never been executed against that forge.** This repository already carries two adapters that were written and never run, and both say so in their own headers; a third would be a pattern rather than an exception. An implementation you cannot verify is a plan, and it belongs in an issue until someone has access.

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Adapter — Host Integration

Severity: Mandatory
