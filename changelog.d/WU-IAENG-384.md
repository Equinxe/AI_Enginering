### Fixed

- `setup-branch-protection.sh` no longer turns strict back on for `develop`. The Director set `develop` to strict=false on 22 Oct 2026, with `main` and `release/*` still strict, but the script still sent `"strict": true` for both branches, so a re-run undid that decision. The value is now set per branch: `main` true, `develop` false, and any other branch refused. The off-GitHub checklist says the up-to-date rule applies to `main` and `release/*` only. The suite stubs `gh` and asserts the body sent for each branch (#299, WU-IAENG-384)
- The headers of `ci-build-test.yml`, `ghcr-publish.yml` and `generic.Dockerfile` now match their code. Stack detection has no first-match order: it lists all seven stacks, and a project matching two of them fails. The image is tagged with the full version only, never `1.2`. `:latest` is also added for a `v*` tag that is not a pre-release, and the commit tag is `sha-<short-sha>` (#299, WU-IAENG-384)

### Notes

- Running `setup-branch-protection.sh` again now sets `develop` to strict=false. A project's existing setting stays as it is until then. A project that wants `develop` strict turns the setting back on in its forge after each run (#299, WU-IAENG-384)
