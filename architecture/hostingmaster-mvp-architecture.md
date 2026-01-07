# Hostingmaster – MVP Architecture & Model Summary

This document summarizes the **binding architectural, role, and data‑model decisions** for the Hostingmaster MVP. The goal is a **scalable, multi‑tenant, and strongly white‑label capable platform** that can evolve without structural refactoring.

---

## 1. Hostingmaster Target Vision

Hostingmaster is a platform for centralized management of hosting‑related services, including:

* Domains
* SSL certificates
* later: Web hosting, Mail hosting, Virtual Datacenters (Kubernetes, OpenStack, VMs)

Core assumptions:

* Operated **on Kubernetes**
* Persisted in **MongoDB**
* Provider‑agnostic via **plugins / connectors**
* Strongly **white‑label capable**
* **Hierarchical multi‑tenancy**

The physical substrate (bare metal, OpenStack, public cloud) is **out of scope for the MVP**.

---

## 2. Tenancy & Role Model

### 2.1 Hierarchical Tenant Model

Tenants form an **arbitrarily deep tree**:

```
Platform (System)
└── Reseller (Root Reseller)
    ├── Sub‑Reseller A
    │   ├── Sub‑Reseller A1
    │   │   └── Customers
    │   └── Customers
    └── Customers
```

Binding decisions:

* There is **no separate “SubReseller” entity**
* Every Sub‑Reseller is technically a **Reseller with a parent**
* Tenant depth is **unlimited at the backend level**

---

### 2.2 Roles

| Role          | Responsibility                                                  |
| ------------- | --------------------------------------------------------------- |
| PlatformAdmin | Platform operation, bootstrap, provider plugin installation     |
| ResellerAdmin | Management of a reseller tenant incl. sub‑resellers & customers |
| CustomerAdmin | Management of own domains & SSL certificates                    |

The PlatformAdmin **does not sell products**. Commercial activity starts at reseller level.

---

## 3. Bootstrap / First Reseller

Since there is no natural “first reseller”, a **one‑time bootstrap process** is required.

* On first startup, **exactly one root reseller** is created
* Possible implementations:

  * Kubernetes Job / Helm hook
  * CLI (`hostingmasterctl bootstrap`)
  * One‑time bootstrap API
* After successful bootstrap, this path is **permanently locked**

Bootstrap is a **technical provisioning step**, not a business process.

---

## 4. Reseller Data Model

### Reseller (Minimal Model)

```
Reseller
- resellerId
- parentResellerId (nullable)
- ancestors[]        // materialized path
- status             // active, suspended
```

`ancestors[]` enables:

* efficient subtree queries
* clean RBAC enforcement
* foundation for pricing and policy inheritance

---

## 5. Provider Integration

### 5.1 Separation of Concerns

| Dimension                             | Responsibility |
| ------------------------------------- | -------------- |
| ProviderPlugin (technical)            | PlatformAdmin  |
| ProviderAccount (credentials & usage) | Reseller       |

---

### 5.2 Entities

**ProviderPlugin (global):**

* pluginId (e.g. `internetx`, `enom`, `thesslstore`)
* capabilities (domains, ssl)
* version, health, limits

**ProviderAccount (per reseller):**

* providerAccountId
* resellerId
* pluginId
* credentialsRef (Secret / later Vault)
* mode: `OWN` | `INHERIT_PARENT`

---

### 5.3 Inheritance Rules

* Sub‑resellers may use their own credentials (`OWN`)
* or reference the parent reseller’s provider account (`INHERIT_PARENT`)
* **No credential copying**, only references
* Revocation at parent level automatically affects all descendants

---

## 6. Pricing & Price Logic

The platform supports **multiple pricing strategies**, combinable per reseller.

### 6.1 Price Resolution Priority

1. **Explicit price override** (fixed end price)
2. **Derived pricing rules** (markup / markdown)
3. **Inherited price list** from parent reseller
4. **Provider base price** (fallback)

This allows both full price control and simple markup‑based models.

---

### 6.2 Price List Model

**PriceList:**

* priceListId
* resellerId
* currency
* effectiveFrom
* rules[]

**Rule types (MVP):**

* OverrideRule (fixed price)
* MarkupRule (`+5%`, `+2 EUR`, etc.)
* InheritRule (inherit parent prices, optionally combined with markup)

Price resolution must be **deterministic and conflict‑free**.

---

## 7. Hosting Plans & Included Domains

Hosting plans may include **domains as bundled benefits**.

### HostingPlan (simplified)

* planId
* resellerId
* name
* billingPeriod
* includedBenefits[]

### IncludedDomainBenefit

* quantity (e.g. 1)
* period (e.g. 1 year)
* tldAllowList (e.g. .de, .com)
* renewalPolicy

**Logic:**

* Domain orders first check for applicable included benefits
* If matched: price = 0 (covered by plan)
* Otherwise: normal price resolution applies

---

## 8. Domains & SSL – Lifecycle

Domains and SSL certificates are **asynchronous resources**.

* Customer is always the owner
* Provisioning is handled via provider connectors
* Explicit lifecycle/state machines are mandatory

Example states:

* pending
* submitted
* awaiting_validation
* active
* failed
* canceled

---

## 9. Persistence & Isolation

* Persistence layer: MongoDB
* Every business entity contains at least `resellerId`
* Customer‑bound entities additionally contain `customerId`
* **All queries are tenant‑filtered at server side**

Recommended indexes:

* resellerId
* resellerId + customerId
* ancestors[]

---

## 10. MVP Boundaries

Explicitly excluded from MVP:

* Provider accounts per customer
* Domain transfers
* Complex promotions / coupons

Backend is modeled to be **future‑proof**; UI‑level restrictions are acceptable.

---

## 11. Binding Summary

* Resellers form an arbitrarily deep tree
* Sub‑resellers are normal resellers with a parent
* Provider credentials can be inherited downward
* Prices can be overridden or derived via rules
* Hosting plans may include domains
* Domains & SSL are asynchronous
* Bootstrap is handled cleanly and explicitly

➡️ With these decisions, the Hostingmaster MVP is **architecturally consistent, extensible, and stable**.
