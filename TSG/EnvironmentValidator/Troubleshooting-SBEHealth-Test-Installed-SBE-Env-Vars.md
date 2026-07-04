# AzStackHci_SBEHealth_Test-Installed-SBE-Env-Vars

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Installed-SBE-Env-Vars</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Installed Solution Builder Extension environment variables consistency ("Validate Installed SBE Env Vars")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-Installed-SBE-Env-Vars</code> (an SBE health check emitted during pre-update validation)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Warning</strong>: the check flags an inconsistent installed-SBE state so you can reconcile it. It does not fail the check or block the operation, but the mismatch should be cleared before the next update.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>The machine environment variables that record the installed Solution Builder Extension (<code>SBEInstalledContent</code> and <code>SBEInstalledMetadata</code>), together with the SBE version read from <code>oemMetadata.xml</code>, must be internally consistent: either a complete installed SBE (both set), or no SBE at all (both unset).</td>
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

If you just want the short version: this warning means the machine environment variables
that record the **installed** Solution Builder Extension (SBE) are in a half-set,
mismatched state on this node, usually left behind by an interrupted or partial SBE
update. Reconcile it by re-running the Solution Builder Extension update to completion so
the platform re-populates those variables consistently (**"Update to latest available
Solution Builder Extension to restore consistent SBE state"**), then re-run the pre-update
check. Full detail and how to verify the fix are below.

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content that ships
alongside the Azure Local solution: drivers, firmware, and a partner module that can
contribute health tests during deployment and updates. When an SBE is installed, the
platform records where it lives on the node in two **machine environment variables**:

- `SBEInstalledContent`: the path to the installed SBE content.
- `SBEInstalledMetadata`: the path to the installed SBE metadata (which contains
  `oemMetadata.xml`, the file the SBE **version** is read from).

During **pre-update** validation, the SBE health check reads those two variables and the
derived version, and reports the installed-SBE state as one of three outcomes:

- **Installed (SUCCESS).** Both variables are set: that pairing is the installed signal. The
  node has a complete installed SBE. The SBE version shown in the detail is read from
  `oemMetadata.xml` under the metadata path and is informational; it defaults to `1.0` when
  that file is absent, so a missing version does not by itself change this outcome. The detail
  reads *"Detected SBE `<version>` is installed."*
- **No SBE (SUCCESS).** Both variables are unset (or no version resolves). There is no
  installed SBE, which is a valid state; SBE health checks are simply skipped. The detail
  reads *"No SBE installed."*
- **Inconsistent (WARNING).** The variables are in a mismatched combination that is neither
  a complete install nor a clean "no SBE" (for example the content path is missing while
  the metadata path still points at a real SBE version). The detail reads *"Inconsistent
  SBE ENV vars!!"* and lists the content path, metadata path, and version it saw. The
  remediation is *"Update to latest available Solution Builder Extension to restore
  consistent SBE state."*

Only the **Inconsistent** outcome is actionable, and it is a **Warning**, not a hard
failure: the check does not block the deployment or update. It is an early guard. An
inconsistent installed-SBE state most often comes from an SBE stage or update that was
interrupted or only partially applied, leaving one variable updated and the other stale. If
that mismatch is carried into the next update it can cause downstream "new plus old" SBE
path problems, so the check surfaces it now so you can reconcile it first.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / update task, owned by the person
  running the update, together with the **hardware partner (OEM)** whose SBE is in use if
  the SBE itself needs to be re-staged. It is **not** a generic Windows task and **not** a
  networking task, so do not route it to the network team.
- **This is safe to investigate read-only.** Reading the check result, the event log, and
  the two environment variables changes nothing.
- **It does not restart nodes or bounce running workloads.** This is a pre-update validation
  signal, not a runtime operation. Reading the check and re-running the SBE update do not
  restart cluster nodes or move running VMs.
- **Do not hand-edit these environment variables to "make the warning go away."** They are
  meant to be a faithful record of the installed SBE. Set them by hand and you can hide a
  real half-staged SBE and cause a later update to run against the wrong content. The
  supported fix is to reconcile the installed SBE itself (re-run the SBE update), which sets
  the variables correctly as a side effect.

## Where this failure appears

You can see this warning in two places, the Azure portal and the node itself.

### In the Azure portal

When you run update readiness (or update validation) from the portal, the validation phase
runs the Environment Checker and surfaces SBE health results on the cluster's **Updates**
view. An inconsistent `Test-Installed-SBE-Env-Vars` appears there as a warning under the SBE
health checks, with the "Inconsistent SBE ENV vars" detail.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event
log as the JSON body of an **Event ID 17205** entry, and to the cluster-wide
`HealthCheckResult.*.json` on the infrastructure share. Read this check's most recent result
on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-Installed-SBE-Env-Vars*' } |
    Select-Object -First 1 Name, Status, Severity, Description, @{n='Detail';e={$_.AdditionalData.Detail}}
```

The `Name` on the node carries a domain prefix (`AzStackHci_SBEHealth_`) and can carry a node
suffix, so the query uses `-like '*Test-Installed-SBE-Env-Vars*'` (leading and trailing
wildcard) to match it. When the state is inconsistent, `Severity` is `WARNING` and `Detail`
reads *"Inconsistent SBE ENV vars!! content: [...], metadata: [...], sbeVersion [...]"*, which
tells you exactly which paths and version the check saw.

You can also read the two environment variables directly on the node to see the mismatch:

```powershell
[pscustomobject]@{
    SBEInstalledContent  = [System.Environment]::GetEnvironmentVariable('SBEInstalledContent','Machine')
    SBEInstalledMetadata = [System.Environment]::GetEnvironmentVariable('SBEInstalledMetadata','Machine')
}
```

A consistent node shows **both** values populated (an installed SBE) or **both** empty (no
SBE). Any other combination is the inconsistency this check warns about.

These are **per-node** machine variables, so the state is evaluated on each node
independently: an inconsistency can exist on one node while the others are fine. Read the two
variables on each node to see which nodes are affected. You do not reconcile them node by node
by hand; re-running the Solution Builder Extension update (step 2) is a cluster-level operation
that re-stages the SBE and re-populates these variables consistently across the nodes.

## Requirements

A consistent installed-SBE state is one of:

- **A complete installed SBE:** `SBEInstalledContent` and `SBEInstalledMetadata` are both set
  (that pairing is what marks the SBE installed). Normally both paths exist and `oemMetadata.xml`
  under the metadata path supplies the SBE version, though the version is informational and
  defaults to `1.0` when that file is absent.
- **No SBE at all:** `SBEInstalledContent` and `SBEInstalledMetadata` are both unset.

Anything else (one set and the other missing, or a metadata path with a real version but no
content path) is inconsistent and raises the warning.

## Troubleshooting Steps

### 1. Read the warning detail and the two variables

Run the Event ID 17205 query above (or open the `HealthCheckResult.*.json`) and read the
`Detail`, then read the two environment variables directly (the second snippet above).
Confirm the mismatch and note which side is stale: for example `SBEInstalledContent` empty
while `SBEInstalledMetadata` still points at a metadata directory that has a real
`oemMetadata.xml` version, or a content or metadata path that no longer exists on disk.

### 2. Reconcile the installed SBE by re-running the update

Do not edit the environment variables by hand. Instead, re-run the **Solution Builder
Extension update** to completion so the platform re-stages the SBE and re-populates
`SBEInstalledContent` and `SBEInstalledMetadata` consistently. This is the verbatim
remediation the check gives: *"Update to latest available Solution Builder Extension to
restore consistent SBE state."*

- Re-add or re-download the SBE through the same channel you used to add it (the Azure Local
  update / Solution Builder Extension flow), and let the update finish rather than cancelling
  it partway.
- Confirm the SBE version matches what the cluster expects, and that the transfer completed
  (no partial extraction).
- If the referenced content or metadata **path does not exist** on disk, the earlier stage
  was incomplete. Re-stage the correct partner (OEM) package from your source, then re-run
  the update. If you did not stage this SBE yourself (most customers do not; the update or
  partner engineer, or the OEM, does), hand this off to them along with the two environment
  variable values and the SBE version. For the exact per-solution steps, see the Solution
  Builder Extension guidance under **Related**.

### 3. Re-run the pre-update check

Re-run the same **update readiness** check that first surfaced this warning, and let it
re-evaluate SBE health. If you are not sure what that means: in the Azure portal, open the
cluster's **Updates** page and run the update readiness (validation) check again; or on a node,
an administrator can trigger a fresh system health check with `Invoke-SolutionUpdatePrecheck
-SystemHealth`:

```powershell
# Trigger a fresh system health check (this re-runs the SBE health checks)
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then check the health state
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is what actually re-runs the health checks (a bare
`Invoke-SolutionUpdatePrecheck` does not re-evaluate them); it re-reads the two environment
variables and re-classifies the installed-SBE state. See the Azure Local update troubleshooting
guidance under **Related** for more on the readiness / precheck step.

### 4. Verify the fix

Re-read the Event ID 17205 result (step 1). A reconciled node reports `Test-Installed-SBE-Env-Vars`
with **no `WARNING` severity** and a detail of either *"Detected SBE `<version>` is installed."*
(both variables now set) or *"No SBE installed."* (both now cleared). Re-reading the two
environment variables shows them **both set** or **both empty**, never one without the other.
If you re-ran the check with `-SystemHealth` (step 3), confirm the overall result with
`Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate` and check that
`HealthState` is `Success` (not `Failure`). In the portal, the SBE health warning clears on the
next validation pass.

## When to escalate

The operator owns the first fix: re-running the SBE update to completion (step 2). It becomes
the **hardware partner (OEM)'s** problem only when that clean, completed re-run cannot produce
a consistent state. Specifically:

- A **completed** SBE update still leaves the variables inconsistent. That points at a
  staging or update-engine problem rather than an interrupted run; escalate with the two
  environment variable values, the SBE version, and the Event ID 17205 detail.
- The content or metadata path is set but points at a location that does not exist and cannot
  be re-created by re-running the update. Escalate to the hardware partner (OEM) to re-supply
  the correct SBE package. The package must install so that, on every node, the end-state is
  consistent: `SBEInstalledContent` and `SBEInstalledMetadata` are both set to paths that
  exist, and the metadata path carries an `oemMetadata.xml` with a resolvable version. That is
  the exact end-state the OEM should confirm before handing the package back.
- The sibling SBE health checks also warn or fail (see **Related**), which can indicate a
  broader SBE configuration problem rather than just a stale environment variable.

## Related

- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-tool-troubleshoot#rerun-deployment
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-SolutionExtensionModule` (the staged SBE `SolutionExtension` module is present,
  integrity-intact, and signed), `Test-SBEPropertiesValid` (partner property values match the
  SBE manifest), and `Test-SBECredentialsValid` (SBE credentials in the secret store match the
  SBE manifest).
