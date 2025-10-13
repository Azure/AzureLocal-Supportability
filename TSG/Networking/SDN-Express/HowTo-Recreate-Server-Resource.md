# Recreate SDN Server Resource

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td>Networking</td>
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
- [Configure server settings](#configure-server-settings)
  - [Ensure NetworkVirtualization enabled](#ensure-networkvirtualization-enabled)
  - [Ensure Azure VFP Extension enabled](#ensure-azure-vfp-extension-enabled)
  - [Recreate the VMSwitch](#recreate-the-vmswitch-optional)
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
    $nodeFqdn = "{0}.{1}" -f $env:COMPUTERNAME, $env:USERDNSDOMAIN
    Get-SdnEnvironmentInfo -NetworkController 'NC_VM_NAME';
    Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl | Where-Object { $_.properties.connections.managementaddresses -match $nodeFqdn }
    ```
2. Once you have located the server resource, assign to variable.
    ```powershell
    $nodeToRepair = Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceID 'RESOURCE_ID'
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

## Configure server settings 
Depending on what operation triggered the re-creation of the VM Switch, we need to evaluate what the state of the server settings are. In order to check this, we want to see if `NetworkVirtualization` role is present, and if the `Azure VFP Extension` is enabled on the VMSwitch.
1. Create firewall rule to block all communications between NcHostAgent and Network Controller. 
    ```powershell
    New-NetFirewallRule -Name "NC_BLOCK_OUTBOUND" -DisplayName "NC_BLOCK_OUTBOUND" -Profile Any -RemotePort 6640 -Direction Outbound -Protocol TCP -Action Block
    ```

### Ensure NetworkVirtualization enabled
Ensure that `NetworkVirtualization` Windows Feature is installed. This is the required role that brings in NcHostAgent and Azure VFP Extension.
    ```powershell
    Get-WindowsFeature -Name 'NetworkVirtualization'
    ```
    - Install the feature if not installed.
      ```powershell
      Add-WindowsFeature -Name 'NetworkVirtualization' -IncludeAllSubFeature -IncludeManagementTools
      ```

### Ensure Azure VFP Extension enabled
Ensure that `Azure VFP Extension` is enabled on the VM Switch that is used for Compute.
   ```powershell
   # update the name of switch to match your environment
   $switch = Get-VMSwitch -Name 'ConvergedSwitch(mgmtcomp)';

   Get-VMSwitchExtension -VMSwitchName $switch.Name -Name "Microsoft Azure VFP Switch Extension" 
   ```
   - If the feature is disabled, enable the feature.
     ```powershell
     Disable-VmSwitchExtension -VMSwitchName $switch.Name -Name "Microsoft Windows Filtering Platform";
     Enable-VmSwitchExtension -VMSwitchName $switch.Name -Name "Microsoft Azure VFP Switch Extension" 
     ```

### Recreate the VMSwitch (optional)
This operation is required as Network Controller may have already learned the VMSwitchID and it's blocked from updating the configuration. 

1. Suspend the cluster node to put node into maintenence.
   > [!IMPORTANT]
   > If you have combined your Storage and Compute intents, ensure that your Virtual Disks have successfully been put into maintenance mode and no active storage jobs are running before proceeding.
1. Enable firewall rule on server and stop NcHostAgent service.
    ```powershell
    New-NetFirewallRule -Name "NC_BLOCK_OUTBOUND" -DisplayName "NC_BLOCK_OUTBOUND" -Profile Any -RemotePort 6640 -Direction Outbound -Protocol TCP -Action Block;
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
    $switch = Get-VMSwitch -Name 'ConvergedSwitch(mgmtcomp)';
    $switch.Id
    ```
1. Follow steps [Ensure Azure VFP Extension enabled](#ensure-azure-vfp-extension-enabled).

## Create server resource
Now that we have re-created the switch, we can create a new server resource.
1. Update the `$nodeToRepair` variable with new values and then create the resource against Network Controller.
    ```powershell
    $newResourceId = $switch.Id.Guid;
    $nodeToRepair.resourceId = $newResourceId;
    $nodeToRepair.resourceRef = '/servers/$newResourceId';
    $nodeToRepair.instanceId = (New-Guid).Guid # this will change once we put to NC which is expected;

    Set-SdnResource -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRepair.resourceRef -OperationType Add -Object $nodeToRepair
    ```
1. Update the HostID registry on the host now that the resource has been re-created.
    ```powershell
    $updatedServer = Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRepair.ResourceRef;
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\NcHostAgent\Parameters' -Name 'HostId' -Value $updatedServer.InstanceID -Force -ErrorAction Stop
    ```
1. Start the appropriate services and remove firewall rule
   ```powershell
   Set-Service -Name NCHostAgent -StartupType Automatic;
   Start-Service -Name 'NCHostAgent';
   Start-Service -Name 'SlbHostAgent';

   Remove-NetFirewallRule -Name "NC_BLOCK_OUTBOUND"
   ```

## Validate health
As part of the post validation steps, you will want to migrate a VM back onto the node and check several settings to ensure that Network Controller is able to program and configure policies on the host successfully. After deploying workloads to the server, perform the following validation steps.

1. Ensure that you have established connectivity from NcHostAgent to Network Controller ApiService. State should report as `Connected`.
   ```powershell
   Get-NetTCPConnection -RemotePort 6640
   ```
   - If showing as not connected, ensure:
     - Ensure you have remove the firewall rule blocking communications over 6640.
     - Ensure that NcHostAgent service is started. 
     - Certificates are present between Network Controller and Server.
1. Ensure that resource configurationState is success.
   ```powershell
   $updatedServer = Get-SdnServer -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -ResourceRef $nodeToRepair.ResourceRef;
   $updateServer.properties.configurationState | ConvertTo-Json -Depth 10
   ```
   - If showing any warnings, then:
     - Move the vSwitch primary replica to clear any stale configurations and wait a few minutes. Re-run the command to check health state.
       ```powershell
       Move-SdnServiceFabricReplica -NetworkController 'NC_VM_NAME' -ServiceTypeName VSwitchService
       ```
