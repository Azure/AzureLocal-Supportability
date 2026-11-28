# Azure Local {COMPONENT_NAME} supportability index

<!-- Instructions: Replace {COMPONENT_NAME} with the actual component name (e.g., "Networking", "Storage", "Security") -->

<!-- Optional: Add cross-reference to related components if applicable -->
<!-- For {RELATED_COMPONENT} resources, see [TSG/{RELATED_COMPONENT}/README.md](../{RELATED_COMPONENT}/README.md). If an article spans components, list it in the primary owner component and add pointer rows from related components instead of duplicating ownership. -->

## Directory inventory

<!-- Instructions: Organize content by major topic areas within the component. Each topic should have its own section with a complete inventory table. Do not add troubleshooting-only fields such as symptoms, failure surfaces, or fix verification steps to this index. Put those details in the linked article. -->

Use one row per support article. Every linked article must carry a valid HTML-comment metadata marker using schema `azure-local-supportability/tsg-metadata/v2`; this component index does not embed article metadata itself. After copying this file to `TSG/{Component}/README.md`, use the schema at [`../Templates/tsg-metadata.schema.json`](../Templates/tsg-metadata.schema.json).

### Inventory legend

| Field | Required value |
| --- | --- |
| Article | The human-readable article title as a relative link to the article file. |
| Type | The article type that matches the article metadata `document_type`: `Troubleshoot`, `Reference`, `How-to`, `Deep dive`, or `Overview`. To add another document type, extend `../Templates/tsg-metadata.schema.json` and add matching article-template guidance before using it in the index. |
| Applicable products | Name the Azure Local product or feature family explicitly, for example `Azure Local 23H2 solution update`, `Arc VM management`, or `Storage Spaces Direct`. Do not use `all` unless the article truly applies to every Azure Local product path. |
| Owner | Name the accountable team, component owner, or alias. |

Supported versions, what each action changes, workload impact, and execution surface belong in the linked article, not in this index.

For linked articles that include state-changing actions, confirm each new or edited state-changing step has a `**Changes:**` statement, plus `**Plan for:**` or a `> [!WARNING]` callout when the step's impact calls for one, and that every state-changing step includes pre-check, action, expected result or output, stop condition, rollback, and verification steps. Older articles that still use bracketed labels are not required to change.

### {TOPIC_AREA_1}
<!-- Instructions: Replace {TOPIC_AREA_1} with a descriptive topic area name (e.g., "Arc Gateway & Outbound Connectivity") -->
| Article | Type | Applicable products | Owner |
| --- | --- | --- | --- |
| [{DOC_TITLE}]({FOLDER_NAME}/{FILE_NAME}.md) | {DOC_TYPE} | {APPLICABLE_PRODUCTS} | {OWNER} |
<!-- Instructions: 
     - Replace {DOC_TITLE} with descriptive title
     - Replace {FOLDER_NAME} with subfolder name
     - Replace {FILE_NAME} with actual filename following naming convention
     - Replace {DOC_TYPE} with the article type: Troubleshoot, Reference, How-to, Deep dive, or Overview
     - Replace {APPLICABLE_PRODUCTS} with explicit Azure Local product or feature scope
     - Replace {OWNER} with the accountable team, component owner, or alias
     Repeat this row pattern for each document in the topic area -->

### {TOPIC_AREA_2}
| Article | Type | Applicable products | Owner |
| --- | --- | --- | --- |
| [{DOC_TITLE}]({FOLDER_NAME}/{FILE_NAME}.md) | {DOC_TYPE} | {APPLICABLE_PRODUCTS} | {OWNER} |
<!-- Add more documents as needed -->

<!-- Instructions: Add more topic areas as needed. Typical components have 3-5 major topic areas. -->

## Maintenance checklist

- Update this index whenever an article is added, moved, renamed, or re-owned.
- Keep applicable products explicit in every row.
- Keep the owner field current so support, partner, OEM, and engineering readers know where to route follow-up.
- Keep the type aligned with the linked article's metadata `document_type`.
- Use only public Microsoft links for external references in public article rows.

## Before submitting this copied README

Use this gate after copying the template to `TSG/{Component}/README.md`.

| Check | Pass condition |
| --- | --- |
| Placeholders and instructions | No `{PLACEHOLDER}` values or `<!-- Instructions:` comments remain. |
| Copied-context links | `[CONTRIBUTING.md](CONTRIBUTING.md)` resolves to the component contribution guide, and `[repository CONTRIBUTING.md](../../CONTRIBUTING.md)` resolves to the repository contribution guide. |
| Inventory columns | Every topic table keeps Article, Type, Applicable products, and Owner. |
| Required row values | Every row has a linked article title, a type that matches the article metadata `document_type`, explicit applicable products, and an accountable owner. |
| Metadata marker | Every linked article has the required `azure-local-supportability/tsg-metadata/v2` marker, validates against `../Templates/tsg-metadata.schema.json`, and uses `detector.signal: null` when `detector.type` is `none`. |
| State-changing articles | Any linked article with state-changing actions keeps its impact statements (`**Changes:**`, plus `**Plan for:**` and warning callouts when the step's impact calls for them, or the older bracketed labels on steps that have not been edited), privilege requirements, workload-impact or maintenance-window gates, pre-check, action, expected result or output, stop condition, rollback, expected rollback output, rollback verification, escalation, and final verification in the linked article. |
| Row order | Rows are sorted or grouped consistently within each topic area so repeated site work stays predictable. |
| Public-link hygiene | External references in article rows use public Microsoft links only. |
| Evidence | The pull request notes what was checked, including placeholder removal, copied-context link validation, metadata-marker confirmation, and latest lint result. |

---

## Contributing

For component contribution guidelines see [CONTRIBUTING.md](CONTRIBUTING.md).
For universal contribution guidelines see [repository CONTRIBUTING.md](../../CONTRIBUTING.md).
