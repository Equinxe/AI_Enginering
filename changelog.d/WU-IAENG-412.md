### Added

- `Templates/PROJECT_GLOSSARY.md`: an adopting project keeps the meaning of its domain terms in `.ia-engineering/DOMAIN_GLOSSARY.md`, one entry per term with its definition, source and date. The file is created when the first domain term is settled, never empty. Employees use and cite its meanings, and a domain word with no entry is a question, never a guess. The framework's own vocabulary stays in `Core/GLOSSARY.md`, unchanged (#353, WU-IAENG-412)
- The Business Analyst asks its clarifying questions in numbered rounds ordered by dependency, each question with a recommended answer and what it unblocks; a recommendation is never recorded as an answer (#353, WU-IAENG-412)

### Changed

- `Templates/PROJECT_CLAUDE.md`, `Workflows/ONBOARDING.md` Step 2, `Workflows/PROJECT_BOOTSTRAP.md` Phase A and `Templates/EMPLOYEE_BRIEF.md` point to the project domain glossary; Phase A and Onboarding Step 2 ask their questions in numbered rounds (#353, WU-IAENG-412)

### Notes

- An adopting project's existing `CLAUDE.md` does not gain the new Domain Glossary section by itself: copy it from `Templates/PROJECT_CLAUDE.md` by hand, or name in `CLAUDE.md` the domain glossary the project already keeps (#353, WU-IAENG-412)
