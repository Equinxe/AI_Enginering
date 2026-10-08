---
name: dashboard
description: Open this project's IA Engineering usage dashboard in the browser at once. The page keeps itself fresh, so there is no rebuild to wait for.
disable-model-invocation: true
allowed-tools: Bash(bash .claude/skills/dashboard/open-dashboard.sh)
---

# Open the usage dashboard

Run exactly this one command with the Bash tool, from the project root (the directory that holds `.claude/`):

```
bash .claude/skills/dashboard/open-dashboard.sh
```

Then reply with the one line it printed, verbatim, and nothing else.

If it exits non-zero, relay what it printed and stop. Do not rebuild the page, do not try another command, and do not fix anything: the line says why the page did not open.

The first run in a project with no page yet builds the page before opening it, which can take a while. Every later run opens the page immediately.

---

## Why this file lives where it does

`/dashboard` is a Claude Code wrapper around `Adapters/scripts/usage-dashboard.sh --open --no-wait`, the contract that script's header specifies under KEPT FRESH. The page, what it shows and what it decides are in `Governance/DISPATCH_IN_PRACTICE.md`, Measuring Usage. This skill adds nothing to either. It only finds the script from the project root, so the command works the same in the framework repository and in an adopting project, on Windows (Git Bash) and on POSIX systems. The Stop hook `hooks/dashboard-refresh.sh` keeps the page fresh between runs.

It is user-invoked only (`disable-model-invocation`): opening a browser window is the user's call, not the model's.
