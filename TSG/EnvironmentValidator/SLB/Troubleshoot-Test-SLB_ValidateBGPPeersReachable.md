# Troubleshoot-Test-SLB_ValidateBGPPeersReachable

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLB_ValidateBGPPeersReachable</strong></td>
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

The `Test-SLB_ValidateBGPPeersReachable` function checks whether all Border Gateway Protocol (BGP) peers defined in your Software Load Balancer (SLB) configuration are reachable from each node in your Azure Local environment. It attempts a TCP connection to port 179 (BGP) for each peer router IP address from every node session provided. If a peer is unreachable, the function returns a critical failure result with details and remediation guidance. This validator helps ensure BGP connectivity for high availability and network reliability, allowing you to proactively detect and resolve reachability issues before they impact SLB operations.

**Input:**  
The function expects a `SoftwareLoadBalancer` configuration object (as shown below) and a set of PowerShell sessions to the nodes. The configuration must include `NumberOfMuxes` and a `BGPInfo` section with `LocalASN` and an array of `PeerRouterConfigurations` (each specifying `PeerASN` and `RouterIPAddress`).

## Example Configuration

This following describes the BGP (Border Gateway Protocol) configuration for a Software Load Balancer (SLB) in Azure Local environments. Here’s a breakdown of each part:

```text
- SoftwareLoadBalancer: The main object representing the SLB.
    - NumberOfMuxes: Placeholder for the number of MUX (multiplexer) instances in your SLB deployment.
    - BGPInfo: Contains BGP-specific settings.
        - LocalASN: Placeholder for the Autonomous System Number (ASN) assigned to the SLB itself.
        - PeerRouterConfigurations: An array listing each BGP peer router.
            - PeerASN: The ASN of the peer router.
            - RouterIPAddress: The IP address of the peer router.

```

Below is an example of a valid `SoftwareLoadBalancer` configuration object. To specify BGP peers, update the `PeerRouterConfigurations` array under the `BGPInfo` section with the appropriate `PeerASN` and `RouterIPAddress` values.

```json
{
    "SoftwareLoadBalancer": {
        "NumberOfMuxes": <Specify the total number of MUX instances>,
        "BGPInfo": {
            "LocalASN": <Enter the local ASN for the SLB>,
            "PeerRouterConfigurations": [
                {
                    "PeerASN": <Enter ASN for Peer 1>,
                    "RouterIPAddress": "<Enter IP address for Peer 1 router>"
                },
                {
                    "PeerASN": <Enter ASN for Peer 2>,
                    "RouterIPAddress": "<Enter IP address for Peer 2 router>"
                }
            ]
        }
    }
}
```

## Requirements

- Azure Local environment is deployed and accessible.
- **Failover Cluster Network Controller (FCNC)** component must be installed.
- The `AzStackHci` PowerShell module is installed and imported.
- The `Test-SLB_ValidateBGPPeersReachable` function is available in your environment.
- All target hosts are online and reachable from the management system.
- Administrative privileges on both the management system and all target hosts.
- Sufficient permissions to query and modify nodes.

## Troubleshooting Steps

### Review Environment Validator Output

- Execute the `Test-SLB_ValidateBGPPeersReachable` validator and examine the returned result object.
- Carefully review the output for any entries indicating failures associated with BGP peer reachability. Focus on the `AdditionalData` section, especially the `Detail` field, which highlights specific BGP peers that could not be reached and describes the nature of the connectivity issue.
- Refer to the example output below to understand how unreachable peers are reported and use this information to guide your troubleshooting efforts.

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateBGPPeersReachable",
    "DisplayName":  "Border Gateway Protocol (BGP) Peers Reachable",
    "Tags":  {},
    "Title":  "Border Gateway Protocol (BGP) Peers Reachable",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if BGP Peers are reachable",
    "Remediation":  "Ensure BGP Peer  is reachable.",
    "TargetResourceID":  "Property name: RouterIPAddress, value: x.x.x.x",
    "TargetResourceName":  "PeerRouterConfigurations",
    "TargetResourceType":  "BGPInfo",
    "Timestamp":  "\/Date(1761004300036)\/",
    "AdditionalData":  {
                        "Detail":  "\"BGP Peer [x.x.x.x] is not reachable. Please check the network connectivity.\"",
                        "Status":  "FAILURE",
                        "TimeStamp":  "10/20/2025 23:51:40",
                        "Resource":  "BGPInfo",
                        "Source":  "<Node IP Address>"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\073ad76b"
}
```

### Failure Results

Below are all possible failure and warning results produced by `Test-SLB_ValidateBGPPeersReachable`. For each result, example detail messages from the `AdditionalData` field are provided, along with recommended remediation steps to resolve the issue.

---

#### Failure: BGP Peer Unreachable

**Description:**  
The validator could not establish a TCP connection to port 179 (BGP) on one or more configured BGP peer router IP addresses from one or more nodes. This means the node cannot reach the BGP peer, which may impact BGP route advertisement and high availability. Review the `Source` field in the output to identify the node where the connectivity check failed—this helps pinpoint where to begin troubleshooting.

**Example Failure:**

```text
Detail    : BGP Peer <BGP Peer IP address> is not reachable. Please check the network connectivity.
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : BGPInfo
Source    : <Node IP Address>
```

**Remediation Steps:**

- Verify network connectivity between the node and the BGP peer router.
- Confirm that the BGP peer router is powered on and listening on port 179.

    ```powershell
    Test-NetConnection -ComputerName <Peer IP Address> -port 179 -InformationLevel Detailed
    ```

- Verify routing configurations and confirm that the correct IP addresses are specified for each BGP peer.
- Examine router logs for detailed connectivity error messages.
- Refer to switch configuration best practices and review the [BGP configuration guidance for Azure Local SDN SLB](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/Networking/SDN-Express/HowTo-SDNExpress-SDN-Layer3-Gateway-Configuration.md) for additional troubleshooting steps.

#### BGP Configuration Guidance for SLB Integration

To ensure successful BGP integration with Software Load Balancer (SLB) in your Azure Local environment, follow these configuration best practices:

- **Define Peer Routers:**  
    In your SLB configuration, specify each BGP peer under the `PeerRouterConfigurations` array, including accurate `PeerASN` and `RouterIPAddress` values.

- **Validate Local ASN:**  
    Confirm that the `LocalASN` value in the `BGPInfo` section matches your network design and does not conflict with peer ASNs.

- **Network Connectivity:**  
    Ensure all nodes can reach each BGP peer router on port 179. Use `Test-NetConnection` to verify connectivity from each node.

- **Firewall and Routing:**  
    Allow TCP traffic on port 179 between nodes and peer routers. Review firewall rules and routing tables to prevent connectivity issues.

- **Consistent Configuration:**  
    Apply identical BGP settings across all nodes to avoid mismatches and ensure high availability.

- **Documentation:**  
    Maintain up-to-date records of all BGP peers, ASNs, and router IP addresses for troubleshooting and future changes.

By following these steps, you can minimize BGP connectivity issues and support reliable SLB operations in your Azure Local deployment.

---
