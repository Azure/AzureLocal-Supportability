# Recreate SDN Server Resource

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Networking</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td><strong>{Topic Name}</strong>: {Brief description of the how to}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable Scenarios</th>
    <td><strong>{Applicable Scenarios}</strong>: Re-deploy SDN Server resource in event that vSwitchID has changed. </td>
  </tr>
</table>

## Table of Contents
- [Overview](#overview)
- [What and Why](#what-and-why)
- [Prerequisites](#prerequisites)
- [{Section 1 Title}](#section-1-title)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Overview

This guide will assist with re-deployment of the SDN Server Resource.

## What and Why

### What This Guide Covers

This guide will walk you through re-creation of the Server resource object. This requires deleting existing configuration, re-creating the vSwitch again, and re-creating the server entry.

### When to Use This Guide

Use the steps documented in this guide if you have identified that your vSwitchID of your Hyper-V host has changed. 
SDN takes a dependency with the vSwitchID on the Host, and if this is re-created with new ID for any reason, can result in Network Controller unable to push policies to VMs deployed to the Hyper-V host.

## Prerequisites

{List any requirements, permissions, or setup needed before starting}

- {Prerequisite 1}
- {Prerequisite 2}

## Locate the server resource to delete
1. Enumerate current servers
Isolate the Server resource within Network Controller.
```powershell
$nodeFqdn = '<NODE_NAME>'
Get-SdnEnvironmentInfo
Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl | Where-Object { $_.properties.connections.managementaddresses -match $nodeFqdn }
```
2. Once you have located the server resource, assign to variable.
```powershell
$nodeToRemove = Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceID 'RESOURCE_ID'
```

## Delete the existing server resource
1. Take a backup of current server resource. We want to save a backup just in case something goes wrong and need to restore existing configuration, or if need to reload the .json to re-populate variables referenced later.
```powershell
$nodeToRemove | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path (Get-SdnWorkingDirectory) -ChildPath "$($nodeToRemove.InstanceID).json")
```
2. Delete the resource
```powershell
Set-SdnResource -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRemove.ResourceRef -OperationType Delete
```

## Recreate the vSwitch
This operation is required as Network Controller may have already learned the vSwitchID and it's blocked from updating the configuration.

1. Suspend the cluster node to put node into maintenence.
> [!IMPORTANT]
> If you have combined your Storage and Compute intents, ensure that your Virtual Disks have successfully been put into maintenance mode and no active storage jobs are running before proceeding.
2. Enable firewall rule on server and stop NcHostAgent service.
```powershell
New-NetFirewallRule -Name "NC_BLOCK_OUTBOUND" -DisplayName "NC_BLOCK_OUTBOUND" -Profile Any -RemotePort 6640 -Direction Outbound -Protocol TCP -Action Block
Stop-Service -Name NcHostAgent -Force
```
3. Delete the existing VM Switch. We want NetworkATC to re-create the switch for us and apply the configuration intents.
```powershell
# update to reflect your switch name
Remove-VMSwitch -Name 'ConvergedSwitch(mgmtcomp)' -Force
```
