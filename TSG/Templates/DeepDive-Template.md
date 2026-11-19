<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "deep-dive",
  "products": [
    "replace-me"
  ],
  "detector": {
    "type": "none",
    "signal": null
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "not-assessed",
    "last_validated": null,
    "spec_ref": ""
  }
}
-->

<!--
Deep Dive Template

Use this template for in-depth Azure Local technical explanations, architecture details,
mechanism walkthroughs, and design context. If the article is primarily about detecting
and resolving a specific failure, use the troubleshooting template instead.

Authoring rules:
- Replace every placeholder in braces before publishing.
- Use no emojis.
- Do not use em dashes or spaced double hyphens as clause separators in prose.
- Use public Microsoft Learn or Microsoft documentation links only.
- Put images in an images folder next to the article.
- Fence every command, code block, JSON block, or output sample with a language identifier.
-->

# {Title}

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 220px;">Document type</th>
    <td><strong>Deep Dive</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Purpose</th>
    <td>{State what the reader will understand or decide after reading this article.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Applicable products</th>
    <td>{List the Azure Local products, features, components, or OEM platforms this article applies to.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Supported versions</th>
    <td>{List supported Azure Local releases, OS builds, extension versions, firmware versions, or state "not version-specific" with why.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Component</th>
    <td>{Component name}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Topic</th>
    <td>{Topic name and brief description.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Audience</th>
    <td>{Primary readers, such as customer admin, Microsoft Customer Support Services (CSS) engineer, partner deployment engineer, original equipment manufacturer (OEM) engineer, or architect.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Severity or risk posture</th>
    <td>{Use "informational" for explanation-only content. If any action changes state, label each action with [LOW RISK], [MEDIUM RISK], or [HIGH RISK].}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Last reviewed</th>
    <td>{YYYY-MM-DD}</td>
  </tr>
</table>

## Overview

{Summarize the topic in 3 to 5 sentences. Explain why the topic matters, what problem or decision it helps with, and what the reader should be able to do after reading.}

## Reader routing and publish gate

Use this section as the one-screen summary for leaders, field engineers, workload owners, and specialists who need to decide what to do next before reading the deep details.

### Publish-before-use checklist

Do not publish or run copied actions from this template until every item is complete.

| Gate | Required before publishing |
| --- | --- |
| Placeholders removed | Search for brace placeholders such as `{Title}` and replace every one with article-specific content. Do not publish while any placeholder remains. |
| Products and versions explicit | Fill in applicable products and supported versions. Include at least one explicit out-of-scope version, topology, or product case. |
| Public-link hygiene | Use public Microsoft Learn or Microsoft documentation links only. |
| Metadata marker valid | Keep exactly one `azure-local-supportability/tsg-metadata/v1` marker and update it if the article gains a detector or validation evidence. |
| Metadata schema checked | Validate the marker against the public schema. The schema lives at [`tsg-metadata.schema.json`](tsg-metadata.schema.json) in the template folder. After copying this article, use the copied file's relative path back to the schema: component root uses `../Templates/tsg-metadata.schema.json`, one nested topic folder uses `../../Templates/tsg-metadata.schema.json`, and each additional nested folder adds one `../`. |
| Safety contract complete | Every action has an action type, required privilege, workload or maintenance gate, pre-check, action, expected result or output, stop condition, rollback with expected output, rollback verification, final verification, and escalation target. State-changing actions also have a [LOW RISK], [MEDIUM RISK], or [HIGH RISK] label. |
| Evidence sanitized | Remove customer identifiers, secrets, private tenant values, internal URLs, and lab-only names from examples and artifacts. |

### Choose the right template

| Reader need | Use this template? | Use instead |
| --- | --- | --- |
| Explain how an Azure Local mechanism works, what evidence proves it, and where the boundaries are. | Yes. Use Deep Dive. | Not applicable. |
| Detect and resolve a specific failure or validator result. | No. | Troubleshoot template. |
| Perform a task through ordered steps. | No, unless the steps are only examples inside a broader explanation. | How-To template. |
| List settings, limits, defaults, or parameters. | No, unless the reference data supports a mechanism explanation. | Reference template. |
| Introduce a broad component or feature at a high level. | No. | Overview template. |

### One-screen decision summary

| Decision field | Author prompt |
| --- | --- |
| Customer capability gained | {State what the customer can understand, decide, prevent, or operate after reading.} |
| Business or workload impact | {State whether the topic can affect virtual machine (VM) availability, storage, networking, updates, security posture, deployment, or customer operations.} |
| Workload owner view | {State whether workload owners should expect downtime, live migration, restart, drain, degraded performance, or no workload impact.} |
| Downtime and maintenance window | {State expected downtime, maintenance-window need, rough duration, and the reason. Use "none expected" only when evidence supports it.} |
| Primary owner | {Name the likely owner, such as customer IT, Microsoft Customer Support Services (CSS), partner or system integrator (SI), Microsoft engineering, original equipment manufacturer (OEM) vendor, or network team.} |
| Handoff lane | {State how a reader proves this is their lane or not their lane, then name the next owner and the evidence to hand off.} |
| Fastest safe next action | {Give the first read-only check or decision that unblocks the customer fastest.} |
| Stop and escalate when | {List the first condition that should stop self-service and trigger Microsoft Support, partner, OEM, or product-group escalation.} |
| Multi-node or multi-site repeatability | {State whether the guidance applies per node, per cluster, per site, or per fleet, plus batching guidance and the validation loop to repeat after each batch.} |

## Scope and non-goals

| Area | Guidance |
| --- | --- |
| In scope | {List the concepts, scenarios, signals, and products covered.} |
| Out of scope | {List adjacent areas this article does not cover and point to public Microsoft documentation when available.} |
| Applies when | {Describe the product state, deployment phase, topology, or configuration where this explanation is valid.} |
| Does not apply when | {Describe clear exclusions so readers do not apply the guidance to the wrong product, version, or topology.} |

## Prerequisites and assumptions

| Prerequisite | Required value or condition | How to check |
| --- | --- | --- |
| Product and supported versions | {Example: Azure Local {release or later}.} | {How the reader confirms the product and version.} |
| Example, product and version | Azure Local 23H2 or later, if applicable to the topic. | In Azure portal, open the Azure Local cluster Overview page and record the reported version. |
| Permissions | {Required role or local privilege.} | {How to verify access before continuing.} |
| Tools | {Required tools, portals, PowerShell modules, or logs.} | {How to confirm the tool is present and current.} |
| Cluster or workload state | {Required health, maintenance, workload, or connectivity state.} | {Read-only pre-check.} |
| Required artifacts | {Logs, screenshots, configuration exports, or evidence needed.} | {Where to collect them.} |

## Table of contents

- [Overview](#overview)
- [Reader routing and publish gate](#reader-routing-and-publish-gate)
- [Scope and non-goals](#scope-and-non-goals)
- [Prerequisites and assumptions](#prerequisites-and-assumptions)
- [Architecture and technical details](#architecture-and-technical-details)
- [Evidence and observability](#evidence-and-observability)
- [Case-ready evidence and source authority](#case-ready-evidence-and-source-authority)
- [Operational boundaries and safety](#operational-boundaries-and-safety)
- [Action pattern, if this article includes steps](#action-pattern-if-this-article-includes-steps)
- [Validation](#validation)
- [Future test automation metadata](#future-test-automation-metadata)
- [References](#references)

## Architecture and technical details

{Explain the mechanism, architecture, data flow, trust boundary, control plane, data plane, dependencies, and important failure modes. Keep this section explanatory. Move step-by-step remediation to the action pattern section when applicable.}

### Key concepts and definitions

| Term | Definition | Why it matters |
| --- | --- | --- |
| {Term} | {Definition in plain language.} | {How this affects the reader's decision or operation.} |

### Dependency map

| Dependency | Direction | Required state | Timeout or degraded behavior | Failure mode | Evidence source |
| --- | --- | --- | --- | --- | --- |
| {Dependency name} | {Inbound, outbound, local, cluster, Azure control plane, or OEM.} | {Expected healthy state.} | {Expected timeout, retry, stale-data, or degraded-state behavior.} | {How this dependency fails and what component sees the failure first.} | {Log, cmdlet, portal surface, or public documentation source.} |

## Evidence and observability

Use this section to explain where the concept can be observed. Use admin surface states exactly as `shown`, `not-evident`, or `absent`: `shown` means the surface carries useful evidence, `not-evident` means the surface was checked and is not expected to show this topic, and `absent` means the author has not characterized the surface yet. Articles with `absent` surfaces are not publish-ready.

| Surface | State | What to look for | Expected healthy signal | Abnormal or important signal | Limitations |
| --- | --- | --- | --- | --- | --- |
| PowerShell on an Azure Local node | {shown, not-evident, or absent} | {Get-* or Invoke-* command, if applicable.} | {Expected output.} | {Unexpected output.} | {Permissions, timing, or version limits.} |
| Azure portal | {shown, not-evident, or absent} | {Azure Local, Arc, resource health, updates, or other blade.} | {Expected status.} | {Unexpected status.} | {Portal refresh or data delay.} |
| Windows event logs | {shown, not-evident, or absent} | {Log name, provider, and Event ID.} | {Expected event or absence.} | {Important event.} | {Retention and clock-skew limits.} |
| Example, Windows event logs | shown | Event Viewer or `Get-WinEvent` for a named provider and Event ID. | The event is absent, informational, or matches the documented healthy state. | The event appears within the article's time window with the documented abnormal value. | Event logs can roll over and node clocks can differ. |
| Cluster logs | {shown, not-evident, or absent} | {Relevant `Get-ClusterLog` component or state.} | {Expected entry or not-evident rationale.} | {Unexpected entry.} | {Collection window and noise limits.} |
| Windows Failover Cluster Manager | {shown, not-evident, or absent} | {Role, resource, network, or node view.} | {Expected status or not-evident rationale.} | {Unexpected status.} | {May not show component-specific state.} |
| Windows Admin Center on a standalone host | {shown, not-evident, or absent} | {Where to check.} | {Expected status or not-evident rationale.} | {Unexpected status.} | {Extension and version limits.} |
| Windows Admin Center in the Azure portal | {shown, not-evident, or absent} | {Where to check.} | {Expected status or not-evident rationale.} | {Unexpected status.} | {Access and refresh limits.} |
| Component or tool log files on disk | {shown, not-evident, or absent} | {Path to component logs or generated reports.} | {Expected entry.} | {Unexpected entry.} | {Log rotation and privacy considerations.} |

## Case-ready evidence and source authority

Use this section when the article may support a support case, escalation, partner handoff, or OEM handoff.

### Evidence package checklist

| Artifact type | Collect | Sanitize before sharing | Used for |
| --- | --- | --- | --- |
| Timeline | {Coordinated Universal Time (UTC) start time, detection time, action time, and recovery time.} | {Remove personal names unless needed for support routing.} | {Correlates symptoms, actions, and validation.} |
| Product and version evidence | {Azure Local version, OS build, extension version, firmware or driver version if relevant.} | {Remove serial numbers unless the OEM support path requires them.} | {Confirms applicability and supported versions.} |
| Observability output | {Logs, events, command output, portal status, or screenshots named in the evidence table.} | {Remove tenant IDs, subscription IDs, secrets, and customer-specific names.} | {Confirms the scenario and rules out adjacent causes.} |
| Configuration snapshot | {Relevant settings before and after an action.} | {Remove credentials, keys, tokens, and private endpoints.} | {Proves pre-check, rollback, and verification states.} |
| Handoff summary | {Owner, lane, stop condition reached, and requested decision.} | {Keep only information needed for the next owner.} | {Prevents the next team from repeating discovery work.} |

### Source-of-truth table

| Mechanism claim | Evidence authority | Validation status | Notes |
| --- | --- | --- | --- |
| {Important mechanism, dependency, boundary, or limitation.} | {Public Microsoft documentation, product output, command output, event log, or lab validation.} | {Validated, partially validated, not validated, or not applicable.} | {What would disprove the claim or where it does not apply.} |

### Ownership and vendor boundary

| Boundary | Microsoft-owned evidence | OEM, partner, or customer-owned evidence | Handoff criteria |
| --- | --- | --- | --- |
| Product behavior | {Azure Local documentation, Azure portal status, PowerShell output, or event logs.} | {Customer configuration or partner deployment notes.} | {Escalate to Microsoft Support when product output contradicts documented behavior or the stop condition is reached.} |
| Hardware or firmware | {Azure Local signals showing the hardware-facing symptom, if any.} | {Firmware setting, BIOS setting, baseboard management controller (BMC) logs, driver package, qualified configuration, or OEM support bundle.} | {Hand off to the OEM when the required evidence points to firmware, driver, device health, or unsupported hardware state.} |
| Network or site infrastructure | {Azure Local network symptoms and affected nodes or adapters.} | {Switch configuration, firewall policy, Domain Name System (DNS), proxy, cabling, or site routing evidence.} | {Hand off to the network or site owner when Azure Local evidence shows dependency failure outside the cluster.} |

## Operational boundaries and safety

{Explain whether this Deep Dive is explanation-only or includes operational actions. If it includes actions, keep them safe for production and use the action pattern below.}

- Risk labels: use exactly one of [LOW RISK], [MEDIUM RISK], or [HIGH RISK] for every action that may change state.
- Required privilege and security impact: {State the least privilege needed and whether the action touches identity, Role-Based Access Control (RBAC), certificates, firewall rules, secrets, or tenant resources.}
- Workload impact: {State whether the action can affect virtual machines (VMs), storage, networking, updates, quorum, Azure Arc connectivity, or customer workloads. Quorum means the cluster vote majority needed to keep cluster services online. Azure Arc is the Azure management connection for hybrid resources.}
- Maintenance and approval gate: {State whether a maintenance window, change approval, customer approval, or workload-owner approval is required before any state-changing action.}
- Do-not-proceed gates: {List conditions where the reader must stop and collect more evidence or escalate.}
- Rollback or recovery boundary: {Explain what can be undone, what cannot be undone, and who owns recovery.}
- Escalation: {State when to contact Microsoft Support, the product group, a partner, or an OEM vendor.}

## Action pattern, if this article includes steps

If this Deep Dive includes any command, configuration change, portal action, or mitigation example, use this pattern for each action. Do not omit any column.

| Step | Action type | Risk label | Required privilege and security impact | Workload or maintenance gate | Pre-check | Action | Expected result or output | Stop condition and escalation | Rollback and expected rollback output | Rollback verification | Final verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {Step name} | {[READ-ONLY] or state-changing.} | {Not applicable for [READ-ONLY]. For state-changing actions, use [LOW RISK], [MEDIUM RISK], or [HIGH RISK].} | {Least privilege required and security posture touched, such as RBAC, certificate, firewall, identity, or secret.} | {Maintenance window, customer approval, workload-owner approval, or "none expected" with evidence.} | {Read-only check that proves the action is applicable and safe.} | {One action only. Use placeholders, not real customer values.} | {Exact success output, status, or observable result.} | {Condition that means stop, do not retry blindly, and escalate or gather more evidence, plus the escalation owner.} | {How to undo the action or recover safely, and the expected rollback output or status.} | {Read-only check proving rollback restored the prior state.} | {Read-only check that confirms the intended state.} |
| Example, read-only inventory | [READ-ONLY] | Not applicable. | Reader access to the target cluster, no security posture change. | No maintenance window expected because the action is read-only. | Confirm the reader has the required role and is connected to the intended cluster. | Run the read-only inventory command or open the documented portal blade. | Output shows the product, version, component state, and timestamp described in this article. | Output is missing, stale, from the wrong cluster, or shows an unexpected state that changes the scenario. Escalate to the article owner or Microsoft Support with the evidence package. | No rollback needed for read-only inventory. Expected rollback output is not applicable. | Not applicable because no state changed. | Repeat the same read-only check after any later action and compare the timestamp and state. |

## Validation

{State how the article was validated. Include what was tested, what was not tested, and how a reader can validate the claims in their environment.}

| Claim or procedure | Validation method | Result | Evidence | Gaps |
| --- | --- | --- | --- | --- |
| {Claim, explanation, or action.} | {Documentation review, lab run, command output, log evidence, or not validated.} | {Pass, fail, not applicable, or not assessed.} | {Public documentation link, sanitized output, or artifact reference.} | {Known uncertainty or future validation needed.} |

### Verify the fix or validate the guidance

{For explanation-only content, describe how the reader validates that they understood the topic and selected the right next step. For operational content, describe the final read-only verification that proves the action reached the intended state.}

## Future test automation metadata

Use this section to make future TSG-FORGE automation possible. Keep placeholders until the article is assessed.

| Field | Value |
| --- | --- |
| Automation candidate | {yes, no, or unknown.} |
| `detector.type` | {none, envchecker, eventlog, command, service, feature, registry, telemetry, manual, portal, or control-plane.} |
| Detector signal | {Exact check name, Event ID, command, service, feature, registry key, telemetry table, or manual surface.} |
| `validation.reproduction_substrate` | {none, vm, hardware, or either. Use only these schema values.} |
| Special fixture note | {Plain-language detail for a lab fixture, scratch object, cluster shape, or manual condition, if any. This is not a `validation.reproduction_substrate` value.} |
| Current fidelity level | {L0, L1, L2, L3, or L4.} |
| Technical grade | {Use null in the JSON metadata marker until TSG-FORGE produces A, B, C, or F. This is the authoritative technical grade field for README indexes and companion evidence.} |
| Automation status | {not-assessed, scaffold, ready, proven, blocked, or manual.} |
| Last validated | {Use YYYY-MM-DD after validation, or null in the JSON metadata marker when not validated.} |
| Execution surface | {on-device, mixed, cloud-diagnostic, cloud-control, or thin. This is separate from automation status.} |
| Spec reference | {Path to future companion spec, or blank.} |

Plain-language detector explanation: describe what evidence source the selected detector represents and why it matches the article. When `detector.type` is `none`, keep `detector.signal` as JSON `null`. When selecting any other detector type, set both `detector.type` and `detector.signal` together so automation can find the exact signal.

### Automation vocabulary

Automation status records test readiness. It is separate from execution surface terms such as on-device, cloud, or mixed, which describe where a generated action can run.

| Vocabulary | Values | Meaning |
| --- | --- | --- |
| Fidelity level | L0 | Static structure, metadata, and persona review only. No live validation. |
| Fidelity level | L1 | Read-only diagnostics or claims were run or checked against a real or authoritative source. |
| Fidelity level | L2 | A safe proxy, synthetic input, or data-source override exercised the same decision path without reproducing the full real-world failure. |
| Fidelity level | L3 | A scratch object or isolated fixture exercised the real mechanism without changing the whole system. |
| Fidelity level | L4 | Full inject, detect, mitigate, and revalidate loop was proven end to end on an appropriate lab substrate. |
| Technical grade | null | No TSG-FORGE technical grade has been produced yet. |
| Technical grade | A, B, C, or F | The authoritative TSG-FORGE technical grade, backed by report or spec evidence. Do not invent a separate grade vocabulary. |
| Detector type | none | No machine detector applies yet. Use with `detector.signal: null`. |
| Detector type | envchecker | Azure Local Environment Validator result or health-check signal. |
| Detector type | eventlog | Windows event log provider, log name, and Event ID. |
| Detector type | command | Read-only command or script result. |
| Detector type | service, feature, registry | Operating system state probe for a service, Windows feature, or registry value. |
| Detector type | telemetry | Fleet or service telemetry query used by internal validation. |
| Detector type | manual or portal | Human-observed portal, visual, or manual validation surface. |
| Detector type | control-plane | Azure Resource Manager or other Azure control-plane state. |
| Automation status | not-assessed | No automation assessment has been completed. |
| Automation status | scaffold | Metadata exists, but detector or validation automation is incomplete. |
| Automation status | ready | Automation is authored and ready to run, but not yet proven. |
| Automation status | proven | Automation has successful validation evidence and a validation date. |
| Automation status | blocked | Automation is known to be blocked, with the blocking reason documented. |
| Automation status | manual | Validation intentionally requires human judgment or an external manual step. |

## References

- {Public Microsoft Learn or Microsoft documentation link. Example: https://learn.microsoft.com/azure/azure-local/}
