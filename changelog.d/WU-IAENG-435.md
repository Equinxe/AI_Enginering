### Added

- `Templates/PROJECT_CLAUDE.md` (0.0.17) gives an adopting project's Main Agent a parallel-agent cap: at most 6 Employees, or other subagents, running at once per machine. Those of every other session on the machine count, a framework session's included. At the cap, the Main Agent queues the next Work Unit, tells the Director, and dispatches it when the count falls below 6. The cap never refuses or drops a Work Unit (Director decision D3, Usage plan W1.5, WU-IAENG-435)

### Changed

- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` (0.0.17) records Director decision D3: 3 agents per machine with v0.0.15, and 6 from the `develop` commit that merged PR #463. It gives the measurement behind 6. With 8 calls at a time, the lighter escape-hatch guard's p50 is 13 to 17 % of before, and the edit guard is now the one that limits parallel agents. A bench of 6 calls at a time on `develop` 2e5341b, with the CPU at 100 %, had a slowest guard call of 9.8 s against the 120 s timeout. The cap is decided again after the edit guard is re-measured (Usage plan W2.3). `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` entry C cites the cap (WU-IAENG-435)

### Notes

- After upgrading, copy the parallel-agent cap paragraph from the Main Agent section of `ia-engineering/Templates/PROJECT_CLAUDE.md` into your project's `CLAUDE.md`. Until then, your Main Agent has no cap. A project still on v0.0.15 keeps a cap of 3 (WU-IAENG-435)
