---
name: dashboard
description: Open this project's IA Engineering usage dashboard in the browser at once. The page keeps itself fresh, so there is no rebuild to wait for.
disable-model-invocation: true
allowed-tools: Bash(bash .claude/skills/dashboard/open-dashboard.sh)
---

# Open the usage dashboard

Run exactly this one command with the Bash tool:

```
bash .claude/skills/dashboard/open-dashboard.sh
```

Run it exactly as written: no `cd`, no prefix, no redirection. Set the Bash tool's timeout to 600000 ms. If it still times out, say so and stop; do not run it again.

Then reply with the one line it printed, verbatim, and nothing else.

If it fails because the file is not found, say in one line that the session's working directory has moved off the project root, and stop.

If it exits non-zero for any other reason, relay what it printed and stop. Do not rebuild the page, do not try another command, and do not fix anything: the line says why the page did not open.

The first run in a project with no page yet builds the page before opening it, which can take a while. Every later run opens the page immediately.
