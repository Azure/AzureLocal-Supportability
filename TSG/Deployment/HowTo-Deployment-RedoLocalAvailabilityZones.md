# How To: Redo Local Availability Zones (LAZ) on a SAN Cluster

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Storage / Cluster</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td><strong>Local Availability Zones</strong>: Clean up and reconfigure LAZ on a SAN (Fibre Channel) cluster</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable Scenarios</th>
    <td><strong>Post-Deployment</strong>: SAN clusters where LAZ was previously configured and needs to be changed</td>
  </tr>
</table>

## Overview

This guide explains how to remove an existing Local Availability Zones (LAZ) configuration from a SAN cluster and re-apply it with a different zone assignment. LAZ configures rack-level fault domains in both the Windows Failover Cluster and MOC (Metal Orchestrator and Compute) to enable VM placement resiliency across physical racks.

There is currently no `Remove-AsLocalAvailabilityZones` cmdlet, so cleanup must be performed manually before re-running the `Enable-AsLocalAvailabilityZones` command with the new desired configuration.

## What and Why

### What This Guide Covers

- Inspecting the current LAZ configuration (cluster fault domains and MOC zones)
- Removing cluster rack fault domains and unparenting nodes
- Removing MOC availability zones
- Re-running `Enable-AsLocalAvailabilityZones` with a new zone assignment

### When to Use This Guide

- A customer configured LAZ but wants to change the node-to-zone assignment (e.g., move a node from Zone1 to Zone2)
- LAZ was partially configured (one step succeeded but the other failed) and needs to be cleaned up before retrying
- A node was replaced and the zone assignment needs to be updated

## Prerequisites

- SAN (Fibre Channel) Azure Local cluster with LAZ previously configured
- Administrative access to a cluster node (Remote PowerShell or console)
- The cluster must be healthy — all nodes online and communicating

## Table of Contents

- [Overview](#overview)
- [What and Why](#what-and-why)
- [Prerequisites](#prerequisites)
- [Step 1: Inspect Current LAZ Configuration](#step-1-inspect-current-laz-configuration)
- [Step 2: Remove Cluster Fault Domains](#step-2-remove-cluster-fault-domains)
- [Step 3: Remove MOC Zones](#step-3-remove-moc-zones)
- [Step 4: Re-run Enable-AsLocalAvailabilityZones](#step-4-re-run-enable-aslocalavailabilityzones)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Step 1: Inspect Current LAZ Configuration

Review the current fault domain and MOC zone state before making changes.

1. **Check cluster fault domains** to see which nodes are assigned to which zones:

   ```powershell
   # List all fault domains and their parent-child relationships
   Get-ClusterFaultDomain | Format-Table Name, Type, ParentName -AutoSize
   ```

   Expected output for a configured LAZ cluster:

   ```
   Name      Type ParentName
   ----      ---- ----------
   NODE1     Node Zone1
   NODE2     Node Zone1
   NODE3     Node Zone2
   NODE4     Node Zone2
   Zone1     Rack
   Zone2     Rack
   ```

   Nodes with a `ParentName` of a zone (e.g., `Zone1`) are assigned to that zone. Rack-type fault domains are the LAZ zones themselves.

2. **Check MOC zones** to see the MOC-side configuration:

   ```powershell
   Import-Module moc -ErrorAction Stop
   $mocConfig = Get-MocConfig
   $zones = Get-MocZone -location $mocConfig.cloudLocation
   foreach ($z in $zones) {
       Write-Host "Zone: $($z.name), Nodes: $($z.properties.nodes -join ', ')"
   }
   ```

> [!NOTE]
> Both the cluster fault domains and MOC zones must be cleaned up. Cleaning only one side will cause a mismatch that blocks future LAZ operations.

## Step 2: Remove Cluster Fault Domains

Remove nodes from their current zone assignment and delete the zone fault domains.

1. **Unparent all nodes from their zones** — this detaches nodes from the rack fault domains without removing the nodes from the cluster:

   ```powershell
   $ErrorActionPreference = "Stop"

   # Get all nodes currently parented to a Rack fault domain
   $zonedNodes = Get-ClusterFaultDomain | Where-Object { $_.Type -eq 'Node' -and $_.ParentName }
   foreach ($node in $zonedNodes) {
       Write-Host "Removing node '$($node.Name)' from zone '$($node.ParentName)'"
       Set-ClusterFaultDomain -Name $node.Name -Parent ""
   }
   ```

2. **Remove the rack (zone) fault domains** now that no nodes reference them:

   ```powershell
   $rackFDs = Get-ClusterFaultDomain | Where-Object { $_.Type -eq 'Rack' }
   foreach ($rack in $rackFDs) {
       Write-Host "Removing rack fault domain '$($rack.Name)'"
       Remove-ClusterFaultDomain -Name $rack.Name -ErrorAction Stop
   }
   ```

3. **Verify cleanup** — no Rack-type fault domains should remain, and nodes should have no parent:

   ```powershell
   Get-ClusterFaultDomain | Format-Table Name, Type, ParentName -AutoSize
   ```

   Expected output — nodes only, no parent, no Rack entries:

   ```
   Name      Type ParentName
   ----      ---- ----------
   NODE1     Node
   NODE2     Node
   NODE3     Node
   NODE4     Node
   ```

## Step 3: Remove MOC Zones

Remove the MOC availability zones. This must be done from a cluster node where the `moc` module is available.

1. **Remove nodes from each MOC zone** by updating the zone with an empty node list, then removing the zone:

   ```powershell
   $ErrorActionPreference = "Stop"
   Import-Module moc -ErrorAction Stop

   $mocConfig = Get-MocConfig
   $location = $mocConfig.cloudLocation
   $zones = Get-MocZone -location $location

   foreach ($z in $zones) {
       Write-Host "Clearing nodes from MOC zone '$($z.name)'"
       Update-MocZone -location $location -name $z.name -nodes @()

       Write-Host "Removing MOC zone '$($z.name)'"
       Remove-MocZone -location $location -name $z.name
   }
   ```

   > [!NOTE]
   > If `Remove-MocZone` is not available in your build, clearing the nodes with `Update-MocZone -nodes @()` is sufficient. The `Enable-AsLocalAvailabilityZones` command will update existing empty zones with the new node assignments.

2. **Verify cleanup**:

   ```powershell
   $remaining = Get-MocZone -location $mocConfig.cloudLocation
   if ($remaining) {
       Write-Host "WARNING: MOC zones still exist: $($remaining.name -join ', ')"
   } else {
       Write-Host "All MOC zones removed successfully."
   }
   ```

## Step 4: Re-run Enable-AsLocalAvailabilityZones

With both cluster fault domains and MOC zones cleaned up, run the LAZ command with the new desired configuration.

1. **Prepare the new zone assignment** — define which nodes go in which zone:

   ```powershell
   $nodeAssignment = @{
       "Zone1" = @("<node1>", "<node3>")
       "Zone2" = @("<node2>", "<node4>")
   }
   ```

   Replace `<node1>`, `<node2>`, etc. with the actual cluster node names.

2. **Run the LAZ command**:

   ```powershell
   Enable-AsLocalAvailabilityZones -Count 2 -Prefix "Zone" -NodeAssignment $nodeAssignment -Force
   ```

   Adjust `-Count` to match the number of zones you need (max 8). Each zone must contain at least one node, and every cluster node must be assigned to a zone.

3. **Monitor progress** — the command invokes an ECE action plan (`LocalAvailabilityZoneOperation`). It will:
   - **Step 1**: Create cluster rack fault domains and assign nodes
   - **Step 2**: Create MOC availability zones and assign nodes

## Verification

After the command completes, verify both layers are configured correctly.

1. **Verify cluster fault domains**:

   ```powershell
   Get-ClusterFaultDomain | Format-Table Name, Type, ParentName -AutoSize
   ```

   Each node should show its new zone as `ParentName`, and the zone Rack entries should exist.

2. **Verify MOC zones**:

   ```powershell
   Import-Module moc -ErrorAction Stop
   $mocConfig = Get-MocConfig
   $zones = Get-MocZone -location $mocConfig.cloudLocation
   foreach ($z in $zones) {
       Write-Host "Zone: $($z.name), Nodes: $($z.properties.nodes -join ', ')"
   }
   ```

   Each zone should contain the expected nodes matching the cluster fault domain assignment.

## Troubleshooting

### "Pre-existing rack fault domains detected"

**Symptoms:** `Enable-AsLocalAvailabilityZones` fails with:
```
Pre-existing rack fault domains detected: Zone1, Zone2. Manual rack fault domain configuration must be removed before enabling local availability zones.
```

**Solution:** The cluster fault domains were not fully cleaned up. Go back to [Step 2](#step-2-remove-cluster-fault-domains) and ensure all Rack-type fault domains are removed. Verify with `Get-ClusterFaultDomain | Where-Object { $_.Type -eq 'Rack' }` — this should return nothing.

### "Node is currently in rack fault domain X but was requested in Y"

**Symptoms:** `Enable-AsLocalAvailabilityZones` fails with:
```
Node 'NODE1' is currently in rack fault domain 'Zone1' but was requested in 'Zone2'. Re-assignment across racks is not supported.
```

**Solution:** Nodes are still parented to old zones. Run the unparent step from [Step 2](#step-2-remove-cluster-fault-domains):
```powershell
Set-ClusterFaultDomain -Name "<node-name>" -Parent ""
```

### "Node is already present in zone: In Use"

**Symptoms:** The MOC step fails with a message indicating a node is already in a different MOC zone.

**Solution:** The MOC zones were not cleaned up. Go back to [Step 3](#step-3-remove-moc-zones) and clear all MOC zones before retrying.

### CSV ownership issues after cleanup

**Symptoms:** After removing fault domains, a Cluster Shared Volume shows as owned by a node that appears offline or unresponsive.

**Solution:** This is unrelated to fault domain cleanup (fault domains are metadata only). Move the CSV to a healthy node:
```powershell
Get-ClusterSharedVolume | Where-Object { $_.State -ne 'Online' } |
    Move-ClusterSharedVolume -Node "<healthy-node-name>"
```

---
