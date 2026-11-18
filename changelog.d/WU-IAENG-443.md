### Changed

- `Core/ORCHESTRATION.md` (0.0.17): the parallel-agent cap moves to Step 4, Dispatch Rules, and holds every dispatch, whatever the size of the plan, reviews and validations included. It is 6 subagents per machine, Employees included, and every Claude Code session on the machine counts. It is 3 while any session on the machine runs v0.0.15 or earlier. Every main session beyond the first lowers it by one. A dispatch counts as 1 plus the subagents its Employee Brief allows the Employee to start, and an Employee starts none otherwise. A pole counts against the share its Pole Brief gives it. At or above the cap, a dispatch waits and the Main Agent tells the Director what waits; if none of the counted subagents is its own, it asks the Director to say when the count falls. The Dependent-Task Queue gains the state Queue — held. The Director approved the lines word for word (Director decision D3, WU-IAENG-443)
- `Templates/PROJECT_CLAUDE.md` (0.0.18) no longer restates the number of the cap. It points the Main Agent to the rule in `ia-engineering/Core/ORCHESTRATION.md`, so a change of the cap reaches every project with the framework's upgrade (WU-IAENG-443)
- `Templates/EMPLOYEE_BRIEF.md` (0.0.13) gains **Subagents you may start**, none by default, and binds every Employee to it (WU-IAENG-443)
- `Workflows/AUTONOMOUS_DELIVERY.md` (0.0.14), Step 2, and `Templates/POLE_BRIEF.md` (0.0.13) give each pole a share of the cap, after the conductor and every pole have each lowered it by one as main sessions. With the default 3 poles, that is one subagent per pole (WU-IAENG-443)
- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` (0.0.18) records the completed rule and counts the model's agents as transcripts, main sessions included. Six subagents and their main session are 7, the last bin below the edit guard's jump, so the earlier "one agent of margin" is withdrawn. The check at 6 calls at a time is reported as one load, not as a confirmation of the cap. W2.3's test is floor-relative: the edit guard's own cost above the no-op is 1 s or less at p50, and on a heavy load no guard call passes 60 s (WU-IAENG-443)

### Fixed

- `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` (0.0.17), entry C, attributed a refusal at 120 s to missing hook files or a failed guard, which fail at once. Such a refusal is a timeout: load, or a guard that hangs. The entry now states the cap of 3 with v0.0.15 and gives a v0.0.15 project the sentence to write. It no longer claims a measurement for that cap (WU-IAENG-443)
- The upgrade note of WU-IAENG-435 said a Main Agent has no cap until the project's `CLAUDE.md` states it. `Core/ORCHESTRATION.md` gives it the cap regardless (WU-IAENG-443)

### Notes

- After upgrading, replace the parallel-agent cap paragraph in your project's `CLAUDE.md` with the one in the Main Agent section of `ia-engineering/Templates/PROJECT_CLAUDE.md`, which points to `Core/ORCHESTRATION.md`. A project on v0.0.15 writes the cap of 3 itself, as `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` entry C gives it (WU-IAENG-443)
