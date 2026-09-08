# AI assistance for the recursive hierarchy

The AI extension combines deterministic recursive-graph validation with
optional model assistance.

## Deterministic behavior

`ZCL_PRODUCT_HIERARCHY_AI->VALIDATE_STRUCTURE` checks:

- Product and hierarchy data are present
- Node IDs are populated and unique
- Hierarchy type and value are populated
- Parent references exist
- A node does not reference itself
- Traversing parent references does not create a recursive cycle

These checks do not require an AI service and remain authoritative.

## AI behavior

- `REVIEW_WITH_AI` runs deterministic validation first and then requests
  advisory feedback about labels, types, and parent-child relationships.
- `GENERATE_HIERARCHY` requests a JSON hierarchy suggestion with a bounded
  depth. It does not write to RAP tables or activate a draft.

Generated data must be parsed, validated again, displayed to a user, and
explicitly accepted before persistence.

## Outbound configuration

Create an authenticated HTTP destination named `ZPRODUCT_HIER_AI`. Point it to
an approved gateway implementing the OpenAI-compatible chat-completions
contract. Configure authentication in the destination or gateway; never place
keys in ABAP or Git.

The code calls `/chat/completions`. The gateway can map that resource to the
approved model provider and deployment.

## Inbound HTTP interface

Create an authenticated SICF service such as:

```text
/sap/bc/zproduct_hierarchy_ai
```

Assign `ZCL_PRODUCT_HIERARCHY_AI_HTTP` as the handler. Do not allow anonymous
access. Restrict access through the relevant SAP ICF service authorizations and
roles.

The handler accepts POST requests only, limits payloads to 32 KB, returns
`Cache-Control: no-store`, and does not accept destinations, hosts, or
credentials from callers.

### Deterministic validation

```json
{
  "operation": "VALIDATE_HIERARCHY",
  "hierarchy": {
    "productId": "DEMO_GALA_APPLE_1KG",
    "productName": "Gala Apple 1kg",
    "productType": "FRUIT",
    "nodes": [
      {
        "nodeId": "N1",
        "parentNodeId": "",
        "hierarchyType": "L1",
        "hierarchyValue": "Food"
      },
      {
        "nodeId": "N2",
        "parentNodeId": "N1",
        "hierarchyType": "L2",
        "hierarchyValue": "Fresh Produce"
      },
      {
        "nodeId": "N3",
        "parentNodeId": "N2",
        "hierarchyType": "L3",
        "hierarchyValue": "Gala Apple"
      }
    ]
  }
}
```

Use `REVIEW_HIERARCHY` with the same payload to request AI feedback.

### Generate a hierarchy suggestion

```json
{
  "operation": "GENERATE_HIERARCHY",
  "productId": "DEMO_GALA_APPLE_1KG",
  "productName": "Gala Apple 1kg",
  "productType": "FRUIT",
  "maxDepth": 3
}
```

Invalid input or graph structure returns HTTP `422`. Transport, gateway, or
provider-response failures return HTTP `502`.
