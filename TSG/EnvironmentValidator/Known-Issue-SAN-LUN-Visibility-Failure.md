---
ArticleType: "KI"
Article_ID: "20260917170005"
Title: "Known issue: SAN LUN visibility validation blocks Deployment or Add Node"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
EngineeringStatus: "Pending"
FixedInBuild:
  OS: []
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Disaggregated"]
  OEM: ["All"]
  OS: ["24H2"]
  SolutionMinorBuild: ["2607", "2608", "2609", "2610"]
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: ""
  ID: 0
Tags: ["Cloud Deployment", "Validation", "HBA", "Diagnostics", "Log Collection"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|---|---|---|
| 2026-09-17 | 2.0 | Verified current SAN validator behavior, adopted the mandatory Known Issue layout, and added fail-closed diagnosis, ownership, risk, verification, and evidence guidance. |

:::

# Known issue: SAN LUN visibility validation blocks Deployment or Add Node

# Symptoms

This article applies when Azure Local uses external block storage over Fibre
Channel or iSCSI and the Environment Validator result
`AzureLocal_SAN_Test_LUN_Visibility` reports `FAILURE`.

The current validator function is `Test-SANALUNVisibility`, invoked through
`Invoke-AzureLocalSANValidation` by `Test-AzureLocalSANValidator`.

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width:180px;">ArticleType</th>
    <td><code>KI</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><code>['Engineering', 'CSS', 'OEM Partners', 'External']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Environment Validator, Azure Local SAN validator</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>. Deployment or Add Node cannot continue while a required SAN LUN is missing or not healthy.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected versions</th>
    <td>The dedicated SAN validation path was introduced for the 2607 release line and remains present in current 2610 source and runtime. No product build that removes the external SAN readiness requirement is established.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Fixed versions</th>
    <td>None established. The known issue remains <code>Pending</code> because the blocking condition is an unresolved external SAN presentation or health problem, not a retired validator defect.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>The lifecycle operation is blocked. Read-only diagnosis does not interrupt running workloads. SAN-side changes, MPIO changes, and a node reboot can affect storage availability and require change control.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The storage or SAN administrator owns array host groups, LUN masking, target ports, and fabric zoning. The Windows or Azure Local administrator owns host initiators, MPIO, drivers, and the validation rerun. The network team owns only the Ethernet path for iSCSI. The OEM or storage vendor owns qualified firmware, drivers, and array-specific DSM guidance.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 15-30 minutes to classify the failure and collect evidence. The correction window depends on the SAN owner and whether a host reboot is required.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td><strong>[LOW RISK]</strong> for inventory, cache refresh, and evidence collection. <strong>[MEDIUM RISK]</strong> for iSCSI login, MPIO registration, path restoration, or reboot. SAN zoning and LUN masking changes are storage-fabric changes and must follow the vendor's change procedure.</td>
  </tr>
</table>

The validator reports one of two conditions for a configured LUN:

```text
SAN LUN '<VolumeName>' (UniqueId '<LunId>') is not visible to node '<NodeName>'.
```

```text
The following SAN LUN(s) are visible but not healthy on this node:
<VolumeName> (UniqueId '<LunId>') reports HealthStatus '<Status>'.
```

The exact punctuation can vary by Environment Checker package. Use the result
name, node, configured volume name, LUN `UniqueId`, and
`AdditionalData.Detail` as the stable evidence.

The validator checks:

- `Infrastructure_1`.
- `ClusterPerformanceHistory`.
- `Witness` only when the cluster witness type is `ClusterWitnessDisk` and a
  witness LUN ID is configured.

For Deployment, the validator checks the configured LUNs across the intended
nodes. For Add Node, the current wrapper checks the joining node and excludes
partition-style, SCSI reservation, and MPIO tests. LUN visibility remains
included, including the configured disk witness when applicable.

**Where this failure appears**

| Admin surface | What to expect |
|---|---|
| PowerShell on an Azure Local node | **Shown**: `Get-Disk` cannot find the configured `UniqueId`, or the matching disk has a `HealthStatus` other than `Healthy`. |
| Azure portal | **Shown**: the failed Deployment or Add Node validation names the SAN LUN visibility result and affected node. |
| Windows event logs | **Shown when persisted**: Environment Checker Event ID 17205 can contain `AzureLocal_SAN_Test_LUN_Visibility`; read the human detail from `AdditionalData.Detail`. |
| Cluster logs from `Get-ClusterLog` | This pre-deployment SAN presentation result is **not evident in cluster logs** as a failover-cluster event. A deployed cluster can have separate storage events, but those do not replace this validator result. |
| Windows Failover Cluster Manager | The pre-deployment Environment Validator result is **not evident in Failover Cluster Manager**. Do not infer that a LUN is correctly presented because no failed cluster resource is shown. |
| Windows Admin Center on a standalone host | The exact result is **not evident in Windows Admin Center on a standalone host**. Use node PowerShell, the lifecycle result, and vendor tools. |
| Windows Admin Center in the Azure portal | The exact SAN LUN mapping comparison is **not evident in Windows Admin Center in the Azure portal**. Use the Azure Local lifecycle view and node evidence. |
| Component or tool log files on disk | **Shown when written**: preserve `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`, `AzStackHciEnvironmentReport.json` or `.xml`, and relevant files under `C:\CloudDeployment\Logs`. |

# Issue Validation

## Errors or Failures

Use this article only when all of these statements are true:

1. The deployment storage type is SAN.
1. The configured transport is Fibre Channel or iSCSI.
1. The failed result is `AzureLocal_SAN_Test_LUN_Visibility`.
1. The result identifies a required LUN as missing or not healthy.
1. The LUN ID is taken from the deployment configuration or validator output,
   not guessed from disk number, drive letter, label, or partition GUID.

**Five-minute decision path**

1. **[LOW RISK]** Run the detection script locally on the node named in the
   failure.
1. If the configured `UniqueId` is absent, route the case to the SAN owner:
   verify the array host group, LUN masking, target ports, initiator identity,
   and FC zoning or iSCSI path.
1. If the disk is present but not `Healthy`, preserve `OperationalStatus`,
   MPIO, HBA, and array-path evidence. Do not assume the Windows health state
   proves one specific failed path.
1. If every configured LUN is present and healthy, stop. Preserve the validator
   result and rerun the original validation once. If it fails again, escalate
   with the evidence bundle.

**Before you start**

- Run the commands from an elevated Windows PowerShell session on the node named
  in the failure.
- Obtain the configured LUN IDs from the deployment configuration or failed
  result. Do not substitute disk numbers because disk numbers can differ among
  nodes and across rescans.
- For Deployment, run the same read-only comparison on every intended node.
- For Add Node, run it on the joining node first. Do not change a deployed
  member unless evidence names that member.
- Do not initialize, format, clear, online, offline, or assign a drive letter to
  a SAN disk while using this article.
- Do not alter zoning, masking, switch configuration, iSCSI sessions, MPIO,
  drivers, or firmware until the owner confirms the failing branch and a
  rollback plan.

## PowerShell Detection Script

**Compare the configured LUN IDs with the local disk inventory**

Replace the placeholders with the exact LUN IDs from the deployment
configuration. Remove the `Witness` entry when no `ClusterWitnessDisk` is
configured.

```powershell
$ErrorActionPreference = 'Stop'

$expectedLuns = [ordered]@{
    Infrastructure_1          = '<infra-lun-unique-id>'
    ClusterPerformanceHistory = '<performance-history-lun-unique-id>'
    Witness                  = '<optional-witness-lun-unique-id>'
}

$unresolved = @(
    $expectedLuns.GetEnumerator() |
        Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.Value) -or
            [string]$_.Value -match '^<'
        }
)
if ($unresolved.Count) {
    throw "Replace or remove every unresolved LUN placeholder: $($unresolved.Name -join ', ')"
}

Update-HostStorageCache
Update-StorageProviderCache -DiscoveryLevel Full

$disks = @(Get-Disk)
$results = foreach ($entry in $expectedLuns.GetEnumerator()) {
    $matches = @(
        $disks |
            Where-Object { $_.UniqueId -ieq [string]$entry.Value }
    )

    if ($matches.Count -eq 0) {
        [pscustomobject]@{
            VolumeName        = $entry.Name
            ExpectedUniqueId  = [string]$entry.Value
            Verdict           = 'MISSING'
            DiskNumber        = $null
            BusType           = $null
            HealthStatus      = $null
            OperationalStatus = $null
        }
        continue
    }

    if ($matches.Count -gt 1) {
        [pscustomobject]@{
            VolumeName        = $entry.Name
            ExpectedUniqueId  = [string]$entry.Value
            Verdict           = 'AMBIGUOUS'
            DiskNumber        = ($matches.Number -join ',')
            BusType           = ($matches.BusType -join ',')
            HealthStatus      = ($matches.HealthStatus -join ',')
            OperationalStatus = ($matches.OperationalStatus -join ',')
        }
        continue
    }

    $disk = $matches[0]
    [pscustomobject]@{
        VolumeName        = $entry.Name
        ExpectedUniqueId  = [string]$entry.Value
        Verdict           = if ([string]$disk.HealthStatus -eq 'Healthy') {
            'PRESENT-HEALTHY'
        }
        else {
            'PRESENT-NOT-HEALTHY'
        }
        DiskNumber        = $disk.Number
        BusType           = [string]$disk.BusType
        HealthStatus      = [string]$disk.HealthStatus
        OperationalStatus = ($disk.OperationalStatus -join ',')
    }
}

$results | Format-Table -AutoSize

$blocking = @(
    $results |
        Where-Object { $_.Verdict -ne 'PRESENT-HEALTHY' }
)
if ($blocking.Count) {
    Write-Warning "$($blocking.Count) configured SAN LUN result(s) require correction."
}
else {
    Write-Host 'Every configured SAN LUN is present and reports Healthy on this node.'
}
```

**Expected result**

- `PRESENT-HEALTHY`: the configured `UniqueId` is visible and reports
  `HealthStatus = Healthy` on this node.
- `MISSING`: the node does not enumerate the configured `UniqueId`.
- `PRESENT-NOT-HEALTHY`: the disk is visible, but its storage health requires
  investigation.
- `AMBIGUOUS`: more than one disk reports the same configured `UniqueId`.
  Stop and collect evidence because the mapping is not safe to interpret.

**Read the persisted Environment Checker result**

Run this after the lifecycle validation has produced or refreshed Event ID
17205:

```powershell
$resultName = 'AzureLocal_SAN_Test_LUN_Visibility'

Get-WinEvent -FilterHashtable @{
    LogName = 'AzStackHciEnvironmentChecker'
    Id      = 17205
} -ErrorAction SilentlyContinue |
    ForEach-Object {
        try {
            $_.Message | ConvertFrom-Json
        }
        catch {
            $null
        }
    } |
    Where-Object { $_.Name -like "*$resultName*" } |
    Select-Object -First 5 `
        Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Remediation
```

The serialized record uses numeric top-level status and severity fields. Use
`AdditionalData.Status` and `AdditionalData.Detail` for the human-readable
result.

**Collect transport and MPIO evidence**

These commands are read-only:

```powershell
# Initiators and current transport state
Get-InitiatorPort |
    Select-Object ConnectionType, NodeAddress, PortAddress

Get-IscsiTarget |
    Select-Object NodeAddress, IsConnected

Get-IscsiSession |
    Select-Object InitiatorNodeAddress, TargetNodeAddress,
        IsConnected, IsPersistent

# MPIO feature, claim catalog, and current map
Get-WindowsFeature -Name Multipath-IO
Get-MSDSMSupportedHW
Get-MSDSMAutomaticClaimSettings
Get-MPIOAvailableHW
mpclaim -s -d
```

For Fibre Channel, preserve the WWPN values from `Get-InitiatorPort` and the HBA
driver and firmware inventory required by the storage vendor. For iSCSI,
preserve the initiator IQN, target IQN, portal addresses, and session state. Test
TCP 3260 only against a target portal provided by the storage owner:

```powershell
Test-NetConnection -ComputerName '<iscsi-target-portal>' -Port 3260
```

A successful TCP test proves only that the portal port is reachable. It does not
prove that authentication, target mapping, LUN masking, MPIO, or the configured
LUN ID is correct.

# Root Cause

The current check is a readiness gate. It compares the configured SAN LUN IDs
with `Get-Disk.UniqueId` on each applicable node and requires each matching disk
to report `HealthStatus = Healthy`.

Common contributing factors include:

- The array host group omits the affected node's initiator.
- LUN masking does not present the required LUN to the affected initiator.
- Fibre Channel zoning omits a required initiator or target port.
- An iSCSI target portal, login, authentication, VLAN, route, or firewall path is
  unavailable.
- HBA, NIC, MPIO, DSM, driver, firmware, or array path state prevents a healthy
  presentation.
- The deployment configuration contains the wrong LUN `UniqueId`.
- The disk is visible but the storage provider reports a nonhealthy state.

The validator does not treat any Fibre Channel or iSCSI disk with a familiar
label as equivalent. It matches the configured IDs case-insensitively by
`UniqueId`. Renaming a volume or assigning a drive letter cannot correct the
failure.

::: audience-css

# Internal Root Cause

Current `ASZ-EnvironmentValidator` source defines
`Test-SANALUNVisibility` in
`AzureLocalSANValidator/AzureLocal.SANValidator.Helpers.psm1`.
The result is:

- Name `AzureLocal_SAN_Test_LUN_Visibility`.
- Severity `CRITICAL`.
- One result per applicable node.
- `SUCCESS` only when all configured LUNs are visible and healthy.
- `FAILURE` when a configured LUN is missing or has a nonhealthy
  `HealthStatus`.

The SAN feature source entered the 2607 release line. Later 2607 work extracted
visibility into the transport-independent check, added the disk-witness LUN,
and extended witness visibility to Add Node. Current 2610 runtime
`AzStackHci.EnvironmentChecker 10.2610.0.2039` contains the same result name,
function, Deployment and AddNode operation metadata, witness path, and Add Node
exclusions.

Do not publish a fixed build for an external zoning, masking, path, or array
health condition. Keep `EngineeringStatus: Pending` and `FixedInBuild` empty
until an authoritative product defect and release boundary are linked to this
article.

:::

# Mitigation Details

Select the branch proved by the detection script.

**Branch A: the configured LUN is missing**

1. Give the storage owner the affected node name, expected LUN `UniqueId`,
   initiator WWPN or IQN, target identifiers, and the output from the detection
   script.
1. Verify the LUN exists on the array and is mapped to the correct host group.
1. Verify every intended node initiator is in the host group.
1. For Fibre Channel, verify initiator-to-target zoning and HBA link state.
1. For iSCSI, verify target portal reachability, target authentication, and the
   intended persistent multipath sessions.
1. Apply the array or fabric correction through the vendor's supported
   procedure.
1. Rescan the affected host and rerun the detection script.

**Branch B: the configured LUN is visible but not healthy**

1. Preserve the disk's `HealthStatus`, `OperationalStatus`, MPIO map, active
   paths, HBA or NIC state, and array-side path health.
1. Verify Multipath-IO is installed and the vendor's supported MPIO or DSM
   configuration is applied consistently on every node.
1. Verify the failing LUN is in the MPIO map and has the vendor-required
   redundant paths.
1. Restore failed paths, correct the supported device claim, or engage the
   storage vendor when the array reports a degraded LUN.
1. Rescan the host and rerun the detection script.

> [!WARNING]
> **[MEDIUM RISK]** Do not run MPIO registration or iSCSI login commands from a
> generic example without confirming the exact vendor, product ID, current
> state, and rollback. MPIO changes can require a reboot. A wrong claim can
> change disk presentation.

When the vendor procedure requires Microsoft DSM registration, first record the
current state:

```powershell
Get-MSDSMSupportedHW
Get-MSDSMAutomaticClaimSettings
Get-MPIOAvailableHW
mpclaim -s -d
```

Use the exact `VendorId` and `ProductId` returned for the qualified array. Follow
the vendor and Microsoft external-storage setup guidance for the state-changing
commands. Do not copy an identifier from another array or another customer.

If a reboot is required:

- For a host being prepared for Deployment, confirm no customer workload is
  running on it.
- For an Add Node target that is not yet a cluster member, reboot only that new
  node.
- If the affected server is already a deployed member, stop. Use the standard
  node-maintenance procedure to verify quorum, storage health, workload drain,
  and recovery before and after the reboot.

**Rollback**

- Revert only the change made during this maintenance window.
- For zoning or masking, restore the prior array or fabric configuration from
  the storage owner's change record.
- For iSCSI, remove only the new persistent login after confirming that it is
  not an intended production path.
- For MPIO or DSM changes, restore the recorded prior claim and auto-claim state
  through the vendor-supported procedure. Do not remove an existing claim used
  by other LUNs.
- If the rollback state is uncertain, stop and engage the storage vendor or
  Microsoft support before changing disk presentation again.

# Escalation

Escalate to Microsoft support when:

- Every intended node sees the exact configured LUN IDs as `Healthy`, but the
  current validator still reports them missing or unhealthy.
- The same `UniqueId` maps to more than one disk.
- The validator result lacks the node, LUN ID, or useful detail needed to route
  the issue.
- The Environment Checker throws an exception instead of returning the named
  result.
- Source and installed runtime behavior disagree.

Escalate to the storage vendor or OEM when:

- The array, HBA, NIC, or vendor DSM reports degraded paths or unsupported
  firmware or driver combinations.
- The qualified VendorId or ProductId cannot be registered through the vendor's
  documented process.
- LUN masking, target ports, zoning, or array health is inconsistent among
  nodes.

Attach:

- Deployment or Add Node operation and timestamp.
- Azure Local solution and Environment Checker versions.
- The full `AzureLocal_SAN_Test_LUN_Visibility` result.
- Expected volume names and LUN IDs.
- Detection-script output from every intended node.
- `Get-InitiatorPort`, iSCSI session or FC evidence, MPIO inventory, and
  `mpclaim -s -d`.
- Array host-group, masking, and zoning evidence from the storage owner.
- Environment Checker and CloudDeployment logs.

::: audience-css

# Internal Escalation

Include the installed
`AzureLocalSANValidator/AzureLocal.SANValidator.Helpers.psm1` and
`AzureLocalSANValidator.psm1` file versions or hashes when runtime behavior does
not match source. Route validator-emission defects to the Environment Validator
owner. Route array qualification, HBA, DSM, and fabric-specific issues to the
storage integration owner and named vendor.

TSG Forge validation for the September 17, 2026 campaign is intentionally
T3/L1. HC1n26r1039 ran solution `12.2610.1004.30`, platform
`12.2610.0.3059`, and Environment Checker `10.2610.0.2039`. The lab had no
Fibre Channel or iSCSI disks, no iSCSI targets or sessions, and no MPIO disks.
Only source, installed command shape, and applicability were validated. No SAN
failure, mitigation, or recovery was reproduced.

:::

# Related Content

- [Connect an external storage array to Azure Local](https://learn.microsoft.com/azure/azure-local/deploy/enable-external-storage)
- [Supported SAN solutions on Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/san-requirements)
- [Multipath I/O troubleshooting guidance](https://learn.microsoft.com/troubleshoot/windows-server/backup-and-storage/windows-server-mpio-troubleshooting)
- [iSCSI storage connectivity troubleshooting](https://learn.microsoft.com/troubleshoot/windows-server/backup-and-storage/iscsi-storage-connectivity-troubleshooting)

::: audience-css

# Source Articles

- [Connect an external storage array to Azure Local](https://learn.microsoft.com/azure/azure-local/deploy/enable-external-storage)
- [Supported SAN solutions on Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/san-requirements)
- [Multipath I/O troubleshooting guidance](https://learn.microsoft.com/troubleshoot/windows-server/backup-and-storage/windows-server-mpio-troubleshooting)

:::
