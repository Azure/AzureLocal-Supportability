---
ArticleType: "KI"
Article_ID: "20260917160010"
Title: "This module requires Az.Accounts version 5.3.0"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
EngineeringStatus: "Pending"
FixedInBuild:
  OS: []
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
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
| 2026-09-17 | 2.0 | Added mandatory publication metadata, canonical layout, audience directives, and source scoping without changing commands or technical evidence. |

:::

# This module requires Az.Accounts version 5.3.0


<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left;">Name</th>
    <td><strong>This module requires Az.Accounts version 5.3.0</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">ArticleType</th>
    <td><code>KI</code></td>
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
    <td><code>Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules</code>, persisted result <code>AzStackHci_ValidatedRecipe_PowerShellModule_Version</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>AzStackHci.EnvironmentChecker and the current Validated Recipe PowerShell-module set</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Warning, potentially blocking</strong>: a confirmed validator failure can stop deployment, update readiness, or another Environment Validator phase. A historical version mismatch by itself is not a failure.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The Azure Local Environment Validator or solution-update owner controls the recipe and remediation. The workload owner approves node changes. This article does not route a module-only symptom to an OEM or hardware owner.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Read-only evidence collection has no workload impact. A confirmed current-recipe failure can block the affected lifecycle operation. Do not claim customer impact from a version difference until the validator and lifecycle result agree.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 15-30 minutes for evidence collection, then 15-30 minutes per affected node for an approved product remediation and revalidation. Add time for repository access, workload coordination, or escalation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Approval boundary</th>
    <td><strong>[LOW RISK]</strong> Run the inventory and validator read-only. <strong>[MEDIUM RISK]</strong> coordinate the workload owner and repository access before a node change. <strong>[HIGH RISK]</strong> do not uninstall, downgrade, or delete a module unless the current product remediation path directs it.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Execution surface</th>
    <td>Diagnose on every affected Azure Local node with Windows PowerShell. The portal and management tools provide lifecycle correlation, not the authoritative module path or recipe value.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validation boundary</th>
    <td>The current review proves L1 read-only diagnostics and validator execution only. It does not claim an L0 full reproduction, downgrade, install, uninstall, mitigation, or revalidation.</td>
  </tr>
</table>

**Decision summary**


Use this article only when the current Environment Validator reports the same
module-version exception or a related failure on the affected node.

1. **[LOW RISK]** Start a new PowerShell session and collect the inventory below
   on every affected node. Preserve the complete output.
2. **[LOW RISK]** Run the current Validated Recipe module check. Its current
   `AdditionalData.Detail` is the authority for the expected versions.
3. **[MEDIUM RISK]** If the current check returns `SUCCESS`, stop. Do not
   reconcile the node to the historical versions in this article.
4. **[HIGH RISK]** If the current check returns `FAILURE`, confirm the
   workload, ownership, and repository gates, then use the product-owned
   `Remediate-PSModules` path. This article does not provide a manual downgrade
   loop.

The diagnostic command and the product remediation use different authorities by
design. `Get-Module -ListAvailable` shows module candidates visible to
PowerShell. `Get-InstalledModule` is only secondary package-ownership evidence
for modules registered with PowerShellGet. The current validator recipe and
`Remediate-PSModules` determine what the product expects now.

# Symptoms


During a ClusterWitness or another Environment Validator operation, the node can
report an exception similar to:

```text
Type 'ValidateClusterWitness' of Role 'EnvironmentValidator' raised an exception:

{
    "ExceptionType":  "text",
    "ErrorMessage":  "This module requires Az.Accounts version 5.3.0. An earlier version of Az.Accounts is imported in the current PowerShell session. Please open a new session before importing this module. This error could indicate that multiple incompatible versions of the Azure PowerShell cmdlets are installed on your system. Please see https://aka.ms/azps-version-error for troubleshooting information.",
    "ExceptionStackTrace":  "at \u003cScriptBlock\u003e, \u003cNo file\u003e: line 8"
}
```

The message is a symptom, not proof that `Az.Accounts` alone is wrong. In the
historical incident behind this article, a dependency such as `Az.Storage` was
outside the recipe and the resulting import error pointed at `Az.Accounts`.
The current validator detail must identify the affected module and expected
recipe before any change is selected.

If the message appears only in a persisted portal result, first rerun the
validator in a fresh session. A stale persisted result and a node-local current
result are different pieces of evidence.

# Issue Validation

## Errors or Failures

**Version boundary and no-downgrade rule**


The original article recorded the following recipe through Azure Local 2511:

| Module | Historical reference through 2511 |
|---|---:|
| `Az.StackHCI` | `2.5.0` |
| `Az.Accounts` | `4.0.2` |
| `Az.Resources` | `7.8.0` |
| `Az.Storage` | `8.1.0` |

The exception text names `Az.Accounts` `5.3.0`, while the historical table names
`4.0.2`. Those values come from different product contexts. Neither value is a
universal repair target.

**Do not install or downgrade to the historical table.** Azure Local recipes
change with the solution and Environment Checker module. A September 16, 2026
2610 lab diagnostic found the shipping validator in `SUCCESS` while the
historical exact pins did not match the node, including newer values for
`Az.Accounts`, `Az.Resources`, `Az.Storage`, and `Az.StackHCI`. That observation
is evidence that the old table is stale for that build, not a new set of
versions to copy into a customer environment.

The current recipe is established only by the current validator's
`AdditionalData.Detail` or the product-owned `Remediate-PSModules` command. A
module version difference without a current validator failure is not sufficient
evidence for remediation.

**Where this failure appears**


Use the node result for module evidence and the lifecycle surfaces only for
correlation:

| Admin surface | Coverage and evidence |
|---|---|
| PowerShell on an Azure Local node | **Shown**: the read-only inventory and `Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules` show the node, candidate versions, paths, status, and current recipe detail. |
| Azure portal | **Shown** when the current readiness evaluation reports the failed validator in the Azure Local cluster's Updates view. The exact module path and package owner are not evident there. |
| Windows event logs | The exact module ownership and current recipe are **not evident in Windows event logs**. An Environment Checker event can preserve the exception for timestamp correlation, but it does not prove which candidate was selected. |
| Cluster logs from `Get-ClusterLog` | This module-version condition is **not evident in the cluster logs** as a quorum, storage, or failover-cluster event. |
| Windows Failover Cluster Manager | The condition is **not evident in Failover Cluster Manager** as a clustered role, resource, or node state. |
| Windows Admin Center on a standalone host | The module path and recipe value are **not evident in Windows Admin Center on a standalone host**. |
| Windows Admin Center in the Azure portal | The module path and recipe value are **not evident in Windows Admin Center in the Azure portal**. Use the Updates view for lifecycle correlation and the node inventory for module evidence. |
| Component or tool log files on disk | **Shown when written**: preserve `C:\CloudDeployment\Logs` and, when the Environment Checker ran under a user profile, `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`, `AzStackHciEnvironmentReport.json`, or `AzStackHciEnvironmentReport.xml`. A missing log is a data gap, not proof that the failure did not occur. |

## PowerShell Detection Script


Run the following **read-only** inventory in a new administrative Windows
PowerShell session on **every affected node**, not only the first node. The
inventory does not import, unload, uninstall, or delete a module.

```powershell
$moduleNames = @(
    'Az.StackHCI',
    'Az.Accounts',
    'Az.Resources',
    'Az.Storage'
)

Write-Host "Node: $env:COMPUTERNAME"
Write-Host "UTC: $([DateTime]::UtcNow.ToString('o'))"

Write-Host 'PSModulePath:'
$env:PSModulePath -split [IO.Path]::PathSeparator |
    ForEach-Object { Write-Host "  $_" }

Write-Host 'Available module candidates:'
foreach ($moduleName in $moduleNames) {
    $available = @(
        Get-Module -Name $moduleName -ListAvailable |
            Sort-Object Version, ModuleBase
    )

    if ($available.Count -eq 0) {
        Write-Host "${moduleName}: no available candidate"
        continue
    }

    $available |
        Select-Object Name, Version, ModuleBase, Path |
        Format-Table -AutoSize
}

Write-Host 'Modules loaded in this PowerShell process:'
$loaded = @(
    Get-Module |
        Where-Object { $_.Name -in $moduleNames } |
        Select-Object Name, Version, ModuleBase, Path
)

if ($loaded.Count -eq 0) {
    Write-Host '  None'
} else {
    $loaded | Format-Table -AutoSize
}

Write-Host 'PowerShellGet package records, if any:'
foreach ($moduleName in $moduleNames) {
    Get-InstalledModule -Name $moduleName -AllVersions -ErrorAction Continue |
        Select-Object Name, Version, Repository, InstalledLocation
}

Write-Host 'Configured repositories:'
Get-PSRepository |
    Select-Object Name, SourceLocation, InstallationPolicy |
    Format-Table -AutoSize
```

Interpret the output as follows:

- `Get-Module -ListAvailable` is the inventory of candidates visible to
  PowerShell. Record every `Name`, `Version`, `ModuleBase`, and `Path`.
- A versioned directory or user-profile path identifies another candidate. It
  does not prove that the Environment Validator selected it.
- `Get-InstalledModule` reports only PowerShellGet-owned package records. A
  missing record does not prove that a candidate is absent and is not permission
  to delete its directory.
- A loaded module describes this PowerShell process only. It does not prove
  what ECE or another lifecycle process loaded.
- A repository listing shows configuration only. It does not prove that a
  package is available or that the product should use that repository.

Next run the current validator in the same new session:

```powershell
$result = @(
    Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules
)

$result |
    Where-Object { $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version' } |
    Select-Object Name, Status, Severity, Remediation,
        @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
```

The `AdditionalData.Detail` value is the authoritative current-recipe evidence.
If it is empty on a failure, preserve the complete result and stop. Do not
select a version from the historical table.

**Diagnostic decision**


- **Current result is `SUCCESS`:** stop. Do not uninstall extra candidates or
  downgrade a passing node. If a portal result is still failing, record both
  timestamps and refresh the readiness evaluation under **Verify the fix**.
- **Current result is `FAILURE` with a module-specific detail:** continue to the
  safety and ownership gates. The detail, not this article's historical table,
  selects the product remediation.
- **No result, a missing module, or an empty detail:** preserve the complete
  output and escalate. Do not use a blanket install or uninstall loop.
- **Only one node fails:** treat the condition as node-local until every affected
  node has a current result. A passing first node is not cluster-wide proof.

# Root Cause

The exception text is a symptom rather than proof that `Az.Accounts` alone is wrong. The current validator detail and recipe comparison determine the affected module and supported remediation.

# Internal Root Cause

::: audience-engineering

No additional internal root-cause detail is required for this article revision.

:::

# Mitigation Details

**Safety, workload, repository, and ownership gates**


Complete these gates before changing a node:

1. **[LOW RISK] Evidence:** save the exact exception, node name, UTC timestamp,
   complete inventory, validator status and detail, configured repositories, and
   the lifecycle result that reported the symptom.
2. **[MEDIUM RISK] Workload coordination:** confirm that deployment, solution
   update, CAU, Environment Validator, ECE, and other module-owning activity is
   not active. Close unrelated diagnostic PowerShell sessions that have the
   target module loaded. Process one affected node at a time and follow the
   workload owner's drain or maintenance decision. This article does not
   authorize stopping VMs, draining a cluster, or rebooting a node.
3. **[MEDIUM RISK] Repository access:** confirm that the product remediation can
   reach its configured package source. Do not assume `PSGallery`, add a
   repository, or use `-Repository PSGallery` based on this article.
4. **[HIGH RISK] Ownership:** confirm that the failing module is external to
   the product-owned path or that the product remediation explicitly owns the
   change. A path alone does not prove ownership. Never delete the inbox
   `AzStackHci.EnvironmentChecker` module or a module directory by hand.
5. **[HIGH RISK] Current recipe:** use the current validator detail and the
   product command below. The historical `4.0.2`, `2.5.0`, `7.8.0`, and `8.1.0`
   values are not authorization to downgrade.

The read-only inventory and validator do not require a reboot. The supported
product remediation below requires a fresh PowerShell session for verification,
not an automatic reboot. If a release-specific product runbook separately
requires a reboot, follow that runbook and preserve the before and after
timestamps.

**Run the current-recipe remediation**


Run this block in a new administrative PowerShell session on one approved node
at a time, or through the supported update remediation workflow that invokes
the same product command:

```powershell
$ErrorActionPreference = 'Stop'
Get-Command Remediate-PSModules -ErrorAction Stop | Out-Null
Remediate-PSModules
```

`Remediate-PSModules` is the product-owned path. It reads the recipe for the
current product operation, reconciles the required module set in dependency
order, checks the configured package sources, and reports errors instead of
silently continuing.

This article intentionally does not use `-Force`, `-AllowClobber`, a hard-coded
`-Repository PSGallery`, a blanket `Uninstall-Module` loop, or recursive module
directory deletion. Adding those switches or commands can replace a current
module with an older one, clobber a dependency, select the wrong source, or
remove product-owned content.

If `Remediate-PSModules` is unavailable, the repository cannot be reached, the
command fails, or ownership is unclear, stop at that node. Preserve the full
error and escalate instead of substituting a manually selected version.

**Verify the fix**


Start a fresh administrative PowerShell session and run the targeted validator
on **every affected node**:

```powershell
$after = @(
    Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules
)

$after |
    Where-Object { $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version' } |
    Select-Object Name, Status, Severity, Remediation,
        @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
```

The node is repaired only when the current result is `SUCCESS` and its detail
does not report a missing module or current-recipe drift. Do not use the
historical table as the success criterion.

After the node-local results pass, refresh the persisted readiness evaluation:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment |
    Format-List HealthState, HealthCheckDate, HealthCheckResult
```

Confirm that the readiness result is successful and that `HealthCheckDate` is
newer than the remediation. The persisted result can lag a targeted validator
run. If it still contains the old exception, preserve both timestamps and the
node-local current result, then escalate rather than repeating a version
change.

**Validation boundary**


The current review deliberately preserves an honest validation limit:

- **L1 completed:** read-only module inventory, repository listing, product
  version evidence, and current validator execution were run on a lab node.
- **L0 not completed:** no duplicate-version injection, downgrade, uninstall,
  install, product remediation, mitigation, revalidation, residue check, or
  cluster-wide comparison was run.
- The current validator returned `SUCCESS` while the historical exact pins did
  not match the observed 2610 module set. This demonstrates stale-version risk;
  it does not reproduce the historical failure and does not prove that any
  downgrade fixes it.
- Therefore this article makes no end-to-end technical-pass claim. Use the
  current validator and product remediation as the decision authority.

**Rollback and failed remediation**


If the product remediation fails, stop the update or readiness retry and
preserve the complete command output. Do not manually uninstall, downgrade, or
delete module directories to force a pass. The product owner must determine
whether the failure is a repository, package, lock, dependency, or current
recipe issue.

If a PowerShell session has the target module loaded, close that diagnostic
session and start a new one for verification. Do not unload a module from an
active validator, update, deployment, or ECE process.

# Escalation


Escalate to the Azure Local Environment Validator or solution-update owner when:

- the validator fails without a module-specific `AdditionalData.Detail`;
- `Remediate-PSModules` is unavailable or fails;
- the current recipe cannot be resolved by the product remediation path;
- the validator still fails after product remediation reports success;
- a module is locked by active workload activity;
- different nodes report different current recipes or module states; or
- the portal result and fresh node result disagree.

Include one evidence bundle per affected node:

- the exact exception and UTC timestamp;
- complete `Name`, `Version`, `ModuleBase`, and `Path` output;
- the complete `PSModulePath` and loaded-module output;
- current repository configuration and any package-owner records;
- deployment, solution-update, CAU, Environment Validator, or ECE state;
- current validator `Status`, `Severity`, `Remediation`, and
  `AdditionalData.Detail`;
- the complete product remediation output, if it was approved and run;
- persisted readiness result and `HealthCheckDate`; and
- post-remediation validator results from every affected node.

Do not attach credentials, tokens, or unrelated customer data. This is a
software module and recipe issue. Do not route it to firmware, BIOS, BMC, or
other hardware remediation unless independent evidence establishes a separate
hardware problem.

# Internal Escalation

::: audience-engineering

Use the evidence bundle above when routing the case to the Environment Validator or solution-update owner.

:::

# Related Content

- [Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md)
- [Azure PowerShell version troubleshooting](https://aka.ms/azps-version-error)

::: audience-css

# Source Articles

- [Azure PowerShell version troubleshooting](https://aka.ms/azps-version-error)
- [Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md)

:::
