### Security

- `block-escape-hatches.sh` hardens command recognition. It recognises `git.cmd`, `git.com` and `git.bat` as git, and a dashed `git-<subcommand>` such as `git-push` or `/mingw64/libexec/git-core/git-stash`, with or without `.exe`, as git running that subcommand. It recognises `rm` under any path (`/bin/rm`, `./rm`), as `rm.exe` and in any case spelling, after a subshell's `(`, and with a target that ends at a `;`, `&`, `|` or `)` (WU-IAENG-450)
- `strip-quotes.awk` reads a command a third time when that reading differs from the other two. A command substitution is read as empty, so a flag glued to one, such as `"--force$(true)"`, `--fo$(true)rce` or a backtick form, is read whole. A quoted or escaped `;`, `&` or `|` is part of its word, so a git option's value such as `-C "a;b"`, or a substitution in it, does not cut its command in two. A rule refuses on a match in any reading. A call starts the same processes as before (WU-IAENG-450)
- A quoted word that holds a space keeps its place after a git option that takes a value and after `stash`, so `git stash "-m a b" list` is not read as the `list` read (WU-IAENG-450)
- The approval-label rule refuses a label that is not a static literal: a `gh pr|issue edit|create` label flag whose value holds a variable or a command substitution, such as `--add-label "control-change/$(echo approved)"`, and a `gh api` write that sets labels from one, or from a file with `-F …=@file`. A literal `$` in a quoted label is refused too. Its refusal names the reason. A `gh api` write in a command that names a label now starts the rule's second `awk`, as a quoted label list already did (WU-IAENG-450)
- The 2,000-segment cap counts the third reading too. A command read three times is read up to 666 segments and refused from 667 (WU-IAENG-450)

### Fixed

- The `core.hooksPath` read exemptions accept a quoted git option value that holds a space: `git -C "/c/Program Files/repo" config --get core.hooksPath` and `git --git-dir="/c/my repo/.git" config --get core.hooksPath` are allowed. A value that holds only whitespace, and the legacy read `git config core.hooksPath` beside a quote, stay refused (#477, WU-IAENG-450)
