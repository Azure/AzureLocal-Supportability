# AzStackHci_ARBStack_ARBIsLocked

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_ARBStack_ARBIsLocked</strong></td>
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
</table>

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) check that confirms the **Arc Resource Bridge (ARB)** appliance resource in Azure has **no resource lock** on it.
> - **Why it matters:** a `ReadOnly` or `CanNotDelete` lock on the ARB blocks the ARB upgrade step of an Azure Local solution update, which fails with `ApplianceResourceScopeLocked`. This check surfaces that condition **before** the update so you can clear it first.
> - **Owner:** operator / whoever applied the Azure resource lock. This is not an Azure Local software defect; the fix is to remove the lock.
> - **Read the Status and Detail:** this check reports a **FAILURE** status when the ARB is locked (or when it cannot sign in to Azure to check). The result **Detail** names the condition. See the detection note below.

## Overview

The Arc Resource Bridge (ARB) is represented in Azure as a `Microsoft.ResourceConnector/appliances` resource. When an Azure resource **lock** (`ReadOnly` or `CanNotDelete`) is placed on that appliance (or on its resource group or subscription, since locks are inherited), the ARB upgrade that runs during an Azure Local solution update is blocked and fails with `ApplianceResourceScopeLocked`. This check runs `az lock list` against the ARB appliance and reports a failure if any lock is present, so the lock can be removed before the update runs.

- **Severity:** the check is defined at Informational severity, but it reports a **FAILURE status** when a lock is found, and that failure blocks the solution update. Treat a failure as actionable.
- **When it runs:** the ARB Stack validator runs this check during **Update** and **Upgrade** readiness (it is intentionally skipped for initial **Deployment**, when no ARB exists yet). In practice you see it as part of a pre-update health check.
- **Read the Status and Detail (IMPORTANT).** A healthy node reports Status SUCCESS with Detail `ARB is not locked as expected.`. A node needs attention when the Status is **FAILURE** and the Detail reads `ARB is locked, <N> locks found...`. A FAILURE whose Detail mentions signing in to Azure is a different problem (see step 2).
- **Who owns the fix.** Whoever applied the lock (often applied intentionally to protect the resource, or inherited from a resource-group or subscription lock). The operator removes the lock from every scope that applies it, then re-runs the readiness check.

## Requirements

- Access to the Azure subscription that contains the ARB appliance, with permission to view and delete resource locks (removing a lock requires `Microsoft.Authorization/locks/delete`, which is included in the **Owner** and **User Access Administrator** roles).
- The Azure CLI (`az`), or the Azure portal, to view and remove the lock.
- The ARB appliance's name and resource group (this guide shows how to find them).

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

Read the check result and confirm the Status is FAILURE with a lock Detail. Read the newest health-check result file and flag the ARB lock check:

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
                Status = $_.Status
                Detail = $_.AdditionalData.Detail
            }
        }
}
```

The same record is on the Windows event log as Event ID 17205 in `AzStackHciEnvironmentChecker`, and in the Azure portal on the cluster's **Updates** tab when a pre-update health check fails.

**Confirm directly against Azure (authoritative).** List the locks on the ARB appliance. First find the appliance, then list its locks:

```powershell
# Find the ARB appliance (name + resource group)
az resource list --resource-type "Microsoft.ResourceConnector/appliances" --query "[].{name:name, rg:resourceGroup}" -o table

# List locks on it (replace <arbName> and <arbRG> from the line above)
az lock list --resource "<arbName>" --resource-type "Microsoft.ResourceConnector/appliances" --resource-group "<arbRG>" -o table
```

Any rows returned are the locks that trip this check. No rows means the ARB is not locked.

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

### 3. Identify the lock and the scope that applies it

Locks are inherited, so a lock on the ARB can live on the appliance itself, on its resource group, or on the subscription. List locks at each scope so you remove the right one:

```powershell
$arb = '<arbName>'; $rg = '<arbRG>'
# On the appliance
az lock list --resource $arb --resource-type "Microsoft.ResourceConnector/appliances" --resource-group $rg -o table
# On the resource group
az lock list --resource-group $rg -o table
# On the subscription
az lock list -o table
```

Note each lock's `name` and `level` (`ReadOnly` or `CanNotDelete`) and the scope it is defined at. You remove it at the scope where it is defined.

### 4. Consequences if you do not fix this

The Azure Local solution update will fail at the ARB upgrade step (`UpgradeArbAndExtensions`) with an `ApplianceResourceScopeLocked` error, because the update cannot modify the locked appliance. The update is blocked until the lock is removed. There is no data loss; the lock is protecting the resource, so confirm with whoever applied it before removing.

### 5. Remediation

Remove the lock from the scope where it is defined so the ARB upgrade can proceed.

**Most common fix (start here):** the block is usually a single `CanNotDelete` or `ReadOnly` lock on the ARB appliance (or inherited from its resource group). Delete that lock (portal Locks blade, or `az lock delete` below), then re-run the update. Removing a lock is an Azure metadata change: it does **not** restart the ARB or disrupt running VMs or AKS workloads. Coordinate with whoever applied the lock first (locks are often applied deliberately by a governance or resource-protection policy, or inherited from a subscription or resource-group lock set by a platform team).

**Remove the lock (Azure portal):**

1. Navigate to the ARB appliance resource in the Azure portal (resource type `Microsoft.ResourceConnector/appliances`), or to its resource group / subscription if the lock is defined there.
2. Under **Settings**, select **Locks**.
3. Identify the `ReadOnly` or `CanNotDelete` lock.
4. Click the delete (trash) icon next to the lock to remove it.

**Remove the lock (Azure CLI):**

```powershell
# Delete a lock defined on the appliance
az lock delete --name "<lockName>" --resource "<arbName>" --resource-type "Microsoft.ResourceConnector/appliances" --resource-group "<arbRG>"

# Or, if the lock is defined on the resource group or subscription:
az lock delete --name "<lockName>" --resource-group "<arbRG>"   # resource-group scope
az lock delete --name "<lockName>"                               # subscription scope
```

After the lock is removed, re-run the Azure Local solution update; it will proceed past the scope-lock validation.

For the full background on the update-time failure this prevents (including the exact `ApplianceResourceScopeLocked` error and the retry step), see the canonical guides:

- [Type 'UpdateArbAndExtensions' fails with ApplianceResourceScopeLocked](../Update/UpgradeArbAndExtensions_fails_ApplianceResourceScopeLocked.md)
- [Known issue: ScopeLockedError during ARB Upgrade](../Upgrade/Known-issue-ScopeLockedError-ARB-Upgrade.md)

**Risk:** [LOW RISK] removing an Azure resource lock is a metadata change that does not affect the running ARB. Confirm with the lock's owner first, since the lock may have been applied deliberately to protect the resource.

### 6. Verification: prove the failure cleared

Confirm no locks remain on the ARB appliance (or the resource group / subscription):

```powershell
az lock list --resource "<arbName>" --resource-type "Microsoft.ResourceConnector/appliances" --resource-group "<arbRG>" -o table
```

An empty result means the ARB is no longer locked. Then re-run the pre-update health check so the validator re-evaluates:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` with a current `HealthCheckDate`. A healthy node reports `ARB is not locked as expected.`

> **Note:** the Azure portal readiness view and the cluster-wide health-check result refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a targeted per-node re-test, so confirm the fix with `az lock list` rather than waiting on the portal.

## Glossary

- **ARB (Arc Resource Bridge):** the on-cluster management appliance that projects Azure Local's Arc-enabled resources into Azure. It is represented in Azure as a `Microsoft.ResourceConnector/appliances` resource.
- **Resource lock:** an Azure Resource Manager control that prevents changes to a resource. A `CanNotDelete` lock blocks deletion; a `ReadOnly` lock blocks all writes. Locks are inherited, so a lock on a subscription or resource group also applies to the ARB inside it.
- **`ApplianceResourceScopeLocked`:** the error the ARB upgrade raises during a solution update when the appliance is locked; this check surfaces that lock ahead of the update.
