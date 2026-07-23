# IA Engineering Glossary

This glossary defines the official vocabulary used throughout IA Engineering.

Every artifact, employee, workflow, and standard must use these definitions consistently.

---

# A

## Adapter

A concrete, installable integration for a specific version-control host and CI platform (currently: GitHub) that turns a subset of IA Engineering's rules from written policy into technical enforcement — for example, git hooks that validate commit format, a CI check that validates pull requests, or branch-protection setup.

An Adapter is AI-agnostic — it checks work by any Employee, running under any AI runtime — but it is not tool-agnostic: a GitHub Adapter assumes GitHub, and another version-control host or CI platform (e.g. GitLab, Azure DevOps) needs its own equivalent Adapter. See `Adapters/README.md`.

---

## Artifact

Any document, standard, workflow, template, employee, or resource that is part of IA Engineering.

---

# E

## Employee

A specialized AI role with a defined mission, responsibilities, authority, inputs, outputs, and stop conditions.

An Employee represents a profession, not a technology.

---

## Engineering Standard

A mandatory rule that defines how software must be developed within IA Engineering.

---

# F

## Framework

The complete collection of principles, standards, workflows, employees, and adapters that compose IA Engineering.

---

# C

## Chain (Agent Chain)

A named, pre-defined sequence of Employees activated by the Main Agent for a specific type of engineering task (e.g., Feature Chain, Release Chain).

Chains encode institutional knowledge about who does what, in what order, for recurring scenarios. See `Core/AGENT_CHAINS.md`.

---

# D

## Director

The human accountable for a project using IA Engineering.

The Director makes all final decisions and approves every release, merge, and architectural or business decision. See `Core/MAIN_AGENT_CONDUCT.md` and `CLAUDE.md`.

---

# H

## Human

The final decision maker.

Humans always retain authority over architectural, business, and product decisions.

---

# I

## Implementation

The concrete code, documentation, configuration, or deliverable produced during a work unit.

---

# P

## Project

A software project using IA Engineering.

Projects extend the framework but never modify it.

---

# R

## Responsibility

The scope of work assigned to an Employee.

Responsibilities define what an Employee owns.

---

# S

## Standard

A mandatory engineering rule.

Standards ensure consistency across all projects.

---

## Stop Condition

A condition requiring an Employee to stop working and return control to the requester.

---

# T

## Task

A specific objective assigned to an Employee.

A task belongs to a single work unit.

---

## Template

A reusable document used to standardize outputs.

---

# W

## Work Unit

The smallest independently reviewable engineering task.

A Work Unit should produce one coherent result suitable for review and commit.

---

## Workflow

A sequence of coordinated work units executed to achieve an engineering objective.

---

# Document Metadata

Version: 0.0.1

Status: Stable

Owner: IA Engineering

Depends On:

- AI_MANIFEST.md

Referenced By:

- All Artifacts
