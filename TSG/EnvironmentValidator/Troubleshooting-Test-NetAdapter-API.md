# Overview

Environment Validator runs NetAdapter checks during Deployment, Update and ScaleOut actions in AzureLocal. The tool detects issues with NetAdapter requirements for Azure Local.

# Symptoms

During validation, the Environment Validator for Hardware has a failed critical result and deployment is unable to continue:

```
2024-01-10 11:43:11 Warning  [EnvironmentValidator:ValidateHardware] Critical (blocking) Hardware failures found in validation. 8 Rules failed: 
2024-01-10 11:43:11 Verbose  [EnvironmentValidator:ValidateHardware] Validator failed. Hardware requirements not met. Review output and remediate: 
Rule: 

HealthCheckSource  : Deployment\Hardware\292f98e5
Name               : AzStackHci_Hardware_Test_NetAdapter
DisplayName        : Test NetAdapter API Node01
Tags               : {}
Title              : Test NetAdapter API
Status             : FAILURE
Severity           : CRITICAL
Description        : Checking NetAdapter has CIM data
Remediation        : https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-tool-prerequisites
TargetResourceID   : Machine: Node01, Class: NetAdapter
TargetResourceName : Machine: Node01, Class: NetAdapter
TargetResourceType : NetAdapter
Timestamp          : 1/10/2024 7:43:03 PM



 AdditionalData: 

Key   : Detail
Value : Unable to retrieve data for NetAdapter on Node01

Key   : Status
Value : FAILURE

Key   : TimeStamp
Value : 01/10/2024 19:43:03

Key   : Resource
Value : Null

Key   : Source
Value : Node01
```

This result means the validation did not find any NetAdapters suitable to use for Azure Local. 

# Issue Validation

If impacted, when the following PowerShell is run on a node, it returns no result.

```
Get-NetAdapter -Physical | Where-Object { $_.NdisMedium -eq 0 -and $_.Status -eq 'Up' -and $_.NdisPhysicalMedium -eq 14 -and $_.PnPDeviceID -notlike 'USB\*'}
```

# Cause

The cause can be one or more of the following:
- NetAdapters must have a Status of Up.
- NetAdapters must be Physical Ethernet adapters
- NetAdapters must not be a USB device.
- NetAdapters must not be virtual.
- NetAdapters must be consistent across all Azure Local nodes.

# Mitigation Details

To verify which of the requirements are not met, run the following on all nodes.

```
Get-NetAdapter -Physical | Format-Table NdisMedium, Status, NdisPhysicalMedium, PnPDeviceID
```

Common issues:  
- NdisPhysicalMedium is 0 (Unspecified). Ensure the network adapter being used is qualified. https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements#select-a-network-adapter and the drivers OEM drivers are installed. Inbox drivers are not allowed. 
- Interfaces is down during validation. Ensure the interface is Up.