### Added

- `Templates/PROJECT_CLAUDE.md` (0.0.17) gives an adopting project's Main Agent a parallel-agent cap: at most 6 subagents running at once per machine, Employees included. Those of every other session on the machine count, a framework session's included. At 6 or more, the Main Agent queues the next Work Unit, tells the Director, and dispatches it when the count falls below 6. The cap never refuses or drops a Work Unit (Director decision D3, Usage plan W1.5, WU-IAENG-435)
- `Core/ORCHESTRATION.md` (0.0.16), The Dependent-Task Queue, gives the same cap to every Main Agent, the framework's own included. The Main Agent counts its own subagents plus those the Director reports. At 6 or more, a dispatchable Work Unit stays dispatchable and waits in the queue until the count falls below 6, and is never refused. The Director approved the line word for word on 18 November 2026 (Director decision D3, WU-IAENG-435)

### Changed

- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` (0.0.17) records Director decision D3: 3 agents per machine with v0.0.15, and 6 from the `develop` commit that merged PR #463. It gives the measurement behind 6. With 8 calls at a time, the lighter escape-hatch guard's p50 is 13 to 17 % of before, and the edit guard is now the one that limits parallel agents. A bench of 6 calls at a time on `develop` 2e5341b, with the CPU at 100 %, had a slowest guard call of 9.8 s against the 120 s timeout. The cap is decided again after the edit guard is re-measured (Usage plan W2.3). `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` entry C cites the cap (WU-IAENG-435)

### Notes

- After upgrading, copy the parallel-agent cap paragraph from the Main Agent section of `ia-engineering/Templates/PROJECT_CLAUDE.md` into your project's `CLAUDE.md`. Until then, your `CLAUDE.md` does not state the cap, but your Main Agent still has it from `ia-engineering/Core/ORCHESTRATION.md`. A project still on v0.0.15 keeps the cap of 3 that the v0.0.15 pilot conditions set: condition 2 of the Security Engineer's release sign-off on #452, "Run at most 3 agents in parallel" (WU-IAENG-435)
