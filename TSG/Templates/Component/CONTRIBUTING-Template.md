# Contributing to Azure Local {COMPONENT_NAME} Documentation

<!-- Instructions: Replace {COMPONENT_NAME} with the actual component name and remove every instruction comment before submitting the copied component file. -->

This document extends the [repository contribution guide](../../CONTRIBUTING.md) with component-specific requirements for `{COMPONENT_NAME}`.

Use this file to define how contributors should scope, validate, and review content for this component. Do not copy article-only sections such as Symptoms, Root Cause, or Resolution into this contribution guide. Instead, require authors to use the correct article template and to complete the checks below.

## Table of Contents

- [Fast Path: Copy, Lint, and PR Evidence](#fast-path-copy-lint-and-pr-evidence)
- [Component Scope and Applicability](#component-scope-and-applicability)
- [Required Article Metadata](#required-article-metadata)
- [Safe and Testable Authoring](#safe-and-testable-authoring)
- [Evidence, Validation, and Discoverability](#evidence-validation-and-discoverability)
- [File Naming](#file-naming)
- [Structure](#structure)
- [Before Opening a Pull Request](#before-opening-a-pull-request)
- [Need Help](#need-help)

## Fast Path: Copy, Lint, and PR Evidence

Use this path when turning the template into a component `CONTRIBUTING.md` and pull request (PR) evidence:

1. Copy this file to `TSG/{ComponentName}/CONTRIBUTING.md` and customize all component-specific scope, topic, and folder entries.
2. Remove every instruction comment, `{curly brace}` placeholder, and `replace-me` value before the PR is ready for review.
3. Confirm the PR summary fields below are ready for a reviewer:

   | Field | PR-ready answer |
   | --- | --- |
   | Non-technical impact | What customer or operator problem this content helps with. |
   | Owner and required sign-off | Component owner, support owner, partner, SI, or OEM reviewer. |
   | Workload impact or downtime risk | None, possible disruption, maintenance window required, or unknown and blocked. |
   | Technical grade and validation evidence | `validation.technical_grade`, TSG-FORGE report or spec evidence, lint result, link check, or not applicable with reason. |
   | Remaining blockers | Open evidence, applicability, support-boundary, or owner questions. |

4. Run source-branch lint from the repository that contains the changed markdown:

   ```bash
   python3 <path-to-tsg-forge-harness.py> --lint --tsg <path-to-changed-markdown>
   ```

   `<path-to-tsg-forge-harness.py>` is the path to the TSG-FORGE `harness.py` script in the maintainer's checked-out tooling. Accepted output is `LINT (structure/safety component only) A` for this template, or a documented type false positive with the exact finding ID and reason. If the contributor cannot run TSG-FORGE locally, paste the command attempted, the error output, and a request for the maintainer to run the same lint before merge.

5. Paste this evidence snippet into the PR description:

   ```text
   Component owner:
   Customer impact summary:
   Workload impact or downtime risk:
   Applicable products and supported versions:
   validation.technical_grade:
   TSG-FORGE report or spec evidence:
   TSG-FORGE lint result:
   Link check result:
   Remaining blockers:
   ```

The `../../CONTRIBUTING.md` link is intentional for the copied file at `TSG/{ComponentName}/CONTRIBUTING.md`. When reviewing this source template, validate that link in the copied component-file context.

## Component Scope and Applicability

<!-- Instructions: Replace this section with component-specific scope rules. Name what belongs here, what does not, and which team or vendor owns handoff cases. -->

Contributions for `{COMPONENT_NAME}` must declare the supported scope before any diagnostic or action steps are accepted:

- **Applicable products**: Azure Local, plus any feature, extension, or component name this guidance applies to.
- **Supported versions**: Azure Local release, operating system build, solution build, Solution Builder Extension (SBE) version, firmware version, or driver version as applicable. Use `replace-me` until the exact range is known.
- **Operation phase**: Deployment, add node, update, upgrade, day-2 or post-deployment operations, or break/fix.
- **Topology and environment**: switchless or switched networking, storage type, Arc-connected state, Azure Kubernetes Service (AKS) Arc, Arc VMs, Original Equipment Manufacturer (OEM) family, or other component-specific topology.
- **Owner and handoff**: customer IT, partner or system integrator (SI), OEM vendor, Microsoft Customer Support Services (CSS), or product group. State when the issue is outside `{COMPONENT_NAME}`.
- **Support boundary**: prerequisites, unsupported configurations, or cases that need OEM or Microsoft support before proceeding.

Completed mini-example:

| Scope field | Completed sample |
| --- | --- |
| Component | Networking |
| Applicable products | Azure Local connectivity validation for Arc-connected clusters |
| Supported versions | Azure Local 23H2 and later, exact build range listed in each article |
| Operation phase | Deployment readiness and update readiness |
| Topology and environment | Switched or switchless, proxy mode, DNS forwarder, and outbound firewall path |
| Owner and handoff | Customer networking team for firewall or proxy, OEM vendor only when adapter firmware or driver support is involved |
| Support boundary | Stop when public endpoint allowlists, proxy credentials, or TLS inspection policy cannot be verified |

### Component topic areas

<!-- Instructions: List 4 to 6 main topic areas for this component. Use PascalCase without spaces. The Networking sample row is intentionally complete, so copied files have a concrete pattern to follow. -->

| Topic area | Use for | Applicability notes |
| --- | --- | --- |
| `OutboundConnectivity` | Firewall, proxy, DNS, and required endpoint access for Azure Local | Include topology, proxy mode, and Azure Local release or build. |
| `{TOPIC_1}` | {TOPIC_1_DESCRIPTION} | {TOPIC_1_APPLICABILITY} |
| `{TOPIC_2}` | {TOPIC_2_DESCRIPTION} | {TOPIC_2_APPLICABILITY} |
| `{TOPIC_3}` | {TOPIC_3_DESCRIPTION} | {TOPIC_3_APPLICABILITY} |
| `{TOPIC_4}` | {TOPIC_4_DESCRIPTION} | {TOPIC_4_APPLICABILITY} |

Use this handoff matrix for cross-component cases:

| Case | Primary owner or handoff | Article requirement |
| --- | --- | --- |
| Firmware, BIOS, driver, or hardware qualification | OEM vendor with Microsoft CSS as needed | Name model, firmware or driver range, and support-boundary evidence. |
| Solution Builder Extension package, model/SKU match, or solution extension content | OEM vendor or SBE publisher | Name SBE version, hardware family, and validation evidence. |
| Network symptom with storage, update, or compute impact | Start with the component whose evidence proves the failing layer | Explain why the issue is or is not in this component's lane. |
| VM workload drain, reboot, or live migration exposure | Customer workload owner and app or VM engineer | State workload impact, downtime risk, maintenance window, and validation plan. |
| Repeated site deployment variance | Partner or SI deployment owner | Record hardware family, topology, version variance, and reuse guidance for future sites. |

## Required Article Metadata

Component README files should index every article and include its title, document type, link, applicable products, supported versions, Highest action classification, Highest state-changing risk, workload impact or downtime risk, owner or handoff, metadata-marker status, validation fidelity, `validation.technical_grade`, TSG-FORGE report or spec evidence, reproduction substrate, automation status, execution surface, and last validated date.

Each article that is created from an article template must contain one valid HTML-comment JSON marker that starts with the literal `<!-- tsg-metadata` label and follows schema `azure-local-supportability/tsg-metadata/v1`. Do not embed that article metadata marker in this component contribution guide. Instead, require article authors to copy the marker from [Markdown snippets](../Templates/Markdown-Snippets.md), validate it against the copied-file-relative [metadata schema](../Templates/tsg-metadata.schema.json), keep `products` explicit, and set placeholders only while drafting.

For every contributed article, require these metadata fields or their article-template equivalent:

- **Document type**: `troubleshoot`, `how-to`, `reference`, `deep-dive`, or `overview`, matching the canonical schema value for the article template. Do not invent a Known Issue document type unless the repository adds an approved Known Issue template and schema value.
- **Applicable products**: explicit product and component names. Do not leave this implicit.
- **Supported versions**: exact version range, build, or `replace-me` during draft only.
- **Detector**: `command`, `control-plane`, `envchecker`, `eventlog`, `feature`, `manual`, `none`, `portal`, `registry`, `service`, or `telemetry`. When `detector.type` is `none`, set `detector.signal` to JSON `null`; when selecting a detector, set both fields together.
- **Validation**: fidelity level, technical grade, reproduction substrate, automation status, last validated date, and TSG-FORGE spec reference when available.
- **Severity**: required for troubleshooting content and any approved component-specific known issue content when the article describes customer impact or a failing check.

Use this metadata vocabulary consistently:

| Field | Values | Meaning |
| --- | --- | --- |
| Fidelity level | L0, L1, L2, L3, L4 | L0 means static review only. L1 means read-only diagnostics were run. L2 means a safe proxy or configuration-restore loop proved the signal or fix direction. L3 means an isolated scratch object reproduced the failure mode and fix. L4 means a full live inject, detect, mitigate, and revalidate loop was proven. |
| Technical grade | JSON `null`, `A`, `B`, `C`, `F` | `validation.technical_grade` is the authoritative TSG-FORGE grade. Set it to JSON `null` until a TSG-FORGE report or spec evidence assigns A, B, C, or F. Do not invent a separate grade vocabulary in component README files. |
| Automation status | `not-assessed`, `scaffold`, `ready`, `proven`, `blocked`, `manual` | Maturity of validation automation. This is not the same as execution surface. |
| Execution surface | `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, `thin` | Where the diagnostic or action runs. Do not write these values into `automation_status`. |
| Reproduction substrate | `vm`, `hardware`, `either`, `none` | Where validation can be reproduced. Use `none` for explanation-only content. |
| Last validated | ISO date or `null` in draft metadata | Date of the latest cited validation evidence. |

## Safe and Testable Authoring

All contributed commands, scripts, portal actions, and configuration changes must be production-safe, tested, and labeled with a canonical action classification:

- [READ-ONLY]: diagnostics, status checks, link checks, or metadata checks that do not change state. Risk is not applicable because no state changes.
- [LOW RISK]: state-changing actions with narrow, reversible impact and no expected workload or availability effect.
- [MEDIUM RISK]: reversible configuration changes, service restarts, cache cleanup, firewall updates, or changes that may briefly affect manageability.
- [HIGH RISK]: node reboot, drain, firmware change, BitLocker or Secure Boot change, storage repair, cluster quorum change, destructive cleanup, or any step that can affect workload availability.

Every action pattern in a contributed article must include these fields:

| Field | Requirement |
| --- | --- |
| Action classification | [READ-ONLY] when no state changes. Use [LOW RISK], [MEDIUM RISK], or [HIGH RISK] only when the action may change state. |
| Risk statement | For [READ-ONLY], state that risk is not applicable because no state changes. For state-changing actions, explain why the selected risk label is correct. |
| Required privilege | Role, local admin right, Azure role, OEM access, or support entitlement needed before the action. |
| Workload or maintenance gate | Whether the action needs a maintenance window, workload owner approval, node drain, reboot plan, or no workload impact. |
| Pre-check | What the operator must confirm before running the action, including prerequisites, current state, backup, recovery key, maintenance window, and workload impact. |
| Action | The exact command or portal action, with placeholders such as `<cluster-name>` and no real customer identifiers. |
| Expected result or output | The success shape, status, log entry, portal state, or command output the reader should see. |
| Stop condition | The condition that means the reader must stop and escalate instead of continuing. |
| Escalation target | Component owner, Microsoft CSS, OEM vendor, product group, or customer workload owner to contact when a stop condition is hit. |
| Rollback | How to undo the change or return to the previous state. If rollback is not available, label the action [HIGH RISK] and say so before the action. |
| Expected rollback output | The command output, portal state, or log entry that shows rollback started and completed. |
| Rollback verification | The independent check that proves the rollback restored the previous state. |
| Verification | The command, portal check, log, event, or validation run that proves the change worked. |

State-changing PowerShell must check current state before changing it, avoid `-Force` unless justified, set error handling where appropriate, and include verification after changes. Do not include commands that delete drive roots, erase customer data, disable security controls, or reboot or drain nodes without explicit pre-checks, stop conditions, rollback guidance, and a [HIGH RISK] label.

## Evidence, Validation, and Discoverability

Each article must show enough evidence for a reviewer and a field engineer to trust the guidance:

- Include the exact validation performed: lab run, customer-safe repro, command output shape, screenshots, logs, Event IDs, telemetry, or source links.
- For troubleshooting content, add a **Where this failure appears** section or equivalent that explains the visible symptom and where to collect proof.
- For remediation content, add a **Verify the fix** step that reruns the relevant health check, command, portal check, or validation procedure.
- For generated code or action patterns, include expected result/output, stop condition, rollback, and verification as separate prompts.
- Define acronyms on first use, avoid internal jargon, and write for a public reader who may not know Azure Local team names or support aliases.
- Cite only public Microsoft documentation for external links. Use Microsoft Learn links without release-specific query strings.
- Keep internal links relative and verify they resolve after the file is copied into the component folder.
- Do not include customer names, tenant IDs, subscription IDs, cluster names, IP addresses, secrets, or private support URLs in public articles.

When the article describes how an issue is detected, characterize the administrator-visible surfaces that apply. Use only these states: `shown` when the article provides concrete evidence for the surface, `not-evident` when the surface was checked and does not show the issue, and `absent` when the surface is still uncharacterized. An `absent` surface is not publish-ready.

| Surface | What the article should say |
| --- | --- |
| PowerShell on an Azure Local node | Show the `Get-*`, `Test-*`, or `Invoke-*` command and the failing output, or state that node PowerShell does not show the issue. |
| Azure portal | Name the Azure Local, Arc, Resource Health, or Updates blade if it shows the issue, or state that the Azure portal does not show it. |
| Windows event logs | Name the log, provider, and Event ID if present, or state that Windows event logs do not show it. |
| Cluster logs with `Get-ClusterLog` | Show the cluster log signal, or state that `Get-ClusterLog` does not show it. |
| Windows Failover Cluster Manager | State whether the issue appears as a failed role, resource, or node in Failover Cluster Manager. |
| Windows Admin Center on a standalone host | State whether Windows Admin Center on a standalone host shows the issue. |
| Windows Admin Center in the Azure portal | State whether Windows Admin Center in the Azure portal shows the issue. |
| Component or tool log files on disk | Point to the component log or report file, or state that no component log file is written. |

## File Naming

Follow the universal naming convention: `<Type>-<Topic>-<Specifics>.md`.

For this component (`{COMPONENT_NAME}`), use the topic areas above or create a new topic when the component owner approves it.

File names must be descriptive, must avoid spaces, and must match the selected document type. Examples:

- `Troubleshoot-OutboundConnectivity-ProxyAuthentication.md`
- `HowTo-OutboundConnectivity-ConfigureProxy.md`
- `Reference-OutboundConnectivity-RequiredEndpoints.md`

## Structure

The repo is organized by major topic areas. Add new files to existing folders when possible, or create new folders when the component owner approves the new topic.

<!-- Instructions: Create a table describing the main folders or topic areas for this component. The first row is a completed example. -->

| Folder | Description | Required README entry |
| --- | --- | --- |
| `OutboundConnectivity/` | Proxy, DNS, firewall, and endpoint requirements for Azure Local connectivity. | Title, document type, link, applicable products, supported versions, Highest action classification, Highest state-changing risk, workload impact, owner, metadata-marker status, validation fidelity, `validation.technical_grade`, TSG-FORGE report or spec evidence, reproduction substrate, automation status, execution surface, last validated date. |
| `{FOLDER_1}/` | {FOLDER_1_DESCRIPTION} | {FOLDER_1_README_ENTRY_REQUIREMENT} |
| `{FOLDER_2}/` | {FOLDER_2_DESCRIPTION} | {FOLDER_2_README_ENTRY_REQUIREMENT} |
| `{FOLDER_3}/` | {FOLDER_3_DESCRIPTION} | {FOLDER_3_README_ENTRY_REQUIREMENT} |

Place images in an `images/` subfolder under the relevant topic area. Use descriptive filenames and include alt text in the article.

## Before Opening a Pull Request

A component contribution is not ready for review until every item below is true:

- The copied component `CONTRIBUTING.md` links to the repository contribution guide as `../../CONTRIBUTING.md`.
- The final file contains no `{curly brace}` placeholders and no authoring instruction comments.
- The component README indexes every new or changed article with title, document type, link, applicable products, supported versions, Highest action classification, Highest state-changing risk, workload impact, owner, metadata-marker status, validation fidelity, `validation.technical_grade`, TSG-FORGE report or spec evidence, reproduction substrate, automation status, execution surface, and last validated date.
- Every article uses the correct template and includes the required metadata marker from `../Templates/Markdown-Snippets.md` when it is an article template output.
- Every applicable product, supported version, operation phase, topology, owner, and support boundary is explicit.
- Every action uses [READ-ONLY] when no state changes or [LOW RISK], [MEDIUM RISK], or [HIGH RISK] when state may change, and includes pre-check, action, expected result/output, stop condition, rollback, and verification.
- Evidence is attached or cited in the PR: tested commands, expected outputs, logs, screenshots, Event IDs, telemetry samples, or source links as appropriate.
- Internal relative links resolve from the copied file location, and external links use public Microsoft documentation without release-specific query parameters.
- Public content contains no customer identifiers, secrets, tenant IDs, subscription IDs, private IP addresses, private support links, or internal-only URLs.
- Source-branch TSG-FORGE lint or review has been run on changed markdown. Fix real findings, record any type false positives with the reason, and include the result in the PR description.

## Need Help

- Use the repository contribution guide at [../../CONTRIBUTING.md](../../CONTRIBUTING.md) for universal process, CLA, document-type, and code-safety rules.
- Use Microsoft Learn for public Azure Local product references: <https://learn.microsoft.com/azure/azure-local/>.
- Ask the component owner when applicability, version support, risk, or support boundary is unclear.
