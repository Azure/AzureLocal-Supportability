# AzStackHci_Network_Test_HostNetworkConfigurationReadiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_HostNetworkConfigurationReadiness</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment, Add-Server, Pre-Update</strong></td>
  </tr>
</table>

## Overview

This validator is run per-node and checks that the Host Network Configuration is in an expected state.

## Requirements

The validator enforces the following requirements on each node:
1. Each Adapter defined in the intent must have a DNS Client Configuration.
2. Hyper-V must be running on the host node.
3. The Management VM Network Adapter must be connected to the Management VMSwitch.
4. All adapters defined in all intents must be physical NICs and in the "Up" state.
5. Management, Compute, and Storage intents must be defined in the system with the same adapters (they may be converged or non-converged).

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Hosts are not configured properly. You can identify the host by the `TargetResourceID` field.

Here is an example:
```json
{
    "Name": "AzStackHci_Network_Test_HostNetworkConfigurationReadiness",
    "DisplayName": "Test if host network requirement meets for the deployment on all servers",
    "Tags": {},
    "Title": "Test host network configuration readiness",
    "Status": 1,
    "Severity": 2,
    "Description": "Checking host network configuration readiness status on <hostnode>",
    "Remediation": "Make sure host network configuration readiness is correct. Review detail message to find out the issue.",
    "TargetResourceID": "<hostnode>",
    "TargetResourceName": "HostNetworkReadiness",
    "TargetResourceType": "HostNetworkReadiness",
    "Timestamp": "\\/Date(timestamp)\\/",
    "AdditionalData": {
    "Detail": "On <hostnode>:\\nERROR: External VMSwitch ComputeSwitch(compute) is not having any VMNetworkAdapter attached to it.\\nERROR: Please remove the VMSwich, or add at least one VMNetworkAdapter to it.\\nPASS: DNS Client configuration has valid data for all adapters defined in intent\\nPASS: Hyper-V is running correctly on the system\\nPASS: External VMSwitch ConvergedSwitch(Management) have 2 VMNetworkAdapter(s) attached to it\\nPASS: At least 1 VMSwitch is having the network adapter defined in the management intent\\nPASS: All adapters defined in intent are physical NICs and Up in the system\\nPASS: Intent Management is already defined in the system with same adapter(s)\\nPASS: Intent Compute is already defined in the system with same adapter(s)\\nPASS: Intent Storage is already defined in the system with same adapter(s)",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>",
    "Resource": "HostNetworkReadiness configuration status",
    "Source": "<hostnode>"
    }
}
```

---

### Failure: External VMSwitch ComputeSwitch('intent name') is not having any VMNetworkAdapter attached to it. ERROR: Please remove the VMSwich, or add at least one VMNetworkAdapter to it.

On clusters with separate Compute, Management, and Storage intents, this validator will incorrectly report an error if the Compute VMSwitch does not have any VMNetworkAdapters attached to it. This happens if a node does not have any Virtual Machines running in it. Refer to the remediation steps below to work around this issue.

### Example Failures

```text
ERROR: External VMSwitch ComputeSwitch(compute) is not having any VMNetworkAdapter attached to it.
ERROR: Please remove the VMSwich, or add at least one VMNetworkAdapter to it.
```

### Remediation Steps

#### Create a temporary VM Network Adapter and attach it to the Compute VMSwitch

To work around this issue, you can create a temporary VM Network Adapter and attach it to the Compute VMSwitch. After proceeding with the update, you can remove this temporary adapter.

1. On each node that reports this error, run the following PowerShell command to create a temporary VM Network Adapter:
    ```powershell
    $switchName = "ConvergedSwitch(compute)" # <-- Replace with your Compute VMSwitch name (refer to error message)
    $adapterName = "TempVMNetAdapter"

    # Create a temporary VM Network Adapter on the host (Management OS)
    Add-VMNetworkAdapter -ManagementOS -Name $adapterName -SwitchName $switchName
    ```

2. Retry the validation, and if the error is resolved, proceed with the update operation.

3. After the update is complete, remove the temporary VM Network Adapter
    ```powershell
    $switchName = "ConvergedSwitch(compute)" # <-- Replace with your Compute VMSwitch name (refer to error message)
    $adapterName = "TempVMNetAdapter"

    # Remove the VM Network Adapter
    Remove-VMNetworkAdapter -ManagementOS -Name $adapterName
    Get-VMNetworkAdapter -ManagementOS -Name $adapterName -ErrorAction SilentlyContinue
    ```

### Failure: ERROR: DNS Client configuration is missing for the following adapter(s): 'adapter name(s)'

This error indicates that the DNS Client configuration is missing for one or more adapters defined in the intent. Usually this is caused by the Network Adapter being in the "Down" state.

### Example Failures

```text
ERROR: DNS Client configuration is missing for the following adapter(s): ethernet
```

### Remediation Steps

#### Make sure the Network Adapter is Up

1. On each node that reports this error, check the state of the Network Adapter:
    ```powershell
    Get-NetAdapter -Name "ethernet" # <-- Replace with the adapter name from the error message
    ```

2. If the adapter is in the "Down" state, ensure that it is physically connected and enabled. You can enable it using:
    ```powershell
    Enable-NetAdapter -Name "ethernet" # <-- Replace with the adapter name from the error message
    ```

### Failure: ERROR: Cannot find valid advanced property VlanId for adapter 'adapter name'

This error indicates that the VLAN ID Advanced Property could not be found for the specified adapter. This may happen if:
- The adapter is down
- The adapter driver is out of date

### Example Failures

```text
ERROR: Cannot find valid advanced property VlanId for adapter 'ethernet'
```

### Remediation Steps

#### Check that the Adapter exposes the VLAN ID Advanced Property
1. On each node that reports this error, check the advanced properties of the Network Adapter.
    ```powershell
    Get-NetAdapterAdvancedProperty -Name "ethernet" -RegistryKeyword "VlanId" # <-- Replace with the adapter name from the error message
    ```
2. If the VLAN ID property is not found, ensure that the adapter driver is up to date. Refer to the manufacturer's documentation for instructions on updating the driver.
    ```powershell
    Get-NetAdapter -Name "Ethernet" | Get-NetAdapterHardwareInfo | Format-List #< -- Replace with the adapter name from the error message
    ```
### Failure: ERROR: Cannot find valid RSS property for adapter 'adapter name'

This error indicates that the RSS (Receive Side Scaling) property could not be found for the specified adapter. This may happen if:
- The adapter is down
- The adapter driver is out of date
- The adapter does not support RSS

### Example Failures

```text
ERROR: Cannot find valid RSS property for adapter 'ethernet'
```
### Remediation Steps

#### Check that the Adapter supports RSS
1. On each node that reports this error, check that the adapter supports RSS.
      ```powershell
      Get-NetAdapterRss -Name "ethernet" # <-- Replace with the adapter name from the error message
      ```

2. If the adapter does not support RSS, you may need to replace it with a compatible adapter or update the driver to a version that supports RSS.

### Failure: ERROR:  The following adapter(s) are not physical adapter or not Up in the system: 'adapter name(s)'

This error indicates that one or more adapters defined in the intent are not physical adapters or are not in the "Up" state.

### Example Failures

```text
ERROR: The following adapter(s) are not physical adapter or not Up in the system: ethernet. Intent adapters should be physical adapters and Up in the system.
```

### Remediation Steps

#### Check the Adapter State
1. On each node that reports this error, check the state of the Network Adapter:
    ```powershell
    Get-NetAdapter -Name "ethernet" # <-- Replace with the adapter name from the error message
    ```
2. If the adapter is in the "Down" state, ensure that it is physically connected and enabled. You can enable it using:
    ```powershell
    Enable-NetAdapter -Name "ethernet" # <-- Replace with the adapter name from the error message
    ```
