# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_ExceptionFound

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_ExceptionFound</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment (without ArcGateway), Upgrade (without ArcGateway)</strong></td>
  </tr>
</table>

## Overview

This is a **catch-all exception handler** for the infrastructure IP pool connection validation. When the `Test-NwkInfraConnectionValidator_InfraIpPoolConnection` function encounters an unhandled exception during any phase of infrastructure IP connectivity validation, this result is returned.

Unlike other validators in the `NetworkInfraConnection` family that report specific issues (e.g., DNS failure, vNIC readiness), this validator fires when an **unexpected error** occurs — typically due to environmental issues such as VMSwitch configuration failures, Hyper-V component errors, or other system-level problems that prevent the validator from completing normally.

The exception message and stack trace are captured in the `AdditionalData.Detail` field.

## Requirements

1. Hyper-V role must be installed and functioning
2. VMSwitch must be configurable on the host
3. Network adapters specified in the management intent must be present and operational
4. Infrastructure IP pool must be valid and reachable
5. System must have sufficient resources to create test virtual network adapters

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. The `AdditionalData.Detail` field contains the exception message and stack trace, which is essential for identifying the root cause.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_ExceptionFound",
  "DisplayName": "Exception found during infra IP pool connection validation.",
  "Title": "Exception found during infra IP pool connection validation.",
  "Status": 1,
  "Severity": 2,
  "Description": "Experienced exception during infra IP pool readiness validation. Please check information in AdditionalData.Detail section",
  "Remediation": "URI",
  "TargetResourceID": "Infra_IP_Connection_Exception",
  "TargetResourceName": "Infra_IP_Connection_Exception",
  "TargetResourceType": "InfraIpPool",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "Infra_IP_Connection_Exception",
    "Resource": "Infra_IP_Connection_Exception",
    "Detail": "<Exception Message>\n\r<Stack Trace>",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

> **Important:** Copy the full `AdditionalData.Detail` content. The exception message and stack trace are the primary clues for diagnosing the root cause.

---

### Failure: General Exception During Validation

If the exception message does not match the VMSwitch scenario above, the exception may have been thrown by any of the sub-steps in the infra IP validation process:

1. **VMSwitch creation/discovery** — Could not find or create a suitable external VMSwitch
2. **vNIC creation** — Could not create the test virtual network adapter on the VMSwitch
3. **IP assignment** — Could not assign infrastructure IP to the test vNIC
4. **Gateway ping** — Error while testing ICMP connectivity to the default gateway
5. **DNS testing** — Error while testing DNS server connectivity on port 53
6. **Endpoint connectivity** — Error while running curl.exe tests to Azure endpoints

#### Remediation Steps

##### 1. Read the Exception Details Carefully

The `AdditionalData.Detail` field contains both the exception message (first line) and the stack trace (subsequent lines). The stack trace shows which function threw the error.

**Common patterns in the stack trace:**

| Stack Trace Contains | Likely Cause |
|----------------------|--------------|
| `EnvValidatorNwkLibConfigureVMSwitchForTesting` | VMSwitch setup failed |
| `New-VMSwitch` | VMSwitch creation failed |
| `Add-VMNetworkAdapter` or `Get-VMNetworkAdapter` | vNIC management failed |
| `New-NetIPAddress` | IP assignment failed |
| `InfraIpCurlTestToEndpoint` | curl endpoint test failed |
| `Get-AzStackHciConnectivityTarget` | Failed to fetch endpoint manifest |

##### 2. Check System Prerequisites

```powershell
# Verify Hyper-V feature and management tools
Get-WindowsFeature -Name "Hyper-V", "Hyper-V-PowerShell" | Select-Object Name, Installed

# Check VMSwitch creation capability
Get-Command Get-VMSwitch -ErrorAction SilentlyContinue | Select-Object Name, Source
```

##### 3. Review System Event Logs

```powershell
# Check for recent errors in System log related to networking/Hyper-V
$startTime = (Get-Date).AddHours(-2)
Get-WinEvent -LogName System -MaxEvents 100 |
    Where-Object { $_.TimeCreated -gt $startTime } |
    Where-Object { $_.Message -like "*network*" -or $_.Message -like "*Hyper-V*" -or $_.Message -like "*switch*" } |
    Select-Object TimeCreated, LevelDisplayName, Message |
    Format-Table -Wrap
```

##### 4. Re-install Hyper-V
If the exception is complaining something like below:
```
Failed while adding virtual Ethernet switch connections. Switch port create failed, switch = "ABCDEF00-1234-5678-ABCD-ABCDABCDABCD", port name = "ABCDEF00-1234-5678-ABCD-ABCDABCDABCD", port friendly name = "ConvergedSwitch(MYINTENT)": Class not registered (0x80040154)
```
It means the Hyper-V is not installed correctly on the machine, you will need to re-install Hyper-V feature on the machine:

```powershell
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
# reboot machine
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
# reboot machine again
```
##### 5. Retry the Validation
After addressing the underlying issue, re-run the Environment Validator.

---

## Additional Information

### How This Validator is Triggered

This result is produced by the top-level `catch` block in the `Test-NwkInfraConnectionValidator_InfraIpPoolConnection` function. The function performs these steps inside a `try` block:

1. Retrieves infrastructure IP range from IP pools
2. Validates Hyper-V and VMSwitch prerequisites
3. Finds or creates an external VMSwitch using management intent adapters
4. Creates a test vNIC on the VMSwitch
5. For each infrastructure IP (up to 9):
   - Assigns the IP to the test vNIC
   - Tests gateway connectivity (ICMP ping)
   - Tests DNS connectivity (port 53)
   - Tests Azure endpoint connectivity (curl.exe)
6. Cleans up test resources

If **any** unhandled exception occurs during steps 1–6, the catch block returns this `ExceptionFound` result with the exception details.

### When This Validator is Skipped

The infrastructure IP connectivity validator (including all endpoint tests) is **skipped** when **ArcGateway enabled**. ArcGateway provides alternative connectivity.

### Related Validators

This exception can mask failures that would normally be reported by these specific validators:

- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_MANAGEMENT_VNIC_Readiness`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNSClientServerAddress_Readiness`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_{ServiceName}`

### Related Documentation

- [Azure Local network requirements](https://learn.microsoft.com/azure/azure-local/concepts/host-network-requirements)
