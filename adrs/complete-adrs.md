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


