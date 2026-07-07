# AzStackHci_SBEHealth_Test-Endpoint-Matches-ModelSKU

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Endpoint-Matches-ModelSKU</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Solution Builder Extension manifest matches hardware model and SKU ("Validate SBE manifest matches hardware model, sku")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-Endpoint-Matches-ModelSKU</code> (an SBE health check emitted during pre-update validation)</td>
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
manifest there is missing this model. Confirm with your hardware partner (OEM) that the override
endpoint is correct for this server, or **reset to the default endpoint** with
`Set-OverrideUpdateConfiguration -ResetDefaultOemUpdateUri`, then re-run the pre-update health
check. Full detail and how to verify the fix are below.

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
surfaces the mismatch now while it is easy to fix.

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
- **Reset to the default endpoint is a safe, supported action.** `Set-OverrideUpdateConfiguration
  -ResetDefaultOemUpdateUri` returns SBE update discovery to the Microsoft-hosted default, which is
  the configuration Microsoft recommends for most environments.

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

### 3. Fix the mismatch (correct the override, or reset to default)

Do not edit the check. Resolve the model/SKU mismatch one of two ways:

- **The override endpoint is intentional (your OEM serves SBE content there):** confirm with your
  hardware partner (OEM) that this endpoint is correct for **this** server model, and that the
  manifest published there lists this model (and SKU). If the manifest is simply missing this
  hardware, the OEM must publish an updated manifest at that endpoint that includes it.

  For the OEM publishing the fix, the manifest lists supported hardware as `SupportedModel` entries
  under `ApplicableUpdate/UpdateInfo/SupportedModels`, each optionally carrying `SupportedSKUs` and
  `NotSupportedSKUs` (semicolon-separated). The matching semantics the check uses are worth knowing:
  the server model is compared with non-word characters stripped and as a **prefix match** (the
  server model must start with a listed `SupportedModel` value), and SKU support is then governed by
  the matched model's `SupportedSKUs` / `NotSupportedSKUs` (no SKU attributes means no SKU
  restriction). So a `SupportedModel` entry must be present whose value is a prefix of this server's
  (non-word-stripped) model, and its SKU rules must admit this server's SKU.
- **The override is not needed (or was set in error):** reset SBE update discovery to the
  Microsoft-hosted default endpoint, which supports the shipping hardware models:

  ```powershell
  Set-OverrideUpdateConfiguration -ResetDefaultOemUpdateUri
  ```

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

- The override endpoint is correct for this hardware, but the OEM's manifest there still does not
  list this server's model or SKU. Escalate to the hardware partner (OEM) with this server's model
  and SKU (step 1) and the "Supported models" list from the failure detail, so they can publish an
  updated manifest.
- The check reports it could not locate the `Microsoft.AzureStack.UpdateService.Validation` module,
  or could not determine the default endpoint. That is not a model/SKU problem: confirm the LCM
  extension is installed and the `Microsoft.AzureStack.UpdateService.Validation` nuget is present,
  and escalate with that detail.
- The sibling SBE health checks also fail (see **Related**), which can indicate a broader SBE
  endpoint or configuration problem rather than a per-model one.

## Related

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
