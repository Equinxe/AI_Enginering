### Fixed

- `validate-framework.sh` section 22 refuses a chain diagram line that holds more than one bracket pair. A line such as `[Containment] Compliance Engineer [Assessment]` was read as one output and hid the step between them; an output line is now `[` first, `]` last and no bracket in between (issue #233) (#243, WU-IAENG-350)
- `validate-framework.sh` section 13 counts the chains `Core/AGENT_CHAINS.md` names, reads a CRLF copy, and fails when it finds none, instead of passing unconditionally. The `Adapters/README.md` validator row points to the section headers the script prints as the list of sections (issues #227, #228) (#243, WU-IAENG-350)
