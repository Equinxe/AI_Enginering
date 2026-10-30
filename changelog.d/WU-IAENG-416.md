### Changed

- `Workflows/CODE_REVIEW.md` (0.0.13): the mandatory Prompt Engineer review now also covers `Templates/EMPLOYEE_BRIEF.md` and the whole of `Adapters/ai-runtimes/generate-agents.sh`, as well as `Employees/` and any `Core/*.md` document. Step 4 holds the only list of these files and cites the source of each entry: `Core/EMPLOYEE_SELECTION.md` (Prompt Engineer trigger) for the first two, and the Director's decision of 28 Oct 2026 on issue #206 for the template and the generator. The Actors table, the Step 4 Output, the Multi-Lens Review table and the Exit Criteria refer to that list instead of repeating it. `Workflows/` documents stay outside the review. `Core/EMPLOYEE_SELECTION.md` is unchanged (Director, 29 Oct 2026) (#206, part of #221)
- `Registry/workflows.yml`: the Code Review blocking condition on the Prompt Engineer's approval refers to the list in `Workflows/CODE_REVIEW.md` Step 4 and cites the Director's decision (#206)

### Notes

- A Pull Request still open when this change merges falls under the wider rule: if it changes `Templates/EMPLOYEE_BRIEF.md` or `Adapters/ai-runtimes/generate-agents.sh`, it needs the Prompt Engineer's approval before merge, and a second reviewer named by the Director when the Prompt Engineer wrote it
