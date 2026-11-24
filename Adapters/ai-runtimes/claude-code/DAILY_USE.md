# Daily Use with Claude Code

---

# Purpose

`README.md` Getting Started ends when the adoption is merged into `develop`. This page takes over from there. It follows one Work Unit through the daily loop of a project that has adopted the framework and works with Claude Code: start it, approve its plan, dispatch it to an Employee in a worktree, review it, merge it, clean up, and come back to `develop`. Then it says where a human runs a command that a guard refuses.

This page sets no rule. The rules are in `Core/ORCHESTRATION.md` (the Main Agent's seven steps), `Workflows/FEATURE_DEVELOPMENT.md` (from branch to merge) and `Workflows/CODE_REVIEW.md` (the review). When this page and one of them disagree, the rule is right, and this page needs a Work Unit to correct it.

**Audience.** The Director of an adopting project, on Windows, macOS or Linux. Commands run from the project root, so the framework's own files start with `ia-engineering/`.

**Sources.** Every claim about Claude Code cites its page at `code.claude.com/docs/en/`, checked on 24 November 2026. A claim no page makes is labelled as observed, with where and when, or as derived.

**Version.** This page describes the framework from v0.0.16. A project that pins v0.0.15 dispatches every Employee in the main checkout (`README.md`, Getting Started, "Adopting v0.0.15 into an existing repository"). For it, the worktree in Step 3 and its removal in Step 7 do not apply, and its guards may word a refusal differently from `TROUBLESHOOTING.md` entry D.

---

# Before You Start

- The adoption is merged into `develop`, and `.ia-engineering/SESSION_STATE.md` exists (`README.md`, The steps that are not commands).
- `.claude/agents/` holds one agent per Employee. `./ia-engineering/Adapters/ai-runtimes/generate-agents.sh --check` exits 0 when every agent is current.
- A terminal is open at the project root, outside Claude Code. On Windows, use Git Bash (`Governance/TROUBLESHOOTING.md` entry AA). You use it in Step 7, and whenever you decide that a command a guard refused should run (Where a Human Runs a Refused Command, below).
- The GitHub CLI is signed in: `gh auth status`.

---

# The Loop at a Glance

| Step | Who acts | Where | Your part |
|---|---|---|---|
| 1. Start a Work Unit | You, then the Main Agent | Claude Code, started at the root of the main checkout, on `develop` | Say what you want |
| 2. Approve the plan | You | The Claude Code session | Approve it, or ask for changes |
| 3. Dispatch | The Main Agent, then the Employee | The Employee's worktree, under `.claude/worktrees/` | Nothing: wait for the Work Unit Report |
| 4. Pull Request | The Employee | Its worktree, then GitHub | Nothing |
| 5. Review | The Code Reviewer, and QA or a specialist when a rule calls one | Comments on the Pull Request | Read the decision, and apply the labels only you may apply |
| 6. Merge | The Main Agent, or the Engineering Manager or Technical Lead | `gh pr merge`, from the main checkout | Answer Claude Code if it asks permission |
| 7. Clean up | The Engineering Manager or Technical Lead, or you | The main checkout | Run it yourself, or let it be dispatched |
| 8. Back on `develop` | The Main Agent | The main checkout | Read the delivery |

---

# Step 1 — Start a Work Unit

1. In your terminal, at the project root, check the main checkout:

   ```bash
   git status --short --branch
   ```

   The only line should be `## develop...origin/develop`. If it says `[behind N]`, run `git pull --ff-only`.
2. Start Claude Code in the same directory: `claude`. Start it in the main checkout, never inside a worktree under `.claude/worktrees/`: there `ia-engineering/` is empty, and every guarded call is refused (`TROUBLESHOOTING.md` entry C, cause 1).
3. The session-start hook prints the reading order, the header and Next Step of `SESSION_STATE.md`, and any drift from the framework (`hooks/README.md`).
4. Say what you want, in your own words. You do not name the Employee or write the brief. The Main Agent reads `CLAUDE.md` and `SESSION_STATE.md`, analyses the request, and comes back with a plan (`Core/ORCHESTRATION.md`, Steps 1 to 3).

---

# Step 2 — Approve the Plan

The plan lists each Work Unit with its objective, its Employee, its inputs and outputs, its Definition of Done, the Standards that apply, and its expected commit message (`Core/ORCHESTRATION.md`, Step 3). It also gives each Work Unit's id, which is registered in the project's `Registry/work-units.yml`, either in the Work Unit's own commit or up front in one bookkeeping Pull Request (`Workflows/FEATURE_DEVELOPMENT.md`, Step 4).

A plan that carries an action classified Medium or higher reaches you only after the Technical Lead's Plan Review, with its record attached (`Core/ORCHESTRATION.md`, Step 3).

**Approve it in the session.** Write your answer in the Claude Code session: approve the plan, or say what to change. Nothing is dispatched before you approve (`Core/ORCHESTRATION.md`, Step 3). Silence is not an approval, and neither is a confirmation you gave for something else (`Standards/RISK_STANDARD.md`, Forbidden Practices). For a High or Critical action, your confirmation names that action.

Plan approval is not where `Decision: approved` goes. That line is the Code Reviewer's, on the Pull Request, in Step 5.

---

# Step 3 — Dispatch in a Worktree

The Main Agent writes an Employee Brief (`Templates/EMPLOYEE_BRIEF.md`) and dispatches the named Employee from `.claude/agents/`, with the Agent tool's `isolation: "worktree"`. What follows is Claude Code's part:

- **The worktree.** Claude Code creates a git worktree under `.claude/worktrees/<name>/`. The install gitignores that directory. Observed on a framework Employee's worktree on 24 November 2026, it starts on a new branch named `worktree-<name>`.
- **Its starting point is `main`, not `develop`.** A subagent's worktree branches from the repository's default branch on the remote, unless the `worktree.baseRef` setting says otherwise ([Worktrees, Choose the base branch](https://code.claude.com/docs/en/worktrees.md#choose-the-base-branch)). The framework does not set it. In an adopting project the default branch is `main`, which holds no adoption until the first release. So the Employee creates its own branch from `origin/develop`, after `git fetch origin`, as `Workflows/FEATURE_DEVELOPMENT.md` Step 2 says.
- **The framework there.** The worktree's `ia-engineering/` is an empty directory. The Employee reads the framework from the main checkout, at the absolute path its definition names under "Where the Framework Is". The git hooks run from the main checkout, through the absolute `core.hooksPath` that `install.sh` sets (`Governance/TROUBLESHOOTING.md` entry AB). The Claude Code hooks run from the main checkout too (`TROUBLESHOOTING.md` entry C, cause 1).
- **The lock.** While the agent runs, Claude Code locks the worktree ([Worktrees, Worktree locks and manual removal](https://code.claude.com/docs/en/worktrees.md#worktree-locks-and-manual-removal)). `git worktree list --porcelain` shows a line such as `locked claude agent <name> (pid <n>)` (observed on 24 November 2026).

The main checkout stays on `develop` throughout, so the Main Agent can keep reading it while the Employee works (`Core/MAIN_AGENT_CONDUCT.md`, Workspace Isolation). The number of agents running at once is held by the parallel-agent cap (`Core/ORCHESTRATION.md`, Step 4, Dispatch Rules). At the cap, a dispatch waits, and the Main Agent tells you what waits.

---

# Step 4 — The Employee's Commit and Pull Request

In its worktree, the Employee commits its Work Unit as one commit, with the `Work Unit:` and `Employee:` trailers (`Standards/COMMIT_STANDARD.md`). The git hooks check the commit as it is made. The Employee pushes its branch and opens a Pull Request to `develop` (`Workflows/FEATURE_DEVELOPMENT.md`, Steps 4 and 5).

It ends with its Work Unit Report (`Templates/WORK_UNIT_REPORT.md`). The Main Agent checks the report against the repository, not against its wording (`Core/ORCHESTRATION.md`, Step 5).

---

# Step 5 — Review

The Main Agent dispatches the Code Reviewer on the Pull Request (`Workflows/CODE_REVIEW.md`). It also dispatches the QA Engineer when the change alters executable behaviour (`Workflows/FEATURE_DEVELOPMENT.md`, Step 7), and any other reviewer a rule requires (Step 8, item 3).

**Where `Decision: approved` goes.** The Code Reviewer posts its Review Decision as a comment on the Pull Request (`Workflows/CODE_REVIEW.md`, Step 8). The decision line is in that comment: `Decision: approved`, `Decision: changes requested` or `Decision: escalated` (`Employees/Specialized/CODE_REVIEWER.md`, Review Decision). The decision names the head commit it reviewed: for the Main Agent's merge, an approval counts only on the head it was given on (`Core/MAIN_AGENT_CONDUCT.md`, Git Execution via Named Employee, condition 1). The CI check **Review Recorded (advisory)** looks for that line in the Pull Request's comments. It never blocks a merge (`Adapters/scripts/check-review-recorded.sh`). You do not write the line yourself.

**Changes requested.** The Main Agent sends the fix round back to the authoring Employee. The Employee pushes a new commit, never a force-push, and the review runs again on the new head (`Workflows/CODE_REVIEW.md`, Step 9). An approval of an earlier head is void, unless the only new commits are merges of `develop` that `Adapters/scripts/check-approval-carry-over.sh` accepts.

**Your part.** Two labels are yours alone: `size/approved`, on a Pull Request above the 1,500-line review limit (`Standards/PULL_REQUEST_STANDARD.md`, Reviewability), and `control-change/approved`, on one that changes a control path (`Adapters/README.md`, the Control Path Guard row). The guard refuses either label to an agent (`TROUBLESHOOTING.md` entry D).

---

# Step 6 — Merge

**Who runs `gh pr merge`.** `Workflows/FEATURE_DEVELOPMENT.md` Step 8 names the actor:

- **The Main Agent**, under the Director's standing exception, when all three of its conditions hold (`Core/MAIN_AGENT_CONDUCT.md`, Git Execution via Named Employee): the approvals are on the current head; every other approval a rule requires is recorded; and every required check is green on that head, with the merge pinned to it.
- **The Engineering Manager or the Technical Lead**, dispatched by the Main Agent, in every other case. That dispatch is made without `isolation: "worktree"`, so that the Employee works in the main checkout (Step 7, Who, says why).

A merge into `main` or a `release/*` branch, a tag and a release are never the Main Agent's. They are the Release Manager's, with your approval (`Workflows/RELEASE.md`).

**The command,** from the main checkout:

```bash
gh pr merge <number> --merge --match-head-commit <head commit>
```

- `--merge` makes a merge commit. Never squash or rebase: each commit keeps its own trailers (`Standards/COMMIT_STANDARD.md`).
- `--match-head-commit` merges only if the Pull Request's head is still the approved commit.
- There is no `--delete-branch`. The branch is still checked out in the Employee's worktree, and git refuses to delete it there. Step 7 removes the worktree first.

If Claude Code stops the call with a permission prompt, or auto mode blocks it, that refusal is Claude Code's, not the framework's (`TROUBLESHOOTING.md` entry E). Answer the prompt, or run the same command in your terminal.

---

# Step 7 — Clean Up

**Why this step exists.** An Employee that committed leaves its worktree behind. Claude Code removes a subagent's worktree by itself only when the subagent finished without changes. Otherwise a periodic sweep removes it later, once it is older than the `cleanupPeriodDays` setting and holds no work ([Worktrees, Isolate subagents with worktrees](https://code.claude.com/docs/en/worktrees.md#isolate-subagents-with-worktrees)). Until then the branch stays checked out in that worktree, and git refuses to delete it. Observed with git 2.54.0 on Windows, on 24 November 2026:

```
error: cannot delete branch '<branch>' used by worktree at '<path>'
```

So the worktree is removed first, and the branch second (`Workflows/FEATURE_DEVELOPMENT.md`, Step 8).

**Who.** Step 8's actor runs the cleanup. The Main Agent's standing exception names the merge and the deletion of the merged branch, not the removal of a worktree, which is a git mutation of its own (`Core/MAIN_AGENT_CONDUCT.md`, Git Execution via Named Employee). So after a merge the Main Agent ran, it dispatches this step to the Engineering Manager or the Technical Lead, or you run it in your terminal. Whether the exception should also cover this step is your decision (issue #490).

**A dispatched cleanup runs in the main checkout.** The Main Agent dispatches it without `isolation: "worktree"`, and runs no git command in the main checkout until the Employee reports (`Core/MAIN_AGENT_CONDUCT.md`, Workspace Isolation, Wait). From a worktree of its own, the Employee could not do this step. Claude Code blocks an isolated agent's command whose working directory is the main checkout, and git redirected into it ([Worktrees, How Claude Code enforces isolation](https://code.claude.com/docs/en/worktrees.md#how-claude-code-enforces-isolation)). In that worktree, `git switch develop` fails as well, because the main checkout has `develop` checked out: `fatal: 'develop' is already used by worktree at '<path>'` (observed with git 2.54.0 on 24 November 2026). The generated agents set no `isolation`, so this is chosen at each dispatch.

**The commands,** from the root of the main checkout:

```bash
git switch develop
git pull --ff-only                                          # fetches origin, brings in the merge
git worktree list                                           # the Employee's line ends in [<branch>]
git merge-base --is-ancestor <branch> origin/develop && echo merged          # prints merged
git merge-base --is-ancestor origin/<branch> origin/develop && echo merged   # prints merged
git -C .claude/worktrees/<name> status --short --ignored    # nothing you still need
git worktree remove .claude/worktrees/<name>                # never with --force
git branch -d <branch>
git branch -d worktree-<name>
git push origin --delete <branch>
```

- `git pull --ff-only` fetches `origin` before it merges, so `origin/develop` and `origin/<branch>` are current for the lines after it.
- The two `git merge-base` lines check that `develop` has the work. Each prints `merged` when every commit of the branch is in `origin/develop`: the first for your local branch, the second for its copy on `origin`, which can hold more, for example a fix round pushed from another worktree. Both must print `merged` before anything is removed or deleted. When one does not, the table below says what to do.
- `git status --short --ignored` lists the worktree's ignored files, on lines that start with `!!`. `git worktree remove` refuses for modified or untracked files, but it deletes ignored files without asking (observed with git 2.54.0 on 24 November 2026). They can be a `.env` that `.worktreeinclude` copied there ([Worktrees, Copy gitignored files into worktrees](https://code.claude.com/docs/en/worktrees.md#copy-gitignored-files-into-worktrees)), or files the Employee left under `local_test_data/`. `install.sh` gitignores both. Move out anything you still need before the removal.
- `git worktree remove` deletes the worktree's directory and its record. It keeps every commit: the commits stay on the branch.
- `git branch -d` deletes the Work Unit's branch, but it does not check `develop`. It refuses a branch that is not fully merged into its upstream, or into the current branch when the branch has no upstream ([git-branch, `-d`](https://git-scm.com/docs/git-branch#Documentation/git-branch.txt--d)). After `git push -u`, the upstream is the branch's own copy on `origin`. So `-d` deletes a pushed branch that never reached `develop`, with only a warning that starts `warning: deleting branch '<branch>' that has been merged to` (observed with git 2.54.0 on 24 November 2026). That is why the `git merge-base` lines come first. When `-d` refuses, that refusal is information: never force it.
- `worktree-<name>` is the branch Claude Code created with the worktree. When the Employee worked on a branch of its own, this one holds no commit of its own. If `git branch -d` refuses it, leave it. Such branches add up. When `git log --oneline origin/main..worktree-<name>` prints nothing, the branch holds no commit that `main` does not have, and deleting it loses nothing: you may delete it in your terminal with `git branch -D worktree-<name>`, which the guards refuse to an agent.
- `git push origin --delete` deletes the remote branch. GitHub does not delete it on merge: `setup-branch-protection.sh` turns that setting off, so that GitHub never deletes a release branch.

**When git refuses.** Never add `--force`: what git protects is work, and the decision about it is yours. Git does not protect everything, though: `-d` does not check `develop`, and the removal takes ignored files. The commands above check both first.

| git says | What it means | What to do |
|---|---|---|
| A `git merge-base` line prints nothing | `origin/develop` does not have every commit of the branch, or of its copy on `origin`. That is work that never reached `develop`. | Stop, and delete nothing, locally or on the remote. `git log --oneline origin/develop..<branch>`, or `git log --oneline origin/develop..origin/<branch>`, lists the commits. Bring the branch to the Main Agent. |
| `fatal: Not a valid object name origin/<branch>` | The branch was never pushed: there is no copy on `origin`. | If the first `git merge-base` line printed `merged`, go on, and skip `git push origin --delete`. |
| `'<path>' contains modified or untracked files, use --force to delete it` | The worktree holds changes nobody committed. | Run `git -C .claude/worktrees/<name> status --short` to see them. They are an Employee's unfinished work or files it left. Decide what happens to them before anything is removed. |
| `cannot remove a locked working tree, lock reason: claude agent <name> (pid <n>)` | Claude Code locked the worktree for a running agent. | Wait for that Employee's Work Unit Report. A lock left by a session that has ended is released by Claude Code's sweep, or by you with `git worktree unlock .claude/worktrees/<name>` once you know no session runs there. |
| `working trees containing submodules cannot be moved or removed` | The worktree's `ia-engineering/` was initialised, for example by `TROUBLESHOOTING.md` entry C, remedy 1. Git removes such a worktree only with `--force` ([git-worktree, remove](https://git-scm.com/docs/git-worktree#Documentation/git-worktree.txt-remove)), which also discards uncommitted changes. | This one is yours, by hand. First check that `git -C .claude/worktrees/<name> status --short` and `git -C .claude/worktrees/<name>/ia-engineering status --short` both print nothing. Then run `git worktree remove --force .claude/worktrees/<name>`. |
| `cannot delete branch '<branch>' used by worktree at '<path>'` | The worktree is still there. | Remove the worktree first. |
| The branch `is not fully merged` | The branch has commits that its upstream does not have, or, when it has no upstream, that `develop` does not have. For a pushed branch, these are commits that were never pushed. | `git log --oneline origin/develop..<branch>` lists what `develop` does not have. Bring the branch to the Main Agent. |

**Older worktrees.** `git worktree list` shows every worktree of the clone. A stale one is where the checks above matter most: its Employee may have pushed its branch and never opened a Pull Request. From the main checkout, on `develop`, run `git fetch origin`, then, for each worktree, the commands above from the two `git merge-base` lines on, with that worktree's name and branch. When either line prints nothing, leave the worktree and the branch, locally and on the remote, and bring the branch to the Main Agent. `git worktree prune` removes the record of a worktree whose directory no longer exists.

---

# Step 8 — Back on `develop`

1. `git status --short --branch` in the main checkout shows `## develop...origin/develop` and nothing else.
2. When the pull brought commits newer than `.ia-engineering/SESSION_STATE.md`, the Stop gate asks the Main Agent to update it: `iaeng: stop gate — .ia-engineering/SESSION_STATE.md is behind the repository` (`TROUBLESHOOTING.md` entry D). That is expected. The Main Agent rewrites "Where the Project Stands" and "Next Step".
3. The Main Agent delivers: what was built, who did it, the risk records, and every open item filed as an issue. Then it stops and waits for your next request (`Core/ORCHESTRATION.md`, Step 7).

---

# Where a Human Runs a Refused Command

Three kinds of refusal reach a session. `TROUBLESHOOTING.md` starts with an index from the message to its entry.

- **A framework guard.** The message starts with `iaeng: BLOCKED —` or `iaeng: stop gate —` (entry D).
- **Claude Code itself.** A permission prompt, an auto-mode block, or a worktree isolation check (entry E).
- **A guard that failed.** Every call is refused, and no `iaeng:` line says why (entry C).

**The Employee stops and reports.** When the refusal prints a remedy, the Employee may follow it: that is the control's own way through. Otherwise it stops, quotes the refusal in its Work Unit Report, and goes no further with that action. It never rewrites the command into another form that does the same thing and gets past the guard. That is routing around a blocking control, which `Standards/RISK_STANDARD.md` forbids (Forbidden Practices), whether the refusal looks right or wrong. A refusal the Employee believes is wrong, a false positive, is reported the same way, with the command and why it is legitimate. The Main Agent files it as an issue: a false positive is a defect of the guard, and a fix to the guard is a Work Unit (`Standards/GIT_STANDARD.md`, Escape Hatches). The guard's own message says so: "A control in the way is a rule in the way: escalate it with this message quoted."

**The Main Agent brings it to you,** with the refusal quoted and what the action was for. It follows the same rule as the Employee.

**You decide.** If you decide that the action should happen, a human runs it by hand. The guard's last line says the same: "If the Director has decided this action, a human runs it by hand — the hook never learns exceptions."

**Where you run it:**

- **In a terminal outside Claude Code, opened at the project root.** On Windows, that is Git Bash. This is the verified place. The framework's guards are Claude Code `PreToolUse` hooks, and "PreToolUse runs only when Claude calls a tool" ([Hooks reference, PreToolUse](https://code.claude.com/docs/en/hooks.md#pretooluse)). A command you type in your own terminal is not a tool call. The project's git hooks still run there, because they are git's, not Claude Code's. When one of them refuses, fix what it refuses: never get past it with `--no-verify` (`Standards/GIT_STANDARD.md`, Escape Hatches).
- **With Claude Code's `!` prefix: derived, not verified.** Shell mode runs a command "directly without going through Claude", and it "doesn't require Claude to interpret or approve the command" ([Interactive mode, Shell mode with `!` prefix](https://code.claude.com/docs/en/interactive-mode.md#shell-mode-with-prefix)). Since `PreToolUse` runs only on Claude's tool calls, the guards should not run on a `!` command. Neither page says so in as many words, and it has not been observed in this framework yet. Until it is, run a refused command in your terminal. Shell mode also adds the command and its output to the conversation, and Claude responds to it.

Tell the Main Agent what you ran and what it printed, so that the session state stays true.

---

# Related Documents

- `README.md` — Getting Started, up to the merged adoption
- `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` — the index from a refusal's text to its entry
- `Governance/TROUBLESHOOTING.md` — entries AB (git hooks in a worktree) and AE (`Filename too long` in a nested worktree)
- `Workflows/FEATURE_DEVELOPMENT.md` — Steps 2 to 8, from branch to merge and cleanup
- `Workflows/CODE_REVIEW.md` — the review and its decision
- `Core/ORCHESTRATION.md` — the Main Agent's seven steps and the parallel-agent cap
- `Core/MAIN_AGENT_CONDUCT.md` — Workspace Isolation, and who executes which git operation
- `Standards/RISK_STANDARD.md` — confirmation of High and Critical actions, and the ban on routing around a control

---

# Metadata

Owner: IA Engineering

Version: 0.0.1

Status: Draft

Category: Adapter — AI Runtime (Claude Code)

Severity: Recommended
