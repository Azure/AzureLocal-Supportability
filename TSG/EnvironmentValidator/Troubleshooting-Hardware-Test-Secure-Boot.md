---
ArticleType: "TSG"
Article_ID: "20260917160017"
Title: "AzStackHci_Hardware_Test_Secure_Boot"
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
  Source: "ADO Work Item"
  ID: 38583976
Tags: ["Validation", "Firmware", "BIOS", "BitLocker", "Cloud Deployment"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory publication metadata, audience scoping, and current article layout without changing technical guidance. |

:::

# AzStackHci_Hardware_Test_Secure_Boot

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_Secure_Boot</strong> (aggregated as <code>AzStackHci_Hardware_SecureBoot</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Secure Boot (the aggregated name shown in the portal). The per-machine result JSON and event log carry the verbose form <code>Test Secure Boot &lt;machine&gt;</code>; both refer to this same check.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-SecureBoot</code> (run with <code>Invoke-AzStackHciHardwareValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Hardware (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: this validator blocks deployment until UEFI Secure Boot is enabled on the machine.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>Each machine must have <strong>UEFI Secure Boot enabled</strong> in firmware before deployment.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Deployment and Add Node (pre-deployment validation).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Overview

This validator checks that **UEFI Secure Boot is enabled** on each Azure Local machine.
Secure Boot is part of the Azure Local hardware security baseline: it ensures the
machine only loads boot software that is signed by a trusted authority, and it is a
prerequisite for the platform's secured-core and attestation features. The check fails
when Secure Boot is disabled, or when the machine is not in a state where Secure Boot
can be evaluated (for example a machine running in legacy BIOS / CSM mode rather than
UEFI).

It runs by calling `Confirm-SecureBootUEFI` on each machine. A machine with Secure Boot
enabled returns `True` and the check is a **SUCCESS**; a machine with Secure Boot
disabled returns `False` and the check is a **FAILURE**. On a machine that is not in
UEFI mode at all, `Confirm-SecureBootUEFI` reports that the platform does not support
the cmdlet, which is treated as the machine not meeting the Secure Boot requirement.

Secure Boot verifies the signature of the boot manager, boot drivers, and other
pre-operating-system components before Windows trusts them. This reduces the risk that
untrusted boot code can run below the operating system and hide from normal Windows
security controls.

While this check is failing, deployment is blocked at the Hardware validation stage and
the machine cannot proceed. This is a pre-deployment gate (it runs during Deployment and
Add Node validation), so the machine it flags is normally a **host being validated to
become a cluster node**, not a running cluster member. The fix is usually short: check for
BitLocker, enable Secure Boot in firmware, and re-validate. Two cautions apply, though: a
host being vetted may have been **recycled from another project and could already have
BitLocker enabled** (a Secure Boot change trips it into recovery, so check first), and the
cluster-drain precaution is only needed if the machine is already a live, deployed member.

### Customer impact and expected time

| Situation | Customer impact | Typical working time |
| --- | --- | --- |
| Pre-deployment or Add Node host | No production workload impact. The host remains blocked from deployment until validation passes. | About 15 to 30 minutes when BMC access and the BitLocker recovery key are ready. Vendor firmware boot time can extend this. |
| Existing deployed cluster member | VMs are live-migrated away and the node is unavailable during its firmware reboot. Work one node at a time. | Plan 30 to 60 minutes per node, plus any storage resynchronization time before moving to the next node. |

These are planning estimates, not service-level guarantees. Slow firmware initialization,
remote-console access, live-migration duration, and storage repair can increase the window.

## Where this failure appears

You can see this failure in two places, the Azure portal and the machine itself. Both
show the same underlying result.

### In the Azure portal

This check runs during the deployment validation step. When you deploy Azure Local from
the portal (or with a deployment template), the **Validation** phase runs the
environment checks and lists any that fail:

1. Open the Azure Local deployment for your cluster and go to its **Validation**
   results (the deployment surfaces these before it proceeds to apply).
2. In the list of checks, this one appears under its display name, **Secure Boot**, with
   a **Critical** severity.
3. Select the failing check to see the per-machine detail, which names the machine whose
   Secure Boot is off.

### On the machine

Two on-box sources carry the result.

**Run the single validator (fastest).** The Environment Checker module ships on every
Azure Local machine, so you can run this one Hardware check directly and read the result
in a few seconds. Use `-Include Test-SecureBoot` to run only this check, so you do not
have to run the full Hardware validation suite:

```powershell
$validator = Get-Command Invoke-AzStackHciHardwareValidation -ErrorAction Stop
if (-not $validator.Parameters.ContainsKey('Include')) {
    throw "This installed Environment Checker does not expose -Include. Run the full Hardware validation and filter its returned results instead."
}

$r = Invoke-AzStackHciHardwareValidation -Include Test-SecureBoot -PassThru
if (@($r).Count -eq 0) {
    throw 'The targeted validator returned no Secure Boot result. Preserve the module version and full output, then escalate.'
}
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

The targeted `-Include` path is confirmed by the command metadata on the installed
module, rather than by assuming a release-wide minimum version. If the guard reports
that `-Include` is unavailable, run the full validator and filter the returned results:

```powershell
$r = Invoke-AzStackHciHardwareValidation -PassThru |
    Where-Object { $_.Name -match '^AzStackHci_Hardware_(Test_Secure_Boot|SecureBoot)$' }
if (@($r).Count -eq 0) {
    throw 'The full validator returned no canonical or verified legacy Secure Boot result. Preserve the module version and full output, then escalate.'
}
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

You can also read the underlying value directly:

```powershell
# True = Secure Boot enabled; False = supported but disabled.
# An error ("Cmdlet not supported on this platform") means the machine is not in UEFI mode.
Confirm-SecureBootUEFI
```

A machine with Secure Boot disabled returns `Status` of `FAILURE` and a detail line of
the form:

```
SecureBoot is 'False' on AzL-Node-01. Expected 'True'. Ensure SecureBoot is supported and enabled on AzL-Node-01.
```

**Event log (per machine).** The Environment Checker writes every check result to the
**AzStackHciEnvironmentChecker** event log, located at
`C:\Windows\System32\winevt\Logs\AzStackHciEnvironmentChecker.evtx`. Each result is the
JSON body of an **Event ID 17205** entry. To read this check's most recent result on a
machine:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    Where-Object { $_.Message -match 'AzStackHci_Hardware_(Test_Secure_Boot|SecureBoot)' } |
    Select-Object -First 1 -ExpandProperty Message
```

In both sources the result for this check looks like this:

```json
{
  "Name": "AzStackHci_Hardware_Test_Secure_Boot",
  "DisplayName": "Test Secure Boot AzL-Node-01",
  "Title": "Test Secure Boot",
  "Severity": "Critical",
  "Status": "FAILURE",
  "Description": "Checking Secure Boot is enabled",
  "TargetResourceName": "Machine: AzL-Node-01, SecureBoot",
  "Remediation": "https://aka.ms/hci-envch",
  "AdditionalData": {
    "Detail": "SecureBoot is 'False' on AzL-Node-01. Expected 'True'. Ensure SecureBoot is supported and enabled on AzL-Node-01.",
    "Status": "FAILURE"
  }
}
```

> **A note on names across surfaces.** The portal shows the aggregated display name
> **Secure Boot**, while the per-machine result JSON and the event log carry the verbose form
> **Test Secure Boot `<machine>`**. The underlying `Name`,
> `AzStackHci_Hardware_Test_Secure_Boot`, is the same on both, so if you are matching strings
> between the portal and the on-box output, expect the two forms.

### Check several candidate hosts

For a rack or Add Node wave, run the read-only posture check across the exact host list
before scheduling firmware work. Use host names, not unreviewed wildcard discovery:

```powershell
$candidateHosts = @(
    'AzL-Node-01',
    'AzL-Node-02'
)

Invoke-Command -ComputerName $candidateHosts -ScriptBlock {
    $value = $null
    $errorText = $null
    try {
        $value = Confirm-SecureBootUEFI -ErrorAction Stop
    }
    catch {
        $errorText = $_.Exception.Message
    }

    [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        SecureBoot   = $value
        Error        = $errorText
    }
} | Format-Table -AutoSize
```

`SecureBoot = True` is ready. `False` requires the firmware change in this guide.
An error requires the UEFI and GPT checks below before anyone changes boot mode.

### Where this result is not evident

- **Cluster logs from `Get-ClusterLog`:** this pre-deployment validator result does
  not appear as an authoritative failover-cluster event. Use the Environment Checker
  result and Event ID 17205 instead.
- **Failover Cluster Manager:** this failure does not appear as a failed clustered
  role, resource, or node because the normal target is not yet a cluster member.
- **Windows Admin Center on a standalone host:** the specific Environment Checker
  result does not appear there. Run the on-box PowerShell check in this article.
- **Windows Admin Center in the Azure portal:** the specific result does not appear
  there. Use the Azure Local deployment Validation results instead.

### Environment Checker files on disk

On the machine where the validator ran, the Environment Checker also writes its own
log and reports under `%USERPROFILE%\.AzStackHci`:

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

## Before you start: who does this, and confirm it is safe

- **Who owns this.** Enabling Secure Boot is a firmware change, so it is done by the **server
  or hardware administrator** with firmware / BMC (iDRAC / iLO / XClarity) access. The
  **Windows administrator** confirms and suspends BitLocker; the **network team** can provide
  BMC access but does not own this change. The firmware operator needs the exact BMC address,
  working HTTPS reachability to its management interface, permission to open the remote console,
  and valid credentials. Virtual-media access is not required for this procedure. If you are
  first-line or temporary staff, do not change firmware without the machine's owner.
- **Confirm all of these before you reboot into firmware** (skipping any one is how machines
  get stranded):
  - The **BitLocker recovery key is escrowed** and you can retrieve it (see step 1). A Secure
    Boot change is measured into TPM PCR 7 and can trip an encrypted volume into the recovery
    screen.
  - The machine boots in **UEFI mode with a GPT system disk**, not legacy BIOS / MBR. Switching
    boot mode alone will not boot an OS that was installed in legacy/MBR mode.

    ```powershell
    # A GPT boot disk means the OS was installed in UEFI mode.
    Get-Disk | Where-Object IsBoot | Select-Object Number, PartitionStyle
    # If Confirm-SecureBootUEFI errors with "Cmdlet not supported on this platform",
    # the machine is in legacy BIOS / CSM mode, not UEFI.
    # Cross-check the boot mode from Windows: a winload.efi boot path means UEFI,
    # winload.exe means legacy BIOS. (msinfo32 also reports "BIOS Mode: UEFI" or "Legacy".)
    bcdedit /enum '{current}' | Select-String 'path'
    ```

  - If this machine is **already a deployed cluster member** (encrypted or not), the firmware
    reboot takes a live node down, so drain it first (see
    [Track B: existing deployed cluster member](#track-b-existing-deployed-cluster-member)).
    One node at a time.

## How to fix it

Secure Boot is a firmware (UEFI/BIOS) setting, so the change is made in the machine's
firmware setup, not from Windows.

### Track A: pre-deployment or Add Node host

This is the normal path. There is no cluster drain because the machine is not yet serving
production workloads:

1. Check the recovery protector and suspend BitLocker if protected.
2. Enable Secure Boot and the standard Microsoft Secure Boot key configuration in firmware.
3. Boot Windows and confirm `Confirm-SecureBootUEFI` returns `True`.
4. Resume any BitLocker volumes you suspended, then re-run the validator.

### 1. Check for BitLocker, and suspend it if present

Do this even on a fresh pre-deployment host. A host you are vetting may have been **recycled
from a previous project with BitLocker already enabled**, and changing Secure Boot alters the
machine's measured-boot state (it is measured into TPM PCR 7). If a protected volume is left
armed, **the next boot after the change stops at the BitLocker recovery screen** and asks for
the 48-digit recovery password, which can strand the machine.

```powershell
# Are any volumes protected? (On a truly clean, never-encrypted host this is empty.)
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, VolumeStatus
```

If every volume reports `ProtectionStatus = Off`, there is nothing to suspend; go to step 2.
If any volume is protected, first list its recovery-password protector:

```powershell
manage-bde.exe -protectors -get C: -Type RecoveryPassword
```

Repeat the command for each protected data volume. The command proves that a recovery
password protector exists locally, but it does not prove the password is recoverable from
your organization's escrow system. Retrieve the matching key from the approved location
before proceeding, such as Microsoft Entra ID, Active Directory Domain Services, your
management service, or the customer's documented key vault.

Only after retrieval is confirmed, suspend BitLocker with `-RebootCount 0` so the
suspend holds across the firmware change and reboot until you explicitly resume it:

> [LOW RISK] Suspending protection does not decrypt the volume, but it temporarily
> stops BitLocker from enforcing the TPM measurement until protection is resumed.
> Do not continue unless the recovery password is retrievable and the change owner
> accepts this temporary reduction in protection.

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
# Repeat for any data volume that reports ProtectionStatus = On, for example:
# Suspend-BitLocker -MountPoint "D:" -RebootCount 0
```

### 2. Enable Secure Boot in firmware (UEFI/BIOS)

> If this machine is already a deployed, encrypted cluster member, do **not** reboot it into
> firmware yet. Follow [Track B: existing deployed cluster member](#track-b-existing-deployed-cluster-member)
> first so you take the node down safely.

1. Reboot the machine and enter firmware setup (the key varies by vendor, commonly
   `F2`, `F10`, `Del`, or via the BMC / iDRAC / iLO / XClarity remote console).
2. Make sure the machine is in **UEFI boot mode**, not legacy BIOS / CSM. Secure Boot
   only applies in UEFI mode, and the OS disk must be GPT. If the machine was installed
   in legacy/MBR mode, switching boot mode alone will not boot the existing OS; the
   machine must be installed in UEFI mode.
3. Enable **Secure Boot**. If prompted, make sure the standard Microsoft Secure Boot keys
   (PK / KEK / db) are provisioned (often shown as "Install default Secure Boot keys" or
   "Standard" key configuration).
4. Save and exit, and let the machine boot back into the OS.

The expected firmware end state is:

- Boot mode is `UEFI`, with CSM or legacy boot disabled.
- Secure Boot is `Enabled`.
- Secure Boot mode is the vendor's standard or deployed mode, not setup or audit mode.
- A platform key is enrolled and the standard Microsoft KEK and allowed-signature
  database are present.

Use the BMC remote console to re-enter firmware and confirm those values if the vendor
interface does not show a post-change configuration summary. The exact labels are
vendor-specific, so record a screenshot or exported firmware configuration when the
customer's change process requires evidence.

The exact menu names are vendor-specific; consult your hardware vendor's documentation
for the precise location of the Secure Boot and boot-mode settings. As a starting point,
Secure Boot and boot mode usually live here:

| Vendor (tool) | Where Secure Boot and boot mode usually live |
| --- | --- |
| Dell (iDRAC / BIOS Setup) | System BIOS > System Security > Secure Boot; boot mode under System BIOS > Boot Settings > Boot Mode |
| HPE (iLO / UEFI System Utilities) | System Configuration > BIOS/Platform Configuration (RBSU) > Server Security > Secure Boot; boot mode under Boot Options |
| Lenovo (XClarity / UEFI Setup) | UEFI Setup > Security > Secure Boot; boot mode under Boot Manager / Startup |

These paths vary by model and firmware version, so confirm them against your server's
current firmware documentation rather than treating them as exact.

### 3. Confirm Secure Boot is on

```powershell
Confirm-SecureBootUEFI
```

This should now return `True`.

### 4. Resume BitLocker (only if you suspended it in step 1)

```powershell
Resume-BitLocker -MountPoint "C:"
# And any data volume you suspended, for example:
# Resume-BitLocker -MountPoint "D:"
```

Resuming reseals the BitLocker key to the new (Secure Boot enabled) measurements, and the
machine boots normally from then on.

### Track B: existing deployed cluster member

Because this is a pre-deployment check, it does not normally fire on a machine that is
already a deployed cluster node. But if you are enabling Secure Boot on a machine that is
**already a live, encrypted cluster member** for any reason, add one precaution to the steps
above: the firmware reboot takes a running node down, so **drain it first** and do this
**one node at a time**.

This is a [MEDIUM RISK] change: draining live-migrates VMs off the node, and the node is
unavailable until you resume it.

```powershell
# Replace the placeholder with the exact node you will service.
$node = '<node-name>'
if ($node -eq '<node-name>') {
    throw 'Replace <node-name> with the exact cluster node name.'
}

# Confirm the cluster is healthy and has enough surviving votes.
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
    } else {
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
            $operationalStates = @($_.OperationalStatus)
            $_.HealthStatus -ne 'Healthy' -or
            $operationalStates.Count -eq 0 -or
            @($operationalStates | Where-Object { [string]$_ -ne 'OK' }).Count -gt 0
        }
)
if ($unhealthyVirtualDisks.Count -gt 0) {
    $unhealthyVirtualDisks |
        Select-Object FriendlyName, HealthStatus, OperationalStatus |
        Format-Table -AutoSize
    throw 'One or more virtual disks are not Healthy/OK. Do not drain the node.'
}
$virtualDisks | Select-Object FriendlyName, HealthStatus, OperationalStatus
if (@(Get-StorageJob).Count -gt 0) {
    throw 'Wait for all storage jobs to finish before draining the node.'
}

# Required precondition: every quorum, storage, and target-node check above passed.
# Only then pause and drain this node so its VMs live-migrate off.
Suspend-ClusterNode -Name $node -Drain -Wait
Get-ClusterNode -Name $node | Select-Object Name, State
Get-ClusterGroup |
    Where-Object {
        [string]$_.OwnerNode -eq $node -and
        $_.GroupType -eq 'VirtualMachine'
    } |
    Select-Object Name, OwnerNode, State
```

Proceed only when the node is `Paused` and the virtual-machine query returns no rows.
Then run steps 1 through 4 above. Finally bring the node back and let storage resync
before the next one:

```powershell
Resume-ClusterNode -Name $node
Get-StorageJob                                       # wait until empty
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus   # back to Healthy
```

Repeat for each remaining member, one node at a time, so the cluster always keeps quorum and
storage resiliency.

## Verify the fix

Re-run the single validator:

```powershell
$validator = Get-Command Invoke-AzStackHciHardwareValidation -ErrorAction Stop
if (-not $validator.Parameters.ContainsKey('Include')) {
    throw "This installed Environment Checker does not expose -Include. Run the full Hardware validation and filter its returned results instead."
}

$r = Invoke-AzStackHciHardwareValidation -Include Test-SecureBoot -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

A machine with Secure Boot enabled returns `Status` of `SUCCESS`. Once every machine you
are deploying reports success, re-run the deployment validation; the **Secure Boot**
check should now pass and deployment can proceed.

## When to escalate

Open a support case if any of the following are true:

- `Confirm-SecureBootUEFI` returns `True`, but the **Secure Boot** check still fails
  during deployment validation.
- The firmware has no Secure Boot setting, or Secure Boot cannot be enabled because the
  platform does not support it. Secure Boot is an Azure Local hardware requirement, so
  confirm the machine is covered by the
  [Azure Local system requirements](https://learn.microsoft.com/azure/azure-local/concepts/system-requirements-23h2)
  and its OEM solution compatibility matrix.
- `Confirm-SecureBootUEFI` reports that the cmdlet is not supported on the platform even
  after you have set the machine to UEFI boot mode.
- The machine stops at the BitLocker recovery screen after the change and the recovery
  key is not available.

## Glossary

| Term | Meaning in this guide |
| --- | --- |
| BMC | The server's out-of-band management controller, such as Dell iDRAC, HPE iLO, or Lenovo XClarity Controller. |
| CSM | Compatibility Support Module. It provides legacy BIOS-style boot and must be disabled for Secure Boot. |
| GPT / MBR | GUID Partition Table is the disk layout used for UEFI boot. Master Boot Record is the legacy layout and cannot be fixed by only enabling UEFI. |
| Measured boot | The process that records boot-component measurements in the TPM so disk encryption and attestation can detect changes. |
| TPM PCR 7 | The TPM register that includes Secure Boot policy measurements. Changing Secure Boot can change PCR 7 and trigger BitLocker recovery. |
| PK | Platform Key. It establishes control of the Secure Boot policy. |
| KEK | Key Exchange Key database. It authorizes updates to the allowed and revoked signature databases. |
| db | The allowed-signature database used by Secure Boot. |

::: audience-css

# Source Articles

- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- [Azure Local security features and baseline](https://learn.microsoft.com/azure/azure-local/concepts/security-features)
- [Secure Boot (Windows hardware security)](https://learn.microsoft.com/windows-hardware/design/device-experiences/oem-secure-boot)
- [Suspend-BitLocker before firmware changes](https://learn.microsoft.com/powershell/module/bitlocker/suspend-bitlocker)
- [Suspend-ClusterNode (pause and drain a node)](https://learn.microsoft.com/powershell/module/failoverclusters/suspend-clusternode)
- [Resume-ClusterNode](https://learn.microsoft.com/powershell/module/failoverclusters/resume-clusternode)

:::
