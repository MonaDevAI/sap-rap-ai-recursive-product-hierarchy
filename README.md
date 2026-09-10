# SAP RAP AI Recursive Product Hierarchy

Proof-of-concept SAP ABAP RAP application combining a draft-enabled recursive
product hierarchy with optional AI-assisted validation and hierarchy
generation.

This repository demonstrates how SAP RAP can be extended with AI-assisted
hierarchy recommendations, recursive business object modeling, draft
processing, and external service integration to explore real-world master data
governance scenarios.

## Architecture

```mermaid
graph TD
    UI["SAP Fiori Elements"] --> BO["SAP RAP Business Object"]
    BO --> HE["Recursive Hierarchy Engine"]
    BO --> AV["AI-Assisted Validation"]
    HE --> DT["Active and Draft Tables"]
    AV --> HTTP["Authenticated HTTP Integration"]
    HTTP --> AI["External AI Service"]
    DT --> PH["Product Hierarchy"]
    AI --> PH
```

The RAP business object remains responsible for transactional consistency,
draft processing, actions, and deterministic validation. AI review is optional
and advisory; it runs only after deterministic hierarchy checks succeed.

## Demo flow

```mermaid
graph LR
    A["Create Product"] --> B["Add Hierarchy Nodes"]
    B --> C["Request AI Review"]
    C --> D["Review Suggested Parent"]
    D --> E["Save Draft"]
    E --> F["Activate"]
    F --> G["Hierarchy Updated"]
```

## Core RAP model

- `ZI_Product_I` is the product root entity.
- `ZI_ProductHierarchy_I` is a recursive child entity.
- `_Parent` is a self-association to the parent hierarchy node.
- `_Children` is a self-association to descendant nodes.
- Active and draft persistence are provided for products and hierarchy nodes.
- `ZUI_PRODUCT_V4` exposes the Fiori elements application through OData V4.
- `ZR_PRODUCT_RECURSIVE_DEMO` creates demonstration products and three-level
  hierarchies.

### How the CDS hierarchy is recursive

```mermaid
graph TD
    PB["ZI_Product_B"] -->|"select from"| PI["ZI_Product_I"]
    HB["ZI_ProductHierarchy_B"] -->|"select from"| HI["ZI_ProductHierarchy_I"]
    PI -->|"_Hierarchy composition"| HI
    HI -->|"_Product association"| PI
    HI --> PARENT["_Parent association to the same CDS entity"]
    PARENT --> HI
    HI --> CHILDREN["_Children association to the same CDS entity"]
    CHILDREN --> HI
    PI -->|"projection"| PC["ZC_Product"]
    HI -->|"projection"| HC["ZC_ProductHierarchy"]
    PC -->|"redirected _Hierarchy"| HC
    HC -->|"redirected recursive associations"| NAV["OData V4 navigation"]
    NAV --> FE["Fiori Elements"]
```

Each `ZI_ProductHierarchy_I` row represents one hierarchy node. Its
`ParentHierID` resolves `_Parent` to another row of the same CDS entity, while
`_Children` performs the inverse match and can return multiple rows. Repeating
those self-association navigations produces an arbitrary-depth tree:

```mermaid
graph TD
    R["Root node"] --> C1["Child node 1"]
    R --> C2["Child node 2"]
    C1 --> G1["Grandchild node"]
    G1 --> D1["Deeper node"]
```

The CDS model defines the recursive relationships; it does not use a recursive
SQL CTE or load the entire tree in one request. RAP exposes the same entity type
at every level, and callers expand or traverse `_Children` and `_Parent` as
needed. Bounded hierarchy search reconstructs ancestor paths in ABAP from these
relationships.

## AI extension

`ZCL_PRODUCT_HIERARCHY_AI` adds:

- Deterministic checks for required fields, duplicate node IDs, missing parent
  references, self-parenting, and recursive cycles
- Structured advisory model review after deterministic validation succeeds
- Grounded concern details including affected node, current parent, optional
  suggested parent, reason, confidence band, and required human review
- ABAP-controlled hierarchy search across all levels or a requested level
- Optional AI ranking restricted to hierarchy candidates retrieved by ABAP
- Generated hierarchy suggestions returned as JSON for user review

`ZCL_PRODUCT_HIERARCHY_AI_HTTP` provides an authenticated JSON API using
generic SAP HTTP classes. Credentials and hosts remain in the
administrator-controlled `ZPRODUCT_HIER_AI_URL` setting or
`ZPRODUCT_HIER_AI` HTTP destination and are never accepted from callers.
Controlled ABAP callers can alternatively provide an HTTPS URL template,
deployment, model, and runtime-only API key directly to the AI class.

The Fiori elements product list and object page expose **Validate Hierarchy**
and **Review with AI** instance-action buttons. AI concerns appear as warnings;
responses that report no semantic concern remain informational.

See [docs/AI_HIERARCHY.md](docs/AI_HIERARCHY.md) for configuration and request
examples.

The HTTP interface also supports `SEARCH_HIERARCHY`. ABAP retrieves a bounded
candidate set from the CDS hierarchy, reconstructs complete paths, and applies
optional level, product-type, and hierarchy-type filters. When AI ranking is
requested, the model may select only a product/node pair from that retrieved
set; ABAP rejects invented selections.

## Enterprise patterns demonstrated

- Recursive RAP modeling with parent and child self-associations
- Draft-enabled transactional processing
- Managed RAP business objects
- Deterministic hierarchy validations
- Instance actions for hierarchy validation and AI review
- ETags and draft-conflict protection
- Fiori elements annotations and action exposure
- Authenticated HTTP integration
- Runtime-controlled external service configuration
- AI-assisted recommendations with deterministic guardrails
- OData V4 service exposure
- abapGit-compatible source and metadata

This is a learning and demonstration project. Validate APIs, released ABAP
language features, service exposure, security controls, and deployment
requirements against the target SAP environment before treating any pattern as
production- or cloud-ready.

## Import

1. Import the repository through abapGit into an appropriate test package.
2. Activate all objects and resolve target-system dependencies.
3. Publish service binding `ZUI_PRODUCT_V4`.
4. Run `ZR_PRODUCT_RECURSIVE_DEMO` to create sample data.
5. Configure the AI destination and authenticated SICF handler only when the
   optional AI extension is required.

The demo report defaults to a non-reset run. Its reset option refuses to
replace active `DEMO_%` data while a corresponding RAP draft exists, preventing
stale-draft ETag conflicts.

Review authorization, service exposure, generated suggestions, and target SAP
release compatibility before production use.
