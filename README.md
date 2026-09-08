# SAP RAP AI Recursive Product Hierarchy

Proof-of-concept SAP ABAP RAP application combining a draft-enabled recursive
product hierarchy with optional AI-assisted validation and hierarchy
generation.

## Core RAP model

- `ZI_Product_I` is the product root entity.
- `ZI_ProductHierarchy_I` is a recursive child entity.
- `_Parent` is a self-association to the parent hierarchy node.
- `_Children` is a self-association to descendant nodes.
- Active and draft persistence are provided for products and hierarchy nodes.
- `ZUI_PRODUCT_V4` exposes the Fiori elements application through OData V4.
- `ZR_PRODUCT_RECURSIVE_DEMO` creates demonstration products and three-level
  hierarchies.

## AI extension

`ZCL_PRODUCT_HIERARCHY_AI` adds:

- Deterministic checks for required fields, duplicate node IDs, missing parent
  references, self-parenting, and recursive cycles
- Advisory model review after deterministic validation succeeds
- Generated hierarchy suggestions returned as JSON for user review

`ZCL_PRODUCT_HIERARCHY_AI_HTTP` provides an authenticated JSON API using
generic SAP HTTP classes. Credentials and hosts remain in the
administrator-controlled `ZPRODUCT_HIER_AI_URL` setting or
`ZPRODUCT_HIER_AI` HTTP destination and are never accepted from callers.
Controlled ABAP callers can alternatively provide an HTTPS URL template,
deployment, model, and runtime-only API key directly to the AI class.

See [docs/AI_HIERARCHY.md](docs/AI_HIERARCHY.md) for configuration and request
examples.

## Import

1. Import the repository through abapGit into an appropriate test package.
2. Activate all objects and resolve target-system dependencies.
3. Publish service binding `ZUI_PRODUCT_V4`.
4. Run `ZR_PRODUCT_RECURSIVE_DEMO` to create sample data.
5. Configure the AI destination and authenticated SICF handler only when the
   optional AI extension is required.

Review authorization, service exposure, generated suggestions, and target SAP
release compatibility before production use.
