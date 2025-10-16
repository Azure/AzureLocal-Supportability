# Troubleshoot-Test-SLB_ValidateSoftwareLoadBalancer

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateSoftwareLoadBalancer</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Deployment, Add Node, Pre-Update</strong></td>
    </tr>
</table>

## Overview
The `Test-SLB_ValidateSoftwareLoadBalancer` function validates the Software Load Balancer (SLB) configuration in your Azure Stack HCI environment. It checks that required properties such as `BackendNetworkMode`, `NumberOfMuxes`, and `BGPInfo` (including `LocalASN` and `PeerRouterConfigurations`) are present and set to supported values. The validator ensures the configuration meets criteria for load balancing, high availability, and network reliability. If any property is missing, invalid, or duplicated, the function returns a failure result with details for remediation. Use this validator to proactively detect and resolve SLB configuration issues before they impact your environment.

---

## Example Configuration

Below is an example of a valid `SoftwareLoadBalancer` configuration object:

```json
{
    "BackendNetworkMode": "VirtualNetwork",
    "NumberOfMuxes": 2,
    "BGPInfo": {
        "LocalASN": 64631,
        "PeerRouterConfigurations": [
            {
                "PeerASN": 64738,
                "RouterIPAddress": "100.70.20.149"
            },
            {
                "PeerASN": 64738,
                "RouterIPAddress": "100.70.20.150"
            }
        ]
    }
}
```

This configuration meets all validation requirements for SLB and BGP properties.

---
## Requirements

- An Azure Stack HCI environment is deployed and accessible.
- The `AzStackHci` PowerShell module is installed and imported.
- You have sufficient permissions to query and modify Software Load Balancer (SLB) nodes and Multiplexer (MUX) instances.
- The `Test-SLB_ValidateSoftwareLoadBalancer` function is available in your environment.
- All target hosts are online and reachable from the management system.
- You have administrative privileges on both the management system and all target hosts.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object:
- Look for failures related to `Test-SLB_ValidateSoftwareLoadBalancer`.
- Example output:
    ```powershell
    $SLBNodesValidRstObject = Test-SLB_ValidateSoftwareLoadBalancer
    $SLBNodesValidRstObject
    ```

## Failure Return Results

Below are all possible failure return results from `$SLBResultObject`, including example messages and recommended remediation steps.


### Failure and Warning Results

---

#### BackendNetworkMode is missing or invalid

**Description:**  
The `BackendNetworkMode` property is either missing, empty, or set to an unsupported value.  
**Example Failure:**  
`BackendNetworkMode property validation failed. Expected value: VirtualNetwork, Actual value: <NULL>`  
**Remediation Steps:**  
Ensure the `BackendNetworkMode` property is present and set to `VirtualNetwork`.

---

#### NumberOfMuxes is missing or out of supported range

**Description:**  
The `NumberOfMuxes` property is missing, empty, less than 1, or greater than 3.  
**Example Failure:**  
`NumberOfMuxes property validation failed. Actual value: 0`  
**Remediation Steps:**  
Set `NumberOfMuxes` to a value between 1 and 3.

---

#### BGPInfo is missing

**Description:**  
The `BGPInfo` property is missing or empty.  
**Example Failure:**  
`BGPInfo property validation failed. Actual value: <NULL>`  
**Remediation Steps:**  
Ensure the `BGPInfo` property is present and properly configured.

---

#### LocalASN is missing or out of valid range

**Description:**  
The `LocalASN` property in `BGPInfo` is missing, empty, or not within the valid ASN range (0–4294967295).  
**Example Failure:**  
`LocalASN property validation failed. Actual value: -1`  
**Remediation Steps:**  
Set `LocalASN` to a valid ASN value between 0 and 4294967295.

---

#### PeerRouterConfigurations is missing or empty

**Description:**  
The `PeerRouterConfigurations` array in `BGPInfo` is missing or contains no entries.  
**Example Failure:**  
`PeerRouterConfigurations property validation failed. Actual value: <NULL>`  
**Remediation Steps:**  
Add at least one valid peer router configuration to `PeerRouterConfigurations`.

---

#### PeerASN is missing or out of valid range

**Description:**  
A `PeerASN` value in `PeerRouterConfigurations` is missing, empty, or not within the valid ASN range (0–4294967295).  
**Example Failure:**  
`PeerASN property validation failed. Actual value: <NULL>`  
**Remediation Steps:**  
Set `PeerASN` to a valid ASN value between 0 and 4294967295 for each peer.

---

#### RouterIPAddress is missing or not a valid IPv4 address

**Description:**  
A `RouterIPAddress` value in `PeerRouterConfigurations` is missing, empty, or not a valid IPv4 address.  
**Example Failure:**  
`RouterIPAddress property validation failed. Actual value: <NULL>`  
**Remediation Steps:**  
Provide a valid IPv4 address for each peer router.

---

#### Duplicate RouterIPAddress detected

**Description:**  
Multiple entries in `PeerRouterConfigurations` have the same `RouterIPAddress`.  
**Example Failure:**  
`Duplicate RouterIPAddress detected. Value: 100.70.20.149`  
**Remediation Steps:**  
Ensure each `RouterIPAddress` in `PeerRouterConfigurations` is unique.


---