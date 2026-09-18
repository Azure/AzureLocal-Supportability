---
ArticleType: "TSG"
Article_ID: "20260917160009"
Title: "Troubleshooting Azure Local Environment Validator Module Versions"
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
Tags: ["Validation", "Solution Update", "Diagnostics"]
---
[[_TOC_]]

# Revision History

| Date | Description |
| --- | --- |
| 2026-09-17 | Retrofitted mandatory publication metadata, audience scope, revision history, and source-article layout without changing the technical procedure. |

# Troubleshooting Azure Local Environment Validator Module Versions

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
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
    <th style="text-align:left;">Component</th>
    <td><code>AzStackHci.EnvironmentChecker</code> module discovery and cleanup during deployment, update, or validation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Signal</th>
    <td>The Environment Validator module import or cleanup path raises an exception. This guide has no standalone <code>Test-*</code> invocation; use the lifecycle result and the node inventory as evidence.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Warning, potentially blocking</strong>: the exception can stop the affected validation or lifecycle phase, but this guide does not establish the product severity of every release. Use the deployment or update result to confirm whether it blocked progress.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The Azure Local Environment Validator or solution-update owner handles module ownership and lifecycle coordination. The workload owner approves any change. A network owner is involved only when independent DNS, TCP, proxy, or firewall evidence points to a separate connectivity issue.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Read-only inventory has no workload impact. A confirmed external module can interfere with validation or cleanup, so the affected deployment or update may stop until the ownership problem is resolved. The approved package-manager operation is scoped to one external module and does not require a VM drain or node reboot by itself.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 15-30 minutes for evidence collection, then 15-30 minutes per node for an approved package-manager change and revalidation. Add time for workload-owner approval or product escalation when ownership is unclear.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Execution surface</th>
    <td>Diagnose on an Azure Local node with Windows PowerShell. Web consoles provide lifecycle correlation only; they do not identify the module path or package owner.</td>
  </tr>
</table>

The `AzStackHci.EnvironmentChecker` PowerShell module can be present in two
different forms:

- **Inbox module, product-owned:** The module base is
  `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker`.
  The inbox module does not have a version-number directory beneath this path.
- **Potential external candidate:** A gallery or administrator installation
  normally has a version-number directory beneath a `PSModulePath` entry. It
  can be installed for the current user or for all users, but the path alone
  does not prove who owns it.

The inbox module is the product-authoritative copy on an Azure Local node.
PowerShell still determines the effective module from the available versions
and the order of `$env:PSModulePath`, so a gallery copy can shadow the inbox
copy or remain unused. `Get-Module -ListAvailable` shows candidates, not which
candidate an already-running validator selected. Candidate presence is not
proof of shadowing, so do not claim that the external copy was active unless
separate process or lifecycle evidence proves it. Always record `ModuleBase`,
`Path`, and `PSModulePath` before changing anything.

This TSG is for diagnosis and, with the required approvals, removal of a
confirmed package-managed external module. It does not authorize deleting the
inbox module, manually deleting module directories, or removing a production
module whose ownership is not established.

## Quick decision

1. Run the read-only inventory on every affected node and preserve the output.
2. If only the product inbox candidate is present, do not uninstall anything.
   Investigate the lifecycle failure with the captured exception and escalate.
3. If one external candidate is present, prove its package-manager ownership
   and scope before requesting approval. If ownership cannot be proved, stop
   and escalate rather than deleting files.

# Symptoms

During deployment, update, or validation, the Environment Validator can
report an exception similar to:

```text
Type 'ValidateConnectivity' of Role 'EnvironmentValidator' raised an exception:
{
    "ExceptionType":  "text",
    "ErrorMessage":  "No match was found for the specified search criteria and module names \u0027AzStackHci.EnvironmentChecker\u0027.",
    "ExceptionStackTrace":  "at Uninstall-Module\u003cProcess\u003e, C:\\Program Files\\WindowsPowerShell\\Modules\\PowerShellGet\\2.2.5\\PSModule.psm1: line 12733\r\nat CleanEnvironmentValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 1230\r\nat EnvironmentValidatorImport, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 784\r\nat RunSingleValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 806\r\nat ValidateConnectivity, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 265\r\nat \u003cScriptBlock\u003e, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 147\r\nat Invoke-EceInterfaceInternal, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 142\r\nat \u003cScriptBlock\u003e, \u003cNo file\u003e: line 36"
}
```

The exception does not by itself prove that the inbox module is missing or
that a gallery module is active. It can also indicate that cleanup attempted
to uninstall a path that PowerShellGet does not own, or that a module is
locked by an active workload.

# Where this failure appears

The direct evidence is the node inventory and the exact lifecycle exception.
The remaining surfaces are either correlation points or explicitly not
diagnostic for module ownership.

| Admin surface | Coverage and evidence |
|---|---|
| PowerShell on an Azure Local node | **Shown**: the read-only inventory below is the authoritative evidence for `Name`, `Version`, `ModuleBase`, `Path`, loaded modules, and `PSModulePath`. |
| Azure portal | The module candidate and owning package are **not evident in the Azure portal**. Use the portal only to correlate the affected deployment or update and its timestamp. |
| Windows event logs | The module candidate and owning package are **not evident in Windows event logs**. An event may preserve the exception for correlation, but it cannot prove which installation the validator selected. |
| Cluster logs from `Get-ClusterLog` | This module-ownership problem is **not evident in the cluster logs** as a cluster health, quorum, or storage event. Use them only when a separate cluster symptom needs correlation. |
| Windows Failover Cluster Manager | This module-ownership problem is **not evident in Failover Cluster Manager** as a clustered role, resource, or node state. |
| Windows Admin Center on a standalone host | The module candidate and package ownership are **not evident in Windows Admin Center on a standalone host**. Use the node inventory instead. |
| Windows Admin Center in the Azure portal | The module candidate and package ownership are **not evident in Windows Admin Center in Azure**. Use the portal lifecycle result only for correlation. |
| Component or tool log files on disk | **Shown when written**: preserve the exact exception and timestamps from `C:\CloudDeployment\Logs` and, when the Environment Checker ran under a user profile, `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`, `AzStackHciEnvironmentReport.json`, or `AzStackHciEnvironmentReport.xml`. A missing log is a data gap, not proof that the failure did not occur. |

The `ValidateConnectivity` role name in the sample stack trace identifies the
Environment Validator code path. It is not evidence of a DNS, TCP, proxy, or
firewall fault. Route this article to the network owner only when an independent
connectivity check supports that conclusion.

# Issue Validation

Run the following **read-only** inventory on each node. Define `$moduleName`
before using it. This command does not import, unload, uninstall, or delete a
module.

```powershell
$moduleName = 'AzStackHci.EnvironmentChecker'
$inboxModuleBase = 'C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker'

$availableModules = @(
    Get-Module -Name $moduleName -ListAvailable |
        Sort-Object Version, ModuleBase
)
$loadedModules = @(
    Get-Module -Name $moduleName
)

Write-Host "Node: $env:COMPUTERNAME"
Write-Host 'PSModulePath:'
$env:PSModulePath -split [IO.Path]::PathSeparator |
    ForEach-Object { Write-Host "  $_" }

Write-Host 'Available module candidates:'
if ($availableModules.Count -eq 0) {
    Write-Host '  None'
} else {
    $availableModules |
        Select-Object Name, Version, ModuleBase, Path |
        Format-Table -AutoSize
}

Write-Host 'Modules loaded in this PowerShell process:'
if ($loadedModules.Count -eq 0) {
    Write-Host '  None'
} else {
    $loadedModules |
        Select-Object Name, Version, ModuleBase, Path |
        Format-Table -AutoSize
}

$nonInboxModules = @(
    $availableModules |
        Where-Object { $_.ModuleBase -ne $inboxModuleBase }
)

Write-Host 'Candidates whose module base is not the inbox path:'
if ($nonInboxModules.Count -eq 0) {
    Write-Host '  None'
} else {
    $nonInboxModules |
        Select-Object Name, Version, ModuleBase, Path |
        Format-Table -AutoSize
}
```

Interpret the output as follows:

- A module whose `ModuleBase` is exactly
  `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker`
  is the expected inbox module. Its version can vary by Azure Local image.
- A versioned module directory, a user-profile module directory, or another
  `PSModulePath` root is evidence of another candidate. It is not proof that
  the validator used that candidate.
- No available module is a module-availability problem. Do not try to fix it
  by uninstalling anything.
- The loaded-module section describes only the current PowerShell process. It
  does not prove that ECE, the Environment Validator, or another service has
  not loaded the module.

### Safe shadow-selection proof boundary

This inventory distinguishes an inbox candidate, an external candidate, and a
module loaded in the diagnostic PowerShell process. It does not prove which
candidate an ECE or Environment Validator process selected. Treat the result
as **external candidate present, active shadowing unproven** unless the process
that ran the validator, or its lifecycle instrumentation, records all of the
following: `Name`, `Version`, `ModuleBase`, `Path`, the process or operation,
and a UTC timestamp.

Do not create a gallery candidate, reorder `PSModulePath`, unload a module,
uninstall a package, delete a module directory, or restart a workload to
manufacture shadowing evidence. Those actions are outside this L1-equivalent
read-only validation. If the owning process cannot expose its selected
`ModuleBase`, preserve the candidate inventory and lifecycle exception,
record that shadowing was not established, and escalate to the Environment
Validator or solution-update owner.

When a product-owned disposable validation plan later provides a package
registration and lifecycle trace, compare that trace with the same inventory
fields before and after the lifecycle operation. Do not promote a candidate
to a confirmed shadowing finding from path order alone.

Record the command output with the node name and UTC timestamp. Also record
whether a deployment, solution update, CAU run, validation, or other
module-owning workload was active. Do not infer ownership from the path alone:
the inbox path is product-owned, while an external path may be owned by an
operator, an automation account, or a prior deployment procedure.

### Evidence to preserve

For CSS or product escalation, retain one evidence set per affected node:

- the exact exception and its UTC timestamp;
- `Name`, `Version`, `ModuleBase`, and `Path` for every available candidate;
- the complete `PSModulePath` and the loaded-module output;
- the deployment, solution-update, CAU, or validation state and its owner;
- the package-manager registration and confirmed installation scope for any
  external candidate; and
- the retry result after verification.

Do not replace the original output with a summary. The distinction between an
available candidate, a loaded module, and the module selected by a lifecycle
process is material evidence.

### Read-only multi-node collection and aggregate report

On a deployed cluster, collect the inventory from every running cluster node
before changing any node. The following block is a read-only remoting
operation: it lists candidates and returns one structured result per node. It
does not import, unload, uninstall, delete, stop, restart, drain, or invoke
the validator. Preserve the per-node output together with the exact
exception and UTC timestamp.

```powershell
$moduleName = 'AzStackHci.EnvironmentChecker'
$inboxModuleBase = 'C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker'

$inventoryScript = {
    param(
        [string]$moduleName,
        [string]$inboxModuleBase
    )

    $availableModules = @(
        Get-Module -Name $moduleName -ListAvailable |
            Sort-Object Version, ModuleBase
    )
    $loadedModules = @(
        Get-Module -Name $moduleName
    )

    [pscustomobject]@{
        Node = $env:COMPUTERNAME
        PSModulePath = @($env:PSModulePath -split [IO.Path]::PathSeparator)
        Available = @(
            $availableModules |
                Select-Object Name, Version, ModuleBase, Path
        )
        Loaded = @(
            $loadedModules |
                Select-Object Name, Version, ModuleBase, Path
        )
        External = @(
            $availableModules |
                Where-Object { $_.ModuleBase -ne $inboxModuleBase } |
                Select-Object Name, Version, ModuleBase, Path
        )
    }
}

$nodes = @(
    Get-ClusterNode -ErrorAction Stop |
        Where-Object State -eq 'Up' |
        Select-Object -ExpandProperty Name
)

if ($nodes.Count -eq 0) {
    throw 'No running cluster nodes were returned. No remote commands were run.'
}

$inventory = @(
    Invoke-Command -ComputerName $nodes `
        -ScriptBlock $inventoryScript `
        -ArgumentList $moduleName, $inboxModuleBase `
        -ErrorAction Stop
)

if ($inventory.Count -ne $nodes.Count) {
    throw "Expected one inventory result per node, received $($inventory.Count) for $($nodes.Count) nodes."
}

$inventory |
    Sort-Object Node |
    Format-List

$inventory |
    Sort-Object Node |
    Select-Object Node,
        @{Name = 'AvailableCount'; Expression = { @($_.Available).Count }},
        @{Name = 'LoadedCount'; Expression = { @($_.Loaded).Count }},
        @{Name = 'ExternalCount'; Expression = { @($_.External).Count }},
        @{Name = 'Classification'; Expression = {
            if (@($_.External).Count -gt 0) {
                'External candidate present, shadowing unproven'
            } elseif (@($_.Available).Count -eq 0) {
                'No available module candidate'
            } else {
                'Inbox-only candidate'
            }
        }} |
    Format-Table -AutoSize
```

The aggregate is a triage aid, not a replacement for the retained
per-node records. An external candidate still requires package-manager
ownership evidence and workload-owner approval. A host that is not yet a
cluster member cannot use `Get-ClusterNode`; run the same read-only inventory
separately on each candidate host and retain one result per host instead of
creating a cluster or broadcasting a remediation.

# Mitigation Details

## Safety and ownership gates

Complete these gates before making any change:

1. **[LOW RISK] Read-only evidence:** Run the inventory above on every
   affected node. Preserve the module table, `PSModulePath`, loaded-module
   output, exact exception, and timestamps.
2. **[MEDIUM RISK] Workload coordination:** Confirm that no deployment,
   solution update, CAU run, Environment Validator execution, or other
   workload that owns or may load this module is active. The owner of that
   workload must approve the change and the retry plan.
3. **[MEDIUM RISK] Scope confirmation:** Identify exactly one external
   `ModuleBase`, its version, and its installation scope from the evidence.
   Do not act on a path merely because it contains a version number.
4. **[MEDIUM RISK] Staged operation:** Use the package manager on one node
   first, then repeat only after verification. Do not broadcast the operation,
   stop processes, reboot nodes, drain VMs, or modify the inbox directory as a
   cleanup shortcut.
5. **[HIGH RISK] Explicit approval:** Obtain confirmation from the workload
   owner before uninstalling an external module. Confirm that PowerShellGet
   has exactly one matching registration for the same module name, version, and
   scope. If the external path cannot be tied to that registration, stop and
   escalate instead of deleting files.

## Remove one confirmed package-managed external installation

Only use this procedure after the gates above are satisfied. Replace the
placeholder with the exact `ModuleBase` captured from the read-only inventory.
The selection must identify one external module and must not match the inbox
path. This action removes the confirmed package-manager installation only. It
does not prove that the external candidate shadowed the inbox module.

```powershell
$moduleName = 'AzStackHci.EnvironmentChecker'
$inboxModuleBase = 'C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker'
$confirmedExternalBase = '<exact external ModuleBase from the inventory>'

$availableModules = @(
    Get-Module -Name $moduleName -ListAvailable |
        Where-Object { $_.ModuleBase -eq $confirmedExternalBase }
)

if ($availableModules.Count -ne 1) {
    throw "Expected exactly one confirmed external module base, found $($availableModules.Count). No change made."
}

if ($availableModules[0].ModuleBase -eq $inboxModuleBase) {
    throw 'The selected module is the inbox module. No change made.'
}

$availableModules |
    Select-Object Name, Version, ModuleBase, Path |
    Format-Table -AutoSize

$approval = Read-Host 'Type REMOVE to uninstall this confirmed external module'
if ($approval -cne 'REMOVE') {
    throw 'Confirmation was not provided. No change made.'
}

$scope = Read-Host 'Enter the confirmed installation scope: CurrentUser or AllUsers'
if ($scope -notin @('CurrentUser', 'AllUsers')) {
    throw 'The installation scope was not confirmed. No change made.'
}

$registeredModules = @(
    Get-InstalledModule -Name $availableModules[0].Name `
        -RequiredVersion $availableModules[0].Version `
        -ErrorAction Stop |
        Where-Object { $_.InstalledLocation -eq $confirmedExternalBase }
)
if ($registeredModules.Count -ne 1) {
    throw "Expected exactly one matching PowerShellGet registration at $confirmedExternalBase, found $($registeredModules.Count). No change made."
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$scopeRoots = if ($scope -eq 'CurrentUser') {
    @(
        (Join-Path $documents 'WindowsPowerShell\Modules'),
        (Join-Path $documents 'PowerShell\Modules')
    )
} else {
    @(
        (Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'),
        (Join-Path $env:ProgramFiles 'PowerShell\Modules')
    )
}
$scopeMatches = @(
    $scopeRoots |
        Where-Object {
            $confirmedExternalBase.StartsWith(
                $_.TrimEnd('\') + '\',
                [System.StringComparison]::OrdinalIgnoreCase)
        }
)
if ($scopeMatches.Count -eq 0) {
    throw "The confirmed ModuleBase does not match the selected $scope module root. No change made."
}

# WARNING: do not proceed unless the approval, scope, and package-manager ownership checks above pass.
Uninstall-Module -Name $availableModules[0].Name `
    -RequiredVersion $availableModules[0].Version `
    -ErrorAction Stop
```

The command intentionally uses terminating errors. Do not replace
`-ErrorAction Stop` with broad suppression. If `Uninstall-Module` reports that
no matching package is registered, a file is locked, or the operation fails
for any other reason, preserve the complete error and stop. Do not use
`Uninstall-Module -Force`, `Remove-Item -Recurse -Force`, a wildcard path, or a
blanket version-removal loop. Manual deletion can remove product files, bypass
ownership checks, and leave the node harder to diagnose.

If the module is loaded in the operator's current diagnostic shell, close that
shell and start a new one after the approved uninstall. Do not unload a module
from an active validator, ECE, update, or deployment process.

### Node order and workload boundary

On a deployed cluster, collect inventory from every affected node before
changing any node. If remediation is approved, process one node, verify it,
and then continue to the next node. Use the read-only collection block above,
or the cluster's approved remoting path, with one retained result per node.
The read-only block is the only fan-out described here. Do not wrap the
uninstall block in a cluster-wide broadcast. Inventory and package-manager
removal do not require a VM drain or node reboot by themselves, but an active
module-owning workload is a stop condition.

## Verify the fix

After the approved uninstall completes, rerun the read-only inventory. The
expected product-node result is a single available module whose `ModuleBase`
is exactly:

```text
C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker
```

The version may vary with the image. A versioned or otherwise external
candidate is not an acceptable success result. Verify the same state on every
affected node before retrying the failed operation.

Then, with the workload owner present, retry the original validator or
lifecycle operation and confirm that:

- the validator no longer reports the module cleanup exception;
- the operation reaches its normal completion state;
- no external module candidate reappears after the lifecycle event; and
- the deployment or update logs contain no new module import or uninstall
  errors.

An inventory that shows only the inbox module proves module-path state. It
does not, by itself, prove that the original validator or lifecycle operation
will succeed.

## Validation boundary

The current validation evidence for this guide is **L1-equivalent and
read-only**: both embedded PowerShell blocks parse, and the inventory plus
inbox-versus-external path classification were executed on one disposable lab
guest with one inbox candidate. No gallery-shadow state was injected, no
module was uninstalled, no recursive deletion was run, and no post-remediation
lifecycle operation was executed. Cluster-wide consistency and the original
failure's remediation remain incident-specific claims to verify on the
affected nodes.

## Escalation

Escalate to the Environment Validator or solution-update owner with the
captured evidence when any of the following applies:

- the inbox module is absent, altered, or not discoverable;
- an external candidate remains after a successful package-manager uninstall;
- `Uninstall-Module` fails, reports an unregistered package, or reports a
  file-lock or access error;
- the external candidate returns after a deployment or update;
- the validator still fails when only the expected inbox module is present; or
- more than one node is affected and ownership or workload state is unclear.

Include the affected node, UTC timestamps, module inventory, exact module
paths, `PSModulePath`, loaded-module output, active workload and owner,
approval record, complete command output, and the retry result. Do not attach
secrets or unrelated customer data.

::: audience-css

# Source Articles

- No additional source article is cited by this guide.

:::
