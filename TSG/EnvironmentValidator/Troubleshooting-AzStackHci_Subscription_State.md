# AzStackHci_Subscription_State

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Subscription_State</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-AzureStackHCISubscriptionState</code> (run with <code>Invoke-AzStackHciArcIntegrationValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Arc Integration (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>. A non-active subscription reports a <strong>FAILURE</strong> status that blocks the solution update. See the detection note.</td>
  </tr>
</table>

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) check that confirms the cluster's **Azure Stack HCI subscription is Active** in Azure. On each node it runs `Get-AzureStackHCISubscriptionStatus` and confirms the "Azure Stack HCI" subscription reports `Status = Active`.
> - **Why it matters:** if the subscription is not Active (disabled, warned, or deleted), or the node cannot reach Azure to check it, the cluster is losing or has lost its Azure management plane. The check surfaces that **before** a solution update so it can be fixed first.
> - **Owner:** depends on the sub-mode. A non-active subscription is an **Azure subscription / billing owner** action; a "cannot connect" failure is a **network / firewall / proxy** action; a "not registered" failure is an **operator re-registration** action.
> - **Read the Status and Detail:** this check reports a **FAILURE** status with a `Detail` string that names the exact sub-mode. Match the `Detail` to the right section below; each sub-mode has a different fix.

## Overview

Every node's Azure Stack HCI subscription must be **Active** for the cluster to stay connected to its Azure management plane. This check runs `Get-AzureStackHCISubscriptionStatus` on each node, selects the subscription whose name begins with `Azure Stack HCI`, and passes only when that subscription's `Status` is `Active`. Anything else is a FAILURE, and the `Detail` string tells you which of three conditions occurred.

- **Severity:** the check is defined at **Critical** severity. It reports a **FAILURE status** whenever the subscription is not Active or cannot be read, and that failure blocks the solution update. Treat a failure as actionable.
- **When it runs:** the Arc Integration validator runs this check during **Deployment**, **Update**, and **Upgrade** readiness. In practice you see it as part of a pre-update health check, or in the deployment / upgrade validation output.
- **The three failure sub-modes (IMPORTANT).** Read the `Detail` string and branch:
  1. **Subscription not Active:** `Azure Stack HCI Subscription is inactive on computer <NODE>.` The subscription exists but its state is not `Active`. This is an Azure-side subscription or billing problem.
  2. **Cannot read the subscription:** `Error checking subscription status on <NODE>: Error executing Get-AzureStackHCISubscriptionStatus: <reason>.` The node could not determine the subscription state. The `<reason>` names the cause (not registered, cannot connect, timed out, node not in a cluster).
  3. **No Azure Stack HCI subscription found:** the registration returned no `Azure Stack HCI` subscription at all. The cluster is not registered, or the registration was removed.
- **Who owns the fix.** A non-active subscription is owned by whoever owns the Azure subscription and billing. A connectivity failure is owned by the network / firewall / proxy admin. A missing registration is owned by the operator who registers the cluster with Azure.

> **Most common in the field (start here).** In practice the most common triggers are the "cannot read the subscription" sub-modes: a node that cannot reach Azure (`Unable to connect to service`) or a cluster that lost its registration (`Azure Stack HCI is not registered with Azure`). A subscription that is genuinely disabled is less common. Read the `Detail` string first (step 1) and start with the matching sub-mode in step 5.

## Requirements

- Access to the Azure subscription the cluster is registered to, in the Azure portal, with permission to view the subscription's state (and, if it is disabled, to reactivate it or engage the subscription owner).
- The cluster registered with Azure (Azure Arc), and outbound connectivity from every node to the Azure Stack HCI cloud endpoints.
- A cluster node session to run `Get-AzureStackHCISubscriptionStatus` (the same cmdlet the check runs) for authoritative confirmation.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

Read the newest health-check result on a node and flag the subscription-state check:

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
$latest = $null
if ($base) {
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $latest) {
    Write-Warning "No HealthCheck result on this node; use the authoritative on-box check below, or read the AzStackHciEnvironmentChecker event log (Event ID 17205)."
}
else {
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -like '*Subscription_State*' } |
        ForEach-Object {
            [pscustomobject]@{
                Status = $_.AdditionalData.Status
                Source = $_.AdditionalData.Source
                Detail = $_.AdditionalData.Detail
            }
        }
}
```

The same record is on the Windows event log as Event ID 17205 in `AzStackHciEnvironmentChecker`, and in the Azure portal on the cluster's **Updates** tab when a pre-update health check fails. When the cluster share is unreadable, read the same result straight from the event log:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath "*[System[(EventID=17205)]]" |
  ForEach-Object { try { $_.Message | ConvertFrom-Json } catch { } } |
  Where-Object { $_.Name -eq 'AzStackHci_Subscription_State' } |
  Sort-Object { $_.Timestamp } -Descending |
  Select-Object -First 10 Status, @{n='Source';e={$_.AdditionalData.Source}}, @{n='Detail';e={$_.AdditionalData.Detail}}
```

If the customer noticed this because a pending update will not start, confirm it is the blocker:

```powershell
Get-SolutionUpdate | Select-Object DisplayName, Version, State, HealthCheckResult, HealthCheckDate | Format-Table -AutoSize
```

`HealthCheckResult = Failure` with a recent `HealthCheckDate` means the pre-update validators failed; the JSON above names which one.

**Confirm directly on the node (authoritative).** Run the same cmdlet the check runs and read the "Azure Stack HCI" subscription's status:

```powershell
Get-AzureStackHCISubscriptionStatus | Where-Object SubscriptionName -like 'Azure Stack HCI*' |
    Select-Object SubscriptionName, Status
```

`Status = Active` is healthy. Any other value (or an error, or no row returned) is the failure this check reports.

### 2. What it looks like: example failure signatures

A healthy node reads:

```
Azure Stack HCI Subscription is active on computer NODE01.
```

A node that needs attention reports Status FAILURE with one of the following `Detail` strings. Each maps to a different fix.

**Sub-mode 1: subscription not Active (the headline case).**

```
Azure Stack HCI Subscription is inactive on computer NODE01.
```

The subscription is registered but its Azure state is not `Active` (for example Disabled, Warned, or Deleted). Fix it in Azure (step 5, "Subscription not Active").

**Sub-mode 2: the node could not read the subscription state.** The `Detail` begins `Error checking subscription status on <NODE>: Error executing Get-AzureStackHCISubscriptionStatus:` and ends with the reason:

```
Error checking subscription status on NODE01: Error executing Get-AzureStackHCISubscriptionStatus: Unable to connect to service.
Error checking subscription status on NODE01: Error executing Get-AzureStackHCISubscriptionStatus: Operation timed out.
Error checking subscription status on NODE01: Error executing Get-AzureStackHCISubscriptionStatus: Azure Stack HCI is not registered with Azure.
Error checking subscription status on NODE01: Error executing Get-AzureStackHCISubscriptionStatus: NODE01 is not part of a cluster. Join a cluster and try again.
```

- `Unable to connect to service.` / `Operation timed out.`: the node cannot reach the Azure Stack HCI cloud service. This is a connectivity, firewall, proxy, or DNS problem (step 5, "Cannot connect to Azure").
- `Azure Stack HCI is not registered with Azure.`: the cluster is not registered (step 5, "Not registered").
- `<NODE> is not part of a cluster.`: the node is not yet a cluster member. This is expected pre-deployment; complete deployment / join the node to the cluster first.

**Sub-mode 3: no Azure Stack HCI subscription found.** The registration returned, but no subscription named `Azure Stack HCI` was present. Treat this like "Not registered" (step 5).

> A failure can occasionally appear with an **empty** `Detail` (a transient evaluation during Update or Upgrade). Re-run the readiness check (step 6). If it clears, it was transient. If it persists, run the authoritative on-box cmdlet in step 1 to see the real state, and branch on that.

### 3. Identify the affected nodes

The check runs per node, so confirm which nodes are failing and read each node's live subscription state:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    try {
        $sub = Get-AzureStackHCISubscriptionStatus -ErrorAction Stop |
               Where-Object SubscriptionName -like 'Azure Stack HCI*'
        [pscustomobject]@{ Status = if ($sub) { $sub.Status } else { 'NotFound' }; Error = $null }
    } catch {
        [pscustomobject]@{ Status = 'Error'; Error = $_.Exception.Message }
    }
} | Sort-Object PSComputerName | Select-Object PSComputerName, Status, Error
```

Nodes reporting `Active` are healthy. Nodes reporting any other `Status`, `NotFound`, or an `Error` are the ones to fix.

### 4. Consequences if you do not fix this

If the subscription stays not-Active, the cluster loses its Azure management plane: Arc-managed updates stop arriving, and portal management degrades. Solution updates are blocked at this Arc Integration readiness check until it passes. The cluster keeps running its local VMs and workloads, but it is unmanaged from Azure until the subscription is Active again. A connectivity or registration failure has the same update-blocking effect until connectivity or registration is restored.

### 5. Remediation

Match the `Detail` string from step 2 to the sub-mode and apply the matching fix. All of these are Azure-side or network-side changes; none of them drain nodes or disrupt running VMs.

**Sub-mode: subscription not Active** (`... Subscription is inactive on computer <NODE>`).

1. In the Azure portal, open **Subscriptions** and find the subscription the cluster is registered to.
2. Check its **Status**. If it is Disabled, Warned, Past due, or Expired, the subscription itself needs to be returned to **Active**.
3. Resolve the underlying cause with the subscription owner or Azure Billing / Support: a lapsed payment method, a spending limit reached, a policy or manual disable, or an expired offer. This is not an Azure Local change; it is an Azure subscription change.
4. Once the subscription is Active again, re-run the readiness check (step 6). If the cluster's registration was removed while the subscription was inactive, re-register it (see "Not registered" below).

Risk: [LOW RISK] on the cluster. Reactivating a subscription is an Azure billing / management action and does not change the cluster.

**Sub-mode: cannot connect to Azure** (`Unable to connect to service` / `Operation timed out`).

1. From an affected node, confirm outbound connectivity to the required Azure Local endpoints (the same endpoints registration and Arc use). Firewall, proxy, or DNS changes are the usual cause. For the full list of required outbound endpoints and ports, see [Firewall requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements).
2. If the cluster uses a proxy, confirm the proxy is configured and reachable. See [Troubleshooting External Connectivity Failures in Environment Checker](./Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md) and the connectivity guidance in [Troubleshooting Connectivity Test DNS](./Troubleshooting-Connectivity-Test-Dns.md).
3. Re-run `Get-AzureStackHCISubscriptionStatus` (step 1) from the node; when connectivity is restored it returns the subscription with a real `Status`.

Risk: [LOW RISK]. Restoring outbound connectivity or a proxy setting does not disrupt running workloads.

**Sub-mode: not registered** (`Azure Stack HCI is not registered with Azure`, or no subscription found).

1. Confirm the cluster's Azure registration. A cluster that lost its registration must be re-registered with Azure before this check can pass.
2. Follow the current Azure Local registration guidance at [https://aka.ms/UpgradeRequirements](https://aka.ms/UpgradeRequirements) and the Azure Local registration documentation to re-register the cluster to the correct subscription and resource group.
3. If registration succeeds but the check still fails, re-read the `Detail` (step 1): the state may have moved to the "not Active" or "cannot connect" sub-mode, which have their own fixes above.

Risk: [MEDIUM RISK]. Re-registration changes the cluster's Azure identity binding; confirm the target subscription and resource group with the operator before re-registering.

> **Related:** if the `Detail` instead reads `The provided account MSI@... does not have access to subscription`, that is a different check (the Arc integration validator's access check), not this one. See [Troubleshooting MSI Does Not Have Access to Subscription](./Troubleshooting-MSI-Does-Not-Have-Access-To-Subscription.md).

### 6. Verification: prove the failure cleared

First confirm on the affected nodes that the subscription now reads Active:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    (Get-AzureStackHCISubscriptionStatus | Where-Object SubscriptionName -like 'Azure Stack HCI*').Status
} | Sort-Object PSComputerName
```

Every node should report `Active`. Then re-run the pre-update health check so the validator re-evaluates and refreshes the cluster-wide readiness record:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` with a current `HealthCheckDate`.

> **Note:** the Azure portal readiness view and the cluster-wide health-check result refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a targeted per-node re-test, so confirm the fix with `Get-AzureStackHCISubscriptionStatus` on the nodes rather than waiting on the portal.

## Glossary

- **Azure Stack HCI subscription:** the Azure subscription the Azure Local cluster is registered to, which carries its Azure management plane and billing. The check passes only when this subscription reports `Status = Active`.
- **`Get-AzureStackHCISubscriptionStatus`:** the on-node cmdlet that returns the registered subscriptions and their status. This check runs it and reads the `Azure Stack HCI` subscription's `Status`.
- **Arc Integration validator:** the Environment Validator component (`Invoke-AzStackHciArcIntegrationValidation`, surfaced as `Test-AzStackHciArcIntegration`) that validates the cluster's Azure / Arc integration during Deployment, Update, and Upgrade readiness. This subscription-state check (`Test-AzureStackHCISubscriptionState`) is one of its tests.
- **Active:** the healthy subscription state. Disabled, Warned, Past due, Expired, or Deleted are non-active states that fail this check.
