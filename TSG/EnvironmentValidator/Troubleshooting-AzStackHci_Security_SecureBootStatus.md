---
ArticleType: "TSG"
Article_ID: "20260917145001"
Title: "AzStackHci_Security_SecureBootStatus"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: ["2603+"]
  ExtensionName: ""
  ExtensionVersion: []
Component: "Security"
Engineering_ID:
  Source: ""
  ID: 0
Tags: ["Solution Update", "Validation", "Certificates", "Firmware", "BitLocker", "BIOS"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|------|---------|---------|
| 2026-09-17 | 1.0 | Expanded validation evidence and publication metadata compliance |

:::

# AzStackHci_Security_SecureBootStatus

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Security_SecureBootStatus</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">ArticleType</th>
    <td><code>TSG</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><code>['Engineering', 'CSS', 'OEM Partners', 'External']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.Product</th>
    <td><code>Azure Local</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.OEM</th>
    <td><code>['All']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-SecureBootUpdateStatus</code> (emitted by <code>Invoke-AzStackHciSecurityValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Security (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Informational</strong>: the status is always SUCCESS. The actionable posture is encoded in <code>AdditionalData.Detail</code>.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td>Security readiness and pre-update system health checks.</td>
  </tr>
</table>

> **At a glance**
> - **What it is:** a posture check for the Windows UEFI CA 2023 Secure Boot certificate rollout associated with CVE-2023-24932.
> - **Impact:** this is normally a security-readiness gap, not an outage. Nodes continue to run, but the rollout is incomplete.
> - **Fastest safe answer:** run `Test-AzSSecureBootUpdateCompleted -Verbose` on each node. `True` is complete. `False` means at least one required component is incomplete.
> - **No instant workaround:** the supported remediation is an Azure Local Solution Update, plus OEM BIOS or UEFI firmware where required. Completion may need more than one reboot or a later update retry.
> - **Workload planning:** service one deployed member at a time. Its VMs must move to other nodes before a manual firmware reboot. The number of reboot cycles is not deterministic.
> - **Hard safety gate:** do not change firmware, Secure Boot keys, revocation state, or Secure Boot servicing registry values unless the BitLocker recovery key is retrievable and the approved Azure Local procedure explicitly requires the change.

## Overview

This check reports whether each node has completed the Windows UEFI CA 2023 Secure Boot update. It examines five related outcomes:

1. The Windows UEFI CA 2023 certificate is installed in the Secure Boot `db`.
2. The Microsoft UEFI CA 2023 certificate is installed in `db`.
3. The Microsoft Option ROM UEFI CA 2023 certificate is installed in `db`.
4. The Microsoft Corporation KEK 2K CA 2023 certificate is installed in `KEK`.
5. The Windows boot manager is signed by Windows UEFI CA 2023 and the updated boot manager is in use.

The validator result contains four certificate fields and one boot-manager status. The product completion cmdlet reports the same posture as five component booleans.

### Important result semantics

This validator always emits `Status = SUCCESS` and `Severity = INFORMATIONAL`, including when the rollout is incomplete. Do not filter for a failure status. Read `AdditionalData.Detail` or the component output from `Test-AzSSecureBootUpdateCompleted -Verbose`.

A node needs attention when any of these are true:

- A certificate reads `Installed: False`.
- A certificate reads `Installed: Unknown`.
- `Boot Manager Update Status` is not `BootManagerUpdatedAndInUse`.
- `Test-AzSSecureBootUpdateCompleted` returns `False`.
- The check reports an error while reading UEFI variables.

`UEFICA2023Status=Updated` is useful servicing evidence, but it is not sufficient by itself. The servicing value can be `Updated` while one or more certificate checks remain false. The product completion cmdlet and its individual component results are authoritative.

### Ownership and expected effort

| Situation | Owner | Workload impact | Planning guidance |
| --- | --- | --- | --- |
| Solution Update can continue the rollout | Azure Local update operator | Normal Solution Update maintenance behavior | Run the supported Solution Update and recheck every node. Completion may continue in a later update cycle. |
| Another reboot is required | Azure Local cluster administrator | The serviced node is unavailable during reboot; VMs must run elsewhere | Drain and reboot one node at a time. Do not promise a fixed reboot count. |
| BIOS is below the OEM minimum | OEM or server firmware administrator, coordinated with the cluster administrator | The serviced node is unavailable during the separate firmware window | Plan a separate BIOS or UEFI maintenance step after confirming the exact model and minimum version. |
| The known BIOS and reboot cases do not apply | Microsoft Support and the owning product group | No change should be attempted until the evidence is reviewed | Collect the bounded evidence in this guide and escalate. |

There is no reliable single completion time. A cluster may finish in one planned update window, or it may need additional per-node reboots, a separate OEM firmware window, or a later Solution Update retry.

## Requirements and safety gates

- Local administrator access to every node being checked.
- Azure Local Solution Update 2603 or later for the platform-managed rollout.
- The current OEM BIOS or UEFI requirement for each server model.
- A current cluster-health review before manually draining or rebooting a deployed member.
- A BitLocker recovery password for every protected volume, retrieved from the approved escrow location before any measured-boot or firmware change.

> [LOW RISK] The diagnostic commands in the confirmation and evidence sections are read-only.

> [MEDIUM RISK] A Solution Update, node reboot, or BIOS or UEFI update can move workloads and temporarily reduce cluster capacity. Follow the platform update workflow and service one node at a time.

> [HIGH RISK] Do not manually add or remove Secure Boot certificates, force DBX revocation, clear Secure Boot keys, or hand-edit `AvailableUpdates` as a shortcut. These operations can be irreversible or make a node or recovery media unbootable.

If you are first-line, temporary, or outsourced staff and do not own BitLocker recovery, cluster draining, and firmware maintenance, stop after collecting the read-only evidence and hand it to the cluster and firmware owners.

## Troubleshooting steps

### 1. Confirm Secure Boot is enabled

Run this on every affected node:

```powershell
$secureBootEnabled = Confirm-SecureBootUEFI
if ($secureBootEnabled -ne $true) {
    throw 'Secure Boot is not enabled. Resolve the separate Secure Boot enablement requirement before troubleshooting the 2023 certificate rollout.'
}
$secureBootEnabled
```

`True` confirms the prerequisite. `False`, or an error that the platform does not support the cmdlet, belongs to the separate Secure Boot enablement path rather than this certificate-rollout TSG.

### 2. Run the authoritative completion check

```powershell
$command = Get-Command Test-AzSSecureBootUpdateCompleted -ErrorAction SilentlyContinue
if (-not $command) {
    throw 'Test-AzSSecureBootUpdateCompleted is not installed on this node. Preserve the Environment Checker result and contact Microsoft Support for the release-appropriate verification path.'
}

Test-AzSSecureBootUpdateCompleted -Verbose
```

Interpret the output as follows:

- `True`: all required Secure Boot update components are complete on this node.
- `False`: at least one component is incomplete. Read the verbose component list.
- A command error: preserve the error and the Environment Checker result, then escalate rather than treating the node as complete.

The verbose output identifies:

- `WindowsUEFICAInstalled`
- `MicrosoftUEFICAInstalled`
- `MicrosoftOptionROMUEFICAInstalled`
- `KEKInstalled`
- `BootEFISignerUpdated`

Check every cluster node:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    $command = Get-Command Test-AzSSecureBootUpdateCompleted -ErrorAction SilentlyContinue
    if (-not $command) {
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            Completed    = $null
            Error        = 'Cmdlet not installed'
        }
        return
    }

    try {
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            Completed    = [bool](Test-AzSSecureBootUpdateCompleted)
            Error        = $null
        }
    }
    catch {
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            Completed    = $null
            Error        = $_.Exception.Message
        }
    }
} | Sort-Object PSComputerName | Format-Table -AutoSize
```

Do not infer cluster-wide completion from one node.

### 3. Read the Environment Checker Detail

The latest cluster-wide health result is under the update health-check share. Read `AdditionalData.Detail`, not the top-level numeric status:

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
}

$latest = if ($base) {
    Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

if (-not $latest) {
    Write-Warning 'No cluster-wide HealthCheckResult file was found. Use the product completion cmdlet and Event ID 17205, then run a fresh system health precheck when appropriate.'
}
else {
    Get-Content $latest.FullName -Raw |
        ConvertFrom-Json |
        Where-Object Name -eq 'AzStackHci_Security_SecureBootStatus' |
        Select-Object Name,
            @{n='Status';e={$_.AdditionalData.Status}},
            @{n='Detail';e={$_.AdditionalData.Detail}},
            TargetResourceName,
            Timestamp
}
```

The cluster-wide file can be stale until a full health check runs. Compare its timestamp with the on-node completion check before drawing a conclusion.

### 4. Understand the Detail states

A complete result has this shape:

```text
Boot Manager Update Status: BootManagerUpdatedAndInUse. Windows UEFI CA cert Installed: True. Microsoft UEFI CA cert Installed: True. Microsoft Option ROM UEFI CA cert Installed: True. KEK cert Installed: True.
```

Common incomplete states:

```text
Boot Manager Update Status: BootManagerUpdatedAndInUse. Windows UEFI CA cert Installed: True. Microsoft UEFI CA cert Installed: False. Microsoft Option ROM UEFI CA cert Installed: False. KEK cert Installed: True.
```

```text
Boot Manager Update Status: BootManagerUpdatedButUnableToDetermineInUseStatus. Windows UEFI CA cert Installed: True. Microsoft UEFI CA cert Installed: True. Microsoft Option ROM UEFI CA cert Installed: True. KEK cert Installed: True.
```

```text
An error occurred while checking Secure Boot status: Access denied while querying UEFI variables
```

| Signal | Meaning | Next path |
| --- | --- | --- |
| Any certificate is `False` | The certificate rollout is incomplete | Check the Solution Update history, OEM BIOS minimum, and reboot state |
| Any certificate is `Unknown` | The validator could not establish the firmware state | Preserve the read error and escalate if permissions do not explain it |
| `BootManagerNotUpdated` | The updated boot manager is not present | Apply the supported Solution Update path |
| `BootManagerUpdatedButUnableToDetermineInUseStatus` | The updated boot manager exists, but the validator cannot confirm that the node booted with it | Check the reboot-pending case and recheck after the approved reboot |
| `BootManagerUpdatedAndInUse` with all certificates `True` | Complete | Verify every node, then refresh the system health result |

### 5. Determine why the rollout is incomplete

#### Case 1: BIOS or UEFI firmware is below the OEM minimum

Collect the model and BIOS version:

```powershell
Get-CimInstance Win32_ComputerSystem |
    Select-Object Manufacturer, Model

Get-CimInstance Win32_BIOS |
    Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate
```

Compare the exact model with the OEM guidance linked in the Related section. Known Dell examples from the Azure Local Secure Boot guidance include:

| Dell model | Minimum BIOS version |
| --- | --- |
| AX-640 | 2.21.2 |
| AX-6515 | 2.14.1 |
| AX-740 | 2.21.2 |
| C6420 | 2.21.0 |
| R440 | 2.21.1 |
| R640 | 2.21.2 |
| R740 | 2.21.2 |
| R940 | 2.21.2 |
| XC740xd | 2.21.2 |

This table is not a universal compatibility matrix. For Dell models not listed, and for HPE, Lenovo, DataON, Hitachi, or other systems, use the current OEM Secure Boot page and the qualified Azure Local solution guidance.

If the BIOS is below the required version, use a separate firmware maintenance step. Do not combine an ad hoc firmware change with manual Secure Boot servicing.

#### Case 2: Another reboot is pending

```powershell
$servicingPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing'
$status = Get-ItemProperty -Path $servicingPath -Name UEFICA2023Status -ErrorAction SilentlyContinue
$errorCode = Get-ItemProperty -Path $servicingPath -Name UEFICA2023Error -ErrorAction SilentlyContinue
$restartRequired = $null -ne (
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' -ErrorAction SilentlyContinue |
        Where-Object Name -match 'RestartRequired'
)

[pscustomobject]@{
    UEFICA2023Status = $status.UEFICA2023Status
    UEFICA2023Error  = $errorCode.UEFICA2023Error
    RestartRequired  = $restartRequired
    RebootPending    = $restartRequired -or (
        $status.UEFICA2023Status -eq 'InProgress' -and
        $errorCode.UEFICA2023Error -eq 2147942750
    )
}
```

If `RebootPending` is `True`, schedule a controlled reboot of the drained node. If it is `False`, do not assume the rollout is complete. Re-run `Test-AzSSecureBootUpdateCompleted -Verbose`.

#### Case 3: The known BIOS and reboot cases do not apply

Collect the evidence in the escalation section and contact Microsoft Support. Do not repeatedly reboot or make manual Secure Boot registry changes without a supported diagnosis.

### 6. Apply the supported remediation

#### Path A: Platform-managed Solution Update

Apply the current Azure Local Solution Update. The platform orchestration installs the Secure Boot update node by node and retries incomplete nodes in supported update cycles.

If the Solution Update itself cannot download, stage, or reach required endpoints, investigate that as an update-connectivity problem. See [Troubleshooting external connectivity failures in Environment Checker](./Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md) rather than attributing the network failure to Secure Boot.

After the update, run the completion check on every node. A newly deployed 2603 or later cluster, or a node added on that release, may not receive the certificate rollout during deployment or Add Node itself; the rollout can occur during a later Solution Update.

#### Path B: Controlled reboot for a deployed member

Before a manual reboot, prove the cluster can lose the target node:

```powershell
$node = '<node-name>'
if ($node -eq '<node-name>') {
    throw 'Replace <node-name> with the exact cluster node name.'
}

$nodes = @(Get-ClusterNode -ErrorAction Stop)
$target = @($nodes | Where-Object Name -eq $node)
if ($target.Count -ne 1 -or $target[0].State -ne 'Up') {
    throw "Expected one Up target node named $node."
}

$otherNodes = @($nodes | Where-Object Name -ne $node)
if (@($otherNodes | Where-Object State -ne 'Up').Count -gt 0) {
    throw 'Every other cluster node must be Up before the drain.'
}

$quorum = Get-ClusterQuorum -ErrorAction Stop
$witnessVote = 0
if ($quorum.QuorumResource) {
    $witnessName = if ($quorum.QuorumResource.Name) {
        $quorum.QuorumResource.Name
    }
    else {
        [string]$quorum.QuorumResource
    }
    $witness = Get-ClusterResource -Name $witnessName -ErrorAction Stop
    if ($witness.State -ne 'Online') {
        throw "The quorum witness $witnessName is not Online."
    }
    $witnessVote = 1
}

$votingNodes = @(
    $nodes |
        Where-Object {
            $_.State -eq 'Up' -and
            $_.NodeWeight -gt 0 -and
            ($null -eq $_.DynamicWeight -or $_.DynamicWeight -gt 0)
        }
)
$remainingVotes = @($votingNodes | Where-Object Name -ne $node).Count + $witnessVote
$currentVotes = $votingNodes.Count + $witnessVote
$requiredVotes = [math]::Floor($currentVotes / 2) + 1
if ($remainingVotes -lt $requiredVotes) {
    throw "Pausing $node would leave $remainingVotes vote(s); $requiredVotes are required for quorum."
}

$virtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
if ($virtualDisks.Count -eq 0) {
    throw 'No virtual disks were returned. Do not drain the node until storage health can be established.'
}

$unhealthyVirtualDisks = @(
    $virtualDisks |
        Where-Object {
            $states = @($_.OperationalStatus)
            $_.HealthStatus -ne 'Healthy' -or
            $states.Count -eq 0 -or
            @($states | Where-Object { [string]$_ -ne 'OK' }).Count -gt 0
        }
)
if ($unhealthyVirtualDisks.Count -gt 0) {
    $unhealthyVirtualDisks |
        Select-Object FriendlyName, HealthStatus, OperationalStatus |
        Format-Table -AutoSize
    throw 'One or more virtual disks are not Healthy/OK. Do not drain the node.'
}

if (@(Get-StorageJob).Count -gt 0) {
    throw 'Wait for all storage jobs to finish before draining the node.'
}

[pscustomobject]@{
    ReadyToDrain = $true
    TargetNode = $node
    RemainingVotes = $remainingVotes
    RequiredVotes = $requiredVotes
    VirtualDiskCount = $virtualDisks.Count
}
```

Before the drain, retrieve the BitLocker recovery password from the approved escrow location and confirm it matches the node:

```powershell
Get-BitLockerVolume |
    Select-Object MountPoint, ProtectionStatus, VolumeStatus

manage-bde.exe -protectors -get C: -Type RecoveryPassword
```

Do not proceed until the recovery password is retrievable.

Drain the node:

```powershell
Suspend-ClusterNode -Name $node -Drain -Wait

Get-ClusterNode -Name $node |
    Select-Object Name, State

Get-ClusterGroup |
    Where-Object {
        [string]$_.OwnerNode -eq $node -and
        $_.GroupType -eq 'VirtualMachine'
    } |
    Select-Object Name, OwnerNode, State
```

Proceed only when the node is paused and the virtual-machine query returns no rows. Reboot through the approved maintenance workflow. Resume the node afterward:

```powershell
Resume-ClusterNode -Name $node

Get-StorageJob
Get-VirtualDisk |
    Select-Object FriendlyName, HealthStatus, OperationalStatus
```

Wait until storage jobs are empty and every virtual disk is `Healthy` with every operational status exactly `OK` before servicing another node.

#### Path C: OEM BIOS or UEFI update

Use the OEM procedure for the exact qualified server model. Treat BIOS or UEFI work as a separate maintenance action from Secure Boot certificate servicing.

The canonical Azure Local Secure Boot guidance includes additional preparation for a manual BIOS update after the Secure Boot rollout has started. Follow that guide exactly, including its scheduled-task handling, node suspension, BitLocker suspension, reboot order, and final resume steps. Do not copy isolated commands from that workflow without its prerequisites.

## Where this result appears

### PowerShell on an Azure Local node

Shown by `Test-AzSSecureBootUpdateCompleted -Verbose`, the servicing registry values, and the Environment Checker result Detail.

### Azure portal

Shown on the Azure Local cluster **Updates** page after a pre-update system health check. The portal view can remain stale until the next full health check.

### Windows event logs

Shown in the `AzStackHciEnvironmentChecker` log as Event ID 17205:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' `
    -MaxEvents 2000 |
    ForEach-Object {
        try {
            $payload = $_.Message | ConvertFrom-Json
            if ($payload.Name -eq 'AzStackHci_Security_SecureBootStatus') {
                [pscustomobject]@{
                    TimeCreated = $_.TimeCreated
                    Status = $payload.AdditionalData.Status
                    Severity = $payload.Severity
                    Detail = $payload.AdditionalData.Detail
                }
            }
        }
        catch {
        }
    } |
    Select-Object -First 1
```

Check `TimeCreated`. A historical 17205 result is evidence of the prior health check, not current node health.

### Component and tool log files

The Environment Checker writes under the profile of the account that ran it:

```powershell
$logRoot = Join-Path $env:USERPROFILE '.AzStackHci'
Get-ChildItem -LiteralPath $logRoot -File -ErrorAction SilentlyContinue |
    Where-Object Name -in @(
        'AzStackHciEnvironmentChecker.log',
        'AzStackHciEnvironmentReport.json',
        'AzStackHciEnvironmentReport.xml'
    ) |
    Select-Object Name, FullName, LastWriteTime, Length
```

The product completion cmdlet writes a timestamped log under:

```powershell
Get-ChildItem 'C:\CloudContent\MASLogs\ASSecurityOSConfigLogs' `
    -Filter 'ASOSConfig_ASTestSecureBootUpdateCompleted_*.log' `
    -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5 FullName, LastWriteTime, Length
```

### Where this result is not evident

- **Cluster logs from `Get-ClusterLog`:** the certificate posture does not appear there as an authoritative failover-cluster event.
- **Failover Cluster Manager:** the result does not appear as a failed role, resource, or node property.
- **Windows Admin Center on a standalone host:** the specific Environment Checker result does not appear there.
- **Windows Admin Center in the Azure portal:** the specific result does not appear there. Use the Azure Local **Updates** page instead.

## Verify the fix

On every node:

```powershell
Test-AzSSecureBootUpdateCompleted -Verbose
```

The command must return `True`, and all five verbose component values must be complete.

Then refresh the cluster-wide health result:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment |
    Format-List HealthState, HealthCheckDate
```

Confirm:

1. `HealthState` is `Success`.
2. `HealthCheckDate` is current.
3. The refreshed `AzStackHci_Security_SecureBootStatus` Detail reports `BootManagerUpdatedAndInUse`.
4. All four certificate fields read `Installed: True`.
5. Every cluster node independently returns `True` from `Test-AzSSecureBootUpdateCompleted`.

Do not close the issue from `UEFICA2023Status=Updated` alone.

## Evidence to collect and when to escalate

Collect only the bounded evidence needed for this check:

```powershell
$out = 'C:\SecureBootStatus-Evidence'
New-Item -Path $out -ItemType Directory -Force | Out-Null

Get-ComputerInfo OsName, OsVersion, OsBuildNumber |
    Out-File (Join-Path $out 'os.txt')

Get-CimInstance Win32_ComputerSystem |
    Select-Object Manufacturer, Model |
    ConvertTo-Json |
    Out-File (Join-Path $out 'system.json')

Get-CimInstance Win32_BIOS |
    Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate |
    ConvertTo-Json |
    Out-File (Join-Path $out 'bios.json')

Test-AzSSecureBootUpdateCompleted -Verbose 4>&1 |
    Out-File (Join-Path $out 'completion.txt')

Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' |
    Select-Object UEFICA2023Status, UEFICA2023Error |
    ConvertTo-Json |
    Out-File (Join-Path $out 'servicing.json')
```

Also collect:

- The latest matching Event ID 17205 JSON and its timestamp.
- The latest `ASOSConfig_ASTestSecureBootUpdateCompleted_*.log`.
- The Environment Checker log and report files.
- The Solution Update version and update history.
- The exact OEM model, current BIOS version, and the OEM minimum-version source used.
- BitLocker status and whether a recovery prompt occurred. Do not include the recovery password.

Escalate immediately if a node does not boot, enters a boot loop, or the cluster loses service after a Secure Boot or firmware action. Otherwise, contact Microsoft Support when:

- The product completion cmdlet remains `False` after the supported update and required controlled reboots.
- The BIOS meets the current OEM minimum and the known reboot-pending case does not apply.
- UEFI variables cannot be read.
- Secure Boot servicing logs show repeated DB, KEK, boot-manager, or firmware-apply failures.
- A firmware update must proceed while Secure Boot servicing is still pending.

## Glossary

| Term | Meaning in this guide |
| --- | --- |
| BIOS / UEFI firmware | The server firmware that initializes hardware and enforces Secure Boot policy before Windows starts. |
| BitLocker recovery password | The 48-digit key used to unlock an encrypted volume when measured-boot values change unexpectedly. |
| Boot manager signer | The certificate authority that signed `bootmgfw.efi`. The updated file is signed by Windows UEFI CA 2023. |
| `db` | The Secure Boot allowed-signature database. Three of the 2023 certificates checked here are stored in `db`. |
| DBX | The Secure Boot revoked-signature database. Revocation changes can be irreversible while Secure Boot remains enabled. |
| KEK | Key Exchange Key database. It authorizes updates to Secure Boot signature databases. |
| Measured boot | TPM measurements of the boot chain. Firmware and Secure Boot changes can alter these measurements and trigger BitLocker recovery. |
| UEFI CA | A certificate authority trusted by UEFI Secure Boot to validate signed boot components. |
| Solution Update | The Azure Local platform update workflow that orchestrates supported node-by-node servicing. |

::: audience-css

# Source Articles

- [Troubleshooting guide: Azure Local UEFI 2023 Secure Boot Update](../Security/TSG-Azure-Local-UEFI-2023-Secure-Boot-Update.md)
- [Manage Secure Boot updates](https://learn.microsoft.com/azure/azure-local/manage/manage-secure-boot-updates)
- [OEM pages for Secure Boot](https://support.microsoft.com/topic/original-equipment-manufacturer-oem-pages-for-secure-boot-9ecc3ba4-fb50-4bd3-9e9b-f16b35b8fb68)
- [Frequently asked questions about the Secure Boot update process](https://support.microsoft.com/topic/frequently-asked-questions-about-the-secure-boot-update-process-b34bf675-b03a-4d34-b689-98ec117c7818)
- [Get support for Azure Local](https://learn.microsoft.com/azure/azure-local/manage/get-support)

:::
