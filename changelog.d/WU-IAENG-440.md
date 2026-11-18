### Security

- `block-escape-hatches.sh` hardens git command recognition. Its rules recognise git under each name the shell runs it by: `git.exe`, and any case spelling, which Windows resolves alike. A command path in quotes that holds a space is read by its last component, by every rule, and so is `gh` in the approval-label rule. A legacy `core.hooksPath` read through such a quoted git path is refused, like any other legacy read beside a quote: use `git config --get core.hooksPath` (WU-IAENG-440)
- `strip-quotes.awk` hardens quoted-substitution lexing. A backtick substitution in double quotes is read as commands, as `$(…)` is. The quoted text before a substitution in double quotes is kept wherever its region is kept: in a command context such as `bash -c` or `eval`, for `printf`, and in the approval-label view. The lexer prints a command as it read it before and, when the new reading differs, the new reading on a line of its own, so every refusal of the earlier reading stands. A call starts the same processes as before: reading a command twice takes the same single `awk` (WU-IAENG-440)
- `block-escape-hatches.sh` applies the stash read exemption per segment. Each `git stash` in a command must be followed by `list` or `show`, letter for letter, and a read in one place exempts nothing else. A brace expansion right after `stash` is refused, even when every alternative is a read (WU-IAENG-440)

### Fixed

- `git -C "<path with a space>" stash list` and `git --git-dir="<path with a space>/.git" stash show` are allowed again. The `core.hooksPath` read with such a quoted global option stays refused, and #477 stays open for it (#477, WU-IAENG-440)
- `git.exe config --get core.hooksPath` is allowed, as `git config --get core.hooksPath` is. So is a `git stash list` or `show` whose global option takes the next word as its value, such as `git -C stash list`, which runs `list` in the directory `stash` and stashes nothing (WU-IAENG-440)
