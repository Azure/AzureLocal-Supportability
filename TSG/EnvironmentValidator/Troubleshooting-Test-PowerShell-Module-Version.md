---
ArticleType: "TSG"
Article_ID: "20260917160012"
Title: "AzStackHci_ValidatedRecipe_PowerShellModule_Version"
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
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: ""
  ID: 0
Tags: ["Solution Update", "Validation", "Diagnostics"]
---
[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory PickleFactory metadata, canonical layout, audience directives, and source scoping without changing commands or technical evidence. |

:::

# AzStackHci_ValidatedRecipe_PowerShellModule_Version

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_ValidatedRecipe_PowerShellModule_Version</strong></td>
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
    <td><code>Invoke-AzStackHciValidatedRecipeValidation -Include Test-PSModules</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Validated Recipe / Environment Validator</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: module drift can block deployment or a solution update.</td>
  </tr>
</table>

## Overview

The Validated Recipe PowerShell-module check compares the modules installed on an
Azure Local node with the recipe supported by the Azure Local build and update
operation. The recipe is product data and changes over time. A version that was
valid for an older release is not a safe repair target for a newer release.

This guide uses the validator's current detail and the product-owned
`Remediate-PSModules` reconciliation path. It does not prescribe a fixed historical
module version, a blanket uninstall loop, or manual deletion of module directories.

> **At a glance**
> - **What it is:** a pre-update Validated Recipe check for PowerShell module drift.
> - **What the failure means:** the validator found a missing module, an installed version outside the current recipe, or an incomplete module installation.
> - **Safe repair:** capture the validator detail, confirm the workload gate, run `Remediate-PSModules`, and re-run the validator.
> - **Do not do:** do not copy a module version from an old incident or older TSG into an `Install-Module` or `Uninstall-Module` command.

## Symptoms

During deployment or a solution-update readiness run, the Environment Validator
reports **Test PowerShell Module Version** as failed. The Azure portal may show the
failed check under the cluster's **Updates** view.

Read the persisted result and its `AdditionalData.Detail` field:

```powershell
$healthResults = @(
    Get-SolutionUpdateEnvironment |
        Select-Object -ExpandProperty HealthCheckResult
)

$healthResults |
    Where-Object { $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version' } |
    Select-Object Name, DisplayName, Status, Severity, Remediation,
        @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
```

The detail identifies the module and the current recipe comparison. A drift entry
has the form of a module found on a host with an installed value and an
`expected less-than or equal to` value. A missing-module entry may report an
installed value of `N/A`.

## Issue Validation

Run the targeted validator in a new PowerShell session on each affected node. This
is read-only and does not import, uninstall, or delete a module:

```powershell
$result = @(
    Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules
)

$result |
    Where-Object { $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version' } |
    Select-Object Name, Status, Severity,
        @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
```

To separate the semicolon-delimited entries in the validator detail:

```powershell
$detail = @(
    $result |
        Where-Object { $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version' } |
        ForEach-Object { $_.AdditionalData.Detail }
)

$detail -split ';' |
    Where-Object { $_ -match 'found|Checking version|Failed to parse' } |
    ForEach-Object { $_.Trim() }
```

The `Checking version` entry is the authoritative source for the expected recipe
value on a failing node. Do not infer that value from a passing node's current
inventory, from a prior release, or from another article.

If the result is `FAILURE` but `AdditionalData.Detail` is empty, preserve the full
result and stop. The failure is not actionable enough to select a module version
manually.

## Contributing Factors and Evidence

The check can report any of the following states:

- **Missing module:** the module cannot be parsed or is not installed on the node.
- **Version drift:** an installed version is outside the current recipe boundary.
- **Incomplete package state:** PowerShellGet metadata or the module tree is not
  internally consistent.
- **Workload interference:** an active deployment, update, validator session, or
  another PowerShell process has a module loaded or locked.

The validator detail establishes the module and recipe comparison. It does not
establish which operator, process, or previous procedure changed the node. Do not
assign ownership without the module inventory, workload state, and timestamps.

## Where This Failure Appears

The failure is most useful on the node and in the update-readiness surfaces:

- **PowerShell on an Azure Local node:** shown by
  `Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules`
  and the `AdditionalData.Detail` value.
- **Azure portal:** shown on the Azure Local cluster's **Updates** view when the
  pre-update health check reports the validator failure.
- **Windows event logs:** shown in the `AzStackHciEnvironmentChecker` event log as
  Event ID `17205`. Read the check's `AdditionalData.Detail`, not only the generic
  event description.
- **Component or tool log files:** shown in the Environment Checker's
  `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and
  `AzStackHciEnvironmentReport.json` files for the account that ran the check.
- **Cluster logs:** this validator result does not appear in `Get-ClusterLog`; it is
  not a failover-cluster event.
- **Failover Cluster Manager:** this validator result does not appear in
  Failover Cluster Manager; it is not a clustered role, resource, or node state.
- **Windows Admin Center (standalone host):** this validator result does not appear
  in Windows Admin Center on a standalone host.
- **Windows Admin Center in the Azure portal:** this validator result does not
  appear in Windows Admin Center in the Azure portal; use the Updates view instead.

The persisted result and the event log can lag a targeted validator run until the
next readiness evaluation. Use the targeted command for the immediate node result,
then refresh the readiness result during verification.

## Mitigation Details

### Safety and ownership gates

Complete these gates before changing any node:

1. **[LOW RISK] Read-only evidence:** capture the validator result,
   `AdditionalData.Detail`, node name, UTC timestamp, and the affected module names.
2. **[MEDIUM RISK] Workload coordination:** confirm that deployment, solution
   update, CAU, Environment Validator, and other module-owning activity is not
   active. Close unrelated PowerShell sessions that may have the target module
   loaded.
3. **[MEDIUM RISK] Scope confirmation:** repeat the evidence collection on every
   affected node. The targeted `-Include` invocation is a node-local check, so a
   passing result from one node does not clear another node.
4. **[HIGH RISK] Product-owned repair:** use the current product remediation
   command below. If it is unavailable or returns an error, preserve the complete
   error and escalate. Do not replace it with a historical version pin.

### Run the current-recipe remediation

Run this block in a new administrative PowerShell session on each affected node,
or through the supported update remediation workflow that invokes the same
product command:

```powershell
$ErrorActionPreference = 'Stop'
Get-Command Remediate-PSModules -ErrorAction Stop | Out-Null
Remediate-PSModules
```

`Remediate-PSModules` reads the recipe for the current product operation, reconciles
the module set in dependency order, and reports errors instead of silently
continuing. The command is the source of truth for the versions to install.

Do not run a blanket `Uninstall-Module` loop, do not pass a version copied from an
older release to `Install-Module`, and do not recursively delete a module path.
Those actions can downgrade a node that already passes the current validator or
remove product-owned content.

If `Remediate-PSModules` is not present, the repository is unavailable, or the
command fails, stop at that node. Do not guess a repository, module version, or
replacement command. Escalate with the captured detail and complete error output.

## Verify the Fix

Run the targeted validator again on every affected node:

```powershell
$after = @(
    Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules
)

$after |
    Where-Object { $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version' } |
    Select-Object Name, Status, Severity,
        @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
```

The check is repaired only when the result is `SUCCESS` and the detail contains
the current installed module inventory without a drift or missing-module entry.
Repeat the check on all affected nodes. Do not treat one node's passing result as
cluster-wide proof.

After the node-local checks pass, refresh the readiness evaluation so the
persisted result is current:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment |
    Format-List HealthState, HealthCheckDate, HealthCheckResult
```

Confirm that the readiness result is successful and that its timestamp is newer
than the remediation. If the persisted result still contains the old failure,
preserve both timestamps and the node-local `SUCCESS` result, then escalate rather
than repeating a version change.

## Rollback and Failed Remediation

If the product remediation fails, stop the update or readiness retry and preserve
the complete command output. Do not manually uninstall, downgrade, or delete
module directories to force a pass. The product owner must determine whether the
failure is a repository, package, lock, dependency, or current-recipe issue.

If a PowerShell session has the target module loaded, close that diagnostic session
and start a new one for the verification. Do not unload a module from an active
validator, update, deployment, or ECE process.

## Escalation

Escalate to the Environment Validator or solution-update owner when any of these
conditions applies:

- the validator fails without a module-specific `AdditionalData.Detail`;
- `Remediate-PSModules` is unavailable or fails;
- the current recipe cannot be resolved by the product remediation path;
- the validator still fails after the product remediation reports success;
- a module is locked by an active workload; or
- different nodes report different recipe or module states.

Include the affected node names, UTC timestamps, complete validator detail,
the persisted health-check result, the complete remediation error or output, and
the post-remediation validator result. Do not attach credentials, tokens, or
unrelated customer data.

::: audience-css

# Source Articles

- [Azure Local update troubleshooting](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2)
- [Azure PowerShell version troubleshooting](https://aka.ms/azps-version-error)

:::
