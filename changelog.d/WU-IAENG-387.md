### Changed

- The Check Convention is now a Standard: `Standards/CODE_QUALITY_STANDARD.md` (0.0.4), The Check Convention. Its four rules bind every check, in the framework and in a project, in any language. Three shell rules bind the framework's scripts, and a project's unless the project records another convention: exit codes are an interface (`0` only when everything was evaluated, own codes for a failure to evaluate and for a usage error, the POSIX `diff`/`grep` convention for a new check unless it implements a declared contract); `set -u` and `pipefail`, with `set -e` only where the header states why; a carriage return is removed only where it ends a line, never with `tr -d '\r'` or `gsub(/\r/, "")`. The Standard's Forbidden Practices gain reporting a check as passed when it did not evaluate, and discarding a check's exit status
- `Adapters/README.md`, The Check Convention, keeps its heading, so every existing citation still resolves, and now points to the Standard for the rules. It keeps the record of how they were found, and adds the Exit Code Families register the Standard refers to. No script changed

### Notes

- An adopting project's shell scripts are now held to the shell rules of `Standards/CODE_QUALITY_STANDARD.md`, The Check Convention, unless the project records another convention: review the project's scripts against them, or record the convention it follows instead. The framework's own scripts that do not yet conform are tracked as issues
