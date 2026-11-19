# Troubleshoot_Test-SLB_ValidateFCNCInstalled

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
        <td><strong>SLB Deployment</strong></td>
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

- Execute the validator and inspect the returned result object.
- Carefully review the output for any failures related to `Test-SLB_ValidateFCNCInstalled`. Pay particular attention to the `AdditionalData` section—especially the `Detail` field—which provides specific details about the FCNC installation status on each cluster node.
- For reference, see the example output below:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateFCNCInstalled",
    "DisplayName":  "FCNC is installed on all cluster nodes",
    "Tags":  {},
    "Title":  "FCNC (Failover Cluster Network Controller) component is installed on all cluster nodes",
    "Status":  1,
    "Severity":  2,
    "Description":  "Verifies that the FCNC is properly installed and configured on each node in the cluster",
    "Remediation": "<Remediation URL>",
    "TargetResourceID":  "Node: <Node IP Address>, service: NC API service",
    "TargetResourceName":  "FCNC API Service",
    "TargetResourceType":  "FCNC installation",
    "Timestamp":  "\/Date(1761012662827)\/",
    "AdditionalData":  {
                            "Detail":  "Failover Cluster Network Controller (FCNC) is not installed or not operational on host [<Node IP Address>]. Please verify the installation and configuration.",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 02:11:02",
                            "Resource":  "FCNC installation",
                            "Source":  "<Node IP Address>"
                        },
    "HealthCheckSource":  "DeploySLB\\Standard\\Medium\\NetworkSLB\\22e52eb5"
}
```

### Failure Results

Below are common failure scenarios returned by `Test-SLB_ValidateFCNCInstalled`. For each scenario, example messages from the `AdditionalData` field are shown, along with step-by-step remediation guidance to address the issue.

#### Failure: FCNC Not Installed

**Description:**  
The Failover Clustering Network Controller (FCNC) is considered not installed when the FCNC API service is not running on one or more nodes.

**Example Failure:**

```text
Detail    : Failover Cluster Network Controller (FCNC) is not installed or not operational on host [<Node IP Address>]. Please verify the installation and configuration.
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : FCNC installation
Source    : <Node IP Address>
```

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

3. List all FCNC-related microservices and check their status:  
    (This command lists all cluster services related to FCNC, excluding HCI and MOC services.)

    ```powershell
    Get-ClusterResource | Where-Object {
         $_.ResourceType -eq 'Generic Service' -and
         $_.Name -notlike "*HCI*" -and
         $_.Name -notlike "*MOC*"
    }
    ```

    Review the output to confirm that all expected FCNC microservices are present and in the `Online` state. If any required FCNC service is missing or offline, further investigation is needed. The output should resemble the following example:

    ```text
    Name              State  OwnerGroup        ResourceType   
    ----              -----  ----------        ------------   
    ApiService        Online ApiService        Generic Service
    ControllerService Online ControllerService Generic Service
    FirewallService   Online FirewallService   Generic Service
    FnmService        Online FnmService        Generic Service
    GatewayManager    Online GatewayManager    Generic Service
    ServiceInsertion  Online ServiceInsertion  Generic Service
    SlbManagerService Online SlbManagerService Generic Service
    VSwitchService    Online VSwitchService    Generic Service
    ```

    If no FCNC-related microservices are listed, FCNC is not installed on this cluster.

4. If the `ApiService` is offline, restart it safely:

    ```powershell
    # Check if ApiService is offline
    $apiService = Get-ClusterResource -Name ApiService -ErrorAction SilentlyContinue
    if ($apiService.State -eq 'Offline') {
        # Attempt to bring the service online
        Start-ClusterResource -Name ApiService
    }
    ```

    After restarting, verify the service is online before proceeding.

5. Rerun the validator to confirm resolution.
6. If the issue persists, consult Microsoft documentation or support for further troubleshooting.

---
