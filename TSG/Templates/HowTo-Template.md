<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "how-to",
  "products": ["replace-me"],
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
How-To Template
- Use this template for planned Azure Local management tasks, configuration changes, deployment steps, or operational procedures.
- Replace every {placeholder} before publishing. Search with this regex: \{([^}]+)\}
- Use numbered lists for sequential actions and bullets for options or notes.
- Place images in an ./images folder and reference them from the article.
- Use fenced code blocks with a language identifier for commands, output, JSON, XML, YAML, or logs.
- External links must point to public Microsoft documentation, preferably the latest Azure Local docs.
- Do not publish customer identifiers, tenant identifiers, subscription identifiers, secrets, tokens, or private Microsoft links.
-->

# {Title}

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 220px;">Document type</th>
    <td><strong>How-To</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Purpose</th>
    <td>{State the customer or operator outcome this guide helps achieve and why it matters.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Business impact</th>
    <td>{State the customer capability, workload, deployment, or operations outcome this procedure protects or restores.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Audience</th>
    <td>{Primary reader or owner, such as Azure Local administrator, Microsoft Customer Support Services (CSS) engineer, partner or system integrator (SI) deployment engineer, original equipment manufacturer (OEM) field engineer, or workload owner.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Owner and approver</th>
    <td>{Execution owner, approval owner, and handoff team if the assigned reader is not the owner.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Component</th>
    <td>{Azure Local component or feature area.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Applicable products</th>
    <td>{List exact Azure Local products, SKUs, deployment types, and related Microsoft products. Verify against public documentation before publishing.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Supported versions</th>
    <td>{List supported Azure Local releases, builds, extension versions, firmware versions, or tool versions. State the source used to verify support.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Applies to</th>
    <td>{List environments, cluster states, operations, and scenarios where this guide applies.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Does not apply to</th>
    <td>{List explicit out-of-scope products, versions, symptoms, or conditions. Tell the reader where to go instead.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Estimated duration</th>
    <td>{Expected operator time and elapsed time. Include whether the task needs a maintenance window.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Overall action type and risk</th>
    <td>{Use [READ-ONLY] when the guide only gathers information and state that risk is not applicable because no state changes. For state-changing guides, choose one: [LOW RISK], [MEDIUM RISK], [HIGH RISK]. Explain the reason in one sentence.}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Customer update cadence</th>
    <td>{Who receives updates, how often they receive them, and the next update time if the procedure takes longer than expected.}</td>
  </tr>
</table>

## Overview

{Briefly describe the task, the end state, and the benefit to the customer or operator. Keep this section short enough for a decision maker to skim.}

## Decision summary

Fill this summary before the first command so leaders, account teams, and field engineers can make the same proceed or stop decision.

| Decision field | Required author input |
| --- | --- |
| Owner | {Person, team, or role that runs the procedure.} |
| Approver | {Person, team, or role that approves the maintenance window or state change.} |
| Customer impact | {Plain-language statement of what customer capability is affected now and what capability is restored after success.} |
| Fastest safe unblock | {Shortest approved path, first stop condition, and fallback owner if the path is not safe.} |
| Proceed decision | {Proceed only when prerequisites, approvals, rollback, and evidence capture are ready. Name the approver.} |
| Next customer update | {Time, audience, and content for the next update.} |
| Success statement | {One sentence the support or account team can use to explain that the capability is restored.} |

## Outcome

After completing this guide, the reader should be able to:

- {Outcome 1 with a measurable result.}
- {Outcome 2 with a measurable result.}
- {Completion signal that proves the task succeeded.}

## Scope and routing

Use this guide only when all of the following are true:

- {In-scope condition 1.}
- {In-scope condition 2.}
- {Required product or version condition.}

Do not use this guide when any of the following are true:

- {Out-of-scope condition 1.}
- {Out-of-scope condition 2.}
- {Escalation or handoff condition, such as original equipment manufacturer (OEM)-owned firmware work, network-team ownership, or product-group investigation.}

If the guide is assigned to the wrong owner, collect this handoff evidence before sending it to the owning team.

| Handoff scenario | Owning team or role | Evidence to collect before handoff | Handoff trigger |
| --- | --- | --- | --- |
| Network-owned change | {Network team or partner.} | {Adapter names, switch ports, IP configuration, route or DNS output, and timestamp.} | {Condition that proves the issue is network-owned.} |
| OEM-owned hardware or firmware change | {OEM vendor field engineer.} | {Platform model, firmware levels, baseboard management controller (BMC), integrated Dell Remote Access Controller (iDRAC), or HPE Integrated Lights-Out (iLO) evidence, and supported configuration source.} | {Condition that requires OEM action.} |
| Workload-owned change | {Application or virtual machine (VM) owner.} | {Affected VM or workload list, expected outage, drain status, and approval.} | {Condition that requires workload-owner approval.} |
| Microsoft support or product escalation | {Microsoft CSS or product group.} | {Logs, command outputs, error text, timestamps, versions, and failed verification result.} | {Condition that blocks safe customer action.} |

Document safe alternatives and rejected approaches so the reader knows what not to try.

| Option | Status | Why it is safe, preferred, or rejected | Evidence or approval needed |
| --- | --- | --- | --- |
| {Preferred safe path} | {Use} | {Why this is the lowest-risk approved path.} | {Required evidence or approval.} |
| {Alternative path} | {Use only when...} | {Tradeoff, added risk, or prerequisite.} | {Required evidence or approval.} |
| {Rejected approach} | {Do not use} | {Why this approach is unsafe, unsupported, untested, or outside the guide scope.} | {Who can approve or replace it, if anyone.} |

## Prerequisites

Complete these checks before starting. Do not proceed until every required item is satisfied.

| Prerequisite | Required value or condition | How to check | Stop condition |
| --- | --- | --- | --- |
| Permissions | {Role, role-based access control (RBAC) assignment, local admin right, or tool access required.} | {Command, portal page, or public documentation link.} | {Stop if permission is missing.} |
| Cluster health | {Required health state, quorum state, update state, or node state.} | {Command or portal page to verify.} | {Stop if health state is not safe for this task.} |
| Backup or recovery material | {Backup, recovery key, config export, or rollback artifact required.} | {How to confirm it exists and is usable.} | {Stop if recovery material is unavailable.} |
| Maintenance window | {Required or not required. Include duration and customer communication needs.} | {How to confirm approval.} | {Stop if required approval is missing.} |
| Tools and versions | {PowerShell modules, Azure CLI extensions, browser, portal access, firmware package, or vendor utility.} | {Command to show version or public Microsoft link.} | {Stop if an unsupported tool version is present.} |

## Safety and impact

Classify each action before it appears in this guide:

- [READ-ONLY]: Diagnostics, checks, and information gathering that do not change state. Risk is not applicable because no state changes.
- [LOW RISK]: State-changing actions with no expected customer workload impact and a documented rollback.
- [MEDIUM RISK]: State-changing actions that can affect management operations, validation results, or a single node, but should not interrupt running workloads when prerequisites are met.
- [HIGH RISK]: State-changing actions that can interrupt workloads, require node drain or reboot, alter security posture, modify firmware, delete resources, or require coordinated maintenance.

Document the maintenance impact before any action that changes state:

| Impact area | Author prompt |
| --- | --- |
| Workloads and virtual machines (VMs) | {Can this affect VM availability, live migration, storage paths, network connectivity, or application traffic?} |
| Cluster availability | {Does this require draining a node, rebooting, changing quorum-sensitive state, or pausing an update?} |
| Security posture | {Does this change authentication, certificates, BitLocker, Secure Boot, Defender, firewall, RBAC, or secrets?} |
| OEM or partner ownership | {Is this owned by an OEM, networking team, partner SI, Microsoft CSS, or customer IT?} |
| Customer communication | {Who must be notified, what duration should they expect, and what completion signal should they receive?} |

## Glossary and do-not-proceed checklist

Add short definitions for terms that a first-time Azure Local operator must understand before running commands.

| Term | Plain-language definition | Where the reader verifies it |
| --- | --- | --- |
| Role-based access control (RBAC) | {Define the Azure permission model or role assignment needed for this procedure.} | {Command, portal surface, or public Microsoft documentation link.} |
| Quorum | {Define the minimum cluster voting state needed to keep the cluster available.} | {Command, portal surface, or public Microsoft documentation link.} |
| Microsoft Customer Support Services (CSS) | {Define when Microsoft support owns the next action.} | {Escalation or support handoff link.} |
| System integrator (SI) | {Define when a deployment partner owns the next action.} | {Partner handoff process.} |
| Original equipment manufacturer (OEM) | {Define when the hardware vendor owns the next action.} | {Vendor support path or public Microsoft hardware guidance.} |

Do not proceed unless every row below is satisfied.

| Guardrail | Required proof before continuing | If not satisfied |
| --- | --- | --- |
| All placeholders are replaced | {Every placeholder has a real customer-safe value or a documented reason it is not used.} | Stop and complete the filled-in variables table. |
| Target scope is clear | {State whether the action affects one node, all nodes, one cluster, a resource group, a subscription, or a tenant.} | Stop and get owner approval for the correct scope. |
| Workload impact is approved | {VM, app, network, security, and maintenance impact are documented.} | Stop and obtain the required approval or handoff. |
| Rollback is ready | {Rollback command, portal action, or support path is documented and available.} | Stop unless the approver accepts that rollback is not possible. |
| Expected output is known | {Normal output and stop-condition output are documented.} | Stop and add expected output before running the action. |

## Table of contents

- [Overview](#overview)
- [Decision summary](#decision-summary)
- [Outcome](#outcome)
- [Scope and routing](#scope-and-routing)
- [Prerequisites](#prerequisites)
- [Safety and impact](#safety-and-impact)
- [Glossary and do-not-proceed checklist](#glossary-and-do-not-proceed-checklist)
- [Execution contract](#execution-contract)
- [{Procedure section title}](#procedure-section-title)
- [Rollback](#rollback)
- [Verification](#verification)
- [Expected output examples](#expected-output-examples)
- [Troubleshooting](#troubleshooting)
- [Handoff and escalation package](#handoff-and-escalation-package)
- [Evidence to collect](#evidence-to-collect)
- [Claims and validation evidence](#claims-and-validation-evidence)
- [Metadata vocabulary](#metadata-vocabulary)
- [Future test automation metadata](#future-test-automation-metadata)
- [Next steps](#next-steps)
- [References](#references)

## Execution contract

Complete this contract before the procedure. It is the compact checklist for literal followers, multi-node rollouts, workload owners, and reviewers.

### Filled-in variables and target scope

| Placeholder or variable | Exact value to use | Target scope | Current value | New value | Approval owner | Verification command or surface |
| --- | --- | --- | --- | --- | --- | --- |
| {Placeholder 1} | {Value to use.} | {Node, cluster, resource group, subscription, tenant, site, or workload.} | {Current value or state.} | {New value or state.} | {Approver.} | {Command or UI surface.} |
| {Placeholder 2} | {Value to use.} | {Node, cluster, resource group, subscription, tenant, site, or workload.} | {Current value or state.} | {New value or state.} | {Approver.} | {Command or UI surface.} |

### Action checklist

Every generated action must complete each row. Use [READ-ONLY] for diagnostics and state that risk is not applicable because no state changes. Use risk labels only for state-changing actions.

| Required item | Author prompt |
| --- | --- |
| Action type | {Use [READ-ONLY] for diagnostics or information gathering. Use state-changing when the action modifies configuration, data, resources, firmware, or workload state.} |
| Risk label for state-changing action | {Required only when action type is state-changing. Choose one: [LOW RISK], [MEDIUM RISK], or [HIGH RISK]. For [READ-ONLY], write "not applicable, no state changes."} |
| Privilege required | {Least-privilege role, RBAC assignment, local right, or tool access required for this action.} |
| Workload impact | {State whether the action affects VM uptime, app traffic, live migration, storage paths, networking, security posture, or update flow.} |
| Drain or maintenance approval | {State whether VM drain, node pause, reboot, maintenance window, or customer approval is required.} |
| Pre-check | {Read-only command or UI surface that proves the target is safe to change.} |
| Action | {One command or UI action, with placeholders replaced.} |
| Error handling and retry behavior | {State ErrorAction or equivalent behavior, retry count, delay, and when a retry is unsafe.} |
| Idempotency | {State whether it is safe to run the action more than once and how the command detects existing state.} |
| Expected result or output | {Exact success output, status, or portal state.} |
| Stop condition | {Exact failure output, unexpected state, or blast-radius concern that stops the procedure.} |
| Rollback | {Undo command, portal action, or support path.} |
| Expected rollback output | {Exact output or state that proves the rollback action ran.} |
| Rollback verification | {Read-only command or UI surface that proves the previous state is restored.} |
| Verification | {Read-only command or UI surface that proves the step succeeded.} |
| Escalation | {Owner to contact if action, rollback, or verification fails.} |

### Rollout tracker

Use this tracker when the procedure repeats across nodes, clusters, resource groups, or sites.

| Batch or site | Targets | Order | Pre-validation | Approved window | Re-run validation | Stop criteria | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| {Batch 1} | {Targets included.} | {Order and dependency.} | {Read-only validation before the batch.} | {Window and approver.} | {Validation after the batch.} | {When to stop before the next batch.} | {Not started, running, complete, or stopped.} |
| {Batch 2} | {Targets included.} | {Order and dependency.} | {Read-only validation before the batch.} | {Window and approver.} | {Validation after the batch.} | {When to stop before the next batch.} | {Not started, running, complete, or stopped.} |

## {Procedure section title}

{Explain the scenario or configuration this procedure covers. State whether the actions are per node, per cluster, per resource group, per subscription, or per tenant.}

Repeat the following action pattern for every generated step. Every action must include action type, pre-check, action, expected result or output, stop condition, rollback, and verification. Use [READ-ONLY] for diagnostics and state that rollback and risk are not applicable because no state changes. Use [LOW RISK], [MEDIUM RISK], or [HIGH RISK] only for state-changing actions.

### Step 1: {Action description}

**Action type:** {Use [READ-ONLY] for diagnostics or information gathering and state that risk is not applicable because no state changes. Use state-changing when the action modifies configuration, data, resources, firmware, or workload state.}

**Risk label for state-changing action:** {Required only for state-changing actions. Choose one: [LOW RISK], [MEDIUM RISK], [HIGH RISK]. For [READ-ONLY], write "not applicable, no state changes."}

**Privilege required:** {Least-privilege role, RBAC assignment, local right, or tool access required for this step.}

**Workload impact and approval:** {State VM, app, live migration, network, security, and maintenance impact. State whether drain, reboot, maintenance approval, or workload-owner approval is required.}

**Purpose:** {Explain what this step changes or confirms.}

**Pre-check:** {Confirm the required state before this step. Include the command, portal page, or UI surface.}

```powershell
<# Replace with a read-only pre-check command, if this step uses PowerShell. #>
{PreCheckCommand}
```

**Action:** {Give one clear action. If this is a command, use placeholders such as <ClusterName> or <ResourceGroupName> instead of real customer values.}

```powershell
<# Replace with the safe action command, if this step uses PowerShell. #>
{ActionCommand}
```

**Error handling and retry behavior:** {State ErrorAction or equivalent behavior, retry count, retry delay, and when a retry is unsafe.}

**Idempotency:** {State whether running this step more than once is safe and how the command checks existing state before changing it.}

**Expected result or output:** {Show the expected success message, table values, portal state, or command output shape.}

```text
{ExpectedOutput}
```

**Stop condition:** {State the exact output, error, state, or risk signal that means the reader must stop before continuing.}

**Rollback for this step:** {State how to undo this step if it fails or produces the wrong output. If no rollback exists, explain why and require approval before the action.}

**Expected rollback output:** {Show the output, state, or portal value that proves rollback ran.}

**Rollback verification:** {State the read-only command or UI surface that proves the previous state is restored.}

**Verification for this step:** {State how to prove this single step succeeded before moving to the next step.}

**Escalation:** {State who owns the next action if the step, rollback, or verification fails.}

### Step 2: {Next action description}

**Action type:** {Use [READ-ONLY] for diagnostics or information gathering and state that risk is not applicable because no state changes. Use state-changing when the action modifies configuration, data, resources, firmware, or workload state.}

**Risk label for state-changing action:** {Required only for state-changing actions. Choose one: [LOW RISK], [MEDIUM RISK], [HIGH RISK]. For [READ-ONLY], write "not applicable, no state changes."}

**Privilege required:** {Least-privilege role, RBAC assignment, local right, or tool access required for this step.}

**Workload impact and approval:** {State VM, app, live migration, network, security, and maintenance impact. State whether drain, reboot, maintenance approval, or workload-owner approval is required.}

**Purpose:** {Explain what this step changes or confirms.}

**Pre-check:** {Confirm the required state before this step.}

```powershell
<# Replace with a read-only pre-check command, if this step uses PowerShell. #>
{PreCheckCommand}
```

**Action:** {Give one clear action.}

```powershell
<# Replace with the safe action command, if this step uses PowerShell. #>
{ActionCommand}
```

**Error handling and retry behavior:** {State ErrorAction or equivalent behavior, retry count, retry delay, and when a retry is unsafe.}

**Idempotency:** {State whether running this step more than once is safe and how the command checks existing state before changing it.}

**Expected result or output:** {Show the expected output or state.}

```text
{ExpectedOutput}
```

**Stop condition:** {State when to stop and who to contact.}

**Rollback for this step:** {State how to undo this step or restore the previous state.}

**Expected rollback output:** {Show the output, state, or portal value that proves rollback ran.}

**Rollback verification:** {State the read-only command or UI surface that proves the previous state is restored.}

**Verification for this step:** {State how to prove this step succeeded.}

**Escalation:** {State who owns the next action if the step, rollback, or verification fails.}

## Rollback

Use this section if a step fails, the expected output does not match, the stop condition is reached, or the customer asks to return to the previous state.

| Rollback trigger | Rollback action | Expected result or output | Verification after rollback |
| --- | --- | --- | --- |
| {Trigger 1} | {Command or portal action to restore the previous state.} | {Expected rollback output.} | {How to prove rollback succeeded.} |
| {Trigger 2} | {Command or portal action to restore the previous state.} | {Expected rollback output.} | {How to prove rollback succeeded.} |

If rollback is not possible, replace this section with the explicit reason, the approval required before proceeding, and the support or escalation path.

## Verification

Run these checks after the final step and after any rollback. The guide is not complete until every pass criterion is met.

| Check | Command or UI surface | Expected result or output | Pass criteria | If it fails |
| --- | --- | --- | --- | --- |
| {Verification check 1} | {Command, portal page, or tool.} | {Expected output.} | {Exact values or state that prove success.} | {Rollback, retry, or escalation instruction.} |
| {Verification check 2} | {Command, portal page, or tool.} | {Expected output.} | {Exact values or state that prove success.} | {Rollback, retry, or escalation instruction.} |

## Expected output examples

Use examples with placeholders only. Do not include customer identifiers, subscription identifiers, tenant identifiers, secrets, tokens, or private links.

```text
{Command or portal surface}
Expected: {Expected success value, status, or message}
Unexpected: {Unexpected value, status, or message that triggers a stop condition}
```

## Troubleshooting

### {Common issue 1}

**Symptoms:** {What the reader sees.}

**Likely cause:** {Most likely cause, with evidence.}

**Action:** {Safe next step. If it is diagnostic, label it [READ-ONLY] and state risk is not applicable because no state changes. If it changes state, use the same action contract as the procedure: action type, risk label, privilege, workload or maintenance gate, pre-check, action, expected result or output, stop condition, rollback, expected rollback output, rollback verification, verification, and escalation.}

**Escalate when:** {Condition that requires Microsoft CSS, product group, OEM, network team, partner SI, or customer IT escalation.}

### {Common issue 2}

**Symptoms:** {What the reader sees.}

**Likely cause:** {Most likely cause, with evidence.}

**Action:** {Safe next step. If it is diagnostic, label it [READ-ONLY] and state risk is not applicable because no state changes. If it changes state, use the same action contract as the procedure: action type, risk label, privilege, workload or maintenance gate, pre-check, action, expected result or output, stop condition, rollback, expected rollback output, rollback verification, verification, and escalation.}

**Escalate when:** {Condition that requires escalation.}

## Handoff and escalation package

Create this package when a mis-assigned reader needs to hand off the case or when verification fails after rollback.

| Package item | Required detail |
| --- | --- |
| Summary | {One-line problem, impact, and current state.} |
| Owner requested | {Network, OEM, workload owner, Microsoft CSS, product group, partner SI, or customer IT.} |
| Evidence | {Logs, command outputs, portal screenshots, exact error text, and timestamps in UTC.} |
| Environment | {Product, supported version, cluster state, node count, hardware model if relevant, and tool versions.} |
| Actions already tried | {Pre-checks, actions, expected result, actual result, rollback status, and verification result.} |
| Escalation trigger | {The condition that proves the current reader should not continue.} |
| Redaction | {Customer identifiers, subscription identifiers, tenant identifiers, secrets, tokens, and private data removed.} |

## Evidence to collect

Collect enough evidence for support, audit, or PR review without exposing secrets or customer-private data.

| Evidence | Where to collect it | Redaction required | Why it matters |
| --- | --- | --- | --- |
| {Evidence item 1} | {Command, portal page, event log, component log, or public tool.} | {Values to redact.} | {How this confirms success or explains failure.} |
| {Evidence item 2} | {Command, portal page, event log, component log, or public tool.} | {Values to redact.} | {How this confirms success or explains failure.} |

## Claims and validation evidence

Use this table for mechanism statements, version requirements, safety claims, and rollback claims. Do not publish a technical claim without a source or validation status.

| Claim | Source or evidence | Tested status | Failure mode covered | Rollback proof |
| --- | --- | --- | --- | --- |
| {Technical claim 1} | {Public Microsoft documentation, command output, lab validation, or product source summary that supports the claim.} | {Not tested, static-reviewed, read-only validated, lab validated, or customer validated.} | {What can go wrong if the claim is false or incomplete.} | {How rollback was tested or why rollback is not available.} |
| {Technical claim 2} | {Public Microsoft documentation, command output, lab validation, or product source summary that supports the claim.} | {Not tested, static-reviewed, read-only validated, lab validated, or customer validated.} | {What can go wrong if the claim is false or incomplete.} | {How rollback was tested or why rollback is not available.} |

## Metadata vocabulary

Use these definitions when completing the metadata marker or the future test automation table. The public schema is [tsg-metadata.schema.json](../Templates/tsg-metadata.schema.json) for articles copied into a component folder under `TSG/<Component>/`. If the article is copied into a deeper folder, adjust the relative path so the link still reaches `TSG/Templates/tsg-metadata.schema.json`.

| Field or value | Definition |
| --- | --- |
| detector.type `none` | No detector has been selected. Set `detector.signal` to JSON `null`. When authors select a detector later, they must set `detector.type` and `detector.signal` together. |
| detector.type `command` | A read-only command or script detects the state. Set `detector.signal` to the command or function name. |
| detector.type `envchecker` | An Azure Local Environment Checker validation detects the state. Set `detector.signal` to the validator or check name. |
| detector.type `feature` | An installed Windows feature state detects the condition. Set `detector.signal` to the feature name. |
| detector.type `portal` or `manual` | A human checks a portal or manual surface. Set `detector.signal` to the exact blade, page, or manual check. |
| detector.type `eventlog`, `service`, `registry`, `telemetry`, or `control-plane` | A specific event, service state, registry value, telemetry query, or Azure control-plane state detects the condition. Set `detector.signal` to the exact signal. |
| fidelity level `L0` | Static review only. No live command or detector proof. |
| fidelity level `L1` | Read-only commands or verification steps were run and returned the claimed shape. |
| fidelity level `L2` | The detection signal and reversible remediation direction were validated with a safe proxy or synthetic input. |
| fidelity level `L3` | The real failure pattern was validated on an isolated scratch object or disposable target. |
| fidelity level `L4` | Full inject, detect, mitigate, and revalidate loop was proven end to end on a safe lab substrate. |
| technical_grade `null`, `A`, `B`, `C`, or `F` | Use JSON `null` until a TSG-FORGE grade exists. Use `A`, `B`, `C`, or `F` only when a grading artifact records that grade. This is separate from `fidelity_level`. |
| safe injectability `none` | No safe inject is known. Keep fidelity at L0 or L1 unless read-only validation exists. |
| safe injectability `proxy` | A safe substitute input exercises the same decision logic without causing the real failure. |
| safe injectability `scratch object` | A temporary object, such as a test resource or file, carries the failure and can be deleted. |
| safe injectability `reversible lab-only change` | A lab change can be undone and is not suitable for customer production. |
| safe injectability `destructive` | The action is not safely reversible. Do not use it for live validation without explicit approval and a disposable target. |
| automation_status `not-assessed` | No automation assessment has been performed. |
| automation_status `scaffold` | Metadata exists, but the detector or automation is not ready to run. |
| automation_status `ready` | Automation is defined and ready to run, but not yet proven. |
| automation_status `proven` | Automation has passed validation and cites evidence. |
| automation_status `blocked` | Automation is blocked by safety, access, substrate, or product limitations. |
| automation_status `manual` | Validation remains manual by design. |
| Execution surface | Where an action runs: `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, or `thin`. Do not put execution-surface values in `automation_status`. |

## Future test automation metadata

Complete this section so TSG-FORGE or another validation harness can evaluate this How-To later.

| Field | Required author input |
| --- | --- |
| Metadata schema | Link to [tsg-metadata.schema.json](../Templates/tsg-metadata.schema.json). Adjust the relative path if the article is copied into a deeper folder. |
| Automation candidate | {yes, no, or partial. Explain why.} |
| detector.type | {Choose the exact JSON detector type: none, command, control-plane, envchecker, eventlog, feature, manual, portal, registry, service, or telemetry. Use the adjacent explanation columns or notes for plain-language validation-surface details.} |
| Automation status | {Choose one: not-assessed, scaffold, ready, proven, blocked, or manual. Do not use execution-surface values here.} |
| Technical grade | {Use null until graded, or A, B, C, or F after a TSG-FORGE grading artifact exists.} |
| Safe injectability | {none, proxy, scratch object, reversible lab-only change, or destructive.} |
| Rollback automation | {How rollback could be automated and what state it restores.} |
| Reproduction substrate | {Choose one: none, vm, hardware, or either. Use none with automation_status manual when validation is intentionally manual.} |
| Target fidelity level | {L0, L1, L2, L3, or L4.} |
| validation.last_validated | {Use JSON null until validation has run. After validation, use the ISO date in YYYY-MM-DD format and cite the report, spec, or evidence.} |
| Validation history | {Date, build, substrate, result, and evidence link when available.} |
| Spec reference | {Path to future companion spec, if one exists.} |

## Next steps

After verification passes, state what happens next so the work is closed cleanly.

| Next step | Required author input |
| --- | --- |
| Monitor | {Signals, logs, portal surfaces, or customer symptoms to watch after completion, and for how long.} |
| Close or hand back | {Who accepts the result, what evidence they receive, and how the task is closed or returned to the owning team.} |
| Follow-up work | {Any deferred cleanup, documentation, ticket update, support handoff, or future automation item.} |
| Customer update | {Plain-language completion note, remaining risk, and next update cadence if monitoring continues.} |

## References

Add only public Microsoft links, such as:

- [Azure Local documentation](https://learn.microsoft.com/azure/azure-local/)
- {Public Microsoft documentation link for this task}
