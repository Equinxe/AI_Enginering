### Added

- The Pull Request template has a Merge danger section: whether a revert undoes the change and, if not, what it leaves behind; and what fails if the change is wrong. An approver reads in two lines how costly a wrong approval is (`Templates/PULL_REQUEST.md` 0.0.8 and both GitHub copies; #352, WU-IAENG-411)
- The Code Reviewer runs a Defect Hunt before any approval, over the whole Pull Request diff (or, once a head was hunted, the changes since it): it names the two places in the diff where a critical or major defect would hide best and checks both, and mutates every guard the diff adds or changes in a disposable copy, one mutant at a time with the narrowest check under a time limit, a surviving mutant being a missing test that blocks and an equivalent or timed-out one not (Testing Standard, Falsifiability items 4 and 6); a guard it cannot mutate is listed with why and stays unverified. The Review Decision records the hunt (`Employees/Specialized/CODE_REVIEWER.md` 0.0.5, `Workflows/CODE_REVIEW.md` 0.0.12 Step 8; #352, WU-IAENG-411)

### Notes

- An installed `.github/PULL_REQUEST_TEMPLATE.md` now differs from its Adapter: if you never edited it, copy the Adapter over it by hand (`cp ia-engineering/Adapters/github/PULL_REQUEST_TEMPLATE.md .github/`); `check-framework-drift.sh` reports it `stale` and gives the same remedy. A Pull Request opened before the new template is not sent back for the missing Merge danger: the reviewer asks for the two lines in a comment (WU-IAENG-411)
