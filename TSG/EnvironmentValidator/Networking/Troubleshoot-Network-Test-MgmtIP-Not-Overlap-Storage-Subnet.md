<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet"
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "not-assessed",
    "last_validated": null,
    "spec_ref": ""
  }
}
-->

# AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Informational</strong>: The validator result does not block the operation. The network requirement still applies.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td><strong>Validator execution: deployment and pre-update when static IP configuration is used. Network requirement: all Azure Local deployments with separate management and storage networks.</strong></td>
  </tr>
</table>

## Table of contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Recommended network subnet design](#recommended-network-subnet-design)
- [Known validation limitation](#known-validation-limitation)
- [Symptoms and impact](#symptoms-and-impact)
- [Diagnosis](#diagnosis)
- [Remediation](#remediation)
- [Verification](#verification)
- [Escalation and evidence package](#escalation-and-evidence-package)
- [Related documentation](#related-documentation)

## Overview

This validator checks whether the management IPv4 subnet intersects any storage IPv4 subnet. Management and storage address ranges must be separate. Each storage subnet must also be unique and must not intersect another storage subnet.

An overlap exists whenever two address ranges share one or more addresses. The prefixes don't need to be identical. For example, `198.51.100.0/24` overlaps `198.51.100.0/25` because the `/24` contains the entire `/25`.

Separating traffic with VLANs doesn't make overlapping Layer 3 address ranges valid.

## Requirements

The network plan must meet all the following requirements:

1. The management subnet doesn't intersect any storage subnet.
2. Each storage subnet is unique and doesn't intersect another storage subnet.
3. The selected prefixes are unallocated and valid for the customer network.
4. The deployment inputs use the same approved prefixes across all nodes.

Examples:

| Management subnet | Storage subnet | Result | Reason |
| --- | --- | --- | --- |
| `198.51.100.0/24` | `198.51.100.0/25` | Invalid | The management range contains the storage range. |
| `198.51.100.0/25` | `198.51.100.0/24` | Invalid | The storage range contains the management range. |
| `198.51.100.0/24` | `198.51.100.0/24` | Invalid | The ranges are identical. |
| `198.51.100.0/24` | `203.0.113.0/24` | Valid | The ranges don't intersect. |

The prefixes in this guide use the address blocks reserved for documentation. Don't copy them into a deployment.

## Recommended network subnet design

Choose address ranges through the customer network-planning and IP address management process. Don't use a fixed range only because it appears in an example.

A valid plan has these properties:

- The management range is routable as required by the customer environment.
- The management range doesn't contain, and isn't contained by, a storage range.
- Each storage range is unique and doesn't contain, and isn't contained by, another storage range.
- VLAN separation complements the IP plan but doesn't replace non-overlapping Layer 3 ranges.
- Every node and deployment input uses the approved prefixes consistently.

Example valid design:

```text
Management: 198.51.100.0/24
Storage 1:  203.0.113.0/25
Storage 2:  203.0.113.128/25
```

Example invalid design:

```text
Management: 198.51.100.0/24
Storage 1:  198.51.100.0/25   # Contained by the management range
Storage 2:  203.0.113.0/24
```

## Known validation limitation

Some Environment Checker versions can report success for a containment-style overlap when the prefixes have different prefix lengths. For example, the validator might not detect that management prefix `198.51.100.0/24` contains storage prefix `198.51.100.0/25`.

The affected and corrected package-version boundaries aren't established in this guide. Independently compare the complete CIDR ranges regardless of the installed Environment Checker version.

- Don't treat a successful result from this validator as proof that the network plan is valid.
- Perform the independent CIDR range comparison in [Diagnosis](#diagnosis).
- Treat an informational severity as reporting behavior, not as an exception to the network requirement.

## Symptoms and impact

The issue can appear in either of these forms:

- The validator reports a failure and lists an overlapping management and storage subnet.
- The validator reports success, but an independent range comparison finds an overlap.

An overlapping configuration can cause ambiguous route and cluster-network selection. Depending on the operation and current network state, this can contribute to deployment, update, storage, live migration, or SDN failures. A cluster that is currently operating doesn't prove that the configuration is safe for future lifecycle operations.

Example validator failure:

```text
Management IP <management IP> on subnet <management CIDR> overlaps with storage subnet(s): <storage CIDR>.
```

## Diagnosis

### 1. Review the Environment Checker result

**Action type:** [READ-ONLY]

Review the result named `AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet`. If it failed, record the management prefix and every storage prefix in `AdditionalData.Detail`.

If it passed, continue with the independent comparison because of the known validation limitation.

### 2. Obtain the configured prefixes

**Action type:** [READ-ONLY]

For a system that isn't deployed, use the deployment inputs and approved network plan as the authoritative sources for the intended management and storage prefixes.

For an existing system, compare both the intended inputs and the effective addresses and prefix lengths on every node. Run the following command locally on each node:

```powershell
$ErrorActionPreference = 'Stop'

Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike '169.254.*' -and
        $_.IPAddress -ne '127.0.0.1'
    } |
    Sort-Object InterfaceAlias, IPAddress |
    Select-Object InterfaceAlias, IPAddress, PrefixLength
```

**Expected result:** The collected output identifies the current management and storage adapter addresses and prefix lengths on every node.

**Stop condition:** If adapter purpose, intended prefixes, or effective prefixes can't be identified, don't change the network. Collect the deployment inputs and engage Microsoft Support.

### 3. Compare the complete CIDR ranges

**Action type:** [READ-ONLY]

Run this script from a PowerShell session on an administrative workstation or Azure Local node. Replace the example values with the intended prefixes, and then repeat the comparison for any different effective prefixes found on the nodes. The script compares numeric IPv4 ranges, including containment in either direction.

```powershell
$ErrorActionPreference = 'Stop'

$managementCidr = '<management CIDR>'
$storageCidrs = @(
    '<storage CIDR 1>'
    '<storage CIDR 2>'
)

function ConvertTo-IPv4Number {
    param(
        [Parameter(Mandatory)]
        [System.Net.IPAddress]$Address
    )

    if ($Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "'$Address' isn't an IPv4 address."
    }

    $bytes = $Address.GetAddressBytes()
    [array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Get-IPv4CidrRange {
    param(
        [Parameter(Mandatory)]
        [string]$Cidr
    )

    $parts = $Cidr.Split('/')
    if ($parts.Count -ne 2) {
        throw "'$Cidr' isn't in IPv4 CIDR format."
    }

    try {
        $address = [System.Net.IPAddress]$parts[0]
        $prefixLength = [int]$parts[1]
    }
    catch {
        throw "'$Cidr' isn't a valid IPv4 CIDR."
    }

    if ($prefixLength -lt 0 -or $prefixLength -gt 32) {
        throw "Prefix length '$prefixLength' must be between 0 and 32."
    }

    $addressValue = [uint64](ConvertTo-IPv4Number -Address $address)
    $rangeSize = [uint64][math]::Pow(2, 32 - $prefixLength)
    $start = [uint64]([math]::Floor($addressValue / $rangeSize) * $rangeSize)

    [PSCustomObject]@{
        Cidr = $Cidr
        Start = $start
        End = $start + $rangeSize - 1
    }
}

$managementRange = Get-IPv4CidrRange -Cidr $managementCidr
$storageRanges = $storageCidrs | ForEach-Object {
    Get-IPv4CidrRange -Cidr $_
}

$managementComparisons = foreach ($storageRange in $storageRanges) {
    [PSCustomObject]@{
        FirstPrefix = $managementRange.Cidr
        SecondPrefix = $storageRange.Cidr
        Overlaps = (
            $managementRange.Start -le $storageRange.End -and
            $storageRange.Start -le $managementRange.End
        )
    }
}

$storageComparisons = for ($first = 0; $first -lt $storageRanges.Count; $first++) {
    for ($second = $first + 1; $second -lt $storageRanges.Count; $second++) {
        [PSCustomObject]@{
            FirstPrefix = $storageRanges[$first].Cidr
            SecondPrefix = $storageRanges[$second].Cidr
            Overlaps = (
                $storageRanges[$first].Start -le $storageRanges[$second].End -and
                $storageRanges[$second].Start -le $storageRanges[$first].End
            )
        }
    }
}

$managementComparisons
$storageComparisons
```

Example affected output:

```text
FirstPrefix       SecondPrefix      Overlaps
-----------       ------------      --------
198.51.100.0/24   198.51.100.0/25       True
198.51.100.0/24   203.0.113.0/24       False
198.51.100.0/25   203.0.113.0/24       False
```

**Expected healthy result:** Every `Overlaps` value is `False`.

**Affected result:** Any `Overlaps` value is `True`.

**Stop condition:** Don't continue deployment with an overlapping network plan. If another lifecycle operation is blocked, don't retry that operation until Microsoft Support has reviewed the overlap and the recovery plan. This informational validator doesn't itself block an operation.

## Remediation

### Before deployment

Update the approved network plan and deployment inputs so that:

- The management range doesn't intersect a storage range.
- Storage ranges don't intersect each other.
- The replacement ranges are unallocated and valid in the customer network.
- DNS, routing, VLAN, firewall, and switch configuration are aligned with the corrected plan.

Run the independent CIDR comparison before deployment.

### Existing deployed system

Changing management or storage addressing on a deployed Azure Local system is a high-risk, cross-component operation. It can affect cluster communication, DNS, Arc connectivity, Network ATC, storage connectivity, SDN, and persisted deployment state.

Don't use generic `Remove-NetIPAddress`, `New-NetIPAddress`, or direct Network ATC reconfiguration commands as an in-place repair based only on this TSG.

Open a Microsoft Support case before changing addressing or redeploying an existing system. Microsoft Support must review the topology, current impact, workload protection, and recovery options. Resolution might require a planned redeployment with a corrected address plan. Don't start an in-place readdressing or redeployment until the support-approved plan, maintenance window, data protection, and rollback or recovery path are established.

## Verification

After correcting the configuration:

1. Run the independent CIDR comparison again.
2. Confirm every management-to-storage and storage-to-storage comparison returns `Overlaps = False`.
3. Rerun the applicable Environment Checker workflow.
4. Confirm the deployed adapter addresses and deployment inputs match the approved network plan on every node.
5. Verify cluster, storage, management connectivity, and any enabled SDN functionality before returning the system to service.

If the independent comparison passes but the validator still reports an overlap, preserve the Environment Checker output and escalate with the evidence package below.

## Escalation and evidence package

Provide the following information to Microsoft Support:

- Azure Local solution version and Environment Checker package version.
- Full result for `AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet`.
- Approved management and storage CIDRs.
- Output from the independent CIDR comparison.
- Deployment input containing the host-network and storage-network configuration.
- Read-only `Get-NetIPAddress` output from every node.
- Whether the system is pre-deployment or already deployed.
- Whether SDN is enabled and the current customer impact.

For instructions, see [Create an Azure support request](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request).

## Related documentation

- [Host network requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
- [Custom IPs for storage in Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations#custom-ips-for-storage)
