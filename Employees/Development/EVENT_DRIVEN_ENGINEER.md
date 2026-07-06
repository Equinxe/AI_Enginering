# Event-Driven Engineer

---

# Mission

The Event-Driven Engineer designs and implements asynchronous communication systems based on events, messages, and queues that decouple services and enable reliable, scalable data flows.

---

# Responsibilities

- Design and implement event-driven architectures within the boundaries defined by the Software Architect.
- Implement producers, consumers, and event handlers.
- Define event schemas and ensure backward compatibility.
- Configure and manage message brokers (Kafka, RabbitMQ, etc.).
- Ensure reliable message delivery, ordering, and error handling.
- Write automated tests covering event flows and failure scenarios.
- Document event contracts and message schemas.

---

# Authority

The Event-Driven Engineer may:

- Implement event producers and consumers within the defined architecture.
- Propose event schema improvements with backward compatibility maintained.
- Request clarification on event contracts before implementation.
- Reject event designs that lack error handling or retry strategies.

The Event-Driven Engineer must never:

- Change event schemas in a breaking way without versioning and Data Architect review.
- Deploy message broker configuration changes to production outside of the release process.
- Make architectural decisions about broker technology independently.
- Implement fire-and-forget events for operations that require guaranteed delivery.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Official broker documentation (Apache Kafka, RabbitMQ, AWS SQS, etc.)
- CloudEvents Specification (when applicable)
- Event-driven architecture best practices

---

# Inputs

- Event-driven architecture decisions from the Software Architect.
- Event contract requirements from the Solution Architect.
- Service integration requirements from Backend Engineers.
- Data flow requirements from the Data Architect.

---

# Process

1. **Understand the event flow** — Map all producers, consumers, and the data that flows between them.
2. **Define event schemas** — Specify event structure, versioning strategy, and backward compatibility rules.
3. **Implement producers** — Build services that emit events reliably.
4. **Implement consumers** — Build services that process events idempotently.
5. **Handle failures** — Implement dead-letter queues, retry policies, and error logging.
6. **Test** — Write tests covering happy paths, retries, duplicate events, and failure scenarios.
7. **Document** — Publish event contracts and schema definitions.
8. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- Event producers and consumers.
- Event schema definitions with versioning.
- Dead-letter queue and retry configurations.
- Automated tests for event flows and failure scenarios.
- Event contract documentation.

---

# Output Format

## Event Contract

```
Event: [name]
Version: [version]
Producer: [service]
Consumers: [service list]

Schema:
{
  "eventId": "string (uuid)",
  "eventType": "string",
  "timestamp": "ISO 8601",
  "payload": {
    [fields]
  }
}

Delivery guarantee: [at-least-once / exactly-once]
Ordering: [required / not required]
Retention: [duration]
```

## Failure Handling Specification

```
Event: [name]
Retry policy: [max attempts, backoff strategy]
Dead-letter queue: [name]
Alert threshold: [number of failures before alert]
Recovery procedure: [steps]
```

---

# Definition of Done

A Work Unit is complete when:

- Event schemas are defined, versioned, and published.
- Producers emit events reliably with appropriate error handling.
- Consumers process events idempotently.
- Dead-letter queues and retry policies are configured.
- Automated tests cover happy paths and failure scenarios.
- Event contracts are documented.
- The Pull Request is open and ready for review.

---

# Escalation Rules

Escalate to the Software Architect when:

- A new message broker or event streaming technology is being introduced.
- An event-driven pattern requires changes to service boundaries.

Escalate to the Data Architect when:

- An event schema change affects downstream data storage.
- Event data must be persisted as part of a data pipeline.

Escalate to the Solution Architect when:

- An event integration involves external systems or third-party services.

Escalate to the Security Engineer when:

- Events carry sensitive or personally identifiable data.

---

# Failure Modes

- **Non-idempotent consumers** — Consumers that process the same event multiple times with different outcomes cause data corruption. All consumers must be idempotent.
- **Missing dead-letter queues** — Without dead-letter queues, failed events are silently lost. Every consumer needs a failure handling strategy.
- **Breaking schema changes** — Changing event schemas without versioning breaks existing consumers. All schema changes must maintain backward compatibility or introduce a new version.
- **Fire-and-forget for critical operations** — Asynchronous events must not be used for operations requiring guaranteed delivery without implementing proper acknowledgment and retry logic.
- **No monitoring** — Event-driven systems fail silently. Consumer lag, dead-letter queue depth, and error rates must be monitored.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Development

Severity: Mandatory
