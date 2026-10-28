### Added

- The Pull Request template has a Merge danger section: whether a revert undoes the change and, if not, what it leaves behind; and what fails if the change is wrong. An approver reads in two lines how costly a wrong approval is (`Templates/PULL_REQUEST.md` 0.0.8 and both GitHub copies; #352, WU-IAENG-411)
- The Code Reviewer runs a Defect Hunt before any approval: it names the two places in the diff where a critical or major defect would hide best and checks both, and mutates every guard the diff adds or changes in a throwaway copy, a surviving mutant being a missing test that blocks; a guard it cannot mutate is listed with why and stays unverified. The Review Decision records the hunt (`Employees/Specialized/CODE_REVIEWER.md` 0.0.5, `Workflows/CODE_REVIEW.md` 0.0.12 Step 8; #352, WU-IAENG-411)

### Notes

- An installed `.github/PULL_REQUEST_TEMPLATE.md` now differs from its Adapter: if you never edited it, copy the Adapter over it by hand (`cp ia-engineering/Adapters/github/PULL_REQUEST_TEMPLATE.md .github/`); `check-framework-drift.sh` reports it `stale` and gives the same remedy (WU-IAENG-411)
