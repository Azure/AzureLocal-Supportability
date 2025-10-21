# Troubleshoot-Test-SLB_ValidateBGPPeersReachable

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateBGPPeersReachable</strong></td>
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

The `Test-SLB_ValidateBGPPeersReachable` function checks whether all Border Gateway Protocol (BGP) peers defined in your Software Load Balancer (SLB) configuration are reachable from each SLB node in your Azure Local environment. It attempts a TCP connection to port 179 (BGP) for each peer router IP address from every node session provided. If a peer is unreachable, the function returns a critical failure result with details and remediation guidance. This validator helps ensure BGP connectivity for high availability and network reliability, allowing you to proactively detect and resolve reachability issues before they impact SLB operations.

**Input:**  
The function expects a `SoftwareLoadBalancer` configuration object (as shown below) and a set of PowerShell sessions to the SLB nodes. The configuration must include `BackendNetworkMode`, `NumberOfMuxes`, and a `BGPInfo` section with `LocalASN` and an array of `PeerRouterConfigurations` (each specifying `PeerASN` and `RouterIPAddress`).

**Example Input:**
```json
{
    "SoftwareLoadBalancer": {
        "BackendNetworkMode": "VirtualNetwork",
        "NumberOfMuxes": 2,
        "BGPInfo": {
            "LocalASN": 60001,
            "PeerRouterConfigurations": [
                {
                    "PeerASN": 61001,
                    "RouterIPAddress": "100.10.20.110"
                },
                {
                    "PeerASN": 61002,
                    "RouterIPAddress": "100.10.20.111"
                }
            ]
        }
    }
}
```

---

## Example Configuration

Below is an example of a valid `SoftwareLoadBalancer` configuration object:

```json
{
    "SoftwareLoadBalancer": {
        "BackendNetworkMode": "VirtualNetwork",
        "NumberOfMuxes": 2,
        "BGPInfo": {
            "LocalASN": 60001,
            "PeerRouterConfigurations": [
                {
                    "PeerASN": 61001,
                    "RouterIPAddress": "100.10.20.110"
                },
                {
                    "PeerASN": 61002,
                    "RouterIPAddress": "100.10.20.111"
                }
            ]
        }
    }
}
```

This configuration meets all validation requirements for SLB and BGP properties.

---

## Requirements

- Azure Local environment is deployed and accessible.
- **Failover Cluster Network Controller (FCNC)** component must be installed.
- The `AzStackHci` PowerShell module is installed and imported.
- The `Test-SLB_ValidateSoftwareLoadBalancer` function is available in your environment.
- All target hosts are online and reachable from the management system.
- Administrative privileges on both the management system and all target hosts.
- (remove)Sufficient permissions to query and modify Software Load Balancer (SLB) nodes and Multiplexer (MUX) instances.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object:
- Look for failures related to `Test-SLB_ValidateSoftwareLoadBalancer`.
- Example output:

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
    "TargetResourceID":  "Property name: RouterIPAddress, value: ",
    "TargetResourceName":  "PeerRouterConfigurations",
    "TargetResourceType":  "BGPInfo",
    "Timestamp":  "\/Date(1761004300036)\/",
    "AdditionalData":  {
                        "Detail":  "\"BGP Peer \u0027\u0027 is not reachable. Please check the network connectivity.\"",
                        "Status":  "FAILURE",
                        "TimeStamp":  "10/20/2025 23:51:40",
                        "Resource":  "BGPInfo",
                        "Source":  "192.168.200.93"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\073ad76b"
}
```

## Failure Return Results

Below are all possible failure return results from `$SLBResultObject`, including example messages and recommended remediation steps.


### Failure and Warning Results

---

### Failure: BGP Peer Unreachable

**Description:**  
The validator was unable to establish a TCP connection to port 179 (BGP) on one or more configured BGP peer router IP addresses from one or more SLB nodes. This indicates that the BGP peer is not reachable from the SLB node, which may disrupt BGP route advertisement and high availability.

**Example Failure:**  
```
Status    : Failure
Detail    : BGP Peer 100.10.20.110 is not reachable. Please check the network connectivity.
Source    : slbnode01
Resource  : BGPInfo
TimeStamp : 2024-06-01T12:34:56Z
```

**Remediation Steps:**

- Verify network connectivity between the node and the BGP peer router.
- Confirm that the BGP peer router is powered on and listening on port 179.
    ```powershell
    Test-NetConnection -ComputerName <Peer IP Address> -port 179 -InformationLevel Detailed
    ```
- Check routing configurations and ensure the correct IP address is specified in the configuration.
- Review SLB and router logs for additional connectivity errors.

---

### Warning: No BGP Peers Configured

**Description:**  
The validator did not find any BGP peer router configurations in the provided `SoftwareLoadBalancer` configuration. Without BGP peers, dynamic routing will not function as expected.

**Example Failure:**  
```
Status    : Warning
Detail    : No BGP peers are configured in the SoftwareLoadBalancer BGPInfo section.
Source    : slbnode01
Resource  : BGPInfo
TimeStamp : 2024-06-01T12:34:56Z
```

**Remediation Steps:**
- Add at least one valid BGP peer configuration under `PeerRouterConfigurations` in the `SoftwareLoadBalancer` configuration.
- Ensure each peer entry includes a valid `PeerASN` and `RouterIPAddress`.
- Rerun the validator after updating the configuration.

---