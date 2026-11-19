<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
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

# {Issue title}

Use this template for Azure Local troubleshooting guides. Replace all placeholders in braces before publishing. Keep all actions production-safe, use public Microsoft links only, and test every command example.

## Table of contents

- [Article metadata](#article-metadata)
- [Executive triage summary](#executive-triage-summary)
- [Symptoms and scope](#symptoms-and-scope)
- [Terms to define before publishing](#terms-to-define-before-publishing)
- [Where this appears](#where-this-appears)
- [Preconditions and stop gates](#preconditions-and-stop-gates)
- [Diagnosis](#diagnosis)
- [Contributing factors and evidence](#contributing-factors-and-evidence)
- [Mitigation](#mitigation)
- [Rollback](#rollback)
- [Verification](#verification)
- [Escalation and evidence package](#escalation-and-evidence-package)
- [Prevention and monitoring](#prevention-and-monitoring)
- [Future test automation metadata](#future-test-automation-metadata)
- [Related documentation](#related-documentation)

## Article metadata

| Field | Value |
| --- | --- |
| Component | {Component name} |
| Applicable products | {Azure Local products, services, or features that this guide applies to} |
| Supported versions | {Supported Azure Local releases, OS builds, solution versions, or Solution Builder Extension (SBE) versions} |
| Audience | {Primary reader, such as customer IT admin, Microsoft Customer Support Services (CSS) engineer, OEM field engineer, partner or systems integrator (SI) deployment engineer, or workload owner} |
| Applicable scenarios | {Deployment, update, add node, upgrade, steady state, or workload operation} |
| Severity | {Critical, high, medium, or low, with a short rationale} |
| Customer impact | {VM impact, update blocked, deployment blocked, degraded redundancy, monitoring only, or none} |
| Primary owner | {Customer IT, Microsoft Customer Support Services (CSS), product group, OEM, partner, or systems integrator (SI)} |
| Execution surface | {on-device, mixed, cloud-diagnostic, cloud-control, or thin} |
| Risk summary | {Highest expected mitigation risk and whether a maintenance window is needed} |

## Executive triage summary

| Question | Answer |
| --- | --- |
| What is broken? | {One sentence symptom summary} |
| Who should act? | {Role or team that should run the guide} |
| Fastest safe next action | {The first read-only check to run} |
| Estimated duration | {Expected time to diagnose and mitigate} |
| Downtime or workload risk | {None, possible, expected, or unknown, with reason} |
| Escalate immediately if | {Condition that requires CSS, product group, OEM, or partner help} |

## Symptoms and scope

Describe exactly what the operator or customer sees. Include enough detail to distinguish this issue from similar storage, network, update, Arc, OEM, or workload issues.

| Prompt | Details |
| --- | --- |
| Exact error text | {Paste the exact error, status code, Event ID, health fault, validator result, or portal message} |
| First observed time | {UTC timestamp or approximate time window} |
| Affected resources | {Cluster, node names, volumes, adapters, VMs, Arc Resource Bridge, AKS clusters, or update run} |
| Customer or workload impact | {What workloads, VMs, deployment steps, or update steps are affected} |
| Recent changes | {Updates, firmware changes, network changes, policy changes, node maintenance, or none known} |
| Explicitly not affected | {Resources or operations checked and found healthy} |

**Common error messages:**

```text
{Error message example}
```

**Observable behaviors:**

- {Symptom 1 with affected surface and timestamp}
- {Symptom 2 with affected surface and timestamp}
- {Symptom 3, if applicable}

## Terms to define before publishing

Define acronyms, Azure Local objects, command names, and component names that a first-time reader must understand before following the guide. Keep definitions short and action-oriented.

| Term | Plain-language definition | Why the reader needs it |
| --- | --- | --- |
| {Acronym or product object} | {Short definition using customer-facing language} | {Decision, command, or safety gate that depends on this term} |
| {Safety term, such as quorum, detached virtual disk, or degraded redundancy} | {What the state means and how to recognize it} | {Why it changes the stop condition, risk label, or rollback path} |
| {Cmdlet, portal blade, Event ID, or log name} | {What it is and where the reader sees it} | {How it is used in diagnosis, mitigation, rollback, or verification} |

## Where this appears

For each surface, record whether the issue is `shown`, `not-evident`, or `absent`. `absent` means the surface has not been characterized yet and is not publish-ready. Do not use `not checked` in a final article. Keep Windows Admin Center (standalone host) separate from Windows Admin Center in Azure, which means Windows Admin Center in the Azure portal. The final row covers component or tool log files on disk.

| State | Evidence bar |
| --- | --- |
| shown | The surface displays the issue now. Include the exact command, blade, log, Event ID, path, timestamp, or output. |
| not-evident | The surface was checked for the relevant time window, but no matching signal was found or the issue is not expected there. Include what was checked, the time window or freshness proof, and why that surface is not useful. |
| absent | The surface has not been characterized yet. Treat this as a draft work item, not a publish-ready value. |

| Admin surface | Status | Evidence to capture |
| --- | --- | --- |
| PowerShell on an Azure Local node | {shown, not-evident, or absent} | {Cmdlet name, command output, health fault, validator result, or reason it is not-evident} |
| Azure portal | {shown, not-evident, or absent} | {Azure Local, Arc, Updates, Resource Health, or other blade and the visible status} |
| Windows event logs | {shown, not-evident, or absent} | {Log name, provider, Event ID, level, timestamp, and message excerpt} |
| Cluster logs using Get-ClusterLog | {shown, not-evident, or absent} | {Cluster log channel, timestamp, resource, or reason it is not-evident} |
| Windows Failover Cluster Manager | {shown, not-evident, or absent} | {Failed role, resource, node, network, storage object, or reason it is not-evident} |
| Windows Admin Center (standalone host) | {shown, not-evident, or absent} | {Tool page, status, alert, or reason it is not-evident} |
| Windows Admin Center in the Azure portal | {shown, not-evident, or absent} | {Tool page, status, alert, or reason it is not-evident} |
| Component / tool log files (on disk) | {shown, not-evident, or absent} | {Component or tool log files path, on-disk log path, .AzStackHci report, diagnostic log file, timestamp, and message excerpt} |

## Preconditions and stop gates

Complete these checks before any mitigation. If a stop condition is met, do not continue with state-changing steps until the condition is resolved or the case is escalated.

| Gate | Pre-check | Expected result or output | Stop condition | Owner |
| --- | --- | --- | --- | --- |
| Permissions | {Command or portal check for required role or local admin rights} | {Required role or privilege is present} | {Required privilege is missing} | {Customer IT, Microsoft CSS, OEM, partner, or product group} |
| Workload safety | {Check VM state, owner node, redundancy, or maintenance window} | {Workloads can tolerate the action or are drained} | {Critical workload cannot be moved or protected} | {Workload owner} |
| Cluster health | {Read-only command to confirm quorum, node, storage, and network health} | {Cluster is stable enough for the action} | {Quorum risk, meaning not enough voting members to keep the cluster online; node down; detached virtual disk, meaning disconnected from storage; or degraded redundancy, meaning fewer healthy copies than policy requires} | {Cluster admin} |
| Recovery material | {Check backups, BitLocker recovery keys, snapshots, or configuration export when applicable} | {Recovery material is available and current} | {Recovery material is missing for a risky action} | {Customer IT} |
| OEM or firmware readiness | {Check model, firmware, BIOS, BMC, driver, or qualified configuration when applicable} | {Prerequisites are met or not applicable} | {OEM prerequisite is unmet or unclear} | {OEM or partner} |

## Diagnosis

Run diagnosis before mitigation. Prefer read-only commands. Each diagnosis branch must include expected healthy output, expected affected output, and the mitigation path it authorizes.

| Step | Pre-check | Action | Expected healthy output | Expected affected output | Stop condition | Next branch |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | {Confirm the target resource and time window} | {Run read-only diagnostic command or portal check} | {Healthy output} | {Affected output} | {Output does not match this TSG, or target is wrong} | {Mitigation step, more diagnosis, or escalation} |
| 2 | {Confirm the first result with an independent surface} | {Run second diagnostic command, log query, or portal check} | {Healthy output} | {Corroborating affected output} | {Contradictory evidence or stale data} | {Mitigation step, more diagnosis, or escalation} |
| 3 | {Run the disproving check for the leading diagnosis} | {Command or check that would prove a different cause} | {No disproof found} | {Disproof found} | {Disproof found, do not run this mitigation} | {Alternate TSG or escalation} |

```powershell
# Example read-only diagnosis command. Replace with the exact command for this issue.
{Read-only diagnosis command}
```

## Contributing factors and evidence

Use blameless language. Do not assign human error or state a single root cause unless the evidence proves it. Every causal statement must cite the evidence that supports it.

| Evidence label | Contributing factor or observation | Source | Why it matters |
| --- | --- | --- | --- |
| CONFIRMED | {Directly observed fact} | {Command, log, portal blade, table, file path, Event ID, or output value} | {Impact on the issue} |
| INFERRED | {Reasoned conclusion from confirmed evidence} | {Specific confirmed facts used as the basis} | {Why the inference is justified} |
| UNVERIFIABLE | {Claim that cannot be proven from available sources} | {Missing data, tool, log, access, or time window} | {Smallest next step to close the gap} |

**Disproving check:** {Name the one command, log, or fact that would disprove the leading diagnosis. State whether it was checked.}

## Mitigation

Only run a mitigation after the matching diagnosis branch is satisfied and the preconditions are met. Use [READ-ONLY] for diagnostic or verification actions that do not change state; risk is not applicable because no state changes. Reserve the canonical risk labels for state-changing steps: [LOW RISK], [MEDIUM RISK], or [HIGH RISK].

| Step | Action type or risk label | Privilege | Workload or maintenance gate | Pre-check | Action | Expected result or output | Stop condition | Rollback | Rollback verification | Escalation if blocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [READ-ONLY] | {Required role or local right to read state} | {Risk not applicable because no state changes; no maintenance window required} | {Read-only check that confirms this step applies} | {Diagnostic or verification action that does not change state} | {Expected output} | {Condition that stops the step} | {Not applicable because no state changes} | {Not applicable because no state changes} | {Owner to contact if blocked} |
| 2 | [MEDIUM RISK] | {Required role or local right} | {Maintenance window, workload drain, or owner approval required} | {Check workload, cluster, and permission prerequisites} | {State-changing command or portal action} | {Expected output} | {Condition that stops the step before or during execution} | {Command or procedure that restores the prior state} | {Expected rollback output and command or surface that confirms rollback} | {Owner to contact if blocked} |
| 3 | [HIGH RISK] | {Required role or local right} | {Explicit maintenance window, recovery material, redundancy, and escalation approval required} | {Explicit maintenance window, recovery material, redundancy, and escalation approval check} | {High-risk action, if this TSG truly requires one} | {Expected output} | {Any unmet safety gate, unexpected output, or customer impact} | {Exact rollback or vendor-supported recovery path} | {Expected rollback output and post-rollback health validation} | {CSS, product group, OEM, partner, or SI escalation path} |

```powershell
# Pre-check
{Pre-check command}

# Action
{Mitigation command}

# Verification
{Verification command}
```

Run the rollback block below **only** if a stop condition was met or the verification failed. Do not run it after a successful mitigation, or it will undo the change before final verification.

```powershell
# Rollback (run ONLY if a stop condition was met or the verification failed)
{Rollback command}

# Rollback verification
{Rollback verification command}
```

## Rollback

Every state-changing mitigation step must have a rollback plan. If rollback is not possible, state that clearly, label the step [HIGH RISK], and require escalation before the action.

| Mitigation step | Trigger to roll back | Rollback action | Expected rollback output | Verification after rollback |
| --- | --- | --- | --- | --- |
| {Step number or name} | {Unexpected result, customer impact, timeout, or operator decision} | {Rollback command or portal action} | {Expected output} | {Command, portal status, log, or workload check} |

```powershell
# Rollback example. Replace with the exact rollback for this issue.
{Rollback command}
```

## Verification

Verify both technical recovery and customer impact recovery. Include timing, because some surfaces update only after a scheduled health check or refresh.

| Verification target | Command or surface | Expected success criteria | If it does not pass |
| --- | --- | --- | --- |
| Original detector | {Validator, cmdlet, Event ID, portal blade, or tool log} | {Bad signal is cleared or expected status is present} | {Repeat diagnosis, roll back, or escalate} |
| Cluster health | {Cluster, storage, network, update, or Arc health command} | {Cluster is stable and no new critical health signal appeared} | {Stop and escalate with evidence package} |
| Workloads | {VM, application, live migration, or customer validation check} | {Workloads are healthy or customer confirms recovery} | {Engage workload owner and preserve evidence} |
| Admin surfaces | {Portal, Windows Admin Center, event logs, cluster logs, and component logs as applicable} | {Surfaces show healthy state or documented lag} | {Record lag or unresolved signal and continue diagnosis} |
| Rollback readiness | {Check that rollback is still available or no longer needed} | {Rollback path remains available until success is confirmed} | {Do not close the case} |

```powershell
# Re-run the primary verification command.
{Final verification command}
```

## Escalation and evidence package

Escalate when diagnosis is inconclusive, a stop gate is met, mitigation risk is unacceptable, the issue recurs, or the guide points to a product group, OEM, partner, or Microsoft CSS owner.

| Escalation target | Escalate when | Evidence to include |
| --- | --- | --- |
| Microsoft CSS | {Customer needs assisted support, diagnosis is inconclusive, or mitigation fails} | {Symptoms, timestamps, commands, outputs, logs, Event IDs, portal screenshots, and impact statement} |
| Product group | {Confirmed product defect, unsupported state, repeated failure, or telemetry gap} | {CONFIRMED and INFERRED evidence, build versions, repro steps, and failed mitigation details} |
| OEM vendor | {Firmware, driver, BIOS, BMC, model support, hardware fault, or qualified configuration issue} | {Model, serial or asset identifiers as appropriate, firmware and driver versions, logs, and hardware diagnostics} |
| Partner or SI | {Deployment design, site-specific configuration, cabling, switch, identity, or policy ownership issue} | {Topology, configuration, change history, and exact failed step} |

Before sharing externally, remove secrets, tokens, private keys, and unnecessary personal data.

## Prevention and monitoring

Use prevention guidance to reduce recurrence without blaming the person who operated the system.

- {Monitoring or alert that detects recurrence}
- {Pre-update, pre-deployment, or maintenance check that catches the issue early}
- {Version, firmware, policy, or configuration guidance that reduces recurrence}
- {Owner and cadence for review}

## Future test automation metadata

Complete this section so the TSG can be graded and improved by TSG-FORGE later. Keep the metadata marker aligned with the canonical [TSG metadata JSON Schema](../Templates/tsg-metadata.schema.json).

| Field | Value |
| --- | --- |
| Detector type | {none, envchecker, eventlog, command, service, feature, registry, telemetry, manual, portal, or control-plane} |
| Detector signal | {Cmdlet, Event ID, telemetry query, portal path, log path, or JSON null when Detector type is none} |
| Inject strategy | {Reversible inject, proxy inject, scratch object, read-only validation, manual validation, or not safe to inject} |
| Mitigation selector | {Marker, section, command, portal action, or manual procedure that identifies the mitigation block} |
| Safety floor | {Minimum free space, quorum, redundancy, recovery material, or other floor that prevents harm} |
| Rollback check | {Command or surface proving rollback restored prior state} |
| Reproduction substrate | {vm, hardware, either, or none} |
| Fidelity level | {L0, L1, L2, L3, or L4} |
| Technical grade | {JSON null until TSG-FORGE produces A, B, C, or F from report or spec evidence} |
| Automation status | {not-assessed, scaffold, ready, proven, blocked, or manual} |
| Spec reference | {Path to companion spec, if one exists} |
| Last validated | {JSON null until validation exists, then YYYY-MM-DD} |

When `Detector type` is `none`, set `detector.signal` in the metadata marker to JSON `null`. When you select any other detector type, set both `detector.type` and `detector.signal` together. Set `validation.technical_grade` to JSON `null` until TSG-FORGE report or spec evidence produces A, B, C, or F.

Execution surface and automation status are different fields. Execution surface describes where the article can run and must use on-device, mixed, cloud-diagnostic, cloud-control, or thin. Automation status describes the TSG-FORGE readiness of the test harness and must use not-assessed, scaffold, ready, proven, blocked, or manual.

| Metadata value | Meaning |
| --- | --- |
| Detector `none` | No automated detector is defined yet. Use JSON `null` for `detector.signal`. |
| Detector `envchecker` | Azure Local Environment Checker or readiness check output is the signal. |
| Detector `eventlog` | A Windows event log, provider, and Event ID are the signal. |
| Detector `command`, `service`, `feature`, or `registry` | A command result, service state, Windows feature state, or registry value is the signal. |
| Detector `telemetry`, `manual`, `portal`, or `control-plane` | A fleet signal, human-observed state, portal blade, or Azure control-plane state is the signal. |
| Execution surface `on-device` | The article can be executed by on-box commands on an Azure Local node. |
| Execution surface `mixed` | The article combines on-device steps with connected portal, Azure control-plane, or cloud diagnostics. |
| Execution surface `cloud-diagnostic` | The article depends on cloud or telemetry diagnostics and is not runnable only on the node. |
| Execution surface `cloud-control` | The article changes or verifies Azure control-plane state, such as portal or ARM state. |
| Execution surface `thin` | The article has context only and no executable diagnostic or mitigation path yet. |
| Inject strategy `reversible inject` | The harness creates a real bad state and can restore the prior state automatically. |
| Inject strategy `proxy inject` | The harness feeds controlled input to the real detector without causing the unsafe production failure. |
| Inject strategy `scratch object` | The harness tests with an isolated temporary object, such as a test VM, test file, or scratch resource. |
| Inject strategy `read-only validation` or `manual validation` | The harness validates diagnostics only, or a human must verify the state. |
| Inject strategy `not safe to inject` | No safe or reversible inject exists for this issue. Validate diagnostics only and set automation_status to blocked or manual until a safe proof path exists. |
| Fidelity `L0` | Static lint, metadata, and persona review only. |
| Fidelity `L1` | Read-only diagnostic commands were validated. |
| Fidelity `L2` | A safe proxy or synthetic data source exercised the detector or decision logic. |
| Fidelity `L3` | An isolated scratch object exercised the failure and recovery path. |
| Fidelity `L4` | Full live loop was proven: inject, detect, mitigate, revalidate, and clean up. |
| Technical grade `null` | No TSG-FORGE technical grade has been produced yet. |
| Technical grade `A`, `B`, `C`, or `F` | Authoritative technical grade from TSG-FORGE report or companion spec evidence. Do not invent a separate grade vocabulary. |
| Automation `not-assessed` | No automation review has been performed. |
| Automation `scaffold` | Metadata exists, but runnable automation is incomplete. |
| Automation `ready` | Automation is ready to run but not yet proven. |
| Automation `proven` | Automation has run and passed at the stated fidelity. |
| Automation `blocked` | Automation is designed but blocked by safety, access, or substrate limits. |
| Automation `manual` | The article intentionally requires human validation rather than automation. |

## Related documentation

Use public Microsoft links only. Do not include version-specific query strings in Microsoft Learn URLs.

- {Public Microsoft documentation link}
- {Related public Azure Local TSG link, if available}
