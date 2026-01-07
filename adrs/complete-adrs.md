# Architecture Decision Records (ADRs)

This document contains binding ADRs for the Hostingmaster **Provider Plugin Architecture**.

---

## ADR-0001: Provider Plugin Architecture (Capability-Based)

**Status:** Accepted (binding)

### Context

Hostingmaster integrates external providers for domains and SSL certificates. Providers differ significantly:

* APIs are not uniformly REST-based (SOAP, XML-RPC, SDKs, CSV exports, SFTP, portals).
* Functional capabilities vary (pricing APIs, product catalogs, async vs. sync flows).
* Availability and stability of provider systems cannot be guaranteed.

The core platform must remain stable, extensible, and provider-agnostic.

### Decision

* Provider integrations are implemented exclusively via **provider plugins**.
* Plugins are **capability-based**, not feature-complete by definition.
* Capabilities are explicitly declared (Domains, SSL, Pricing).
* Missing capabilities are **valid and expected**.
* The core system never communicates directly with external providers.

### Consequences

**Positive:**

* Clean isolation of provider-specific complexity
* Providers can be onboarded incrementally
* No protocol assumptions leak into the core

**Negative:**

* Requires explicit capability handling in workflows and UI

---
---


## ADR-0002: Plugin Runtime Contract Binding (gRPC)

**Status:** Accepted (binding)

### Context

The core platform requires a stable, versioned, and strongly typed contract to interact with provider plugins.

Loose or informal integration contracts lead to:

* Schema drift
* Undefined error semantics
* Fragile integrations

### Decision

* Communication between Hostingmaster Core and the Plugin Runtime uses **gRPC**.
* The contract is defined via versioned protobuf definitions.
* Mutating operations are **idempotent**.
* Errors are standardized (error code, retryable flag, provider code).

### Consequences

**Positive:**

* Strong contracts and backward compatibility
* Deterministic error handling
* Clear separation of responsibilities

**Negative:**

* Requires gRPC infrastructure and tooling

------


## ADR-0003: Asynchronous Provisioning Model

**Status:** Accepted (binding)

### Context

Domain and SSL provisioning are inherently asynchronous:

* External validation steps
* Manual approvals
* Provider-side delays

Synchronous assumptions lead to brittle workflows.

### Decision

* All provisioning operations are asynchronous.
* Plugins return an **OperationRef** for every mutating action.
* The core tracks operation state via polling.
* Lifecycle state machines are explicit and persisted.

### Consequences

**Positive:**

* Uniform handling of long-running operations
* Provider delays do not block API requests

**Negative:**

* Requires operation tracking and retry logic

------


## ADR-0004: Pricing Import and Deterministic Price Resolution

**Status:** Accepted (binding)

### Context

Providers expose pricing inconsistently:

* Some via APIs
* Some via CSV or manual exports
* Some not at all

Resellers require full pricing sovereignty, including overrides and inheritance.

### Decision

* Plugins may import **raw provider prices** from any source.
* Plugins never calculate reseller or customer prices.
* The core applies deterministic pricing logic:

  1. Included benefits (hosting plans)
  2. Explicit price overrides
  3. Derived rules (markup / markdown)
  4. Inheritance
  5. Provider base price fallback

### Consequences

**Positive:**

* Deterministic and auditable pricing
* Full reseller control
* Provider limitations do not block pricing

**Negative:**

* Requires internal pricing engine complexity

------


## ADR-0005: Capability Discovery and Feature Gating

**Status:** Accepted (binding)

### Context

Not all providers support the same feature set. Assuming feature parity leads to broken UX and hidden failures.

### Decision

* Plugin capabilities are the **single source of truth** for feature availability.
* UI and workflows are gated based on declared capabilities.
* Unsupported actions must fail explicitly with `NOT_SUPPORTED`.

### Consequences

**Positive:**

* Predictable behavior across providers
* Clear UX expectations

**Negative:**

* Additional conditional logic in UI and workflows

---

**Note:** These ADRs are binding for the Hostingmaster MVP and future extensions unless explicitly superseded.
---


# ADR-0006: Plugin Isolation & Runtime Topology

**Status:** Accepted (binding)

## Context

Provider SDKs and APIs are unstable, heterogeneous, and outside of Hostingmaster control. Running provider integrations in-process risks memory leaks, crashes, and unpredictable behavior propagating into the core system.

At the same time, a strongly typed and versioned integration contract is required.

## Decision

- Provider plugins are executed in a **process-isolated Plugin Runtime**.
- The isolation unit is a **separate container or service** (sidecar or standalone Deployment).
- The Hostingmaster Core communicates with the Plugin Runtime exclusively via **gRPC**.
- In-process execution of provider plugins is forbidden.

## Consequences

**Positive:**
- Fault isolation from provider SDK failures
- Clear ownership boundary
- Justifies use of gRPC as IPC mechanism

**Negative:**
- Additional operational complexity
- Requires runtime orchestration and health monitoring

---


# ADR-0007: Operation Model & State Machine

**Status:** Accepted (binding)

## Context

Domain and SSL provisioning are long-running, asynchronous processes involving external validation, manual approvals, and provider-side delays. A minimal success/failure model is insufficient.

## Decision

All provisioning actions are modeled as **Operations** with an explicit, persisted state machine.

### Binding Generic States

- pending
- submitted
- running
- awaiting_validation
- awaiting_approval
- succeeded
- failed_temporary
- failed_permanent
- cancellation_requested
- canceled
- stuck
- needs_reconciliation

Plugins may map provider-specific states into these generic states.

## Consequences

**Positive:**
- Uniform handling of async workflows
- Explicit recovery and reconciliation paths

**Negative:**
- Increased state management complexity

---


# ADR-0008: Polling, Rate Limiting & Retry Semantics

**Status:** Accepted (binding)

## Context

Naive polling strategies can easily violate provider rate limits and destabilize the system. Retry behavior must be deterministic and provider-safe.

## Decision

- Operation polling is managed by a **scheduler**, not per-request loops.
- Polling uses **exponential backoff with jitter**.
- Provider-specific concurrency and rate caps are enforced.

### Binding Defaults (MVP)

- Initial poll: 5 seconds after submission
- Backoff: 5s → 10s → 20s → 40s → 60s → max 5min
- Jitter: ±20%
- Max concurrent polls: 5 per ProviderAccount, 50 per Plugin
- Operation timeout: 24h → state `stuck`

## Consequences

**Positive:**
- Provider-safe operation handling
- Predictable system load

**Negative:**
- Requires centralized scheduling logic

---


# ADR-0009: Pricing Snapshot & Versioning

**Status:** Accepted (binding)

## Context

Pricing inputs (provider base prices, reseller price lists, hosting plan benefits) may change during order processing. Without snapshots, pricing becomes non-deterministic.

## Decision

- Pricing is resolved into a **PriceSnapshot** at order submission time.
- The snapshot includes:
  - priceListVersion
  - benefitsVersion
  - resolvedAt timestamp
- Provisioning always uses the stored snapshot, not live prices.

## Consequences

**Positive:**
- Deterministic and auditable pricing
- Protection from mid-order price changes

**Negative:**
- Requires snapshot persistence

---


# ADR-0010: ProviderAccount Credential Versioning & Rotation

**Status:** Accepted (binding)

## Context

Provider credentials may be rotated or revoked while operations are in-flight. Without versioning, behavior is undefined.

## Decision

- ProviderAccount references a `credentialsRef` and a monotonically increasing `credentialsVersion`.
- Each Operation stores the `credentialsVersionUsed`.
- Credential rotation affects only new operations.
- Revocation blocks new operations; in-flight operations transition based on provider response.

## Consequences

**Positive:**
- Deterministic credential behavior
- Safe credential rotation

**Negative:**
- Slightly increased metadata complexity

---


# ADR-0011: Plugin Versioning, Rollout & Yank Policy

**Status:** Accepted (binding)

## Context

Plugins evolve over time. In-flight operations must not break during plugin upgrades.

## Decision

- For a given `pluginId`, only one version is **active** at a time.
- A previous version may remain in **draining** state for in-flight operations.
- Each Operation stores the `pluginVersion` used.
- Yanked versions are disabled for new operations but remain available for completion or reconciliation.

## Consequences

**Positive:**
- Safe plugin upgrades
- Predictable rollback behavior

**Negative:**
- Requires runtime support for version pinning

---


# ADR-0012: Multi-Tenancy Enforcement Mechanism

**Status:** Accepted (binding)

## Context

Multi-tenancy must be enforced technically. Convention-based filtering is insufficient and error-prone.

## Decision

- All data access requires an explicit **TenantContext** (resellerId + scope).
- Persistence access is centralized; no raw database access is permitted.
- Tenant filtering is enforced at repository/query layer.
- CI checks and tests ensure no unscoped queries exist.

## Consequences

**Positive:**
- Strong tenant isolation guarantees
- Reduced risk of data leakage

**Negative:**
- Requires disciplined persistence abstraction

---


# ADR-0013: Reconciliation & Compensating Transactions

**Status:** Accepted (binding)

## Context

Distributed provisioning can result in inconsistent states (e.g. provider success but local persistence failure).

## Decision

- Inconsistent states transition to `needs_reconciliation`.
- A reconciliation process attempts to:
  - align local state with provider state, or
  - execute compensating actions (delete/cancel) if supported.
- All compensating actions are modeled as new Operations.
- Idempotency keys are mandatory to prevent duplicate provisioning.

## Consequences

**Positive:**
- Controlled recovery from partial failures
- Explicit handling of distributed consistency issues

**Negative:**
- Additional reconciliation logic required

---


