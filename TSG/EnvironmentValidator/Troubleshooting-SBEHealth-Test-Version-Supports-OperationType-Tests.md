# AzStackHci_SBEHealth_Test-Version-Supports-OperationType-Tests

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Version-Supports-&lt;OperationType&gt;-Tests</strong> (for example <code>Test-Version-Supports-PreUpdate-Tests</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Solution Builder Extension version supports the operation-type health tests ("Validate SBE Version supports &lt;OperationType&gt; type tests")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-Version-Supports-&lt;OperationType&gt;-Tests</code> (an SBE health check emitted during pre-update validation; <code>&lt;OperationType&gt;</code> is the operation, e.g. <code>PreUpdate</code>)</td>
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
later"*. It means the installed Solution Builder Extension (SBE) is **older than 4.1**, so the SBE
health checks were **skipped** for this operation. To make those health checks actually run, **update
the SBE to version 4.1.x.x or later**, then re-run the pre-update health check. You can proceed with the
update without fixing this (it does not block), but the trade-off is that the SBE's own health checks
stay skipped (reduced update-safety coverage) until the SBE is updated, which is often an OEM
dependency, so weigh "proceed now" against "wait for the updated SBE". Full detail and how to verify
are below.

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content (drivers, firmware, and a
partner PowerShell module) that ships alongside the Azure Local solution. The SBE can contribute its own
health tests that run during pre-update validation, but only **version 4.1.x.x or later** (that is,
version 4.1 or newer) implements those health tests.

During pre-update validation this check compares the installed/staged SBE version against that minimum.
The comparison is a .NET version compare (`[System.Version]`) against `4.1`, so `4.1` and `4.1.0.0` are
supported, while `4.0.9.9` is not (the rule is "version is at least 4.1"); a non-numeric / malformed
version simply falls through and the tests proceed. There are two outcomes:

- **SBE is 4.1.x.x or later:** the check does not emit a result, and the SBE health tests run
  normally. You will not see this check.
- **SBE is older than 4.1.x.x:** the check emits a **SUCCESS** result named
  `Test-Version-Supports-<OperationType>-Tests` whose detail reads *"Skipping tests. SBE
  '<OperationType>' type Health Checks are only supported with version 4.1.x.x or later (SBE version
  was ...)"*. The SBE health tests are then **skipped** for this operation.

`<OperationType>` in the check name is the operation being validated, so the concrete on-box names you
will see are `Test-Version-Supports-PreUpdate-Tests` (and, on some builds,
`Test-Version-Supports-PreUpdateJIT-Tests`). This check is **Informational** and always SUCCESS: it
never fails or blocks the update. It is a heads-up that the SBE is too old for its health tests to run,
so you can update the SBE to get that coverage.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / update task, owned by the person running
  the update together with the **hardware partner (OEM)** who provides the SBE. It is **not** a generic
  Windows task and **not** a networking task.
- **This is safe to investigate read-only.** Reading the check result, the event log, and the installed
  SBE version changes nothing.
- **It does not restart nodes or bounce running workloads.** This is a pre-update validation notice, not
  a runtime operation. Reading it and updating the SBE do not restart cluster nodes or move running VMs.
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
report their own results instead).

## Troubleshooting Steps

### 1. Read the notice and the installed SBE version

Run the Event ID 17205 query above (or open the `HealthCheckResult.*.json`) and read the
`AdditionalData.Detail`. It states the SBE version the check saw and that 4.1.x.x or later is required.
Confirm the installed SBE version directly on the node:

```powershell
[pscustomobject]@{
    SBEInstalledMetadata = [System.Environment]::GetEnvironmentVariable('SBEInstalledMetadata','Machine')
    SBEInstallVersion    = [System.Environment]::GetEnvironmentVariable('SBEInstallVersion','Machine')
    SBEStageVersion      = [System.Environment]::GetEnvironmentVariable('SBEStageVersion','Machine')
}
```

If the version shown is earlier than `4.1`, that is why the SBE health tests are being skipped.

### 2. Update the Solution Builder Extension to 4.1.x.x or later

The remediation is to move the cluster onto an SBE that is version 4.1.x.x or later. Obtain the updated
SBE from your hardware partner (OEM) and add it through the same Azure Local update / Solution Builder
Extension flow you use to apply an SBE update, so the installed/staged SBE version becomes 4.1.x.x or
later. If your OEM does not yet publish a 4.1.x.x or later SBE for this hardware, the SBE health tests
remain skipped until they do; that is an OEM dependency, not a cluster fault. See the Solution Builder
Extension guidance under **Related** for the per-solution steps.

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

Re-read the Event ID 17205 result (step in **Where this failure appears**). Once the SBE is 4.1.x.x or
later, the `Test-Version-Supports-<OperationType>-Tests` **skip notice no longer appears** (the check
does not emit a result when the SBE is new enough), and the SBE's own health checks now run and report
their own results. Re-reading the installed SBE version shows `4.1` or later. If you re-ran with
`-SystemHealth`, confirm the overall result with `Get-SolutionUpdateEnvironment | Format-List
HealthState, HealthCheckDate`.

## When to escalate

- The installed SBE is already reported as 4.1.x.x or later, but the skip notice still appears. That is a
  version-detection inconsistency; escalate with the Event ID 17205 detail and the installed SBE version
  values from step 1.
- Your hardware partner (OEM) does not provide a 4.1.x.x or later SBE for this hardware. That is an OEM
  dependency; engage the OEM to obtain a supported SBE version. Until then the SBE health tests remain
  skipped (the update itself is not blocked by this check).
- The sibling SBE health checks also report problems (see **Related**), which can indicate a broader SBE
  configuration issue rather than just an old version.

## Related

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
