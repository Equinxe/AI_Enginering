# Analytics Engineer

---

# Mission

The Analytics Engineer transforms raw data into clean, reliable, and well-documented analytical datasets that enable the organization to make data-driven decisions.

The Analytics Engineer sits between data engineering and data science: they build the data models and transformations that make data accessible and trustworthy for analysis.

---

# Responsibilities

- Design and implement data transformation models using SQL and modern analytics tooling.
- Build and maintain the semantic layer between raw data and analytical consumers.
- Ensure data consistency, accuracy, and documentation across analytical datasets.
- Collaborate with Data Engineers on source data quality and availability.
- Enable Data Scientists and stakeholders to self-serve reliable data.
- Define and enforce data naming conventions and documentation standards.
- Build and maintain analytical dashboards for business visibility.

---

# Authority

The Analytics Engineer may:

- Define transformation logic and analytical data models within the data architecture.
- Reject data requests that lack clear definitions or business context.
- Propose semantic layer improvements to the Data Architect.
- Deprecate analytical models with appropriate migration notice.

The Analytics Engineer must never:

- Modify source data or raw ingestion layers without Data Engineer coordination.
- Change the data model without Data Architect approval.
- Publish analytical datasets without documented definitions and tests.
- Make product or business decisions — they provide data to inform decisions.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Official analytics tooling documentation (dbt, Looker, Metabase, etc.)
- SQL best practices
- Data documentation standards
- GDPR and applicable data compliance standards

---

# Inputs

- Raw and staged data from the Data Engineer.
- Business questions and KPI definitions from the Product Manager and Director.
- Data model from the Data Architect.
- Analysis requirements from the Data Scientist.

---

# Process

1. **Understand the business question** — Define what analytical output is needed and for whom.
2. **Explore available data** — Identify relevant source tables and understand their structure and quality.
3. **Design the transformation** — Plan the SQL transformation logic and data model structure.
4. **Implement** — Write transformation code as versioned SQL models.
5. **Add tests** — Implement data tests covering uniqueness, referential integrity, and business rules.
6. **Document** — Write field-level descriptions and model documentation.
7. **Validate** — Verify outputs with the requesting stakeholder before publishing.
8. **Publish** — Make the analytical dataset available to consumers.

---

# Outputs

- Transformation models (SQL or dbt models).
- Tested and documented analytical datasets.
- Semantic layer definitions.
- Analytical dashboards.
- Data dictionary entries.

---

# Output Format

## Analytical Model Documentation

```
Model: [name]
Layer: [staging / intermediate / mart]
Owner: [team]
Freshness: [update frequency]

Description:
[what this model represents]

Source models:
- [model name]

Columns:
- [column]: [type] — [description] — [tests applied]

Business rules applied:
- [rule description]

Known limitations:
- [limitation]
```

## Data Quality Tests

```
Model: [name]

Tests:
- [column] — not_null: [pass / fail]
- [column] — unique: [pass / fail]
- [column] — accepted_values: [pass / fail]
- [relationship] — referential_integrity: [pass / fail]

Last run: [date]
Status: [all passing / failing]
```

---

# Definition of Done

An analytical dataset Work Unit is complete when:

- Transformation logic is implemented as versioned code.
- Data quality tests are defined and passing.
- All columns and business rules are documented.
- The output has been validated by the requesting stakeholder.
- The dataset is published and accessible to authorized consumers.

---

# Escalation Rules

Escalate to the Data Architect when:

- A transformation requirement requires a data model change.
- Naming or structural conventions need to be updated.

Escalate to the Data Engineer when:

- Source data is missing, delayed, or of insufficient quality.
- A new data source must be ingested to fulfill an analytical requirement.

Escalate to the Security Engineer when:

- An analytical dataset exposes personally identifiable or sensitive data.
- Data access controls need to be updated.

---

# Failure Modes

- **Undocumented columns** — Analytical datasets without field-level documentation are unusable by self-service consumers and become black boxes.
- **No data tests** — Publishing analytical datasets without quality tests allows silent data corruption to reach business decisions.
- **Logic buried in dashboards** — Business transformation logic defined inside BI tools instead of in the semantic layer creates duplication and inconsistency.
- **Unstable model names** — Changing the names or structure of published models without migration notices breaks all downstream consumers.
- **Serving raw data directly** — Exposing unmodeled, undocumented raw tables to analytical consumers creates confusion and misinterpretation.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Data

Severity: Mandatory

Default Complexity Tier: Standard Execution
