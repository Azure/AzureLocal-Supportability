---
ArticleType: "TSG"
Article_ID: "20260917170001"
Title: "AzStackHci_Hardware_Test_NetAdapter"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  - Source: "ADO PR"
    ID: 15166298
  - Source: "ADO PR"
    ID: 11451171
Tags: ["Validation", "NIC", "Driver"]
---
[[_TOC_]]

# Revision History

| Date | Description |
| --- | --- |
| 2026-09-17 | Updated current result names and branches, added read-only diagnosis, maintenance gates, verification, escalation evidence, and publication metadata. |

# AzStackHci_Hardware_Test_NetAdapter

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_NetAdapter</strong>, plus current aggregate names described below</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><strong>Test-NetAdapter</strong>, run by <code>Invoke-AzStackHciHardwareValidation</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Candidate-host physical Ethernet adapters, drivers, link state, and cross-node consistency</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong> for missing adapters, unsupported properties, driver mismatch, or count mismatch. Speed, MTU, and VLAN consistency findings can be warnings.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td>Deployment, Add Node, and Repair Node validation. Current PreUpdate orchestration runs only the system-drive free-space hardware test, not this check.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>Azure Local deployment and network administrator, with the qualified OEM for driver, firmware, adapter, cabling, or platform changes.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td>Diagnosis is read-only. Driver, firmware, link, and adapter changes can interrupt management, storage, compute, and cluster traffic.</td>
  </tr>
</table>

> [!IMPORTANT]
> Do not disable, restart, rename, remove, update, or reconfigure an adapter on a deployed cluster member as a generic response to this validator. Do not change Network ATC intents, DCB, RDMA, VLANs, MTU, virtual switches, switch ports, drivers, or firmware until the exact traffic role and a safe maintenance plan are established.

## Summary

`Test-NetAdapter` first selects adapters that meet all four entry conditions:

- `Get-NetAdapter -Physical` returns the adapter;
- `NdisMedium` is `0`, which represents IEEE 802.3 Ethernet;
- `Status` is `Up`;
- `NdisPhysicalMedium` is `14`, which represents 802.3 Ethernet, and `PnPDeviceID` does not begin with `USB\`.

If no adapter qualifies on a host, the API result is `AzStackHci_Hardware_Test_NetAdapter` and the lifecycle operation is blocked.

For qualifying adapters, the current check also validates required properties, at least one adapter per host, equal adapter counts across hosts, and grouped cross-node consistency. Most cases take 15 to 30 minutes to classify with the read-only steps below. A link or cabling issue can be quick to correct. A driver, firmware, adapter, or platform qualification issue requires the OEM procedure and can require a maintenance window or hardware replacement.

## Current and legacy result names

Current Environment Checker builds can aggregate passing or property-level results into:

- `AzStackHci_Hardware_NetAdapter`
- `AzStackHci_Hardware_NetAdapter-GroupConsistency`

The no-qualifying-adapter branch continues to emit:

- `AzStackHci_Hardware_Test_NetAdapter`

Older reports and detailed results can also contain names such as:

- `AzStackHci_Hardware_Test_NetAdapter_Minimum_Count`
- `AzStackHci_Hardware_Test_NetAdapter_Instance_Property_<PropertyName>`
- `AzStackHci_Hardware_Test_NetAdapter_Group_Consistency`
- `AzStackHci_Hardware_Test_NetAdapter_Instance_Consistency_Count`
- `AzStackHci_Hardware_Test_NetAdapter_Instance_Consistency_Count_ByGroup`

Always use the exact `Name`, `Severity`, and `AdditionalData.Detail` from the affected system. Do not assume every result in this family is critical.

## What the current check evaluates

After the entry filter, the check evaluates these branches:

1. **API and qualifying inventory**: each host must return at least one physical, Up, non-USB Ethernet adapter.
2. **Required adapter properties**: the adapter must be a visible, started, connected, full-duplex hardware interface with the required administrative, operational, media, and error states.
3. **Driver consistency, critical**: adapters grouped by `DriverDescription` are compared across hosts for `DriverDate`, `DriverDescription`, `DriverMajorNdisVersion`, `DriverMinorNdisVersion`, `DriverProvider`, `DriverVersionString`, `MajorDriverVersion`, and `MinorDriverVersion`.
4. **Operational consistency, warning**: adapters in the same driver-description group are compared for `ActiveMaximumTransmissionUnit`, `ReceiveLinkSpeed`, `Speed`, `TransmitLinkSpeed`, `VlanID`, and `MtuSize`.
5. **Adapter counts, critical**: each host must have at least one qualifying adapter, and the qualifying adapter count must be consistent across the hosts being validated.

The current source groups adapters by `DriverDescription`. It does not require every physical adapter in the machine to be identical. It compares the qualifying adapters that enter the check.

## Terms

| Term | Meaning |
| --- | --- |
| Candidate host | The machine being evaluated for Deployment, Add Node, or Repair Node. |
| Qualifying adapter | A physical, Up, non-USB 802.3 Ethernet adapter that enters the property and consistency checks. |
| NDIS | The Windows network-driver interface used to describe adapter type and state. |
| `NdisMedium = 0` | IEEE 802.3 Ethernet in the check's entry filter. |
| `NdisPhysicalMedium = 14` | 802.3 Ethernet in the check's entry filter. |
| Inbox driver | A generic driver delivered with Windows rather than the qualified OEM solution driver package. |
| Network ATC | Azure Local intent-based host networking configuration. It is not changed by this article. |
| Critical consistency | Driver identity and version fields that must match within a driver-description group. |
| Warning consistency | Speed, MTU, and VLAN-related fields that can produce a warning rather than the API failure. |

## Before you start

- Run the diagnostic commands from an elevated Windows PowerShell session.
- Confirm the affected lifecycle operation and the candidate host named in the validator result.
- Use the current `AdditionalData.Detail` to identify the exact branch and severity.
- Do not run this check as a lifecycle proof on a virtual machine. Current Hardware orchestration excludes `Test-NetAdapter` when the computer model is `Virtual Machine`.
- If the target is already a deployed cluster member, diagnosis remains read-only. Any NIC, driver, firmware, link, switch, or Network ATC change requires an approved maintenance plan.
- Before a deployed-member change, identify the adapter's Management, Compute, Storage, and cluster-network roles. Confirm redundant paths, quorum, node state, CSV state, virtual-disk health, and workload evacuation.
- Use the qualified OEM driver and firmware package for the exact server, adapter, and Azure Local solution. Do not select a version only because it is newer.

## Where this failure appears

| Administrator surface | What to expect |
| --- | --- |
| PowerShell on the candidate host | `Invoke-AzStackHciHardwareValidation -Include Test-NetAdapter -PassThru` and the `Get-NetAdapter` commands below show the actionable state. |
| Azure portal | A Deployment, Add Node, or Repair Node validation can show the check as blocking. Portal data can lag until the lifecycle validation runs again. |
| Windows event logs | The `AzStackHciEnvironmentChecker` log can contain Event ID 17205 with the serialized result. Read `AdditionalData.Status` and `AdditionalData.Detail`. |
| Cluster logs (`Get-ClusterLog`) | This candidate-host validator result does not normally appear as a failover-cluster event. Use cluster logs only when a separate cluster-network fault is also present. |
| Failover Cluster Manager | The validator result does not normally appear as a role or resource. Use the console only to confirm deployed-member and network state before maintenance. |
| Windows Admin Center, standalone | The exact validator result is not consistently exposed. Adapter inventory can help with diagnosis, but it does not replace the validator output. |
| Windows Admin Center in Azure | The exact validator result is not consistently exposed. Use the Azure Local lifecycle result and on-node evidence. |
| Component or tool log files | The account that ran Environment Checker can have `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and `AzStackHciEnvironmentReport.json` or `.xml`. Preserve timestamps and the matching result. |

### Read the newest Event ID 17205 result

```powershell
$netAdapterNames = @(
    'AzStackHci_Hardware_Test_NetAdapter',
    'AzStackHci_Hardware_NetAdapter',
    'AzStackHci_Hardware_NetAdapter-GroupConsistency'
)

Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object {
        try { $_.Message | ConvertFrom-Json } catch { $null }
    } |
    Where-Object {
        $_ -and (
            $netAdapterNames -contains $_.Name -or
            $_.Name -like '*NetAdapter*'
        )
    } |
    Select-Object -First 1 `
        Name,
        Severity,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Remediation,
        Timestamp
```

If no fresh record exists, run the targeted validation in the next section. A missing event is a data gap, not a passing result.

## Diagnosis

### 1. Run the targeted validator

On a physical candidate host:

```powershell
Import-Module AzStackHci.EnvironmentChecker -Force

$result = Invoke-AzStackHciHardwareValidation `
    -Include Test-NetAdapter `
    -PassThru

$result |
    Where-Object { $_.Name -like '*NetAdapter*' } |
    Select-Object Name, Status, Severity, Description, Remediation,
        @{n='DetailStatus';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}} |
    Format-List
```

If no NetAdapter result is returned, record the Environment Checker module version, inspect any `ExcludeTests.txt`, and confirm that the host is physical and that the operation runs this check. A virtual-machine skip is expected and is not a passing result.

### 2. Identify why adapters do or do not enter the check

```powershell
$allPhysical = @(Get-NetAdapter -Physical)
$qualifying = @(
    $allPhysical |
        Where-Object {
            $_.NdisMedium -eq 0 -and
            $_.Status -eq 'Up' -and
            $_.NdisPhysicalMedium -eq 14 -and
            $_.PnPDeviceID -notlike 'USB\*'
        }
)

$allPhysical |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed,
        NdisMedium, NdisPhysicalMedium, PnPDeviceID,
        HardwareInterface, Virtual, ConnectorPresent,
        DriverProvider, DriverVersionString, DriverDate |
    Format-Table -AutoSize

[pscustomobject]@{
    PhysicalAdapters = $allPhysical.Count
    QualifyingAdapters = $qualifying.Count
}
```

A passing entry state has at least one qualifying adapter. The filter does not prove that all later property and consistency checks pass.

### 3. Capture the required properties

```powershell
Get-NetAdapter -Physical |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed,
        AdminLocked, ConnectorPresent, EndpointInterface, ErrorDescription,
        FullDuplex, HardwareInterface, Hidden, IMFilter,
        InterfaceAdminStatus, InterfaceOperationalStatus, iSCSIInterface,
        LastErrorCode, MediaConnectState, MediaDuplexState,
        NdisMedium, NdisPhysicalMedium,
        OperationalStatusDownDefaultPortNotAuthenticated,
        OperationalStatusDownInterfacePaused,
        OperationalStatusDownLowPowerState,
        OperationalStatusDownMediaDisconnected,
        State, Virtual, PnPDeviceID |
    Format-List
```

The expected state for a qualifying production adapter is:

- connected, visible, started, full duplex, and a hardware interface;
- administrative and operational status Up;
- `NdisMedium = 0` and `NdisPhysicalMedium = 14`;
- not virtual, hidden, USB, iSCSI, endpoint, or filter-only;
- no reported error or down-state reason.

Do not force these properties directly. They describe the expected result of correct hardware, cabling, driver, firmware, switch, and Network ATC configuration.

### 4. Compare driver, speed, MTU, VLAN, and adapter counts across hosts

Set `$hosts` to the exact physical candidate hosts in the validation:

```powershell
$hosts = @('<host-1>', '<host-2>')
$sessions = @()

try {
    $sessions = @(
        foreach ($hostName in $hosts) {
            New-PSSession -ComputerName $hostName -ErrorAction Stop
        }
    )

    $inventory = @(
        Invoke-Command -Session $sessions -ScriptBlock {
            Get-NetAdapter -Physical |
                Where-Object {
                    $_.NdisMedium -eq 0 -and
                    $_.Status -eq 'Up' -and
                    $_.NdisPhysicalMedium -eq 14 -and
                    $_.PnPDeviceID -notlike 'USB\*'
                } |
                Select-Object @{n='ComputerName';e={$env:COMPUTERNAME}},
                    Name, InterfaceDescription, DriverDescription,
                    DriverProvider, DriverVersionString, DriverDate,
                    DriverMajorNdisVersion, DriverMinorNdisVersion,
                    MajorDriverVersion, MinorDriverVersion,
                    ActiveMaximumTransmissionUnit, ReceiveLinkSpeed,
                    TransmitLinkSpeed, Speed, VlanID, MtuSize
        }
    )

    $inventory |
        Sort-Object DriverDescription, ComputerName, Name |
        Format-Table -AutoSize

    $inventory |
        Group-Object DriverDescription |
        ForEach-Object {
            [pscustomobject]@{
                DriverDescription = $_.Name
                Hosts = @($_.Group.ComputerName | Sort-Object -Unique) -join ', '
                AdapterCount = $_.Count
                DriverVersions = @($_.Group.DriverVersionString | Sort-Object -Unique) -join ', '
                ReceiveLinkSpeeds = @($_.Group.ReceiveLinkSpeed | Sort-Object -Unique) -join ', '
                TransmitLinkSpeeds = @($_.Group.TransmitLinkSpeed | Sort-Object -Unique) -join ', '
                Speeds = @($_.Group.Speed | Sort-Object -Unique) -join ', '
                MtuSizes = @($_.Group.MtuSize | Sort-Object -Unique) -join ', '
                VlanIDs = @($_.Group.VlanID | Sort-Object -Unique) -join ', '
            }
        } |
        Format-Table -AutoSize
}
finally {
    if ($sessions) {
        Remove-PSSession -Session $sessions -ErrorAction SilentlyContinue
    }
}
```

Interpret the output with the current validator detail:

- A difference in the critical driver fields can block the operation.
- A difference in speed, MTU, or VLAN fields can be reported as a warning.
- A different qualifying adapter count across hosts can block the operation.
- Grouping is by `DriverDescription`. Compare like adapters within that group.

### 5. Record installed driver and hardware identity

```powershell
Get-NetAdapter -Physical |
    ForEach-Object {
        $adapter = $_
        $hardware = Get-NetAdapterHardwareInfo -Name $adapter.Name -ErrorAction SilentlyContinue
        $advanced = Get-NetAdapterAdvancedProperty -Name $adapter.Name -AllProperties -ErrorAction SilentlyContinue

        [pscustomobject]@{
            Name = $adapter.Name
            InterfaceDescription = $adapter.InterfaceDescription
            Status = $adapter.Status
            LinkSpeed = $adapter.LinkSpeed
            DriverProvider = $adapter.DriverProvider
            DriverVersion = $adapter.DriverVersionString
            DriverDate = $adapter.DriverDate
            PnPDeviceID = $adapter.PnPDeviceID
            Bus = $hardware.Bus
            Device = $hardware.Device
            Function = $hardware.Function
            Mtu = $adapter.MtuSize
            VlanID = $adapter.VlanID
            AdvancedPropertyCount = @($advanced).Count
        }
    } |
    Format-List
```

Use the server model, adapter model, slot, PnP identity, driver provider, driver version, firmware, and qualified Azure Local solution together. A provider string alone does not prove that a driver is the qualified OEM package.

## Classification

| Evidence | Meaning | Next action |
| --- | --- | --- |
| `Get-NetAdapter -Physical` returns no adapters | Windows or the driver does not expose a physical adapter. | Confirm device presence, Device Manager state, BIOS or BMC inventory, and the qualified OEM driver package. |
| Physical adapters exist, but `QualifyingAdapters = 0` | Every adapter misses at least one entry condition. | Compare `Status`, `NdisMedium`, `NdisPhysicalMedium`, and `PnPDeviceID` against the filter. |
| `Status` is not Up or media is disconnected | The adapter is disabled, disconnected, or lacks a working link. | Check the intended port, cable or transceiver, switch port, and adapter state. Do not bounce a deployed-member management or storage path. |
| `NdisMedium` is not `0` or `NdisPhysicalMedium` is not `14` | Windows does not present the adapter as the required physical Ethernet type. | Verify qualified hardware, OEM driver, firmware, and device presentation. |
| `PnPDeviceID` begins with `USB\` | The adapter is USB and excluded. | Replace it with a qualified internal physical Ethernet adapter. |
| A required property fails | The adapter entered the check but is not in the required connected, started, physical state. | Use the failed property in `AdditionalData.Detail` to identify the driver, hardware, link, or configuration owner. |
| Critical driver fields differ within a driver-description group | The current check found a cross-node driver inconsistency. | Align the nodes to the same qualified OEM solution driver and firmware combination. |
| Speed, MTU, or VLAN fields differ | The current check found an operational consistency warning. | Compare Network ATC intent, switch configuration, link negotiation, and adapter advanced properties before changing anything. |
| Qualifying adapter counts differ across hosts | One or more hosts expose a different usable adapter population. | Identify the missing, down, excluded, or differently presented adapter before continuing. |
| Read-only inventory looks correct, but the check still fails | The failing branch may depend on a property not visible in the reduced table, stale validation output, or a product defect. | Preserve the full fresh result, module version, and complete adapter inventory, then escalate. |

## Remediation

### Path A: restore a missing or down link on a candidate host

1. Identify the exact adapter and intended traffic role.
2. Confirm that the adapter is enabled in firmware and visible in Windows.
3. Confirm the cable or transceiver and switch port are correct and operational.
4. For a new candidate host with no workloads, follow the qualified deployment procedure to restore the link.
5. For a deployed member, stop. Use an approved maintenance plan that preserves management and storage connectivity before any link, adapter, or switch action.
6. Rerun the entry-filter command and the targeted validator.

### Path B: install the qualified OEM driver or firmware

1. Record the server model, adapter identity, current driver, and current firmware.
2. Compare them with the qualified Azure Local solution catalog and the OEM package for that exact system.
3. Follow the OEM installation order and reboot requirements. Do not mix arbitrary driver and firmware versions.
4. On a deployed member, drain workloads and preserve quorum and redundant network paths before the approved maintenance action.
5. After the reboot or driver activation, confirm that all intended adapters are Up and that the driver fields match across like hosts.
6. Rerun the validator.

### Path C: correct cross-node driver inconsistency

1. Group the qualifying adapters by `DriverDescription`.
2. Compare the eight critical driver fields listed in this article.
3. Identify the host that differs from the qualified cluster baseline.
4. Apply the same approved OEM solution driver and required firmware to that host.
5. Do not copy a driver package from another node or use an inbox driver as an alignment shortcut.
6. Verify the fields match, then rerun the validator.

### Path D: investigate speed, MTU, or VLAN inconsistency

1. Determine whether the result is a warning or a critical blocker.
2. Compare the intended Network ATC configuration with the effective adapter and switch state.
3. Check link negotiation, switch port speed, adapter advanced properties, MTU, and VLAN ownership.
4. Change Network ATC or switch configuration only through the qualified network design and change process.
5. Rerun the validator and confirm that no new management or storage path issue appears.

### Path E: replace unsupported hardware

If the adapter remains excluded or fails required properties with the qualified driver and firmware:

1. Capture the complete evidence package in the Escalation section.
2. Confirm the adapter and server combination against the qualified Azure Local solution.
3. Engage the OEM to determine whether the device, riser, cable, transceiver, or system configuration must be replaced.
4. Do not substitute an unqualified adapter to clear the validator.

## Workload and maintenance impact

- The diagnostic commands in this article are read-only and do not require a drain.
- A new candidate host that has not joined the cluster has no cluster workloads to evacuate.
- Driver, firmware, adapter, cabling, switch-port, Network ATC, or reboot changes on a deployed member can interrupt management, compute, storage, live migration, and cluster communication.
- Before a deployed-member change, confirm all nodes are Up, quorum remains safe, CSVs are Online, virtual disks are healthy, no storage job is active, and workloads have an approved evacuation plan.
- Do not proceed when the adapter role is unknown, redundancy is degraded, quorum is at risk, or the approved OEM procedure is unavailable.

## Verify the fix

### 1. Confirm the adapter enters the check

```powershell
$qualifying = @(
    Get-NetAdapter -Physical |
        Where-Object {
            $_.NdisMedium -eq 0 -and
            $_.Status -eq 'Up' -and
            $_.NdisPhysicalMedium -eq 14 -and
            $_.PnPDeviceID -notlike 'USB\*'
        }
)

$qualifying |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed,
        DriverProvider, DriverVersionString, DriverDate,
        NdisMedium, NdisPhysicalMedium, PnPDeviceID |
    Format-Table -AutoSize

if ($qualifying.Count -lt 1) {
    throw 'No qualifying physical Ethernet adapter is available.'
}
```

### 2. Re-run the targeted validator

```powershell
Import-Module AzStackHci.EnvironmentChecker -Force

$result = Invoke-AzStackHciHardwareValidation `
    -Include Test-NetAdapter `
    -PassThru

$result |
    Where-Object { $_.Name -like '*NetAdapter*' } |
    Select-Object Name, Status, Severity,
        @{n='DetailStatus';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}} |
    Format-List
```

The fix is verified only when:

- a fresh NetAdapter result is present;
- the critical aggregate or detailed branch reports success;
- every candidate host has at least one qualifying adapter;
- critical driver fields match within each driver-description group;
- qualifying adapter counts are consistent across the validated hosts;
- any remaining warning is understood and accepted by the network design owner.

### 3. Re-run the lifecycle validation

Run the same Deployment, Add Node, or Repair Node validation that originally failed. A direct targeted pass does not by itself prove that the lifecycle workflow refreshed its persisted health result.

### 4. Confirm deployed-cluster health when applicable

```powershell
Get-ClusterNode
Get-ClusterQuorum
Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus
Get-StorageJob
Get-NetAdapter | Select-Object Name, Status, LinkSpeed
```

All nodes must be Up, quorum must remain safe, CSVs must be Online, virtual disks must be healthy, no unexpected storage job may remain, and the intended network paths must be Up.

## Escalation

Escalate to the OEM hardware or solution owner when:

- the adapter, server, driver, firmware, cable, transceiver, riser, or switch-port qualification is uncertain;
- the adapter is absent from Windows or the BMC inventory;
- the qualified driver and firmware still expose an unsupported medium or required property;
- hardware replacement or firmware work is required.

Escalate to the Azure Local network or Environment Validator owner when:

- the current module returns a NetAdapter failure after the source-exact entry filter and required properties pass;
- aggregate and detailed result names conflict with the current module behavior;
- the driver, count, speed, MTU, or VLAN comparison appears incorrect;
- the targeted validator returns no result on a supported physical Deployment, Add Node, or Repair Node path.

Attach:

- Environment Checker module version and module path;
- lifecycle operation and candidate-host names;
- fresh NetAdapter result with `Name`, `Severity`, and `AdditionalData.Detail`;
- Event ID 17205 result and timestamp;
- complete physical-adapter inventory from every candidate host;
- driver provider, version, date, adapter PnP identity, and hardware location;
- relevant Network ATC intent and effective state;
- OEM server, adapter, firmware, cabling, and switch-port evidence;
- cluster health output if the target is already deployed.

## References

- [Azure Local host network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
- [Azure Local physical network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/physical-network-requirements)
- [Manage Network ATC](https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-network-atc)
- [Azure Local solution catalog](https://aka.ms/azurelocalsolutions)

::: audience-css

# Source Articles

- Azure Local Environment Validator source history for SAN integration and NetAdapter result aggregation.
- Azure Local Environment Validator source history for missing-disk and missing-NIC explanations.

:::
