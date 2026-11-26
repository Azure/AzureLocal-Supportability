# Azure Local {COMPONENT_NAME} supportability index

<!-- Instructions: Replace {COMPONENT_NAME} with the actual component name (e.g., "Networking", "Storage", "Security") -->

<!-- Optional: Add cross-reference to related components if applicable -->
<!-- For {RELATED_COMPONENT} resources, see [TSG/{RELATED_COMPONENT}/README.md](../{RELATED_COMPONENT}/README.md). If an article spans components, list it in the primary owner component and add pointer rows from related components instead of duplicating ownership. -->

## Directory inventory

<!-- Instructions: Organize content by major topic areas within the component. Each topic should have its own section with a complete inventory table. Do not add troubleshooting-only fields such as symptoms, failure surfaces, or fix verification steps to this index. Put those details in the linked article. -->

Use one row per support article. Every linked article must carry a valid HTML-comment metadata marker using schema `azure-local-supportability/tsg-metadata/v2`; this component index records that the marker exists and summarizes its routing fields, but does not embed article metadata itself. After copying this file to `TSG/{Component}/README.md`, use the schema at [`../Templates/tsg-metadata.schema.json`](../Templates/tsg-metadata.schema.json).

### Inventory legend

| Field | Required value |
| --- | --- |
| Article type | Record the article metadata `document_type`: `troubleshoot`, `reference`, `how-to`, `deep-dive`, or `overview`. To add another document type, extend `../Templates/tsg-metadata.schema.json` and add matching article-template guidance before using it in the index. |
| Title | Use the human-readable article title. |
| Link | Use a relative link to the article file. |
| Applicable products | Name the Azure Local product or feature family explicitly, for example `Azure Local 23H2 solution update`, `Arc VM management`, or `Storage Spaces Direct`. Do not use `all` unless the article truly applies to every Azure Local product path. |
| Supported versions | Name the supported release, build range, or `replace-me` until validated. |
| Owner | Name the accountable team, component owner, or alias. |
| Highest action classification | Use `[READ-ONLY]` when every action is non-mutating, `state-changing` when any action can change state, or `None, index-only` when the article has no actions. |
| Highest state-changing risk | Use the highest state-changing action risk label from the linked article: `[LOW RISK]`, `[MEDIUM RISK]`, or `[HIGH RISK]`. Use `Not applicable` for read-only-only or index-only articles. |
| Workload or maintenance impact | State whether the linked article can affect workloads, require a maintenance window, require elevated privileges, or is `None known`. |
| Metadata marker | Use `present` only after confirming the linked article contains the required metadata marker and validates against `../Templates/tsg-metadata.schema.json`. Otherwise use `missing` and fix the article before publishing. When `detector.type` is `none`, `detector.signal` must be JSON `null`; set both detector fields together when selecting another detector type. |
| Execution surface | Use `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, or `thin`. |

For linked articles that include state-changing actions, confirm the article uses the canonical risk labels `[LOW RISK]`, `[MEDIUM RISK]`, or `[HIGH RISK]` and includes pre-check, action, expected result or output, stop condition, rollback, and verification steps.

### Execution surface values

| Value | Meaning |
| --- | --- |
| `on-device` | Executable steps run on an Azure Local node. |
| `mixed` | Steps span on-device and cloud or control-plane surfaces. |
| `cloud-diagnostic` | Diagnostic evidence comes from cloud telemetry or service data. |
| `cloud-control` | Actions or checks run through Azure control-plane, portal, or ARM surfaces. |
| `thin` | No executable diagnostic or remediation surface is present. |

### {TOPIC_AREA_1}
<!-- Instructions: Replace {TOPIC_AREA_1} with a descriptive topic area name (e.g., "Arc Gateway & Outbound Connectivity") -->
| Article type | Title | Link | Applicable products | Supported versions | Owner | Highest action classification | Highest state-changing risk | Workload or maintenance impact | Metadata marker | Execution surface |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {DOC_TYPE} | {DOC_TITLE} | [{FILE_NAME}.md]({FOLDER_NAME}/{FILE_NAME}.md) | {APPLICABLE_PRODUCTS} | {SUPPORTED_VERSIONS} | {OWNER} | {[READ-ONLY], state-changing, or None, index-only} | {[LOW RISK], [MEDIUM RISK], [HIGH RISK], or Not applicable} | {WORKLOAD_OR_MAINTENANCE_IMPACT} | {present or missing} | {on-device, mixed, cloud-diagnostic, cloud-control, or thin} |
<!-- Instructions: 
     - Replace {DOC_TYPE} with the schema document_type token: troubleshoot, reference, how-to, deep-dive, or overview
     - Replace {DOC_TITLE} with descriptive title
     - Replace {FOLDER_NAME} with subfolder name
     - Replace {FILE_NAME} with actual filename following naming convention
     - Replace {APPLICABLE_PRODUCTS} with explicit Azure Local product or feature scope
     - Replace {SUPPORTED_VERSIONS} with the supported release or build range
     - Replace {OWNER} with the accountable team, component owner, or alias
     - Replace {[READ-ONLY], state-changing, or None, index-only} with the linked-article action classification
     - Replace {[LOW RISK], [MEDIUM RISK], [HIGH RISK], or Not applicable} with the highest linked-article state-changing risk
     - Replace {WORKLOAD_OR_MAINTENANCE_IMPACT} with workload, privilege, maintenance-window, or downtime impact
     - Replace {present or missing} after checking the article metadata marker
     Repeat this row pattern for each document in the topic area -->

### {TOPIC_AREA_2}
| Article type | Title | Link | Applicable products | Supported versions | Owner | Highest action classification | Highest state-changing risk | Workload or maintenance impact | Metadata marker | Execution surface |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {DOC_TYPE} | {DOC_TITLE} | [{FILE_NAME}.md]({FOLDER_NAME}/{FILE_NAME}.md) | {APPLICABLE_PRODUCTS} | {SUPPORTED_VERSIONS} | {OWNER} | {[READ-ONLY], state-changing, or None, index-only} | {[LOW RISK], [MEDIUM RISK], [HIGH RISK], or Not applicable} | {WORKLOAD_OR_MAINTENANCE_IMPACT} | {present or missing} | {on-device, mixed, cloud-diagnostic, cloud-control, or thin} |
<!-- Add more documents as needed -->

<!-- Instructions: Add more topic areas as needed. Typical components have 3-5 major topic areas. -->

## Maintenance checklist

- Update this index whenever an article is added, moved, renamed, or re-owned.
- Keep applicable products and supported versions explicit in every row.
- Keep the owner field current so support, partner, OEM, and engineering readers know where to route follow-up.
- Keep action classification, state-changing risk, workload or maintenance impact, and execution surface aligned with the linked article.
- Use only public Microsoft links for external references in public article rows.

## Before submitting this copied README

Use this gate after copying the template to `TSG/{Component}/README.md`.

| Check | Pass condition |
| --- | --- |
| Placeholders and instructions | No `{PLACEHOLDER}` values or `<!-- Instructions:` comments remain. |
| Copied-context links | `[CONTRIBUTING.md](CONTRIBUTING.md)` resolves to the component contribution guide, and `[repository CONTRIBUTING.md](../../CONTRIBUTING.md)` resolves to the repository contribution guide. |
| Inventory columns | Every topic table keeps Article type, Title, Link, Applicable products, Supported versions, Owner, Highest action classification, Highest state-changing risk, Workload or maintenance impact, Metadata marker, and Execution surface. |
| Required row values | Every row has a schema-valid document type plus explicit applicable products, supported versions, accountable owner, highest action classification, highest state-changing risk or `Not applicable`, workload or maintenance impact, and execution surface. |
| Metadata marker | Every linked article has the required `azure-local-supportability/tsg-metadata/v2` marker, validates against `../Templates/tsg-metadata.schema.json`, and uses `detector.signal: null` when `detector.type` is `none` before its row is marked `present`. |
| State-changing articles | Any linked article with state-changing actions keeps risk labels, privilege requirements, workload-impact or maintenance-window gates, pre-check, action, expected result or output, stop condition, rollback, expected rollback output, rollback verification, escalation, and final verification in the linked article. |
| Row order | Rows are sorted or grouped consistently within each topic area so repeated site work stays predictable. |
| Public-link hygiene | External references in article rows use public Microsoft links only. |
| Evidence | The pull request notes what was checked, including placeholder removal, copied-context link validation, metadata-marker confirmation, and latest lint result. |

---

## Contributing

For component contribution guidelines see [CONTRIBUTING.md](CONTRIBUTING.md).
For universal contribution guidelines see [repository CONTRIBUTING.md](../../CONTRIBUTING.md).
