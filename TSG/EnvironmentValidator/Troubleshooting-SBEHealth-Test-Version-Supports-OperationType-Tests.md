---
ArticleType: "TSG"
Article_ID: "20260917160006"
Title: "AzStackHci_SBEHealth_Test-Version-Supports-OperationType-Tests"
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
  ID: 38357187
Tags: ["Validation", "Solution Update", "SBE", "Firmware", "Driver"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory publication metadata, audience scoping, and current article layout without changing technical guidance. |

:::

# AzStackHci_SBEHealth_Test-Version-Supports-OperationType-Tests

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Version-Supports-&lt;OperationType&gt;-Tests</strong> (for example <code>Test-Version-Supports-PreUpdate-Tests</code>)</td>
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
    <td>Solution Builder Extension version supports the operation-type health tests ("Validate SBE Version supports &lt;OperationType&gt; type tests")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-AzStackHciSBEHealth</code>, which evaluates the inline <code>Test-Version-Supports-&lt;OperationType&gt;-Tests</code> gate during pre-update validation; <code>&lt;OperationType&gt;</code> is the operation, for example <code>PreUpdate</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Informational</strong>: the check always reports SUCCESS. It is a <strong>notice that SBE health tests were skipped</strong> because the installed Solution Builder Extension is older than the minimum supported version. It does not block the update, but the SBE health checks will not run until you update the SBE.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>To run the Solution Builder Extension (SBE) health tests for an operation, the installed/staged SBE must be version <strong>4.1.x.x or later</strong>. An older SBE causes the health tests to be skipped.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Pre-update SBE health validation (update readiness), on solutions that ship a Solution Builder Extension.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Quick fix

If you just want the short version: this is **not a failure**. The check reports SUCCESS, and its
detail says *"Skipping tests. SBE ... type Health Checks are only supported with version 4.1.x.x or
later"*. It means the installed or update-package Solution Builder Extension (SBE) is **older than
4.1**, so the **OEM-provided SBE health-validation suite for this operation** is skipped. That suite
may include partner checks for hardware, firmware, drivers, storage, or workload safety, but the exact
set is OEM-defined and is not listed by this gate. Azure Local's built-in checks that already ran
before this gate are not implied to be skipped.

To make the partner checks actually run, **obtain and apply an OEM SBE that supports version 4.1.x.x
or later**, then re-run the pre-update health check. You can proceed without fixing this because the
notice does not block the update, but the trade-off is known missing partner-test coverage. The OEM
package may not be available yet, and downloading or staging it can depend on proxy and repository
access. Full detail and how to verify are below.

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content (drivers, firmware, and a
partner PowerShell module) that ships alongside the Azure Local solution. The SBE can contribute its own
health tests that run during pre-update validation, but only **version 4.1.x.x or later** (that is,
version 4.1 or newer) implements the operation-type health-test contract used by this gate.

During pre-update validation, `Test-AzStackHciSBEHealth` derives an SBE version before it evaluates this
gate. For an installed SBE it reads the machine-scoped `SBEInstalledContent` and
`SBEInstalledMetadata` values, then parses `oemMetadata.xml` under the metadata path. If the operation
has an SBE in the solution-update package, the package's `oemMetadata.xml` supplies the version instead.
An SBE-only update supplies its update version directly. `SBEStageVersion` is used later while staging
an update and is restored afterward; `SBEInstallVersion` is not the source read by this version gate.

The comparison is a .NET version compare (`[System.Version]`) against `4.1`, so `4.1` and `4.1.0` are
supported, while `4.0.9` is not (the rule is "version is at least 4.1"). A non-numeric or malformed
version is a separate **fail-open risk**: `[System.Version]::TryParse` returns false, the skip result is
not emitted, and execution falls through to the partner health tests. The absence of this result is
therefore not proof that the SBE is supported. There are three relevant outcomes:

- **SBE is 4.1.x.x or later:** the check does not emit a result, and the SBE health tests run
  normally. For this check only, the absence of the result is the healthy signal.
- **SBE is older than 4.1.x.x:** the check emits a **SUCCESS** result named
  `Test-Version-Supports-<OperationType>-Tests` whose detail reads *"Skipping tests. SBE
  '<OperationType>' type Health Checks are only supported with version 4.1.x.x or later (SBE version
  was ...)"*. The full partner SBE health-validation call is then **skipped** for this operation.
- **SBE version is malformed or cannot be parsed:** the check emits no version-support result and the
  partner health-validation path proceeds. Treat this as **unknown compatibility, not healthy**. Verify
  the source metadata and escalate instead of relying on the absence of the skip notice.

`<OperationType>` in the check name is the operation being validated, so the concrete on-box names you
will see are `Test-Version-Supports-PreUpdate-Tests` (and, on some builds,
`Test-Version-Supports-PreUpdateJIT-Tests`). This check is **Informational** and always SUCCESS: it
never fails or blocks the update. The SUCCESS-only skip notice is the actionable signal when it is
present. When it is absent, confirm that the version parsed successfully and that partner results
actually ran before calling the check healthy.

> [!WARNING]
> A missing `Test-Version-Supports-<OperationType>-Tests` result means that this predicate did not
> select the old-version branch. It does not, by itself, prove that the SBE is at least 4.1.x.x:
> malformed metadata also takes the no-result path. The safe proof is a parseable per-node
> `oemMetadata.xml` version at or above 4.1, followed by a fresh pre-update check whose partner SBE
> results are present.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / update task, owned by the person running
  the update together with the **hardware partner (OEM)** who provides the SBE. It is **not** a generic
  Windows task and **not** a networking task.
- **This is safe to investigate read-only.** Reading the check result, the event log, and the installed
  SBE version changes nothing.
- **It does not restart nodes or bounce running workloads.** This is a pre-update validation notice, not
  a runtime operation. Reading it and updating the SBE do not restart cluster nodes or move running VMs.
- **Know what coverage is missing.** The old-version branch exits before the OEM-provided partner
  health-validation suite for this operation runs. It does not mean every Azure Local update check is
  skipped. Depending on the OEM package, that suite can contain hardware, firmware, driver, storage,
  or workload-safety tests. The version notice does not enumerate the suite, so use the OEM release
  notes and the later partner result records to identify the exact coverage for the cluster.
- **Identify the delivery path before updating.** Review the Azure portal Updates history and the
  Environment Checker component log to determine whether the SBE came from a solution-update payload
  or an SBE-only package. Use that same delivery path for the replacement package. If the path is not
  clear, hand off the Event ID 17205 detail, the metadata path, and the relevant update record instead
  of guessing.
- **OEM timing is external to this check.** There is no universal Azure Local ETA for a compatible OEM
  package. Ask the OEM for the first package that supports the target operation, its supported hardware
  and SKU list, release date or ETA, and delivery channel. If the OEM has not published one, the
  partner-test gap can remain unresolved indefinitely while the update itself remains unblocked.
- **You do not have to act immediately.** Because the check is Informational and never blocks, you can
  proceed with the operation; the trade-off is that the SBE's own health tests are skipped until the SBE
  is updated to 4.1.x.x or later.

## Where this failure appears

You can see this notice in two places, the Azure portal and the node itself.

### In the Azure portal

When you run update readiness (or update validation) from the portal, the validation phase runs the
Environment Checker and surfaces SBE health results on the cluster's **Updates** view. A
`Test-Version-Supports-<OperationType>-Tests` result appears there under the SBE health checks with the
"Skipping tests ... only supported with version 4.1.x.x or later" detail.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event log as the
JSON body of an **Event ID 17205** entry, and to the cluster-wide `HealthCheckResult.*.json` on the
infrastructure share. Read this check's most recent result on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-Version-Supports*' } |
    Select-Object -First 1 Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}}
```

The `Name` on the node carries a domain prefix (`AzStackHci_SBEHealth_`), the operation type, and can
carry a node suffix, so the query uses `-like '*Test-Version-Supports*'` (leading and trailing wildcard)
to match it. In this JSON the human-readable status and message live under `AdditionalData` (the
top-level `Status` and `Severity` are numeric enums, and the top-level `Description` is a generic check
description), which is why the query projects `AdditionalData.Status` and `AdditionalData.Detail`. The
`AdditionalData.Status` is `SUCCESS` (this check never fails), and the `AdditionalData.Detail` names the
too-old SBE version and says *"only supported with version 4.1.x.x or later"*.

When collecting this remotely, do not chase the `SUCCESS` status as a failure: this check is
SUCCESS-only, and there is no positive result once the SBE is new enough, so the **expected "fixed"
signal is the absence of this result** (the skip-notice stops appearing and the SBE health checks
report their own results instead). That absence is healthy for this predicate only. It is not sufficient
when the version source is malformed or missing, so pair it with the per-node version read below and
evidence that the partner results ran.

### Where this notice does not appear

- **Cluster logs (`Get-ClusterLog`)**: this validator notice does not appear as a failover-cluster event.
  Use Event ID 17205 or the Environment Checker artifacts instead.
- **Windows Failover Cluster Manager**: this notice does not appear in `cluadmin.msc`; it is an
  Environment Checker result, not a clustered role or resource state.
- **Windows Admin Center on a standalone host**: this notice does not appear as a standalone WAC
  health signal. Use the node event and Environment Checker artifacts.
- **Windows Admin Center in the Azure portal**: this notice does not appear in the WAC blade. Use the
  Azure Local Updates view described above.
- **Component / tool log files**: the Environment Checker component logs and reports can carry the
  notice. On the node that ran validation, check
  `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and the matching
  `AzStackHciEnvironmentReport.json` or `.xml` for `Test-Version-Supports`.

## Troubleshooting Steps

### 1. Read the notice and the installed SBE version

Run the Event ID 17205 query above (or open the `HealthCheckResult.*.json`) and read the
`AdditionalData.Detail`. It states the SBE version the check saw and that 4.1.x.x or later is required.
The source reads `SBEInstalledContent` and `SBEInstalledMetadata` to locate an installed SBE, then
derives the installed version from `oemMetadata.xml`. It does not read an `SBEInstallVersion` machine
variable for this gate. Read every cluster node so a partially updated cluster is not hidden by one
compliant node:

```powershell
$nodes = Get-ClusterNode | Select-Object -ExpandProperty Name
Invoke-Command -ComputerName $nodes -ScriptBlock {
    $contentPath = [System.Environment]::GetEnvironmentVariable('SBEInstalledContent', 'Machine')
    $metadataPath = [System.Environment]::GetEnvironmentVariable('SBEInstalledMetadata', 'Machine')
    $stageVersion = [System.Environment]::GetEnvironmentVariable('SBEStageVersion', 'Machine')
    $metadataFile = $null
    $derivedVersion = $null
    $parseError = $null

    if (-not [string]::IsNullOrWhiteSpace($metadataPath)) {
        $metadataFile = Join-Path -Path $metadataPath -ChildPath 'oemMetadata.xml'
        if (Test-Path -LiteralPath $metadataFile) {
            try {
                [xml]$oemMetadata = Get-Content -LiteralPath $metadataFile -Raw -ErrorAction Stop
                $derivedVersion = [string]$oemMetadata.UpdatePackageManifest.UpdateInfo.Version
                if ([string]::IsNullOrWhiteSpace($derivedVersion)) {
                    $parseError = 'Version element is empty'
                }
            }
            catch {
                $parseError = $_.Exception.Message
            }
        }
        else {
            $parseError = 'oemMetadata.xml is missing'
        }
    }
    else {
        $parseError = 'SBEInstalledMetadata is empty'
    }

    [pscustomobject]@{
        Node = $env:COMPUTERNAME
        SBEInstalledContent = $contentPath
        SBEInstalledMetadata = $metadataPath
        SBEStageVersion = $stageVersion
        OemMetadataPath = $metadataFile
        DerivedInstalledVersion = $derivedVersion
        VersionParseError = $parseError
    }
} | Sort-Object Node | Format-Table -AutoSize
```

Interpret the fields as follows:

- `SBEInstalledContent` and `SBEInstalledMetadata` are machine-scoped paths for the installed SBE.
- `DerivedInstalledVersion` is the value parsed from `oemMetadata.xml`, which is the installed-SBE
  input used by this gate when no update-package SBE supersedes it.
- `SBEStageVersion` is staging context, not the primary version source for this comparison.
- `VersionParseError` is actionable. A missing or malformed value can make the inline predicate take
  its no-result path, so do not treat that node as healthy.

If the operation is evaluating an SBE inside a solution-update or SBE-only package, also inspect that
package's `oemMetadata.xml` and the Event ID 17205 detail. The package version can be the value compared
instead of the installed metadata version. A single node or a single package result is not a
cluster-wide proof; repeat the report for every cluster and retain the `Node` and package source.

If a parseable version is earlier than `4.1`, that is why the SBE health tests are being skipped.

### 2. Update the Solution Builder Extension to 4.1.x.x or later

The remediation is to move the cluster onto an SBE that is version 4.1.x.x or later. First identify
the delivery path from the Updates history and Environment Checker component log:

- If the SBE is part of a solution update, use the SBE payload and `oemMetadata.xml` from that solution
  update.
- If it was delivered as an SBE-only update, use the OEM's SBE package flow and verify the package
  metadata before staging it.
- If the delivery record is unclear, do not guess which package to apply. Hand off the Event ID 17205
  detail, the per-node metadata report, and the update record to the update owner or OEM.

The 4.1.x.x boundary is a compatibility contract for the operation-type partner health-test entry
point. Ask the OEM to confirm that the package implements the SBE health-validation contract for the
target operation and hardware/SKU, not only that its version string is new enough. The package download
or staging path may require proxy, certificate, or repository access, so a failed download is a
delivery-path issue to triage separately from the version predicate. If the OEM does not yet publish a
compatible package, the partner health tests remain skipped; this can remain unresolved indefinitely
without being a cluster fault. See the Solution Builder Extension guidance under **Related** for the
per-solution steps.

### 3. Re-run the pre-update check

Re-run the same pre-update / system health check that surfaced this notice so it re-evaluates the SBE
version. In the Azure portal, open the cluster's **Updates** page and run update readiness again; or on a
node, an administrator can trigger a fresh system health check with `Invoke-SolutionUpdatePrecheck
-SystemHealth`:

```powershell
# Trigger a fresh system health check (this re-runs the SBE health checks)
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then check the health state
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is what actually re-runs the health checks (a bare
`Invoke-SolutionUpdatePrecheck` does not re-run them).

### 4. Verify the fix

Re-read the Event ID 17205 result (step in **Where this failure appears**) on every node. Once a
parseable installed or package SBE version is 4.1.x.x or later, the
`Test-Version-Supports-<OperationType>-Tests` **skip notice no longer appears** because the check does
not emit a result on its supported branch. Confirm that the partner SBE health results now appear for
the operation. The absence of the skip notice without a parseable per-node version or partner results
is not verified recovery because malformed input also follows the no-result path.

If you re-ran with `-SystemHealth`, confirm the overall result with
`Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate`. That overall state does
not replace the per-node version and partner-result checks above.

## When to escalate

- The installed SBE is already reported as 4.1.x.x or later, but the skip notice still appears. That is a
  version-detection inconsistency; escalate with the Event ID 17205 detail, the per-node
  `SBEInstalledContent` and `SBEInstalledMetadata` values, the parsed `oemMetadata.xml` version, and
  the update-package source if one was evaluated.
- A node has an empty or malformed `oemMetadata.xml`, or `VersionParseError` is populated. This is a
  fail-open compatibility risk, not evidence that the SBE is supported. Include the raw parse error,
  the metadata path, and the operation type.
- Your hardware partner (OEM) does not provide a 4.1.x.x or later SBE for this hardware. That is an OEM
  dependency; engage the OEM for a supported package, release date or ETA, supported hardware/SKU
  list, and delivery channel. Until then the SBE health tests remain skipped, possibly indefinitely
  (the update itself is not blocked by this check).
- The sibling SBE health checks also report problems (see **Related**), which can indicate a broader SBE
  configuration issue rather than just an old version.

::: audience-css

# Source Articles

- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment troubleshooting):
  https://learn.microsoft.com/azure/azure-local/manage/troubleshoot-deployment#restart-the-deployment-via-azure-portal
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-Installed-SBE-Env-Vars` (the installed-SBE environment variables are consistent),
  `Test-Endpoint-Connectivity` (the node can reach the SBE manifest endpoint),
  `Test-Endpoint-Matches-ModelSKU` (the SBE manifest lists this hardware model and SKU), and
  `Test-SolutionExtensionModule` (the staged SBE `SolutionExtension` module is present, integrity-intact,
  and signed).

:::
