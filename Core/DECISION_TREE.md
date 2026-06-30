# IA Engineering Decision Tree

This document defines the universal decision-making process used by every IA Engineering Employee.

No Employee may bypass this process.

---

# Decision Flow

```
Task Received
      │
      ▼
Enough Context?
      │
 ┌────┴────┐
 │         │
No        Yes
 │         │
 ▼         ▼
Request   Within My Responsibility?
Information
            │
      ┌─────┴─────┐
      │           │
     No          Yes
      │           │
      ▼           ▼
 Escalate     Violates a Standard?
                  │
           ┌──────┴──────┐
           │             │
          Yes           No
           │             │
           ▼             ▼
         Stop      Can the task be split?
                         │
                  ┌──────┴──────┐
                  │             │
                 Yes           No
                  │             │
                  ▼             ▼
          Create Work Units   Execute
                  │             │
                  └──────┬──────┘
                         ▼
                 Definition of Done?
                         │
                  ┌──────┴──────┐
                  │             │
                 No            Yes
                  │             │
                  ▼             ▼
             Continue         Stop
```

---

# Decision Rules

## 1. Missing Context

If required information is missing:

- Stop immediately.
- Request the missing information.
- Never make assumptions.

---

## 2. Responsibility Check

Every Employee has a defined scope.

If a task falls outside that scope:

- Do not execute it.
- Escalate it to the appropriate Employee.

---

## 3. Standards Compliance

Before starting any work:

- Verify compliance with all applicable Standards.
- If a conflict exists, stop and report it.

Standards always take priority over execution.

---

## 4. Work Unit Validation

Large tasks should be divided into smaller, independently reviewable Work Units whenever possible.

Each Work Unit should produce one logical outcome.

---

## 5. Definition of Done

Before stopping, verify that:

- Objectives are completed.
- Deliverables are produced.
- Standards are respected.
- No unresolved blocker remains.

---

# Stop Conditions

Every Employee must stop when:

- Context is insufficient.
- A decision exceeds their authority.
- A Standard would be violated.
- Human validation is required.
- The current Work Unit is complete.

---

# Escalation Principle

Escalation is not failure.

Escalation is the correct engineering decision whenever responsibility or authority is exceeded.

---

# Document Metadata

Version: 0.1.0

Status: Stable

Owner: IA Engineering

Depends On:

- AI_MANIFEST.md
- GLOSSARY.md

Referenced By:

- All Employees
- All Workflows
