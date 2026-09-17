---
ArticleType: "TSG"
Article_ID: "20260917160005"
Title: "AzStackHci_SBEHealth_Test-Endpoint-Matches-ModelSKU"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: "Solution Builder Extension"
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: "ADO Work Item"
  ID: 38357077
Tags: ["Validation", "Solution Update", "SBE", "Firmware", "Driver"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory PickleFactory metadata, audience scoping, and current article layout without changing technical guidance. |

:::

# AzStackHci_SBEHealth_Test-Endpoint-Matches-ModelSKU

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Endpoint-Matches-ModelSKU</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">ArticleType</th>
    <td><code>TSG</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><code>['Engineering', 'CSS', 'OEM Partners', 'External']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.Product</th>
    <td><code>Azure Local</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.OEM</th>
    <td><code>['All']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Solution Builder Extension manifest matches hardware model and SKU ("Validate SBE manifest matches hardware model, sku")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-Endpoint-Matches-ModelSKU</code> (implemented by <code>Get-ManifestMatchesModelandSKUResult</code>, an SBE health check emitted during pre-update validation)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Informational</strong>: this check reports whether the SBE manifest at your configured endpoint lists this server's model and SKU, but it does <strong>not</strong> block the update. A failure still means this hardware would not receive SBE updates from that endpoint and should be resolved.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>The current update and running VMs are not blocked by this check. Until it is corrected, an affected node may miss partner firmware and driver content from the override endpoint, which can leave the platform behind on hardware fixes and complicate later servicing.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The owner of the custom SBE endpoint decides whether the override should remain. The OEM or SBE publisher owns a manifest change when the endpoint is intentional but omits supported hardware.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Read-only triage and a fresh validation normally take about 10-20 minutes. Resetting an unneeded override is usually a 15-30 minute change once its owner approves it. An OEM manifest republish is an external dependency; plan 1-5 business days unless the partner's published SLA is different.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>When a <strong>custom (override) SBE update endpoint</strong> is configured, the Solution Builder Extension (SBE) manifest published at that endpoint must list this server's hardware <strong>model</strong> (and, where restricted, its <strong>SKU</strong>) among its supported models.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Pre-update SBE health validation (update readiness). Only evaluated when the SBE endpoint is an <strong>override</strong> that differs from the default; a default endpoint skips this check.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Quick fix

If you just want the short version: this check failed because you have a **custom (override) SBE
update endpoint** configured, and the SBE manifest at that endpoint does **not** list this server's
hardware model (or its SKU). Either the override endpoint is wrong for this hardware, or the
manifest there is missing this model. First record the endpoint and obtain explicit confirmation
from the owner of that custom endpoint that it is no longer required. Resetting it changes the
discovery source for the whole cluster, not only the node that reported the failure. With that
confirmation, **reset to the default endpoint** with
`Set-OverrideUpdateConfiguration -ResetDefaultOemUpdateUri`, then re-run the pre-update health
check. If the override is intentional, keep it and have the OEM or SBE publisher add the model
and SKU to the manifest instead. Full detail and how to verify the fix are below.

## Impact and decision guide

| Path | What changes | Planning estimate | Owner and risk |
| --- | --- | --- | --- |
| Keep the intentional override and correct its manifest | The endpoint stays in place; the OEM publishes a manifest that admits every affected node model and SKU. | 15-30 minutes to collect evidence and re-run validation, plus partner release time, typically 1-5 business days. | Endpoint owner and OEM. [LOW RISK] to the running cluster, but future SBE servicing remains incomplete until the manifest is published. |
| Reset an override that is no longer needed | The whole cluster returns to the Microsoft-hosted default discovery endpoint. | About 15-30 minutes after owner approval, including revalidation. | Endpoint owner or authorized cluster administrator. [MEDIUM RISK] because it discards an intentional custom source if approval was skipped, although it does not restart nodes or move VMs. |
| Endpoint cannot be reached | The node cannot retrieve the manifest, so model/SKU matching is not yet the right diagnosis. | Network or proxy owner estimates the repair. | Network or proxy owner. [LOW RISK] to investigate; use the connectivity guide before changing model/SKU configuration. |

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content that ships alongside
the Azure Local solution. The SBE content is published at a **manifest endpoint**. By default that
endpoint is a Microsoft-hosted `aka.ms` URL that redirects to your vendor's content; some
environments instead configure a **custom (override) endpoint** (for example to serve SBE content
from an internal location).

The SBE manifest lists the hardware **models** (and optionally the **SKUs**) it supports. This
check confirms that, when an override endpoint is in use, the manifest published there actually
lists **this** server's model and SKU, so this hardware can receive SBE updates from that endpoint.
The outcome is one of:

- **SUCCESS (matched).** The manifest lists this server's model (and SKU). The detail reads *"The
  current SBE discovery manifest endpoint ... has matching entries for the server model ... and
  SKU ..."*.
- **SUCCESS (skipped).** The SBE endpoint is the **default** (not an override). The check does not
  compare model/SKU in that case, because Microsoft does not advise changing from the default, so
  it is a benign skip.
- **FAILURE.** An override endpoint is configured, but its manifest does **not** list this server's
  model (or the model is present but the SKU is excluded). The detail reads *"System model '...' is
  not supported by SBE. Supported models: ..."*, and the remediation is to confirm the override is
  correct for this hardware or reset to the default.

This check is **Informational**: a failure does **not** block the deployment or update. It is an
early warning that this hardware would not get SBE updates from the configured endpoint, so it
surfaces the mismatch now while it is easy to fix. The practical workload impact is delayed access
to partner firmware and driver updates, not an immediate VM outage or update gate.

### Boundary with endpoint connectivity

`Test-Endpoint-Connectivity` and `Test-Endpoint-Matches-ModelSKU` answer different questions:

- **Connectivity:** can the node reach the configured SBE endpoint over HTTPS and receive a
  usable response? If the request fails, returns an error, or never reaches the manifest, use
  [Troubleshooting SBE Health: SBE Manifest Endpoint Connectivity](./Troubleshooting-SBEHealth-Test-Endpoint-Connectivity.md)
  and involve the network or proxy owner.
- **Model/SKU matching:** after the manifest is available, does its content admit this node's
  model and SKU? A connectivity failure is not evidence of a model mismatch, and changing a
  firewall rule will not add a missing `SupportedModel` entry.

If both checks appear in the same validation run, resolve reachability first and then re-run this
content check so that its result is based on the manifest that the node actually retrieved.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / update-configuration task, owned by
  whoever configured the custom SBE endpoint, together with the **hardware partner (OEM)** whose
  manifest lists the supported models. It is **not** a generic Windows task and **not** a
  networking task.
- **This is safe to investigate read-only.** Reading the check result, the event log, the
  configured endpoint, and this server's model/SKU changes nothing.
- **It does not restart nodes or bounce running workloads.** This is a pre-update validation
  signal, not a runtime operation. Reading the check, and either correcting the override endpoint or
  resetting it to the default, do not restart cluster nodes or move running VMs.
- **Resetting the endpoint requires owner confirmation.** `Set-OverrideUpdateConfiguration
  -ResetDefaultOemUpdateUri` is supported and returns SBE update discovery to the Microsoft-hosted
  default, but it changes the endpoint for the whole cluster. Confirm with the owner of the
  custom endpoint that it is no longer deliberate before running it. If ownership or intent is
  unknown, stop and escalate rather than silently discarding an internal update source.

## Where this failure appears

You can see this failure in two places, the Azure portal and the node itself.

### In the Azure portal

When you run update readiness (or update validation) from the portal, the validation phase runs
the Environment Checker and surfaces SBE health results on the cluster's **Updates** view. A failed
`Test-Endpoint-Matches-ModelSKU` appears there under the SBE health checks with the "Validate SBE
manifest matches hardware model, sku" title and the "not supported by SBE" detail.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event log as
the JSON body of an **Event ID 17205** entry, and to the cluster-wide `HealthCheckResult.*.json` on
the infrastructure share. Read this check's most recent result on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-Endpoint-Matches-ModelSKU*' } |
    Select-Object -First 1 Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}}
```

The `Name` on the node carries a domain prefix (`AzStackHci_SBEHealth_`) and can carry a node
suffix, so the query uses `-like '*Test-Endpoint-Matches-ModelSKU*'` (leading and trailing wildcard)
to match it. In this JSON the human-readable status and message live under `AdditionalData` (the
top-level `Status` and `Severity` are numeric enums, and the top-level `Description` is a generic
check description), which is why the query projects `AdditionalData.Status` and
`AdditionalData.Detail`. When the model/SKU is not supported, `AdditionalData.Status` is `FAILURE`
and `AdditionalData.Detail` reads *"System model '...' is not supported by SBE. Supported models:
..."*, listing the models the manifest does support (so you can see whether this server's model is
simply absent).

The event result is the authoritative record of what the validator compared. The registry command
in step 1 is an operator readback used to compare that identity with the failure detail. If the
registry values and the model or SKU named by the check do not agree, do not normalize or guess;
include both outputs when escalating because the discrepancy may be a source or normalization
problem.

For a mixed-hardware cluster, collect the same evidence from every node before deciding that the
manifest is correct. This fan-out preserves the human-readable `AdditionalData.Status` and
`AdditionalData.Detail` fields and does not change the endpoint, manifest, or node state:

```powershell
# Run from a cluster node with remoting access to the other cluster nodes.
$nodes = Get-ClusterNode | Select-Object -ExpandProperty Name

$perNode = foreach ($node in $nodes) {
    Invoke-Command -ComputerName $node -ScriptBlock {
        $hardware = [pscustomobject]@{
            Node  = $env:COMPUTERNAME
            Model = Get-ItemPropertyValue -Path 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -Name 'SystemProductName'
            SKU   = Get-ItemPropertyValue -Path 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -Name 'SystemSKU'
        }

        $check = Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
            ForEach-Object { $_.Message | ConvertFrom-Json } |
            Where-Object { $_.Name -like '*Test-Endpoint-Matches-ModelSKU*' } |
            Select-Object -First 1 Name,
                @{n='Status';e={$_.AdditionalData.Status}},
                @{n='Detail';e={$_.AdditionalData.Detail}}

        if ($check) {
            $status = $check.Status
            $detail = $check.Detail
        }
        else {
            $status = 'NO RESULT'
            $detail = 'No matching-check result was found in the last 2000 events'
        }

        [pscustomobject]@{
            Node   = $hardware.Node
            Model  = $hardware.Model
            SKU    = $hardware.SKU
            Status = $status
            Detail = $detail
        }
    } -ErrorAction Stop
}

$perNode | Sort-Object Node | Format-Table -Wrap -AutoSize
```

If the rows show different models or SKUs, evaluate each node against the manifest. One matching
node does not prove that every node is supported, and a `NO RESULT` row is a data gap that should
be collected again or included in the escalation package.

### In cluster result files and management tools

The cluster-wide `HealthCheckResult.*.json` files on the infrastructure share carry the same
check result when the cluster-wide health check has run. Search for
`Test-Endpoint-Matches-ModelSKU` and use `AdditionalData.Status` and `AdditionalData.Detail` there
as well.

### Where this failure does not appear

- **Cluster logs (`Get-ClusterLog`):** this SBE content result does not appear as a
  failover-cluster event. Use Event ID 17205 or the Environment Checker artifacts instead.
- **Windows Failover Cluster Manager:** this result does not appear in `cluadmin.msc`; it is an
  Environment Checker result, not a clustered role or resource state.
- **Windows Admin Center on a standalone host:** this result does not appear as a standalone WAC
  health signal. Use the node event and Environment Checker artifacts.
- **Windows Admin Center in the Azure portal:** this result does not appear in the WAC blade. Use
  the Azure Local Updates view described above.
- **Component / tool log files:** the Environment Checker component logs and reports can carry the
  result. On the node that ran validation, check
  `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and the matching
  `AzStackHciEnvironmentReport.json` or `.xml` for `Test-Endpoint-Matches-ModelSKU`.

## Troubleshooting Steps

> **First, confirm you even have an override endpoint.** This check only fails when a **custom
> (override)** SBE endpoint is configured; on the default Microsoft-hosted endpoint it skips and you
> would never see this failure. If step 2 below shows you are on the default endpoint, this check is
> not the issue and no model/SKU change is needed. Throughout, **SKU** means a hardware sub-variant /
> configuration code that distinguishes builds of the same server model.

### 1. Read this server's model and SKU

The check compares the manifest against the values Azure Local reads for this server. Read the same
values so you know what the manifest must list:

```powershell
[pscustomobject]@{
    Model = (Get-ItemPropertyValue -Path 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -Name 'SystemProductName')
    SKU   = (Get-ItemPropertyValue -Path 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -Name 'SystemSKU')
}
```

Note the exact model and SKU strings. The failure detail (`AdditionalData.Detail`, from the step in
**Where this failure appears**) also lists the models the manifest currently supports, so compare
that list against this model.

**This is per server.** Model and SKU are read per node, so on a **mixed-hardware cluster** some
nodes may match the manifest while others do not. Check each node's model and SKU against the
manifest, not only the node that flagged, so you catch every affected server.

### 2. Confirm the configured SBE endpoint (and whether it is an override)

This check only fails when a **custom (override)** endpoint is configured, so confirm what the
cluster is using:

```powershell
(Get-SolutionDiscoveryDiagnosticInfo).Configuration.ComponentUris["SBE"]
```

`ComponentUris["SBE"]` is the SBE manifest endpoint the validator reads. If it is the default Microsoft-hosted
`aka.ms/AzureStackSBEUpdate/<vendor>` URL, this check would have skipped; a FAILURE means the
endpoint is an override that differs from the default.

### 3. Choose the owner-approved fix

Do not edit the check. Use the per-node report to choose one of the following paths.

#### 3a. Operator decision: keep the override or reset it

- **The override is intentional:** keep it, confirm the endpoint is correct for every affected
  node, and ask the OEM or SBE publisher to update the manifest as described in step 3b.
- **The override is not needed or was set in error:** first record the current endpoint and get
  explicit confirmation from its owner that it may be removed. Then, as an authorized cluster
  administrator, reset SBE update discovery to the Microsoft-hosted default:

  ```powershell
  Set-OverrideUpdateConfiguration -ResetDefaultOemUpdateUri
  ```

Do not run the reset solely because it is a one-line command. It changes the source used by the
whole cluster and can silently discard an intentional internal or partner-managed endpoint.

#### 3b. OEM or SBE publisher: update the manifest

For an intentional override, the manifest lists supported hardware as `SupportedModel` entries
under `ApplicableUpdate/UpdateInfo/SupportedModels`, each optionally carrying `SupportedSKUs` and
`NotSupportedSKUs` as semicolon-separated values. The matching semantics are:

- The server model is compared with non-word characters stripped and as a **prefix match**. The
  server model must start with a listed `SupportedModel` value.
- SKU support is then governed by the matched model's `SupportedSKUs` and `NotSupportedSKUs`.
  With neither attribute present, that model entry has no SKU restriction.
- If `SupportedSKUs` is present, the server SKU must be in that semicolon-separated allow-list.
  A value in `NotSupportedSKUs` is excluded even when the model prefix matches.

The following is an illustrative fragment using those element and attribute names:

```xml
<ApplicableUpdate>
  <UpdateInfo>
    <SupportedModels>
      <SupportedModel SupportedSKUs="SKU-Standard;SKU-Pro">Contoso X9000</SupportedModel>
      <SupportedModel>Contoso X9100</SupportedModel>
      <SupportedModel NotSupportedSKUs="SKU-Lab">Contoso X9200</SupportedModel>
    </SupportedModels>
  </UpdateInfo>
</ApplicableUpdate>
```

Worked matching examples:

- Model `Contoso X9000 RevA` with SKU `SKU-Pro` matches the first entry because the model has
  the `Contoso X9000` prefix and the SKU is allowed.
- The same model with SKU `SKU-Lab` does not match that entry because `SupportedSKUs` is an
  allow-list.
- Model `Contoso X9100 RevA` matches the second entry for any SKU because that entry has no SKU
  restriction.
- Model `Contoso X9200 RevA` with SKU `SKU-Lab` is rejected by `NotSupportedSKUs`; another SKU
  can match the same model prefix.

The OEM should validate this illustrative shape against the manifest schema shipped with its SBE
package before publishing. Include the exact per-node model/SKU table, current endpoint, failing
`AdditionalData.Detail`, and the intended supported SKU set in the partner request.

### 4. Re-run the pre-update check

Re-run the same pre-update / system health check that surfaced this warning so it re-evaluates the
manifest. In the Azure portal, open the cluster's **Updates** page and run update readiness again;
or on a node, an administrator can trigger a fresh system health check with
`Invoke-SolutionUpdatePrecheck -SystemHealth`:

```powershell
# Trigger a fresh system health check (this re-runs the SBE health checks)
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then check the health state
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is what actually re-runs the health checks (a bare
`Invoke-SolutionUpdatePrecheck` does not re-run them).

### 5. Verify the fix

Re-read the Event ID 17205 result (see **Where this failure appears**). A fixed check reports
`Test-Endpoint-Matches-ModelSKU` with `AdditionalData.Status = SUCCESS` and an `AdditionalData.Detail`
that the manifest *"has matching entries for the server model ... and SKU ..."* (or a benign skip, if
you reset to the default endpoint). If you re-ran with `-SystemHealth`, confirm the overall result with
`Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate` and check that
`HealthState` is `Success` (not `Failure`). In the portal, the SBE health check clears on the next
validation pass.

## When to escalate

Escalate in this order, based on the evidence:

1. **Custom endpoint owner, when intent is unknown.** Provide the endpoint from
   `ComponentUris["SBE"]`, the owner-confirmation question, and the per-node model/SKU table.
   Do not reset the endpoint until that owner confirms that it is no longer required.
2. **OEM or SBE publisher, when the override is intentional but the manifest is incomplete.**
   Include every affected node, its exact model and SKU, the supported-model list from
   `AdditionalData.Detail`, the current endpoint, and the intended SKU allow or deny rules. This
   is usually a partner release dependency, not a node-side change; plan for the partner's SLA
   rather than treating it as a same-day command-only fix.
3. **Network or proxy owner, only when reachability fails.** Use the connectivity guide when the
   endpoint cannot be reached or does not return a usable response. Do not route a manifest content
   mismatch to the network team when the endpoint was successfully read.
4. **Environment Validator or LCM owner, when the validator cannot identify the module or
   endpoint.** If the check reports that it could not locate the
   `Microsoft.AzureStack.UpdateService.Validation` module, or could not determine the default
   endpoint, confirm the LCM extension and the `Microsoft.AzureStack.UpdateService.Validation`
   NuGet package are present and escalate with that exact detail.
5. **SBE or update owner, when sibling checks also fail.** Multiple failures among the related SBE
   health checks can indicate a broader endpoint or staged-content problem rather than a
   per-model mismatch.

For any escalation, attach the Event ID 17205 timestamp, the `AdditionalData.Status` and
`AdditionalData.Detail` values, the endpoint, the per-node fan-out output, and the time and result
of the `Invoke-SolutionUpdatePrecheck -SystemHealth` re-run.

::: audience-css

# Source Articles

- **Firewall blocks SBE update discovery** (internal SBE connectivity guide with the per-vendor
  `aka.ms/AzureStackSBEUpdate/<vendor>` endpoints and how to discover the active endpoint with
  `Get-SolutionDiscoveryDiagnosticInfo`):
  [Firewall-blocks-update-discovery.md](../SolutionExtension/Firewall-blocks-update-discovery.md)
- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/azure/azure-local/manage/troubleshoot-deployment#restart-the-deployment-via-azure-portal
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-Endpoint-Connectivity` (the node can reach the SBE manifest endpoint), `Test-Installed-SBE-Env-Vars`
  (the installed-SBE environment variables are consistent), and `Test-SolutionExtensionModule` (the
  staged SBE `SolutionExtension` module is present, integrity-intact, and signed).

:::
