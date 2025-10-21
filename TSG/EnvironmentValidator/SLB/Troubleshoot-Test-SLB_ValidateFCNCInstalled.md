# AzStackHci_NetworkSLB_Test_SLBValidator_ValidateFCNCInstalled

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>Test-SLB_ValidateFCNCInstalled</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Deployment</strong></td>
    </tr>
</table>

## Overview

This validator checks whether the Failover Cluster Network Controller (FCNC) is installed in the Azure Local cluster. It ensures that all Network Controller (NC) microservices are running as cluster resources. FCNC is required for proper operation of the Software Load Balancer (SLB) features. If FCNC is missing, SLB functionality will not work as expected.

## Requirements

- Azure Local environment is deployed and accessible.
- **Failover Clustering Network Controller (FCNC)** must be installed on all cluster nodes.
- **Administrative privileges** are required on each node.
- **PowerShell remoting** must be enabled and functional between all nodes.
- All target hosts are online and reachable from the management system.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the environment validator as described in the deployment documentation.
- Look for failures related to `Test-SLB_ValidateFCNCInstalled`.
- Example output:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateFCNCInstalled",
    "DisplayName":  "FCNC is installed on all cluster nodes",
    "Tags":  {

            },
    "Title":  "FCNC (Failover Cluster Network Controller) component is installed on all cluster nodes",
    "Status":  0,
    "Severity":  2,
    "Description":  "Verifies that the FCNC is properly installed and configured on each node in the cluster",
    "Remediation":  "FCNC (Failover Cluster Network Controller) must be installed prior to deploying SLB",
    "TargetResourceID":  "Node: 192.168.200.92, service: NC API service",
    "TargetResourceName":  "FCNC API Service",
    "TargetResourceType":  "FCNC installation",
    "Timestamp":  "\/Date(1761012662827)\/",
    "AdditionalData":  {
                            "Detail":  "\"Failover Cluster Network Controller (FCNC) is installed and operational on host \u0027192.168.200.92\u0027.\"",
                            "Status":  "SUCCESS",
                            "TimeStamp":  "10/21/2025 02:11:02",
                            "Resource":  "FCNC installation",
                            "Source":  "192.168.200.92"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\22e52eb5"
}
```

## Failure Return Results

Below are possible failure return results from `$FCNCInstalledResults`, with example messages and recommended remediation steps.

### Failure: FCNC Not Installed

**Description:**  
The Failover Clustering Network Controller (FCNC) is considered not installed when the FCNC API service is not running on one or more nodes.

**Example Failure:**  
- `FCNC is not installed on node 'Node01'.`

**Remediation Steps:**
1. On the affected node, check if the FCNC API service is present and running:
    ```powershell
    $apiService = Get-ClusterResource ApiService -ErrorAction SilentlyContinue
    $null -ne $apiService
    ```
2. If the FCNC API service is present but offline, attempt to online it:
    ```powershell
   Start-ClusterResource -Name ApiService -Wait 30
   ```
3. List all other FCNC-related microservices and verify their status:
    (This will exclude ohter HIC and MOC services)
    ```powershell
    Get-ClusterResource | Where-Object { $_.ResourceType -eq 'Generic Service' -and $_.Name -notlike "*HCI*" -and $_.Name -notlike "*MOC*"}
    ```
    If no FCNC-related microservices are listed, FCNC is not installed on this cluster.
4. Re-run the validator to confirm resolution.

---

### Failure: Unable to Verify FCNC Installation Status

**Description:**  
The validator could not determine the FCNC installation status, possibly due to connectivity or permission issues.

**Example Failure:**  
- `Unable to verify FCNC installation status on node 'Node02'.`

**Remediation Steps:**
1. Ensure PowerShell remoting is enabled and accessible between nodes.
2. Verify administrative privileges on the affected node.
3. Check network connectivity and firewall settings.
4. Retry the validator after resolving connectivity or permission issues.

---

### Failure: FCNC Feature Installation Failed

**Description:**  
An attempt to install the FCNC feature failed.

**Example Failure:**  
- `Failed to install FCNC on node 'Node03'.`

**Remediation Steps:**
1. Review the event logs for installation errors:
    ```powershell
    Get-EventLog -LogName System -Source 'Microsoft-Windows-FailoverClustering' -Newest 20
    ```
2. Address any reported issues (e.g., missing prerequisites, pending reboots).
3. Retry the installation and validation steps.

---

### Failure: FCNC Not Present After Installation

**Description:**  
The FCNC component is still missing after installation steps.

**Example Failure:**  
- `FCNC component not present on node 'Node04' after installation.`

**Remediation Steps:**
1. Confirm the installation completed successfully and no errors were reported.
2. Ensure the node was rebooted if prompted.
3. If the issue persists, consult Microsoft documentation or support for further troubleshooting.

