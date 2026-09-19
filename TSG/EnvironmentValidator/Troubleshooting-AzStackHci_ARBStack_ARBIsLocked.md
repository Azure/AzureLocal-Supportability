---
ArticleType: "TSG"
Article_ID: "20260917170002"
Title: "AzStackHci_ARBStack_ARBIsLocked"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: "ADO Work Item"
  ID: 38357185
Tags: ["Solution Update", "Validation", "ARC Resource Bridge", "RBAC"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory publication metadata, safety and ownership gates, complete administrator-surface guidance, and current validation evidence while preserving the legacy technical procedure. |

:::

# AzStackHci_ARBStack_ARBIsLocked

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_ARBStack_ARBIsLocked</strong></td>
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
    <td><code>Test-ARBIsNotLocked</code> (run with <code>Invoke-AzStackHciARBStackValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>ARB Stack (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Informational</strong> severity, but a lock reports a <strong>FAILURE</strong> status that blocks the update. See the detection note.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>The Azure Local solution update is blocked before the ARB upgrade can modify the appliance. Reading lock state and removing an approved lock do not restart the ARB, move VMs, or interrupt AKS workloads. Starting or resuming the update is a separate change with its normal workload and maintenance-window assessment.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The Azure subscription governance owner who applied or inherited the lock. An identity with <strong>Owner</strong> or <strong>User Access Administrator</strong> at the defining scope performs an approved removal. CSS or the Azure Local administrator collects evidence and reruns validation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 10-15 minutes for read-only confirmation and evidence collection. Lock-owner approval and governance processing can add organization-dependent time. Removing one approved appliance-scope lock and revalidating usually takes another 10-20 minutes.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td><strong>[LOW RISK]</strong> for read-only detection and for removing one approved appliance-scope lock. <strong>[MEDIUM RISK]</strong> for changing a resource-group or subscription lock because that affects every protected resource in that scope. Never remove a parent-scope lock without the defining owner's approval.</td>
  </tr>
</table>

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) check that confirms the **Arc Resource Bridge (ARB)** appliance resource in Azure has **no resource lock** on it.
> - **Why it matters:** a `ReadOnly` or `CanNotDelete` lock on the ARB blocks the ARB upgrade step of an Azure Local solution update, which fails with `ApplianceResourceScopeLocked`. This check surfaces that condition **before** the update so you can clear it first.
> - **Owner:** the Azure subscription governance owner who applied the Azure resource lock. This is not an Azure Local software, firmware, BMC, BIOS, storage, or networking defect.
> - **Read the Status and Detail:** this check reports a **FAILURE** status when the ARB is locked (or when it cannot sign in to Azure to check). The result **Detail** names the condition. See the detection note below.
> - **Fastest safe path:** select the correct subscription, list the locks on the exact ARB appliance, obtain approval from the lock owner, remove only the lock at its defining scope, and rerun the system-health precheck.

## Overview

The Arc Resource Bridge (ARB) is represented in Azure as a `Microsoft.ResourceConnector/appliances` resource. When an Azure resource **lock** (`ReadOnly` or `CanNotDelete`) is placed on that appliance (or on its resource group or subscription, since locks are inherited), the ARB upgrade that runs during an Azure Local solution update is blocked and fails with `ApplianceResourceScopeLocked`. This check runs `az lock list` against the ARB appliance and reports a failure if any lock is present, so the lock can be removed before the update runs.

- **Severity:** the check is defined at Informational severity, but it reports a **FAILURE status** when a lock is found, and that failure blocks the solution update. Treat a failure as actionable.
- **When it runs:** the ARB Stack validator runs this check during **Update** and **Upgrade** readiness (it is intentionally skipped for initial **Deployment**, when no ARB exists yet). In practice you see it as part of a pre-update health check.
- **Read the Status and Detail (IMPORTANT).** A healthy node reports Status SUCCESS with Detail `ARB is not locked as expected.`. A node needs attention when the Status is **FAILURE** and the Detail reads `ARB is locked, <N> locks found...`. A FAILURE whose Detail mentions signing in to Azure is a different problem (see step 2).
- **Who owns the fix.** Whoever applied the lock (often applied intentionally to protect the resource, or inherited from a resource-group or subscription lock). The operator removes the lock from every scope that applies it, then re-runs the readiness check.

## Quick fix

Use this short path only after the safety and ownership gate below is satisfied:

```powershell
# Sign in and select the subscription that contains the ARB.
az login
az account set --subscription '<subscription-id>'
az account show --query '{subscription:id, tenant:tenantId, user:user.name}' -o table

# Find the ARB, then inspect the exact appliance.
az resource list --resource-type 'Microsoft.ResourceConnector/appliances' `
    --query '[].{name:name, resourceGroup:resourceGroup, id:id}' -o table
az lock list --resource '<arbName>' `
    --resource-type 'Microsoft.ResourceConnector/appliances' `
    --resource-group '<arbRG>' -o table
```

The appliance query is an initial signal only. Whether it returns rows or not, run the exact
three-scope discovery in step 3 before deciding which lock applies or declaring the ARB clear.
Delete only an approved lock ID returned by that discovery. Do not delete a parent-scope lock merely
to make this one update pass.

## Requirements

- Access to the Azure subscription that contains the ARB appliance.
- Permission to list resource locks for read-only diagnosis.
- The **Owner** or **User Access Administrator** role at the scope where the lock is defined before removal. Removing a lock requires `Microsoft.Authorization/locks/delete`.
- The Azure CLI (`az`), or the Azure portal, to view and remove the lock.
- The ARB appliance's name and resource group (this guide shows how to find them).
- Approval from the owner of an intentional governance or resource-protection lock.

## Safety and ownership gate

1. **Start read-only.** Listing resources, lock state, role assignments, validator results, and logs is [LOW RISK].
2. **Prove the exact scope.** Record the lock name, level, ID, and the scope where it is defined. A lock inherited from the resource group or subscription must be changed at that parent scope.
3. **Prove authority before deletion.** Confirm the current identity has Owner or User Access Administrator at the defining scope. If `az lock delete` would return `AuthorizationFailed`, stop and route the request to the subscription governance owner.
4. **Get approval for parent-scope changes.** A resource-group or subscription lock protects resources beyond the ARB. Removing it is [MEDIUM RISK] and requires explicit approval from the defining owner. Prefer a temporary, approved exception or owner-performed change.
5. **Do not confuse a management lock with another ARM control.** Azure management locks are defined at subscription, resource-group, or resource scope. Azure Policy deny effects and deny assignments are separate controls and are not returned by `az lock list`. If the lock lists are empty but writes remain denied, preserve the authorization error and investigate policy or deny assignments instead of deleting unrelated locks.
6. **Separate precheck from update execution.** `Invoke-SolutionUpdatePrecheck -SystemHealth` is a validation action. Starting or resuming the solution update is a separate operational change that can drain nodes and move workloads.

## Where this failure appears, and where it does not

| Admin surface | Expected signal |
| --- | --- |
| PowerShell on an Azure Local node | **Shown**: the Event ID 17205 result and the `Invoke-SolutionUpdatePrecheck -SystemHealth` revalidation path. |
| Azure portal | **Shown**: the Azure Local cluster **Updates** view shows the failing readiness result; the ARB appliance, resource group, or subscription **Locks** blade shows the defining lock. |
| Windows event logs | **Shown**: `AzStackHciEnvironmentChecker`, Event ID 17205, with `AdditionalData.Status` and `AdditionalData.Detail`. |
| Cluster logs from `Get-ClusterLog` | This check does **not** appear as an authoritative cluster-log event because the condition is Azure control-plane state, not a failover-cluster transition. |
| Windows Failover Cluster Manager | This check does **not** appear as a dedicated cluster role, resource, or node signal. |
| Windows Admin Center on a standalone host | This check does **not** appear as a dedicated WAC diagnostic. Use the node result, Azure CLI, or portal Locks blade. |
| Windows Admin Center in the Azure portal | This check does **not** appear as a separate WAC diagnostic. Use the Azure Local Updates view and the ARB Locks blade. |
| Component or tool log files on disk | **Shown**: the Environment Checker log and report files under `%USERPROFILE%\.AzStackHci` in the profile that ran the check. |

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

First establish the Azure CLI context and list the lock on the exact ARB resource:

```powershell
az login
az account set --subscription '<subscription-id>'
az account show --query '{subscription:id, tenant:tenantId, user:user.name}' -o table

$arbs = @(az resource list --resource-type 'Microsoft.ResourceConnector/appliances' `
    --query '[].{name:name, resourceGroup:resourceGroup, id:id}' -o json |
    ConvertFrom-Json)
$arbs | Format-Table name, resourceGroup, id -AutoSize
if ($arbs.Count -ne 1) {
    throw "Expected one ARB in the selected subscription, found $($arbs.Count). Select the appliance for the affected cluster explicitly."
}
$arb = $arbs[0]
if (-not $arb.id) {
    throw 'No Microsoft.ResourceConnector/appliances resource was found in the selected subscription.'
}

az lock list --resource $arb.name `
    --resource-type 'Microsoft.ResourceConnector/appliances' `
    --resource-group $arb.resourceGroup -o table
```

Any row is actionable lock evidence, but this resource-level query alone is not sufficient to prove
where a lock is defined or that no inherited lock applies. Record the lock name, level, ID, and
scope, then run step 3 to query and classify the ARB resource, resource group, and subscription
scopes independently.

To read the check result itself, query Event ID 17205:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*ARBIsLocked*' } |
    Select-Object -First 1 Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Remediation
```

`AdditionalData.Status = FAILURE` with `AdditionalData.Detail` containing
`ARB is locked, <N> locks found` confirms this lock path. The leading and trailing wildcard are
required because the serialized result name can carry a domain prefix or node suffix.

The legacy cluster-wide health-result query remains useful when Event ID 17205 is unavailable:

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
$latest = $null
if ($base) {
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $latest) {
    Write-Warning "No HealthCheck result on this node; use the az lock query below or read the AzStackHciEnvironmentChecker event log (Event ID 17205)."
}
else {
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -like '*ARBIsLocked*' } |
        ForEach-Object {
            [pscustomobject]@{
                Status = $_.AdditionalData.Status
                Detail = $_.AdditionalData.Detail
            }
        }
}
```

The same record is on the Windows event log as Event ID 17205 in `AzStackHciEnvironmentChecker`, and in the Azure portal on the cluster's **Updates** tab when a pre-update health check fails.

**Confirm directly against Azure (authoritative).** The equivalent standalone commands are:

```powershell
# Find the ARB appliance (name + resource group)
az resource list --resource-type "Microsoft.ResourceConnector/appliances" --query "[].{name:name, rg:resourceGroup}" -o table

# List locks on it (replace <arbName> and <arbRG> from the line above)
az lock list --resource "<arbName>" --resource-type "Microsoft.ResourceConnector/appliances" --resource-group "<arbRG>" -o table
```

Any rows returned are actionable evidence. No rows at this one scope are inconclusive. Complete all
three successful scope queries in step 3 before declaring the ARB clear.

### 2. What it looks like: example failure signatures

A healthy node reads:

```
ARB is not locked as expected.
```

A node that needs attention reads (Status FAILURE), naming the lock count and the ARB:

```
ARB is locked, 1 locks found. Please remove all the locks for the ARB (cluster-<id>-arcbridge) to proceed with the operation.
```

A different FAILURE mode is a sign-in problem rather than a lock (the check could not authenticate to Azure to look):

```
Failed to login to Azure using MSI. Error: <error text>
```

What each state means:

- **`ARB is locked, <N> locks found`**: one or more Azure resource locks are present on the ARB appliance (or inherited from its resource group or subscription). Remove them (step 5). This is the condition that blocks the ARB upgrade with `ApplianceResourceScopeLocked`.
- **`Failed to login to Azure using MSI`**: the check could not sign in to Azure to read the locks. This is a managed-identity or connectivity problem, not a lock. Resolve the sign-in issue first. See [Troubleshooting MSI Does Not Have Access to Subscription](./Troubleshooting-MSI-Does-Not-Have-Access-To-Subscription.md).

For the MSI sign-in branch, collect these read-only checks before reassigning the issue:

```powershell
Test-NetConnection management.azure.com -Port 443
netsh winhttp show proxy
Get-Service himds | Select-Object Name, Status, StartType
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" show
```

If TCP 443 or the Arc agent is unhealthy, route to the network, proxy, or Arc owner. If those checks
are healthy but the validator still reports MSI login failure, use the linked MSI-access guide and
collect the Environment Checker component logs before escalation.

### 3. Identify the lock and the scope that applies it

Locks are inherited, so a lock on the ARB can be defined directly on the appliance or inherited
from its resource group or subscription. The following read-only block queries every applicable
scope, fails closed if any query or JSON conversion fails, and filters out locks defined on
unrelated resources in the same subscription:

```powershell
$ErrorActionPreference = 'Stop'
$arb = '<arbName>'
$rg = '<arbRG>'

function Invoke-AzJsonOrThrow {
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [Parameter(Mandatory)]
        [string] $ScopeName
    )

    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $output = @(& az @Arguments --only-show-errors 2> $stderrPath)
        $exitCode = $LASTEXITCODE
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
        if ($exitCode -ne 0) {
            throw "Failed to query $ScopeName. Do not declare the ARB clear. Azure CLI error: $stderr"
        }
        if (-not ($output -join '').Trim()) {
            throw "The $ScopeName query returned no JSON output. Do not declare the ARB clear."
        }
        try {
            $json = ($output -join [Environment]::NewLine) |
                ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "The $ScopeName query returned invalid JSON. Do not declare the ARB clear. $($_.Exception.Message)"
        }
        return @($json)
    }
    finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

$account = Invoke-AzJsonOrThrow `
    -Arguments @('account', 'show', '--output', 'json') `
    -ScopeName 'selected subscription context'
$subscriptionId = $account.id
if (-not $subscriptionId) {
    throw 'The selected subscription ID could not be determined. Do not declare the ARB clear.'
}

$arbResource = Invoke-AzJsonOrThrow `
    -Arguments @(
        'resource', 'show',
        '--name', $arb,
        '--resource-type', 'Microsoft.ResourceConnector/appliances',
        '--resource-group', $rg,
        '--output', 'json'
    ) `
    -ScopeName 'ARB resource identity'
$arbId = $arbResource.id.TrimEnd('/')
if (-not $arbId) {
    throw 'The ARB resource ID could not be determined. Do not declare the ARB clear.'
}

$rgId = "/subscriptions/$subscriptionId/resourceGroups/$rg"
$subscriptionScope = "/subscriptions/$subscriptionId"

$resourceResults = Invoke-AzJsonOrThrow `
    -Arguments @(
        'lock', 'list',
        '--resource', $arb,
        '--resource-type', 'Microsoft.ResourceConnector/appliances',
        '--resource-group', $rg,
        '--output', 'json'
    ) `
    -ScopeName 'ARB resource locks'
$resourceLocks = @($resourceResults | Where-Object {
    $_.id -and $_.id.StartsWith(
        "$arbId/providers/Microsoft.Authorization/locks/",
        [StringComparison]::OrdinalIgnoreCase
    )
})

$resourceGroupResults = Invoke-AzJsonOrThrow `
    -Arguments @('lock', 'list', '--resource-group', $rg, '--output', 'json') `
    -ScopeName 'resource-group locks'
$resourceGroupLocks = @($resourceGroupResults | Where-Object {
    $_.id -and $_.id.StartsWith(
        "$rgId/providers/Microsoft.Authorization/locks/",
        [StringComparison]::OrdinalIgnoreCase
    )
})

$subscriptionResults = Invoke-AzJsonOrThrow `
    -Arguments @('lock', 'list', '--subscription', $subscriptionId, '--output', 'json') `
    -ScopeName 'subscription locks'
$subscriptionLocks = @($subscriptionResults | Where-Object {
    $_.id -and $_.id.StartsWith(
        "$subscriptionScope/providers/Microsoft.Authorization/locks/",
        [StringComparison]::OrdinalIgnoreCase
    )
})

$scopeChecks = @(
    [pscustomobject]@{ Scope = 'ARB resource'; DirectLockCount = $resourceLocks.Count }
    [pscustomobject]@{ Scope = 'Resource group'; DirectLockCount = $resourceGroupLocks.Count }
    [pscustomobject]@{ Scope = 'Subscription'; DirectLockCount = $subscriptionLocks.Count }
)
$scopeChecks | Format-Table -AutoSize

$applicableLocks = @(
    $resourceLocks | Select-Object @{n='AppliesAs';e={'Direct'}}, name, level, id
    $resourceGroupLocks | Select-Object @{n='AppliesAs';e={'Inherited from resource group'}}, name, level, id
    $subscriptionLocks | Select-Object @{n='AppliesAs';e={'Inherited from subscription'}}, name, level, id
)
$applicableLocks | Format-Table AppliesAs, name, level, id -AutoSize
```

The scope table must contain all three rows. Any exception or missing row means verification is
incomplete, so stop and do not declare the ARB clear. For each applicable lock, record its
`AppliesAs`, `name`, `level` (`ReadOnly` or `CanNotDelete`), and full `id`. The full ID identifies
the exact defining scope and prevents an unrelated lock from being selected for removal.

Also verify that the current identity is authorized at the defining scope:

```powershell
# Run this at the exact scope that owns the lock.
$scope = '<lock-scope-resource-id>'
az role assignment list --scope $scope --include-inherited `
    --fill-principal-name false `
    --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='User Access Administrator'].{role:roleDefinitionName, scope:scope, principalId:principalId}" `
    -o table
```

This list is a scope preflight, not proof that every listed principal is the signed-in user. Confirm
the current identity and your organization's group membership through its approved identity process.
If you cannot prove that the signed-in identity receives Owner or User Access Administrator at this
scope, do not attempt deletion.

### 4. Consequences if you do not fix this

The Azure Local solution update will fail at the ARB upgrade step (`UpgradeArbAndExtensions`) with an `ApplianceResourceScopeLocked` error, because the update cannot modify the locked appliance. The update is blocked until the lock is removed. There is no data loss; the lock is protecting the resource, so confirm with whoever applied it before removing.

### 5. Remediation

Remove the lock from the scope where it is defined so the ARB upgrade can proceed.

**Most common fix (start here):** the block is usually a single `CanNotDelete` or `ReadOnly` lock on the ARB appliance. Delete that exact appliance-scope lock after approval, then re-run the precheck. Removing a lock is an Azure metadata change: it does **not** restart the ARB or disrupt running VMs or AKS workloads. Coordinate with whoever applied the lock first.

> **STOP before changing a parent scope.** A resource-group or subscription lock may protect many
> resources. Do not remove it from an Azure Local troubleshooting session unless the defining
> governance owner has explicitly approved the change and its wider blast radius.

**Remove the lock (Azure portal):**

1. Navigate to the ARB appliance resource in the Azure portal (resource type `Microsoft.ResourceConnector/appliances`), or to its resource group / subscription if the lock is defined there.
2. Under **Settings**, select **Locks**.
3. Match the full lock ID from step 3 and confirm its level is `ReadOnly` or `CanNotDelete`.
4. Click the delete (trash) icon next to the lock to remove it.

**Remove the lock (Azure CLI):**

```powershell
# Delete only the exact approved lock returned by step 3.
az lock delete --ids "<full-lock-id>"
```

If deletion returns `AuthorizationFailed`, stop. Do not broaden permissions or try a different
identity informally. Provide the lock ID and defining scope to an Owner or User Access Administrator
and ask that owner to remove the approved lock.

After the lock is removed, rerun the system-health precheck. Start or resume the Azure Local solution
update only through the normal change process; the update itself can drain nodes and move workloads.

For the full background on the update-time failure this prevents (including the exact `ApplianceResourceScopeLocked` error and the retry step), see the canonical guides:

- [ARB upgrade fails with ApplianceResourceScopeLocked (appliance scope lock)](../Update/UpgradeArbAndExtensions_fails_ApplianceResourceScopeLocked.md)
- [Known issue: ScopeLockedError during ARB Upgrade](../Upgrade/Known-issue-ScopeLockedError-ARB-Upgrade.md)

Removing an Azure resource lock is a [LOW RISK] metadata change that does not affect the running ARB. Confirm with the lock's owner first, since the lock may have been applied deliberately to protect the resource.

### Optional fleet inventory before an update wave

The following read-only loop reports ARB appliances with locks across subscriptions visible to the
signed-in identity. It does not remove anything:

```powershell
$rows = foreach ($subscription in (az account list --query "[?state=='Enabled'].{id:id,name:name}" -o json | ConvertFrom-Json)) {
    $arbs = az resource list --subscription $subscription.id `
        --resource-type 'Microsoft.ResourceConnector/appliances' `
        --query '[].{name:name,resourceGroup:resourceGroup,id:id}' -o json |
        ConvertFrom-Json

    foreach ($arbResource in @($arbs)) {
        $locks = az lock list --subscription $subscription.id `
            --resource $arbResource.name `
            --resource-type 'Microsoft.ResourceConnector/appliances' `
            --resource-group $arbResource.resourceGroup -o json |
            ConvertFrom-Json
        [pscustomobject]@{
            Subscription = $subscription.name
            ResourceGroup = $arbResource.resourceGroup
            ARB = $arbResource.name
            LockCount = @($locks).Count
            Locks = (@($locks).name -join ', ')
        }
    }
}
$rows | Sort-Object Subscription, ResourceGroup, ARB | Format-Table -AutoSize
```

The resource-level query reports locks defined directly on the ARB. Query the resource-group and
subscription scopes separately to find inherited locks.

### 6. Verification: prove the failure cleared

Rerun the complete three-scope discovery block from step 3 after every approved deletion. Do not
substitute a resource-level query. The ARB is clear of management locks only when all three scope
queries succeed and every direct lock count is zero:

```powershell
if ($scopeChecks.Count -ne 3) {
    throw 'Lock verification did not succeed at all three scopes. Do not declare the ARB clear.'
}
if ($resourceLocks.Count -ne 0) {
    $resourceLocks | Format-Table name, level, id -AutoSize
    throw 'The validator condition is not cleared because a direct ARB resource lock remains.'
}
$inheritedLocks = @($resourceGroupLocks) + @($subscriptionLocks)
if ($inheritedLocks.Count -ne 0) {
    $applicableLocks | Format-Table AppliesAs, name, level, id -AutoSize
    throw (
        'The direct ARB lock condition is cleared, but one or more inherited ' +
        'management locks still apply. Do not start the update until the ' +
        'governance owner resolves or approves each parent-scope lock.'
    )
}
'CLEAR: ARB resource, resource-group, and subscription lock queries all succeeded with zero applicable locks.'
```

If any Azure CLI query errors, returns invalid output, or cannot resolve the selected subscription or
ARB resource ID, stop. An error is not an empty result. After the three-scope check prints the
`CLEAR` message, rerun the pre-update health check so the validator re-evaluates:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm the precheck completed with a current `HealthCheckDate`, then re-read the specific Event ID
17205 result. The ARB lock check is cleared only when its `AdditionalData.Status` is `SUCCESS` and
its `AdditionalData.Detail` is `ARB is not locked as expected.`. The aggregate `HealthState` alone
does not prove this specific check cleared.

> **Note:** the Azure portal readiness view and the cluster-wide health-check result refresh only
> when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a targeted per-node
> re-test. Confirm the Azure lock state with the successful three-scope verification in step 3
> rather than waiting on the portal.

### Evidence collection and escalation

Collect the following before escalation:

```powershell
$out = Join-Path $env:TEMP ('ARBIsLocked-{0:yyyyMMdd-HHmmss}' -f (Get-Date))
New-Item -ItemType Directory -Path $out -Force | Out-Null

Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    Where-Object { $_.Message -like '*ARBIsLocked*' } |
    Select-Object -First 20 TimeCreated, Id, Message |
    Export-Clixml (Join-Path $out 'Event17205.xml')

Get-ChildItem (Join-Path $env:USERPROFILE '.AzStackHci') -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'AzStackHciEnvironment(Check|Report)' } |
    Copy-Item -Destination $out -Force

az account show -o json > (Join-Path $out 'az-account.json')
az lock list --resource '<arbName>' `
    --resource-type 'Microsoft.ResourceConnector/appliances' `
    --resource-group '<arbRG>' -o json > (Join-Path $out 'arb-resource-locks.json')
if ($LASTEXITCODE -ne 0) { throw 'Failed to collect ARB resource locks.' }
az lock list --resource-group '<arbRG>' -o json > (Join-Path $out 'resource-group-locks.json')
if ($LASTEXITCODE -ne 0) { throw 'Failed to collect resource-group locks.' }
az lock list --subscription '<subscription-id>' -o json > (Join-Path $out 'subscription-locks.json')
if ($LASTEXITCODE -ne 0) { throw 'Failed to collect subscription locks.' }
```

Escalate with this bundle when any of the following is true:

- the specific validator still reports `ARB is locked` after all three scope queries succeeded and
  the filtered applicable-lock list was proven empty;
- all three scope queries succeeded with no applicable lock but an update write is denied, which can
  indicate Azure Policy or a deny assignment rather than a management lock;
- any required scope query fails or cannot be parsed, because lock absence is then unverified;
- the validator reports MSI login failure after Arc agent, proxy, and TCP 443 checks are healthy;
- an approved lock was removed but it is recreated by automation or policy before revalidation.

## Glossary

- **ARB (Arc Resource Bridge):** the on-cluster management appliance that projects Azure Local's Arc-enabled resources into Azure. It is represented in Azure as a `Microsoft.ResourceConnector/appliances` resource.
- **Resource lock:** an Azure Resource Manager control that prevents changes to a resource. A `CanNotDelete` lock blocks deletion; a `ReadOnly` lock blocks all writes. Locks are inherited, so a lock on a subscription or resource group also applies to the ARB inside it.
- **`ApplianceResourceScopeLocked`:** the error the ARB upgrade raises during a solution update when the appliance is locked; this check surfaces that lock ahead of the update.
- **MSI (managed identity):** the Azure identity the validator uses from the cluster to authenticate and read the ARB lock state.
- **Resource group:** an Azure container for related resources. A lock defined here is inherited by every resource in the group.
- **Subscription:** the Azure billing and governance boundary above resource groups. A lock defined here applies to resources throughout the subscription.
- **Owner:** an Azure role with resource-management and access-management permissions, including lock deletion.
- **User Access Administrator:** an Azure role focused on access management that includes the authorization permissions needed to manage resource locks.

::: audience-css

# Source Articles

- **Current Environment Checker implementation:** `ASZ-EnvironmentValidator/AzStackHci.EnvironmentChecker/AzStackHCIARBStack/AzStackHci.ARBStack.Helpers.psm1`, function `Test-ARBIsNotLocked`. The September 17, 2026 live source on module `10.2610.0.2039` signs in with MSI, discovers the ARB, and runs `az lock list` against `Microsoft.ResourceConnector/appliances`.
- **Live validation:** disposable Azure Local lab node, September 17, 2026. The shipping `Test-ARBIsNotLocked` returned `SUCCESS` with `ARB is not locked as expected.`. The operator identity did not have the target subscription in its current Azure CLI contexts, so Owner or User Access Administrator could not be proven and no lock mutation was attempted.
- [ARB upgrade fails with ApplianceResourceScopeLocked](../Update/UpgradeArbAndExtensions_fails_ApplianceResourceScopeLocked.md)
- [Known issue: ScopeLockedError during ARB Upgrade](../Upgrade/Known-issue-ScopeLockedError-ARB-Upgrade.md)

:::
