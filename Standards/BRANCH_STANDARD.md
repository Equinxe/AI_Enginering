# Branch Standard

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory

---

# Purpose

This standard defines how Git branches must be created, named, and managed within IA Engineering.

Branches isolate engineering work, improve collaboration, and protect the stability of the project.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Principles

## Stable Main Branch

The `main` branch always represents the latest stable version of the project.

Direct development on `main` is prohibited.

---

## Development Branch

The `develop` branch is the integration branch.

Completed work is merged into `develop` before being released to `main`.

---

## Milestone Branches

Engineering work must be performed inside milestone branches.

Each milestone has its own dedicated branch.

Example:

```
milestone/v0.0.2-engineering-standards
```

A milestone branch groups multiple related Work Units into one engineering objective.

---

## Branch Isolation

A branch must have a single engineering objective.

Avoid mixing unrelated work inside the same branch.

---

## Branch Lifetime

Branches are temporary.

Once merged, they should be deleted unless there is a valid engineering reason to keep them.

---

# Branch Naming

IA Engineering defines the following branch naming convention.

## Production

```
main
```

---

## Integration

```
develop
```

---

## Milestones

```
milestone/<version>-<name>
```

Examples:

```
milestone/v0.0.2-engineering-standards

milestone/v0.0.3-employees

milestone/v0.1.0-mvp
```

---

## Hotfixes

```
hotfix/<description>
```

Example:

```
hotfix/login-crash
```

---

## Experiments

Experimental work should never impact production development.

```
experiment/<description>
```

Example:

```
experiment/context-loader
```

---

# Branch Workflow

Default workflow:

```
main
│
└── develop
      │
      └── milestone/*
```

Engineering changes follow this lifecycle:

```
Milestone Branch
        │
        ▼
Pull Request
        │
        ▼
develop
        │
        ▼
Release Review
        │
        ▼
main
```

---

# Responsibilities

Each branch should represent one engineering objective.

Commits represent Work Units.

Branches represent Milestones.

---

# Forbidden Practices

Do not:

- develop directly on `main`;
- mix multiple milestones in one branch;
- keep obsolete branches indefinitely;
- create branches without a defined engineering objective;
- use inconsistent branch names.

---

# Rationale

Using a consistent branching strategy provides:

- Better collaboration
- Safer releases
- Easier milestone tracking
- Cleaner Git history
- Better support for AI Employees

---

# References

- Git Standard
- Commit Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
