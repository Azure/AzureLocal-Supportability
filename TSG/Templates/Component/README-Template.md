# Azure Local {COMPONENT_NAME} supportability index

<!-- Instructions: Replace {COMPONENT_NAME} with the actual component name (e.g., "Networking", "Storage", "Security") -->

<!-- Optional: Add cross-reference to related components if applicable -->
<!-- For {RELATED_COMPONENT} resources, see [TSG/{RELATED_COMPONENT}/README.md](../{RELATED_COMPONENT}/README.md). If an article spans components, list it in the primary owner component and add pointer rows from related components instead of duplicating ownership. -->

## Directory inventory

<!-- Instructions: Organize content by major topic areas within the component. Each topic should have its own section with a complete inventory table. Do not add troubleshooting-only fields such as symptoms, failure surfaces, or fix verification steps to this index. Put those details in the linked article. -->

Use one row per support article. Every linked article must carry a valid HTML-comment metadata marker using schema `azure-local-supportability/tsg-metadata/v1`; this component index records that the marker exists and summarizes its routing fields, but does not embed article metadata itself. After copying this file to `TSG/{Component}/README.md`, use the schema at [`../Templates/tsg-metadata.schema.json`](../Templates/tsg-metadata.schema.json).

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
| Technical grade | Record the article metadata `validation.technical_grade`. Use `null` until TSG-FORGE produces `A`, `B`, `C`, or `F`; do not invent a grade from the README alone. |
| Validation evidence | Record the evidence pointer machine tooling or reviewers should read, for example the article metadata `validation.spec_ref`, a TSG-FORGE report name, or `None yet`. |
| Fidelity level | Record the article metadata `validation.fidelity_level`: `L0`, `L1`, `L2`, `L3`, or `L4`. |
| Reproduction substrate | Record the article metadata `validation.reproduction_substrate`: `vm`, `hardware`, `either`, or `none`. |
| Automation readiness | Record the article metadata `validation.automation_status`: `not-assessed`, `scaffold`, `ready`, `proven`, `blocked`, or `manual`. Use `manual` for intentionally human-run guidance and `blocked` only when automation is blocked by an unresolved dependency. |
| Execution surface | Keep this distinct from automation readiness. Use `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, or `thin`. |
| Last validated | Use an ISO date such as `2026-08-17`, or `Not validated`. |

For linked articles that include state-changing actions, confirm the article uses the canonical risk labels `[LOW RISK]`, `[MEDIUM RISK]`, or `[HIGH RISK]` and includes pre-check, action, expected result or output, stop condition, rollback, and verification steps.

### Technical grade and automation rubric

If older review text says validation grade, read it as the article metadata field `validation.technical_grade`. Do not create a separate grade value in this index.

| Value | Meaning |
| --- | --- |
| `A` | TSG-FORGE evidence shows the article is complete for its type, safety gates are present, metadata is valid, links resolve, and lint is clean. |
| `B` | Usable, but non-blocking gaps remain, such as missing optional evidence or a documented false-positive warning. |
| `C` | Incomplete validation, fallback-only validation, missing required routing metadata, or unclear automation readiness. |
| `F` | Structural, safety, metadata, or command defect that must block publishing. |
| `null` | `validation.technical_grade` stays JSON `null` until TSG-FORGE produces `A`, `B`, `C`, or `F`. |
| `L0` | Static-only validation, such as metadata, lint, link, and persona review. |
| `L1` | Read-only diagnostic commands or evidence collection were validated. |
| `L2` | A reversible proxy, mocked input, or faithful data-source validation was used. |
| `L3` | A scratch object or isolated test object reproduced the failure and recovery path. |
| `L4` | Full live inject, detect, mitigate, and revalidate loop was proven on a lab substrate. |
| `not-assessed` | Automation readiness has not been reviewed. |
| `scaffold` | Automation metadata exists, but runnable automation is not built. |
| `ready` | Automation is designed and ready for validation, but not yet proven. |
| `proven` | Automation was validated with evidence. |
| `blocked` | Automation cannot proceed until a named dependency is resolved. |
| `manual` | The article intentionally requires a human action or judgment. |
| `vm`, `hardware`, `either`, `none` | Reproduction substrate values from the metadata schema. |
| `on-device` | Executable steps run on an Azure Local node. |
| `mixed` | Steps span on-device and cloud or control-plane surfaces. |
| `cloud-diagnostic` | Diagnostic evidence comes from cloud telemetry or service data. |
| `cloud-control` | Actions or checks run through Azure control-plane, portal, or ARM surfaces. |
| `thin` | No executable diagnostic or remediation surface is present. |

### {TOPIC_AREA_1}
<!-- Instructions: Replace {TOPIC_AREA_1} with a descriptive topic area name (e.g., "Arc Gateway & Outbound Connectivity") -->
| Article type | Title | Link | Applicable products | Supported versions | Owner | Highest action classification | Highest state-changing risk | Workload or maintenance impact | Metadata marker | Technical grade | Validation evidence | Fidelity level | Reproduction substrate | Automation readiness | Execution surface | Last validated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {DOC_TYPE} | {DOC_TITLE} | [{FILE_NAME}.md]({FOLDER_NAME}/{FILE_NAME}.md) | {APPLICABLE_PRODUCTS} | {SUPPORTED_VERSIONS} | {OWNER} | {[READ-ONLY], state-changing, or None, index-only} | {[LOW RISK], [MEDIUM RISK], [HIGH RISK], or Not applicable} | {WORKLOAD_OR_MAINTENANCE_IMPACT} | {present or missing} | {A, B, C, F, or null} | {SPEC_REF, report name, PR evidence, or None yet} | {L0, L1, L2, L3, or L4} | {vm, hardware, either, or none} | {not-assessed, scaffold, ready, proven, blocked, or manual} | {on-device, mixed, cloud-diagnostic, cloud-control, or thin} | {YYYY-MM-DD or Not validated} |
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
     - Replace {SPEC_REF, report name, PR evidence, or None yet} with the validation evidence source
     - Replace {L0, L1, L2, L3, or L4} with the metadata fidelity level
     - Replace {vm, hardware, either, or none} with the metadata reproduction substrate
     - Replace {YYYY-MM-DD or Not validated} with the latest validation date or Not validated
     Repeat this row pattern for each document in the topic area -->

### {TOPIC_AREA_2}
| Article type | Title | Link | Applicable products | Supported versions | Owner | Highest action classification | Highest state-changing risk | Workload or maintenance impact | Metadata marker | Technical grade | Validation evidence | Fidelity level | Reproduction substrate | Automation readiness | Execution surface | Last validated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {DOC_TYPE} | {DOC_TITLE} | [{FILE_NAME}.md]({FOLDER_NAME}/{FILE_NAME}.md) | {APPLICABLE_PRODUCTS} | {SUPPORTED_VERSIONS} | {OWNER} | {[READ-ONLY], state-changing, or None, index-only} | {[LOW RISK], [MEDIUM RISK], [HIGH RISK], or Not applicable} | {WORKLOAD_OR_MAINTENANCE_IMPACT} | {present or missing} | {A, B, C, F, or null} | {SPEC_REF, report name, PR evidence, or None yet} | {L0, L1, L2, L3, or L4} | {vm, hardware, either, or none} | {not-assessed, scaffold, ready, proven, blocked, or manual} | {on-device, mixed, cloud-diagnostic, cloud-control, or thin} | {YYYY-MM-DD or Not validated} |
<!-- Add more documents as needed -->

<!-- Instructions: Add more topic areas as needed. Typical components have 3-5 major topic areas. -->

## Maintenance checklist

- Update this index whenever an article is added, moved, renamed, re-owned, re-validated, or converted for automation.
- Keep applicable products and supported versions explicit in every row.
- Keep the owner field current so support, partner, OEM, and engineering readers know where to route follow-up.
- Keep action classification, state-changing risk, workload or maintenance impact, technical grade, validation evidence, fidelity level, reproduction substrate, automation readiness, execution surface, and last validated aligned with the linked article metadata and latest validation evidence.
- Use only public Microsoft links for external references in public article rows.

## Before submitting this copied README

Use this gate after copying the template to `TSG/{Component}/README.md`.

| Check | Pass condition |
| --- | --- |
| Placeholders and instructions | No `{PLACEHOLDER}` values or `<!-- Instructions:` comments remain. |
| Copied-context links | `[CONTRIBUTING.md](CONTRIBUTING.md)` resolves to the component contribution guide, and `[repository CONTRIBUTING.md](../../CONTRIBUTING.md)` resolves to the repository contribution guide. |
| Inventory columns | Every topic table keeps Article type, Title, Link, Applicable products, Supported versions, Owner, Highest action classification, Highest state-changing risk, Workload or maintenance impact, Metadata marker, Technical grade, Validation evidence, Fidelity level, Reproduction substrate, Automation readiness, Execution surface, and Last validated. |
| Required row values | Every row has a schema-valid document type plus explicit applicable products, supported versions, accountable owner, highest action classification, highest state-changing risk or `Not applicable`, workload or maintenance impact, technical grade from `validation.technical_grade`, validation evidence, fidelity level, reproduction substrate, non-placeholder automation readiness, execution surface, and last validated value. |
| Metadata marker | Every linked article has the required `azure-local-supportability/tsg-metadata/v1` marker, validates against `../Templates/tsg-metadata.schema.json`, and uses `detector.signal: null` when `detector.type` is `none` before its row is marked `present`. |
| State-changing articles | Any linked article with state-changing actions keeps risk labels, privilege requirements, workload-impact or maintenance-window gates, pre-check, action, expected result or output, stop condition, rollback, expected rollback output, rollback verification, escalation, and final verification in the linked article. |
| Row order | Rows are sorted or grouped consistently within each topic area so repeated site work stays predictable. |
| Public-link hygiene | External references in article rows use public Microsoft links only. |
| Evidence | The pull request notes what was checked, including placeholder removal, copied-context link validation, metadata-marker confirmation, and latest lint result. |

---

## Contributing

For component contribution guidelines see [CONTRIBUTING.md](CONTRIBUTING.md).
For universal contribution guidelines see [repository CONTRIBUTING.md](../../CONTRIBUTING.md).
