# Live migration fails with "No mapping between account names and security IDs was done" (0x80070534)

## Overview

On an Azure Local 24H2 cluster running a solution version **earlier than 12.2605**, live migration of certain virtual machines fails with the error **"No mapping between account names and security IDs was done" (0x80070534)**. Because a solution update drains each node by moving its VMs to another node, this same failure can also cause a **Cluster Aware Updating (CAU) run or solution update to fail** when an affected VM cannot be live migrated off a node.

This issue is specific to Azure Local **24H2**, and only before solution update **12.2605**. The two OS generations are told apart by the leading number of the Azure Local version (shown on the Azure Local resource in the Azure portal, or from `Get-StampInformation`): **23H2** versions begin with **10.** or **11.** (for example 11.2510), and **24H2** versions begin with **12.** (for example 12.2604 or 12.2605).

On **23H2** (a 10.x or 11.x version) this is **not** a problem, and the affected VMs live migrate normally. The failure appears only after a cluster is **updated to 24H2** (a 12.x version), as an upgrade regression, and it then persists on 24H2 until the cluster is updated to **12.2605 or later**, which restores correct live migration. In short: 23H2 (10.x or 11.x) works; 24H2 (12.x) below 12.2605 fails; 24H2 at 12.2605 or later works again.

The fix is included in the Azure Local **12.2605** solution update and is enabled automatically when the cluster is updated. It removes an account validation step that live migration does not actually need (see Cause). This article explains how to confirm you are hitting this issue, how to resolve it by updating, and an interim quick migration workaround that lets you complete the update to the fixed version and then be turned back off.

**Severity:** High. An affected VM cannot be live migrated, and a solution update or CAU run can fail when that VM cannot be drained off a node. The interim workaround below keeps the cluster serviceable until you reach the fixed version.

**Who resolves this and how long:** a cluster administrator (customer IT, or the deploying partner), from an elevated PowerShell session on a cluster node. The interim workaround is a few commands per cluster (minutes) and is fully reversible; the permanent fix is the standard solution update to 12.2605. This is an identity (Active Directory SID resolution) and platform-update issue, not a networking or hardware fault.

### Terms used in this article

- **SID (Security Identifier):** the unique ID Windows assigns to an account. Each VM records the SID of the account that created it.
- **Live migration:** moves a running VM to another node with no downtime.
- **Quick migration:** moves a VM by briefly saving its state to disk and restoring it on the other node (a short pause, no reboot, no data loss).

## Symptoms

- Live migration of one or more VMs fails with:

  ```
  No mapping between account names and security IDs was done. (0x80070534)
  Virtual machine migration operation for '<VMName>' failed at migration source '<NodeName>'.
  ```

- A solution update or CAU run fails to drain a node. The reported error may look like a node that failed to update or a migration that will not complete (for example the run reports a failed or timed out node, or a migration stays queued or hangs).
- The failure is often **directional**: the same VM migrates successfully in one direction but fails in the other, or it starts failing only **after a node has been rebooted** (for example during an update). Other VMs on the same cluster migrate normally.

## Issue Validation

To confirm the scenario you are encountering is the issue documented in this article, confirm both of the following.

**1. Confirm the error signature.** On the node that was the **source** of the failed migration, check the Hyper-V VMMS logs. The two confirming events come from **different logs**, so query both:

```powershell
foreach ($log in 'Microsoft-Windows-Hyper-V-VMMS-Admin',
                 'Microsoft-Windows-Hyper-V-VMMS-Operational') {
    Get-WinEvent -LogName $log -MaxEvents 200 -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Id -eq 21024 -or
        $_.Id -eq 1106 -or
        $_.Message -match 'No mapping between account names' -or
        $_.Message -match '80070534'
      } |
      Select-Object TimeCreated, LogName, Id, LevelDisplayName, Message |
      Format-List
}
```

Two events together confirm the issue, and they live in different logs:

- Event **21024** in the **Microsoft-Windows-Hyper-V-VMMS-Admin** log is the failure *marker*: "Virtual machine migration operation for '&lt;VMName&gt;' failed at migration source '&lt;NodeName&gt;'". It names the affected VM but does **not** itself contain the SID error text.
- Event **1106** in the **Microsoft-Windows-Hyper-V-VMMS-Operational** log carries the *definitive signature*: "No mapping between account names and security IDs was done", with the HRESULT rendered as the bare code `80070534` (note: no `0x` prefix, and not in the Admin log). This is the event that confirms the cause.

> To collect for Microsoft Support: export the **Microsoft-Windows-Hyper-V-VMMS-Admin**, **Microsoft-Windows-Hyper-V-VMMS-Operational**, and **Microsoft-Windows-Hyper-V-High-Availability-Admin** logs from the source node, and note the failing VM name and the cluster's Azure Local solution version.

**2. Confirm the VM is exposed to this issue.** The affected VM was created or imported under an account whose Security Identifier (SID) does not resolve in Active Directory. This happens in either of these cases:

- The VM was **created or imported under a local (non-domain) administrator account** on a cluster node (for example the built in Administrator, or another local account). A local account SID exists only on that node and can never be resolved through Active Directory.
- The VM was created by a **domain account that has since been removed (deleted) from the domain**. Once the account is deleted, its SID is orphaned and no longer resolves in Active Directory.
- The VM was **migrated or imported into Azure Local from VMware or Hyper-V** (for example using Azure Migrate). If the migration registered the VM under a local node administrator account rather than a domain account, the recorded owner SID is a local account that exists only on that node and cannot be resolved through Active Directory.

VMs created under a normal domain account that still exists are not affected and migrate correctly regardless of solution version.

## Cause

Before live migrating a VM, Azure Local builds earlier than 12.2605 validate the account that originally created or imported the VM by resolving its Security Identifier (SID). On 24H2 that resolution goes through Active Directory. The live migration fails whenever the creating account's SID cannot be resolved in Active Directory, which happens for two reasons:

1. The VM was created or imported under a **local node administrator** account instead of an Active Directory account. A local account exists only on the one node that owns it and is never present in Active Directory. This commonly happens when a VM is **migrated into Azure Local from VMware or Hyper-V** (for example using Azure Migrate) and the migration registers the VM under a local administrator, or when a VM is created directly under the built in Administrator or another local account.
2. The VM was created or imported under an **Active Directory administrator account that no longer exists**. Once that account is deleted, its SID is orphaned and no longer resolves in Active Directory.

In either case the security setup step of the live migration fails with `0x80070534`, "No mapping between account names and security IDs was done", and the migration is aborted.

**What the fix changes.** Validating the account that created the VM is not necessary for a live migration to succeed. On builds earlier than 12.2605 this unnecessary validation caused live migrations to fail needlessly for the two cases above. The Azure Local **12.2605** solution update removes that validation, and it is enabled automatically when the cluster is updated, so live migration no longer depends on resolving the account that created the VM. Clusters below 12.2605 still perform the unnecessary validation, which is why an affected VM still fails to live migrate there.

## Resolution

Update the cluster to Azure Local **12.2605 or later**. The solution update enables the fix on every node automatically. There is nothing to set manually, and no VM needs to be recreated. You can see the cluster's current Azure Local version in the Azure portal on the Azure Local resource, or in the cluster's Updates view. After the update:

- Affected VMs live migrate correctly in both directions.
- If you applied the quick migration workaround below, revert the affected VMs back to live migration (see the workaround section).

If you cannot update immediately, use the interim quick migration workaround below to keep the cluster serviceable, including to complete the update to the fixed version itself.

## Interim workaround: quick migration

Live migration of an affected VM fails on a cluster below 12.2605, but **quick migration of the same VM succeeds**. Quick migration succeeds because it does not perform the live-migration security handshake that resolves the owner SID through Active Directory; it saves and restores the VM state instead. Setting the affected VMs to use quick migration lets the cluster move them between nodes, including during the rolling node drain of a solution update, so you can complete the update to 12.2605 (which then enables the permanent fix). This setting is stored in the cluster database, persists across node reboots, and is fully reversible.

### Quick migration compared with live migration

Both methods move a running VM to another node without a reboot and without data loss. The difference is whether the VM keeps running during the move.

| | Live migration | Quick migration |
|---|---|---|
| VM during the move | Stays running the whole time | Saved to disk, briefly paused, then resumed on the destination |
| Downtime | None. The final switchover is sub-second and not noticeable | A short pause while the VM state is saved and restored |
| Length of the pause | Not applicable | Scales with the VM's assigned memory. Typically a few seconds to a few tens of seconds |
| In-guest impact | None | The guest is frozen during the pause. Time-sensitive sessions may notice a brief stall; most network connections survive a pause of a few seconds |
| Reboot or data loss | No | No. State is saved and restored, so the VM resumes exactly where it left off |
| Result on a cluster below 12.2605 (affected VM) | Fails with 0x80070534 | Succeeds |

For most workloads the brief pause of a quick migration is acceptable, and it is far preferable to a failed update or a VM that cannot be moved off a node. For a latency-sensitive workload, plan the move (and any update that drains its node) for a maintenance window. If the pause is not acceptable for a particular VM, keep that VM on a single node until the cluster is updated to 12.2605, then live migration works normally.

### Apply the workaround

Identify the affected VMs (the VMs that fail live migration with this error, named in the Event 21024 entries, or the VMs that match the two creation conditions above). Set each of them to use quick migration. Replace `VM1`, `VM2`, `VM3` with the names of your affected VMs.

```powershell
# Set the affected VMs to quick migration.
$affectedVMs = @("VM1", "VM2", "VM3")
foreach ($vm in $affectedVMs) {
    $vmObj = Get-VM -Name $vm -ComputerName (Get-ClusterGroup $vm).OwnerNode
    $res   = Get-ClusterResource -VMId $vmObj.VMId
    $res | Set-ClusterParameter -Name DefaultMoveType -Value 1
    $current = ($res | Get-ClusterParameter DefaultMoveType).Value
    Write-Host "$vm : DefaultMoveType = $current"
}
```

A `DefaultMoveType` of **1** means quick migration. The system default of **4294967295** means live migration.

Verify the setting:

```powershell
foreach ($vm in $affectedVMs) {
    $vmObj = Get-VM -Name $vm -ComputerName (Get-ClusterGroup $vm).OwnerNode
    $val   = (Get-ClusterResource -VMId $vmObj.VMId |
              Get-ClusterParameter DefaultMoveType).Value
    Write-Host "$vm : DefaultMoveType = $val"
}
```

With the affected VMs set to quick migration, proceed with the solution update to 12.2605 or later. The cluster uses quick migration to drain those VMs during each node's update, so the update completes instead of failing on the SID lookup.

### Disable the workaround after updating

Once the cluster is on 12.2605 or later, the permanent fix is enabled and the affected VMs live migrate correctly. Revert them to the default (live migration):

```powershell
foreach ($vm in $affectedVMs) {
    $vmObj = Get-VM -Name $vm -ComputerName (Get-ClusterGroup $vm).OwnerNode
    $res   = Get-ClusterResource -VMId $vmObj.VMId
    $res | Set-ClusterParameter -Name DefaultMoveType -Value 4294967295
    Write-Host "$vm : reset to default (live migration)"
}
```

Confirm the fix by live migrating a previously affected VM between nodes. It should now succeed in both directions.

## Additional Notes

- The `DefaultMoveType` setting is stored in the cluster database, so it persists across node reboots and through the phases of an orchestrated solution update. It is not reverted by the update, so remember to reset it after the cluster reaches 12.2605.
- No VM needs to be recreated. The update fixes migration for existing affected VMs in place.
- This issue is distinct from [Live migrations may fail when upgrading OS from 22H2 to 23H2](../Upgrade/Known%252Dissue-%252D-Live-migrations-may-fail-when-upgrading-OS-from-22H2-to-23H2.md), which is caused by VMs that use dynamic memory and is resolved by a different registry setting. If your migrations fail with the `0x80070534` "No mapping between account names and security IDs" error, use this article.
