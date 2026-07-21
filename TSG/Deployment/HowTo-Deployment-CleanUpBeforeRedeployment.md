# How To: Clean Up an Existing Azure Local Deployment Before Redeployment

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Deployment / Lifecycle</strong> (Azure resources, Arc resource bridge, custom location)</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td><strong>Cleanup before redeploy</strong>: delete the Azure resources from a prior deployment in dependency order to avoid orphaned cloud resources</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable Scenarios</th>
    <td><strong>Azure Local, version 23H2 and later</strong>: redeploying after a failed or irrecoverable deployment, rebuilding a system, or decommissioning then redeploying</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Who runs this</th>
    <td><strong>Owner</strong> or <strong>Contributor</strong> on every subscription and resource group that holds deployment resources</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Reversibility</th>
    <td><strong>Irreversible</strong>: deleted resources cannot be recovered (a soft-deleted key vault is recoverable only until it is purged or its retention period ends)</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Impact / downtime</th>
    <td><strong>Total</strong>: every workload on the system is destroyed; the system is offline until it is reimaged and redeployed</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Estimated time</th>
    <td>Azure resource deletion is typically tens of minutes; the full reimage and redeploy adds several hours (varies by hardware and node count)</td>
  </tr>
</table>

## Overview

Every Azure Local deployment creates a set of Azure resources (the Arc resource bridge, a custom location, the Azure Local instance, per-node Arc machine resources, storage paths, a key vault, and storage accounts). Before you can cleanly redeploy, these resources must be removed.

The order matters. Workload resources (VMs, disks, NICs, storage paths, logical networks) are projected into Azure **through** the custom location and Arc resource bridge, and Azure does **not** reliably block deletion of a parent while its dependents still exist. Deleting a parent first — or bulk-deleting the resource group, which is not dependency-aware — leaves **orphaned resources** that become difficult or impossible to delete and that block a clean redeployment. This guide gives the dependency-safe order.

This guide extends the official [Decommission Azure Local](https://learn.microsoft.com/azure/azure-local/manage/decommission-azure-local) procedure — which lists the resources to remove — with the dependency-safe **deletion order**, the cross-resource-group dependency check, and the CLI, verification, and troubleshooting steps that procedure does not cover.

> [!IMPORTANT]
> Delete from the inside out: **workload resources first, then the Arc resource bridge, then the custom location, then the infrastructure resources.** Never delete the Arc resource bridge or custom location while any workload still depends on them.

## What and Why

### What This Guide Covers

- The Azure resources a deployment creates, and the dependency-safe order to delete them
- A checkpoint to confirm nothing still depends on the platform before you remove it
- When to delete the whole resource group vs. delete resources individually
- Reimaging the machines before re-running deployment

### When to Use This Guide

- A deployment failed and the recommended recovery is a full redeploy (reimage + redeploy)
- You are rebuilding a system after an irrecoverable cluster or configuration state
- You are decommissioning a system, optionally to redeploy onto the same hardware

> [!WARNING]
> These deletions are **destructive and irreversible**. The Arc resource bridge is the Azure control plane for the system's VMs; deleting it removes the ability to manage those VMs from Azure. Proceed only when a full redeployment (or decommission) is the agreed plan.

## Glossary

- **Arc resource bridge (ARB)** — the on-premises appliance VM that Azure uses as the control plane to manage the system's VMs. It runs on the cluster as a `*-control-plane-*` VM and is what `az arcappliance delete hci` removes.
- **Custom location** — the Azure resource that points at the Arc resource bridge and gives Azure a target to create resources (VMs, disks, logical networks) on your system. It is deleted only **after** the Arc resource bridge.
- **extendedLocation** — the property on each projected Azure resource that references the custom location it was created through. The Step 3 Resource Graph checkpoint queries this property to find resources that still depend on the platform.
- **Soft-delete vs. purge (Key Vault)** — deleting a key vault **soft-deletes** it: the vault and its secrets stay recoverable for a retention period and the name stays reserved. **Purging** permanently removes the soft-deleted vault and frees the name, unless purge protection is enforced.

## Prerequisites

- **Owner** or **Contributor** on every subscription / resource group that holds deployment resources
- The list of **all** resource groups involved — workload resources (VMs, disks, NICs) may live in different resource groups than the platform resources
- Azure portal access; optionally Azure CLI with the `stack-hci-vm`, `customlocation`, and `arcappliance` extensions if you prefer CLI
- Console or out-of-band access to the physical machines for the reimage step

## Table of Contents

- [Overview](#overview)
- [What and Why](#what-and-why)
- [Glossary](#glossary)
- [Prerequisites](#prerequisites)
- [Step 1: Inventory the Deployment Resources](#step-1-inventory-the-deployment-resources)
- [Step 2: Remove Resource Locks](#step-2-remove-resource-locks)
- [Step 3: Delete Workload Resources First](#step-3-delete-workload-resources-first)
- [Step 4: Delete the Arc Resource Bridge, Then the Custom Location](#step-4-delete-the-arc-resource-bridge-then-the-custom-location)
- [Step 5: Delete the Infrastructure and Registration Resources](#step-5-delete-the-infrastructure-and-registration-resources)
- [Step 6: Reimage and Redeploy](#step-6-reimage-and-redeploy)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Step 1: Inventory the Deployment Resources

Identify every Azure resource the deployment created so nothing is missed. A standard deployment creates the following (the inventory follows [Decommission Azure Local](https://learn.microsoft.com/azure/azure-local/manage/decommission-azure-local)):

| Count | Resource type |
|-------|---------------|
| 1 per machine | Machine - Azure Arc |
| 1 | Azure Local (the instance / cluster resource) |
| 1 | Arc resource bridge |
| 1 | Key vault (only if dedicated to this deployment) |
| 1 | Custom location |
| Up to 2 | Storage account (key vault audit logs; plus cloud witness if a cloud witness is used) |
| 1 per workload volume | Azure Local storage path - Azure Arc |

Plus any workload resources created after deployment: Azure Local VMs, AKS Arc clusters, VM images, logical networks, network interfaces, virtual hard disks (data disks), and network security groups.

> [!NOTE]
> Counts reflect a typical deployment — confirm against your portal. A cloud witness storage account is required for a 2-node system and optional otherwise (a file-share witness means no cloud witness account). In a **failed** deployment, some resources may never have been created; skip any that don't exist — the order still holds for those that do.

Open the resource group(s) in the [Azure portal](https://portal.azure.com/) and review the resource list and the **Settings > Deployments** blade to confirm the full set before deleting anything.

## Step 2: Remove Resource Locks

By default, deployment applies **DoNotDelete** locks to the resources it creates; governance policies may also apply **ReadOnly** locks. Either kind blocks deletion, and locks can be **inherited** from a parent subscription scope, not just the resource or its resource group.

1. In the Azure portal, open the resource group, expand **Settings**, and select **Locks**.
2. Delete the **DoNotDelete** and **ReadOnly** locks on the resources you are about to remove. If a delete later fails with a lock error, check parent scopes for an inherited lock.

## Step 3: Delete Workload Resources First

> [!WARNING]
> **Back up workload data before you start.** The deletions in this step are irreversible and destroy all workload data on the system — VM guest data, AKS Arc workloads, and their data disks. Export or back up anything you need to keep, and capture any VM, disk, and network configuration you intend to recreate, before deleting anything.

Delete every resource that depends on the custom location / Arc resource bridge **before** touching those platform resources. Work top-down: delete the top-level workloads (VMs, then AKS clusters) first, then the resources they used (network interfaces, data disks), then the containers those lived in (storage paths, logical networks). Deleting a container before the resources inside it orphans them:

1. **Azure Local VMs**, then **AKS Arc clusters** — the top-level workloads. Deleting an Azure Local VM does **not** remove its network interfaces or data disks; those are separate resources you must delete yourself (steps below). In the portal, use **Show hidden types** on the resource group to reveal resources a VM delete left behind.
2. **VM images**.
3. **Network interfaces**, then **virtual hard disks** (data disks) that were attached to the VMs.
4. **Network security groups**.
5. **Storage paths** (delete after the virtual hard disks they contain) and **logical networks** (delete after the network interfaces they host).

CLI equivalents use the `az stack-hci-vm` command group. Delete one resource type at a time, in the same inside-out order, using the names from your Step 1 inventory (or the matching `... list` command). Run each command once per resource of that type:

```azurecli
# --yes skips the per-resource confirmation prompt; omit it to confirm each delete.

# 1. Azure Local VMs (deleting a VM does NOT delete its NICs or data disks)
az stack-hci-vm delete --resource-group <rg> --name <vm-name> --yes

# 2. VM images
az stack-hci-vm image delete --resource-group <rg> --name <image-name> --yes

# 3. Network interfaces the VMs left behind
az stack-hci-vm network nic delete --resource-group <rg> --name <nic-name> --yes

# 4. Data disks (virtual hard disks) the VMs left behind
az stack-hci-vm disk delete --resource-group <rg> --name <disk-name> --yes

# 5. Network security groups
az stack-hci-vm network nsg delete --resource-group <rg> --name <nsg-name> --yes

# 6. Storage paths (after the data disks they contain)
az stack-hci-vm storagepath delete --resource-group <rg> --name <storagepath-name> --yes

# 7. Logical networks (after the NICs they host)
az stack-hci-vm network lnet delete --resource-group <rg> --name <lnet-name> --yes
```

> [!NOTE]
> Delete **AKS Arc clusters** through their own management path (not `az stack-hci-vm`) before the resources above. Also note that `az stack-hci-vm nic` only attaches/detaches a vNIC on a VM — the NIC **resource** is deleted with `az stack-hci-vm network nic delete` (used above).

> [!IMPORTANT]
> Confirm each VM is actually gone — both the Azure resource **and** the underlying VM on the cluster (`Get-VM` on a node) — before continuing. "Gone in Azure" does not mean "gone on the cluster," and deleting the Arc resource bridge while an orphaned VM remains makes the on-premises VM very hard to remove.

> [!IMPORTANT]
> **Checkpoint — prove nothing still depends on the platform.** Before Step 4, confirm no resource still projects through the custom location, in **any** resource group or subscription. In **Azure Resource Graph Explorer** (or `az graph query`), run the following with the full custom location resource ID; it must return **zero rows**:
> ```kusto
> resources
> | where extendedLocation.name =~ '<custom-location-resource-id>'
> | project name, type, resourceGroup, subscriptionId
> ```

> [!NOTE]
> For "zero rows" to be trustworthy, set the Resource Graph scope to **Directory** (all subscriptions you can access) — workload resources can live in a different subscription than the platform. Azure Resource Graph is eventually consistent and can lag ARM by a few minutes, so re-run after a short wait and cross-check the resource group blade in the portal. Confirm any AKS Arc clusters are gone independently; their child resources may not surface as top-level rows.

## Step 4: Delete the Arc Resource Bridge, Then the Custom Location

Only after Step 3 and the checkpoint above are complete, delete the platform resources in this order:

1. **Arc resource bridge**
2. **Custom location**

Microsoft documents this order for Azure Local: *"The custom location should only be deleted after the Arc resource bridge has been deleted"* ([What is Azure Local VM management?](https://learn.microsoft.com/azure/azure-local/manage/azure-arc-vm-management-overview), Components). Remove the Arc resource bridge with `az arcappliance delete hci` — the supported method, which deletes the on-premises appliance VM **and** the Arc resource bridge Azure resource together (deleting only the Azure resource from the portal leaves the on-premises appliance VM on the cluster). With its host gone, the custom location is then removed as a separate, trivial resource delete.

```azurecli
az arcappliance delete hci --config-file "<path>\<resourceName>-appliance.yaml"
az customlocation delete --name <custom-location-name> --resource-group <resource-group>
```

> [!NOTE]
> Deleting the Arc resource bridge from the **portal** leaves the on-premises appliance VM (named `*-control-plane-*`) on the cluster; `az arcappliance delete hci` (above) removes it. If the appliance VM remains, the [Step 6](#step-6-reimage-and-redeploy) reimage removes it and all MOC/ARB metadata from the nodes, so no separate cleanup is needed for a redeploy. To remove it **without** reimaging (for example, an in-place decommission), contact Microsoft Support.

## Step 5: Delete the Infrastructure and Registration Resources

With workloads and the platform projection removed, delete the remaining resources:

1. **Azure Local** instance resource — deleting this resource removes the cluster's Azure registration; in 23H2 this portal/CLI resource delete is the supported cleanup path.
2. **Machine - Azure Arc** resources (one per node). See [Manage the Azure Connected Machine agent](https://learn.microsoft.com/azure/azure-arc/servers/manage-agent) to disconnect a machine and delete its Arc resource.
3. **Key vault** and its secrets — **only if** the key vault is dedicated to this deployment. Do **not** delete a key vault shared with other Azure Local systems.
4. **Storage accounts** — the key vault audit-log account and the cloud witness account (if used).

What you keep depends on whether you are redeploying onto the same hardware or fully decommissioning:

| Resource | Redeploy (same hardware) | Full decommission |
|----------|--------------------------|-------------------|
| Machine - Azure Arc (per node) | Optional (reimage re-registers; stale entries refresh by name) | Delete |
| Resource group | Keep / reuse | Delete |
| Dedicated key vault | Delete (purge if reusing the name — see below) | Delete |
| Arc resource bridge service principal (Entra ID) | Keep | Delete if not shared |

> [!IMPORTANT]
> Azure Key Vault soft-delete is always on. After you delete a **dedicated** vault, it and its secrets remain recoverable for the retention period (default 90 days) and the **name stays reserved**. If the redeploy will reuse the same vault name, **purge** the soft-deleted vault first (`az keyvault purge --name <vault> --location <region>`), provided purge protection is not enforced.

> [!NOTE]
> The Arc resource bridge service principal / app registration lives in Microsoft Entra ID, not in the resource group, and is not removed by a resource-group delete. Leaving a stale one is generally harmless for a redeploy; remove it only if you are certain it is not shared.

### Deleting the whole resource group

If the system was deployed into a **dedicated** resource group, you may delete the entire resource group instead of Steps 4–5 — **but only if all of the following are true:** Step 3 and its checkpoint are complete with zero remaining dependents and no VM left on the cluster; the resource group holds nothing shared with other systems; and all dependent resources live in **this** resource group. A resource-group delete is not dependency-aware and works here only because you already removed the workload-to-platform dependency manually.

> [!WARNING]
> A resource-group delete does **not** run `az arcappliance delete hci`, so the on-premises Arc resource bridge appliance VM and MOC metadata are left on the nodes. This is acceptable only because Step 6 reimages the machines; do not use resource-group delete as an Azure-side decommission without reimaging.

## Step 6: Reimage and Redeploy

A redeployment starts from a clean operating system on each machine.

1. Reimage each machine with a fresh installation of the Azure Local OS — see [Install the Azure Local operating system](https://learn.microsoft.com/azure/azure-local/deploy/deployment-install-os). (The deployment node-cleanup process is not a substitute for a clean image when recovering from an irrecoverable state.)
2. Re-run deployment following the current [Azure Local deployment documentation](https://learn.microsoft.com/azure/azure-local/deploy/deployment-introduction).

## Verification

1. The Azure Resource Graph checkpoint query in Step 3 returns **zero rows**.
2. The resource group contains **no** Azure Local VMs, storage paths, custom location, Arc resource bridge, or Azure Local instance resource (or the dedicated resource group no longer exists).
3. No Arc VM that belonged to the system still appears in Azure, and none is still running on the cluster (`Get-VM` on each node).
4. If reusing a dedicated key vault name, the soft-deleted vault has been purged.
5. The machines boot from a clean OS image and are ready for deployment.

## Troubleshooting

### A VM was deleted in Azure but still runs on-premises (orphaned VM)

**Symptoms:** The Arc VM no longer appears in Azure but is still running on the cluster.
**Solution:** Recreate the Arc VM from the Azure portal using the **same** resource group, VM name, VM image, and admin credentials as the original (uncheck guest management; do not attach NICs or disks), then delete it again from the portal — this pushes the delete through to the cluster. Do this **before** deleting the VM image, custom location, and Arc resource bridge — all of which must still exist to recreate the VM. This is the known workaround for a specific class of deletion issue (see [Arc VMs deletion](../ArcVMs/arc-vm-deletion.md)); orphaning can have other causes, so if it does not resolve the VM, contact Microsoft Support.

### A delete fails because a resource is locked

**Symptoms:** Delete returns an error about a **DoNotDelete** or **ReadOnly** lock.
**Solution:** Return to [Step 2](#step-2-remove-resource-locks) and remove the lock on that resource and its resource group, and check the subscription scope for an inherited lock, then retry.

### The custom location or Arc resource bridge was deleted before the workload resources

**Symptoms:** VMs, disks, NICs, or storage paths can no longer be deleted; deletes hang or fail because the projection path is gone.
**Solution:** The dependent resources are now orphaned. Recovery generally requires redeploying the Arc resource bridge and custom location to restore the management path, then deleting the resources in the correct order. If you cannot recover the path, contact Microsoft Support.

### An on-premises Arc resource bridge appliance VM remains after deletion

**Symptoms:** The Arc resource bridge resource is gone from Azure, but a `*-control-plane-*` appliance VM remains on the cluster (typically because the bridge was deleted from the portal rather than with `az arcappliance delete hci`).
**Solution:** For a redeploy, the [Step 6](#step-6-reimage-and-redeploy) reimage removes the residual appliance and all MOC/ARB metadata from the nodes — no separate cleanup is required. If you must remove it **without** reimaging, contact Microsoft Support.

---
