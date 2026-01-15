# Troubleshoot_Test-SLB_ValidateDNSName

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>Test-SLB_ValidateDNSName</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>SLB Deployment</strong></td>
    </tr>
</table>

## Overview

This validator verifies that DNS name resolution is correctly configured for Software Load Balancer (SLB) VMs in the Azure Local cluster. It ensures that each SLB VM's DNS name (both short name and FQDN) resolves to the expected reserved IP address. Proper DNS resolution is required for SLB functionality to work correctly. If DNS resolution fails or returns incorrect IP addresses, SLB deployment and operations will be impacted.

## Requirements

- Azure Local environment is deployed and accessible.
- **DNS Server** must be configured and reachable from all cluster nodes.
- **DNS records** for SLB VMs must be registered with the correct IP addresses.
- **Management network intent** must be configured on the cluster.
- **Administrative privileges** are required on each node.
- **PowerShell remoting** must be enabled and functional between all nodes.

## Troubleshooting Steps

### Review Environment Validator Output

- Execute the validator and inspect the returned result object.
- Carefully review the output for any failures related to `Test-SLB_ValidateDNSName`. Pay particular attention to the `AdditionalData` section—especially the `Detail` field—which provides specific details about the DNS resolution status for each SLB VM.
- For reference, see the example output below:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateDNSName",
    "DisplayName":  "Resolve DNS Name for SLB VMs",
    "Tags":  {},
    "Title":  "Resolve DNS Name for SLB VMs",
    "Status":  "SUCCESS",
    "Severity":  "CRITICAL",
    "Description":  "Test if the DNS names for SLB VMs can be resolved",
    "Remediation":  "https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/EnvironmentValidator/SLB/Troubleshoot-Test-SLB_ValidateDNSName.md",
    "TargetResourceID":  "DNS resolution for SLB VMs",
    "TargetResourceName":  "SoftwareLoadBalancer",
    "TargetResourceType":  "DNS resolution for SLB VMs",
    "Timestamp":  "1/14/2025 5:55:09 AM",
    "AdditionalData":   {
                            "Detail":  "DNS resolution validation passed. All SLB VM names resolved successfully to their configured IP addresses.",
                            "Status":  "SUCCESS",
                            "TimeStamp":  "01/14/2025 05:55:09",
                            "Resource":  "SoftwareLoadBalancer",
                            "Source":  "DNS resolution for SLB VMs",
                        },
    "HealthCheckSource": "DnsSLB\Standard\Medium\NetworkSLB\ae3e210e"
}
```

### Failure Results

Below are common failure scenarios returned by `Test-SLB_ValidateDNSName`. For each scenario, example messages from the `AdditionalData` field are shown, along with step-by-step remediation guidance to address the issue.

---

### Failure: No Management Intent Found

**Description:**
The validator could not find any network intents configured with the management intent set. This is required to identify the correct network interface for DNS resolution verification.

**Example Failure:**

```text
Detail    : No management intent found.
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : SoftwareLoadBalancer
Source    : DNS resolution for SLB VMs
```

**Remediation Steps:**

1. Verify that network intents are properly configured on the cluster:

    ```powershell
    Get-NetIntent | Where-Object { $_.IsManagementIntentSet }
    ```

2. If no management intent is returned, review your network configuration and ensure that network intents were properly deployed during cluster setup.

3. Consult the Azure Local deployment documentation to verify the expected network intent configuration for your environment.

---

### Failure: DNS Name Resolution Failed (NULL Response)

**Description:**
The DNS server could not resolve the SLB VM name to any IP address. This typically indicates that the DNS record for the SLB VM does not exist or the DNS server is unreachable.

**Example Failure:**

```text
Detail    : DNS resolution failed for '<SLB-VM-Name>'. Expected IP: '<Expected-IP>', Resolved IP: '<NULL>'
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : SoftwareLoadBalancer
Source    : DNS resolution for SLB VMs
```

**Remediation Steps:**

1. Verify DNS server connectivity from the cluster node:

    ```powershell
    Get-DnsClientServerAddress -InterfaceAlias "vManagement*"
    ```

2. Test DNS resolution manually for the SLB VM name:

    ```powershell
    Resolve-DnsName "<SLB-VM-Name>" -ErrorAction SilentlyContinue
    Resolve-DnsName "<SLB-VM-Name>.<Domain-FQDN>" -ErrorAction SilentlyContinue
    ```

3. If the DNS record does not exist, create the A record on your DNS server for both the short name and FQDN:
   - **Name:** `<SDNPrefix>-slb01` (and `<SDNPrefix>-slb02` for multi-node deployments)
   - **IP Address:** The reserved IP address from the management network pool

4. Verify the DNS record was created successfully by re-running the resolution test.

---

### Failure: DNS Name Resolved to Incorrect IP Address

**Description:**
The DNS record exists but resolves to a different IP address than the reserved IP address configured for the SLB VM. This mismatch will cause connectivity issues with the SLB infrastructure.

**Example Failure:**

```text
Detail    : DNS resolution failed for '<SLB-VM-Name>'. Expected IP: '<Expected-IP>', Resolved IP: '<Actual-IP>'
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : SoftwareLoadBalancer
Source    : DNS resolution for SLB VMs
```

**Remediation Steps:**

1. Identify the expected reserved IP address for the SLB VM:

    ```powershell
    $packagePath = Get-ASArtifactPath -NugetName "Microsoft.AS.Network.Deploy.HostNetwork" -Verbose:$false
    Import-Module "$packagePath\content\Powershell\Modules\HostNetworkHelpers\HostNetworkHelpers.psd1" -Force
    
    # For SLB VM 1
    Get-HostNetworkReservedIpAddress -NetworkId Management -ReservationId "SlbVmNic1IpAddress01"
    
    # For SLB VM 2 (multi-node deployments)
    Get-HostNetworkReservedIpAddress -NetworkId Management -ReservationId "SlbVmNic1IpAddress02"
    ```

2. Update the DNS A record on your DNS server to point to the correct reserved IP address.

3. If using dynamic DNS registration, verify that no other system has registered the same name with a different IP.

4. Clear the DNS client cache and re-test resolution:

    ```powershell
    Clear-DnsClientCache
    Resolve-DnsName "<SLB-VM-Name>"
    ```

---

### Failure: Exception During DNS Resolution

**Description:**
An unexpected error occurred during the DNS resolution validation process. This could be due to module loading failures, network connectivity issues, or configuration problems.

**Example Failure:**

```text
Detail    : Exception testing DNS resolution: <Exception-Details>
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : SoftwareLoadBalancer
Source    : DNS resolution for SLB VMs
```

**Remediation Steps:**

1. Review the full exception message in the validator output for specific details about the failure.

2. Check network connectivity to the DNS server:

    ```powershell
    Test-NetConnection -ComputerName <DNS-Server-IP> -Port 53
    ```

3. Review the Windows Event Log for any related errors:

    ```powershell
    Get-WinEvent -LogName "Microsoft-Windows-DNS-Client/Operational" -MaxEvents 20
    ```

4. If the issue persists, collect the full error details and contact Microsoft Support.

---
