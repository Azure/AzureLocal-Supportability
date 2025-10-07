# Recreate SDN Server Resource

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td>Networking, NetworkController, SDN</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td>Recreate a Network Controller Server Resource</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable Scenarios</th>
    <td>Fixes issue if VMSwitch has been re-created with new Switch ID.</td>
  </tr>
</table>

## Table of Contents
- [Overview](#overview)
- [What and Why](#what-and-why)
- [Prerequisites](#prerequisites)
- [Locate server resource](#locate-server-resource)
- [Delete server resource](#delete-server-resource)
- [Recreate the vSwitch](#recreate-the-vswitch)
- [Create server resource](#create-server-resource)
- [Validate health](#validate-health)

## Overview

This guide will assist with re-deployment of the SDN Server Resource.

## What and Why

### What This Guide Covers

This guide will walk you through re-creation of the Server resource object. This requires deleting existing configuration, re-creating the vSwitch again, and re-creating the server entry.

### When to Use This Guide

Use the steps documented in this guide if you have identified that your vSwitchID of your Hyper-V host has changed. 
SDN takes a dependency with the vSwitchID on the Host, and if this is re-created with new ID for any reason, can result in Network Controller unable to push policies to VMs deployed to the Hyper-V host.

## Prerequisites
The steps below are expected to be executed directly on the Hyper-V host that you are attempting to repair.

- Ensure you have installed the latest version of [SdnDiagnostics](https://learn.microsoft.com/en-us/azure/azure-local/manage/sdn-log-collection#install-the-sdn-diagnostics-powershell-module-on-the-client-computer) on the Hyper-V host we performing the operation from.
    ```powershell
    # check to see if module is installed and if none available, install from PSGallery
    # if module is installed, then update to ensure we have latest version
    if ($null -ieq (Get-Module -ListAvailable -Name SdnDiagnostics)) {
        Install-Module -Name SdnDiagnostics
    } else {
        Update-Module -Name SdnDiagnostics
    }
    
    # check if module is already imported into runspace
    # if it it, remove from runspace and re-import to ensure we have the latest version loaded
    if (Get-Module -Name SdnDiagnostics) {
        Remove-Module -Name SdnDiagnostics
    } else {
        Import-Module -Name SdnDiagnostics
    }
    ```

## Locate server resource
1. Isolate the Server resource within Network Controller.
    ```powershell
    $nodeFqdn = '<NODE_NAME>'
    Get-SdnEnvironmentInfo -NetworkController <NC_VM_NAME>
    Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl | Where-Object { $_.properties.connections.managementaddresses -match $nodeFqdn }
    ```
2. Once you have located the server resource, assign to variable.
    ```powershell
    $nodeToRemove = Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceID 'RESOURCE_ID'
    ```

## Delete server resource
1. Take a backup of current server resource. We want to save a backup just in case something goes wrong and need to restore existing configuration, or if need to reload the .json to re-populate variables referenced later.
    ```powershell
    $nodeToRepair | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path (Get-SdnWorkingDirectory) -ChildPath "$($nodeToRepair.InstanceID).json")
    ```
1. Delete the resource
    ```powershell
    Set-SdnResource -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRepair.ResourceRef -OperationType Delete
    ```

## Recreate the vSwitch
This operation is required as Network Controller may have already learned the vSwitchID and it's blocked from updating the configuration.

1. Suspend the cluster node to put node into maintenence.
> [!IMPORTANT]
> If you have combined your Storage and Compute intents, ensure that your Virtual Disks have successfully been put into maintenance mode and no active storage jobs are running before proceeding.
1. Enable firewall rule on server and stop NcHostAgent service.
    ```powershell
    New-NetFirewallRule -Name "NC_BLOCK_OUTBOUND" -DisplayName "NC_BLOCK_OUTBOUND" -Profile Any -RemotePort 6640 -Direction Outbound -Protocol TCP -Action Block
    Stop-Service -Name NcHostAgent -Force
    ```
1. Delete the existing VM Switch. We want NetworkATC to re-create the switch for us and apply the configuration intents.
    ```powershell
    # update the name of switch to match your environment
    Remove-VMSwitch -Name 'ConvergedSwitch(mgmtcomp)' -Force
    ```
1. Monitor NetworkATC to ensure that it's able to provision/configure a new vSwitch. Once NetworkATC is able to re-create the switch properly, retrieve the new switch ID.
    ```powershell
    # update the name of switch to match your environment
    $switch = Get-VMSwitch -Name 'ConvergedSwitch(mgmtcomp)'
    $switch.Id
    ```

## Create server resource
1. Now that we have re-created the switch, we can create a new server resource.
    ```powershell
    $switchID = '<ID_FROM_PREVIOUS_STEP>'
    $nodeToRepair.resourceId = $switchID
    $updatedEndpoint = Get-SdnApiEndPoint -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef "/servers/$($nodeToRepair.resourceID)"
    
    Set-SdnResource -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRepair.ResourceRef -OperationType Add
    ```
1. Update the HostID registry on the host now that the resource has been re-created.
    ```powershell
    $updatedSdnResource = -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRepair.ResourceRef
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\NcHostAgent\Parameters' -Name 'HostId' -Value $updatedSdnResource.InstanceID -Force -ErrorAction Stop
    ```
1. Start the appropriate services and remove firewall rule
   ```powershell
   Start-Service -Name 'NCHostAgent'
   Start-Service -Name 'SlbHostAgent'

   Remove-NetFirewallRule -Name "NC_BLOCK_OUTBOUND"
   ```

## Validate health
