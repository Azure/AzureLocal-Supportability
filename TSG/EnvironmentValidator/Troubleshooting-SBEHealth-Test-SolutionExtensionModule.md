---
ArticleType: "TSG"
Article_ID: "20260917160018"
Title: "AzStackHci_SBEHealth_Test-SolutionExtensionModule"
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
  ID: 38357441
Tags: ["Validation", "Solution Update", "SBE", "Firmware", "Driver"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory publication metadata, audience scoping, and current article layout without changing technical guidance. |

:::

# AzStackHci_SBEHealth_Test-SolutionExtensionModule

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-SolutionExtensionModule</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Solution Builder Extension module health</td>
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
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-SolutionExtensionModule</code> (run with <code>Invoke-AzStackHciSBEHealthValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: when the module cannot be validated the check fails and the operation (deployment or update) is blocked at SBE health validation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>The deployment or update cannot proceed until the staged SBE package is valid. A readiness failure does not restart nodes, move VMs, or create a mixed-version cluster because the operation is stopped before SBE application begins.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The deployment or update operator owns evidence collection and re-staging. The hardware partner (OEM) owns a package that still fails integrity, signature, or manifest validation after a clean re-stage.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Read-only diagnosis normally takes 10-20 minutes. Allow about 30-60 minutes for a clean re-stage and fresh precheck, plus package transfer time. An OEM package correction is an external dependency; use the partner's support SLA rather than promising a completion time.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>The staged Solution Builder Extension (SBE) package must contain a valid, integrity-intact, correctly signed <code>SolutionExtension</code> module.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Deployment and Update (SBE health validation), on solutions that ship a Solution Builder Extension.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Quick fix

If you need the short path: collect the staged content and metadata locations from every node,
open the newest `SBEContentIntegrityErrors_*.txt` report, and do not edit any staged file.
Identify whether the failure came from an **update readiness check** or **deployment validation**,
then replace the whole staged SBE package through that same supported channel. During an update,
run `Invoke-SolutionUpdatePrecheck -SystemHealth` afterward and require
`Get-SolutionUpdateEnvironment` to report `HealthState = Success`. If a clean OEM package still
fails, escalate to the OEM with the all-node evidence bundle.

> **Customer summary:** The operation is blocked before the SBE is applied because one or more
> nodes cannot validate the staged partner module. Running workloads remain online while the
> package is re-staged. The next decision is whether this is a local staging or transfer problem,
> or an OEM package problem that needs partner correction.

## Impact and decision guide

| Path | Planning estimate | Owner and risk |
| --- | --- | --- |
| Collect all-node evidence and classify the mismatch | 10-20 minutes | Cluster operator or CSS. [LOW RISK], read-only. |
| Re-stage a known-good package and re-run readiness | Usually 30-60 minutes, plus transfer time | Deployment or update operator. [MEDIUM RISK], changes staged update content but does not restart nodes or move VMs by itself. |
| Correct an OEM package that fails after a clean re-stage | Partner-dependent | OEM or SBE publisher. [LOW RISK] to the running cluster while blocked, but the deployment or update remains delayed. |

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content that ships
alongside the Azure Local solution: drivers, firmware, and a partner **SolutionExtension**
PowerShell module that can contribute health tests during deployment and updates. This
validator checks that the staged SBE package contains a `SolutionExtension` module that can
be **validated** for health testing.

The check runs `Test-SolutionExtensionModule` against the SBE package path. It looks for the
module at `<SBE package>\Configuration\SolutionExtension`, runs an **SBE content integrity
check** (the staged content must match the SBE manifest), confirms the module is signed with a
valid partner certificate, and confirms it carries the `HealthServiceIntegration` tag. The
outcome is one of:

- **SUCCESS (validated).** The module is present, intact, signed, and health-integration
  capable, so SBE health testing proceeds.
- **SUCCESS (skipped).** There is no SBE, or the SBE does not implement health tests / does
  not carry the `HealthServiceIntegration` tag. This is a benign skip, not a failure.
- **FAILURE (Critical).** The module **could not be validated**: the staged SBE content
  failed its integrity check, the module is not correctly signed, or the SBE metadata expected
  for the installed SBE version could not be found. The detail reads *"The SolutionExtension
  module could not be validated"*.

A FAILURE blocks the operation at SBE health validation. This is almost always a problem with
the **staged SBE content** (corrupt, incomplete, hand-edited, or mismatched against the
manifest), not with the cluster hardware itself.

### Glossary

- **Staged SBE:** the partner package copied into the deployment or update workspace before it
  is installed.
- **Content:** the SBE payload, including `Configuration\SolutionExtension` and its
  `SolutionExtension.psm1` module.
- **Metadata:** the sibling SBE directory that carries the manifest used to verify the content.
- **Content integrity check:** a comparison of the staged files with the metadata manifest. A
  changed, extra, or missing file fails the comparison.
- **Partner certificate:** the OEM signing certificate used to validate the partner module.
- **`HealthServiceIntegration` tag:** the module-manifest tag that declares that the
  `SolutionExtension` contributes health tests.
- **Pre-update or system health check:** a readiness evaluation. It validates the package but
  does not install the update.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / deployment task, owned by the
  person running the deployment or update together with the **hardware partner (OEM)** whose
  SBE is in use. It is **not** a generic Windows task and **not** a networking task, so do not
  route it to the network team.
- **Do not hand-edit the staged SBE content.** The integrity check compares the staged
  content against the SBE manifest, so editing, adding, or removing files under the SBE
  package will itself cause this check to fail. The fix is to re-stage the correct partner
  package, never to patch files inside it.
- **This is safe to investigate read-only.** Reading the validator result, the event log, and
  the integrity error report changes nothing. The remediation (re-staging the SBE and
  re-running the precheck) is a normal deployment/update action.
- **It does not restart nodes or bounce running workloads.** This is a deployment or update
  readiness gate. A failure here stops the operation before SBE application, so it does not
  create a mixed-version cluster. Reading the check, replacing staged content, and re-running
  the precheck do not restart nodes or move VMs. Do not start the update until the check passes.
- **Do not continue ad hoc if update actions already started.** If the failure appeared after
  update application began rather than during readiness, preserve the update state and engage
  Azure Local support before replacing files. This guide covers the pre-application validation
  gate.

### Ownership lanes

- **Deployment or update operator:** collect all-node evidence, identify the operation that
  staged the package, replace it through the supported channel, and re-run validation.
- **OEM or SBE publisher:** correct a package that still fails integrity, signature, module
  manifest, or metadata validation after a clean re-stage.
- **Network or proxy owner:** engage only when transfer evidence shows an egress, proxy,
  authentication, timeout, or bandwidth problem. A hash mismatch by itself is not a network
  diagnosis.
- **Azure Local support:** engage when update application had already begun, results disagree
  across product surfaces, or a clean OEM package and healthy transfer still fail validation.

## Where this failure appears

You can see this failure in the Azure portal, on each node, and in Environment Checker component
artifacts.

### In the Azure portal

When you deploy or update from the portal, the validation phase runs the Environment Checker
and surfaces failed checks on the cluster's **Updates** (or deployment **Validation**) view.
A failed `Test-SolutionExtensionModule` appears there in red, under the SBE health checks,
with the "could not be validated" detail.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event
log as the JSON body of an **Event ID 17205** entry, and to the cluster-wide
`HealthCheckResult.*.json` on the infrastructure share. Read this check's most recent result
on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-SolutionExtensionModule*' } |
    Select-Object -First 1 Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}}
```

In this JSON the human-readable status and message live under `AdditionalData` (the top-level
`Status` and `Severity` are numeric enums, and the top-level `Description` is a generic check
description), so the query projects `AdditionalData.Status` and `AdditionalData.Detail`. When the
module cannot be validated, `AdditionalData.Status` is `FAILURE` and `AdditionalData.Detail` reads
*"The SolutionExtension module could not be validated ..."*.

When the failure is an **integrity** mismatch, the check also writes a detailed report next to
the SBE metadata, named `SBEContentIntegrityErrors_{node}_{timestamp}.txt`. The failure detail
points at that file and summarizes what it found (for example files with hash mismatches, or
extra or missing files). Read that report to see exactly which staged files diverged from the
manifest, which is the fastest way to tell a corrupt or hand-edited stage from an incomplete
one.

### Locate the staged paths and collect every node

`SBEStagedMetadata` is a machine-scoped value, so do not assume that one node represents the
whole cluster. Run the following from a cluster node with remoting access. It derives the
content path from the metadata path, identifies the `Microsoft.AzureStack.Role.SBE` package,
collects the newest integrity report, and reads the newest Event ID 17205 result on every node:

```powershell
$nodes = (Get-ClusterNode).Name

$perNode = Invoke-Command -ComputerName $nodes -ThrottleLimit 4 -ScriptBlock {
    $metadata = [System.Environment]::GetEnvironmentVariable('SBEStagedMetadata', 'Machine')
    $content = if ([string]::IsNullOrWhiteSpace($metadata)) {
        $null
    }
    else {
        Join-Path -Path (Split-Path -Path $metadata -Parent) -ChildPath 'Content'
    }

    $module = if ($content) {
        Join-Path -Path $content -ChildPath 'Configuration\SolutionExtension\SolutionExtension.psm1'
    }
    else {
        $null
    }

    $rolePackage = Get-ChildItem -Path "$env:SystemDrive\NugetStore" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Microsoft.AzureStack.Role.SBE.*' } |
        Sort-Object Name -Descending |
        Select-Object -First 1

    $integrityReport = if ($metadata -and (Test-Path -LiteralPath $metadata)) {
        Get-ChildItem -LiteralPath $metadata -Filter 'SBEContentIntegrityErrors_*.txt' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
    }
    else {
        $null
    }

    $check = Get-WinEvent -LogName AzStackHciEnvironmentChecker `
        -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 `
        -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Message | ConvertFrom-Json } |
        Where-Object { $_.Name -like '*Test-SolutionExtensionModule*' } |
        Select-Object -First 1

    [pscustomobject]@{
        Node                 = $env:COMPUTERNAME
        StagedMetadata       = $metadata
        MetadataExists       = [bool]($metadata -and (Test-Path -LiteralPath $metadata))
        StagedContent        = $content
        ContentExists        = [bool]($content -and (Test-Path -LiteralPath $content))
        SolutionExtensionPsm1 = $module
        ModuleExists         = [bool]($module -and (Test-Path -LiteralPath $module))
        SBERolePackage       = $rolePackage.FullName
        SBERoleVersion       = if ($rolePackage) { $rolePackage.Name -replace '^Microsoft\.AzureStack\.Role\.SBE\.', '' } else { $null }
        IntegrityReport      = $integrityReport.FullName
        IntegrityReportUtc   = $integrityReport.LastWriteTimeUtc
        Status               = $check.AdditionalData.Status
        Detail               = $check.AdditionalData.Detail
    }
}

$perNode | Sort-Object Node | Format-List
```

A missing value, missing path, `NO RESULT`, or a different package version on one node is evidence
to preserve, not a reason to copy files from another node. One passing node does not clear a
failure on another node.

### In cluster result files and management tools

The cluster-wide `HealthCheckResult.*.json` files on the infrastructure share carry the same
check when a full health check has run. Search for `Test-SolutionExtensionModule` and read
`AdditionalData.Status` and `AdditionalData.Detail`. A targeted check can refresh Event ID 17205
before the cluster-wide file refreshes, so record timestamps from both surfaces.

### Where this failure does not appear

- **Cluster logs (`Get-ClusterLog`):** this SBE package-validation result does not appear as a
  failover-cluster event. Use Event ID 17205 and the Environment Checker artifacts.
- **Windows Failover Cluster Manager:** this result does not appear in `cluadmin.msc`; it is not a
  clustered role, resource, or node-state fault.
- **Windows Admin Center on a standalone host:** this specific validator result does not appear as
  a standalone WAC health signal. Use the on-node event and component artifacts.
- **Windows Admin Center in the Azure portal:** this result does not appear in the WAC blade. Use
  the Azure Local deployment Validation or Updates view instead.
- **Component or tool log files:** the Environment Checker component logs and reports can carry
  the result. On the account and node that ran validation, check
  `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and the matching
  `AzStackHciEnvironmentReport.json` or `.xml`.

## Requirements

- The staged SBE package contains `Configuration\SolutionExtension\SolutionExtension.psd1` and
  `SolutionExtension.psm1`.
- The staged SBE content matches the SBE manifest (passes the content integrity check).
- The `SolutionExtension` module is signed with a valid partner (OEM) certificate.
- The SBE metadata for the installed SBE version is present and reachable.

## Troubleshooting Steps

### 1. Read the failure detail and classify it

Run the all-node collection above, open each referenced integrity report, and classify the cause:

- **"SBE content integrity check failed"** (with a `SBEContentIntegrityErrors_*.txt` reference):
  the staged content does not match the manifest. Open the referenced report to see whether it
  is *hash mismatches* (files were changed or corrupted), *extra files* (content was added, for
  example a hand copied or partially extracted stage), or *missing files* (an incomplete stage).
- **A certificate or module-load error:** the `SolutionExtension` module is present but is not
  correctly signed, or its manifest is malformed.
- **"could not find the SBE Metadata directory"** for an installed SBE version: the SBE is
  registered as installed but its staged metadata is missing.

Before remediation, identify which operation staged the package:

- A failure on the Azure portal **Updates** readiness view or from
  `Invoke-SolutionUpdatePrecheck -SystemHealth` belongs to the update or SBE update channel.
- A failure on the deployment **Validation** view belongs to the deployment media or source.
- If the evidence was handed to you without the operation context, stop and ask the deployment
  or update owner. The staged path alone is not enough to prove which channel owns the package.

### 2. Rule in or rule out the transfer path

Hash mismatches, extra files, and missing files describe the final staged content; they do not by
themselves identify the transfer failure. Review the staging or download logs for proxy
authentication errors, timeouts, interrupted downloads, insufficient space, or incomplete
extraction.

- If transfer evidence shows an egress, proxy, authentication, timeout, or bandwidth problem,
  involve the network or proxy owner before downloading again.
- If transfer completes cleanly and the package still fails with the same file-level mismatch,
  keep ownership with the staging process or OEM package. Do not route a content or signing
  defect to networking.

### 3. Re-stage the correct partner SBE package

Do not patch the staged files. Replace the **whole** SBE package with the exact one your solution
expects from the hardware partner (OEM), staged through the same path the operation uses. Which
path depends on the operation:

- **During an update** (the SBE arrives as a solution update): re-add or re-download the SBE
  update through the same channel you used to add it (the Azure Local update / Solution Builder
  Extension flow), so the staged copy is replaced with the correct partner content.
- **During deployment** (the SBE comes from your deployment media / source): replace the SBE
  content in that deployment source with the OEM-provided package, then re-run the deployment
  validation step.

In both cases, confirm the SBE version matches what the cluster expects and that the transfer
completed (no partial extraction, no added files). If you did not stage this SBE yourself (most
customers do not; the deployment or partner engineer, or the OEM, does), hand this off to them
along with the `SBEContentIntegrityErrors_*.txt` report and the SBE version. For the exact
per-solution steps, see the Solution Builder Extension guidance under **Related**.

### 4. Re-run the check

During an update, trigger a fresh system health evaluation:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait for the new evaluation, then verify its result and timestamp.
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is required. A bare `Invoke-SolutionUpdatePrecheck` does not re-run the
health checks. Require `HealthState = Success` and a new `HealthCheckDate` before starting the
update. During deployment, re-run the deployment validation step instead.

For an OEM reproduction, use the same supported sequence on an Azure Local validation system:
stage the candidate package as a sibling `Content` and `Metadata` pair through the supported
deployment or update path, run the same system health or deployment validation, and collect the
Event ID 17205 detail plus any `SBEContentIntegrityErrors_*.txt` report. Do not validate a candidate
by hand-editing the customer's staged tree.

### 5. Verify the fix

Repeat the all-node collection. The fix is complete only when:

- Every node reports `AdditionalData.Status = SUCCESS` for
  `Test-SolutionExtensionModule`.
- Every staged content and metadata path exists.
- Every node reports the expected `Microsoft.AzureStack.Role.SBE` package version.
- No new `SBEContentIntegrityErrors_*.txt` report is written during the fresh run.
- The portal clears the check from red, and an update precheck reports
  `HealthState = Success` with a new `HealthCheckDate`.

## When to escalate

- The **OEM-provided** SBE package fails the integrity check even after a clean re-stage from
  the partner source. That points at a bad partner package rather than a staging problem;
  escalate to the hardware partner (OEM) with the `SBEContentIntegrityErrors_*.txt` report and
  the SBE version. The package the OEM returns must satisfy all three of the module's validation
  requirements, which the OEM can confirm before handing it back: its content matches the SBE
  manifest (passes the integrity check), the `SolutionExtension` module is signed with a valid
  partner (OEM) certificate, and the module manifest (`SolutionExtension.psd1`) declares the
  `HealthServiceIntegration` tag.
- The module is present and intact but fails certificate validation. That is a partner signing
  issue; escalate to the OEM.
- The sibling SBE health checks also fail (see **Related**), which can indicate a broader SBE
  configuration or credential problem rather than a content-integrity one.
- A clean re-stage succeeds on some nodes but not all nodes, or the nodes report different
  `Microsoft.AzureStack.Role.SBE` versions.
- The failure appeared after update application began rather than during readiness.

For escalation, attach the all-node output, Event ID 17205 timestamps and details, every referenced
integrity report, the SBE package version, the staging or transfer log, the operation type
(deployment or update), and the fresh validation timestamp and result.

::: audience-css

# Source Articles

- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/azure/azure-local/manage/troubleshoot-deployment#restart-the-deployment-via-azure-portal
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-SBEPropertiesValid` (partner property values match the SBE manifest; remediated with
  `Set-SolutionExtensionProperty`) and `Test-SBECredentialsValid` (SBE credentials in the secret
  store match the SBE manifest).
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension

:::
