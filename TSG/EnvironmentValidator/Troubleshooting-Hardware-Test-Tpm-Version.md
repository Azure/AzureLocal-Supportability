---
ArticleType: "TSG"
Article_ID: "20260917170004"
Title: "AzStackHci_Hardware_Test_Tpm_Version"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-18"
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
  ID: 38583985
Tags: ["Validation", "TPM", "Firmware", "BitLocker", "Cloud Deployment"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-18 | 2.1 | Expanded the BitLocker safety gate to cover every protected volume and require explicit external escrow confirmation before firmware changes. |
| 2026-09-17 | 2.0 | Added mandatory publication metadata, read-only validation evidence, explicit OEM constraints, all eight admin surfaces, and safer deployed-member gates. |

:::

# AzStackHci_Hardware_Test_Tpm_Version

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_Tpm_Version</strong> (aggregated as <code>AzStackHci_Hardware_TpmVersion</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>TPM Version (the aggregated name shown in the portal). The per-machine result JSON and event log carry the verbose form <code>Test TPM Version &lt;machine&gt;</code>; both refer to this same check.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-TpmVersion</code> (run with <code>Invoke-AzStackHciHardwareValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Hardware (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: this validator blocks deployment until the machine's TPM reports specification version 2.0.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>Each machine must have a <strong>TPM that reports specification version 2.0</strong> (TPM 2.0) before deployment.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Deployment and Add Node (pre-deployment readiness validation).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Overview

This validator checks that each Azure Local machine has a **Trusted Platform Module (TPM)
that reports specification version 2.0**. TPM 2.0 is part of the Azure Local hardware
security baseline: it is the hardware root of trust that backs measured boot, BitLocker
key protection, and the platform's attestation and secured-core features. The check fails
when a TPM is present but reports a specification version other than 2.0 (for example a
module in TPM 1.2 mode).

It runs by reading the `Win32_Tpm` instance from each machine
(`Get-CimInstance -Namespace root/cimv2/Security/MicrosoftTpm -ClassName Win32_Tpm`) and
comparing the **first segment of the reported `SpecVersion`** to `2.0`. A machine whose
TPM reports `2.0` is a **SUCCESS**; a machine whose TPM reports a different version (such
as `1.2`) is a **FAILURE**.

> **Important coverage note.** This check evaluates the TPM **version** only. If no TPM is
> present at all, `Win32_Tpm` returns nothing and this specific check does not raise a
> failure. The companion check `AzStackHci_Hardware_TpmProperties`
> (`Test-TpmProperties`) fails for a present-but-disabled TPM, but an absent TPM can pass
> both checks. Verify TPM presence directly with `Get-Tpm` or `Win32_Tpm`.

While this check is failing, deployment is blocked at the Hardware validation stage and
the machine cannot proceed. Unlike a software setting, the fix is a **firmware and
hardware** change that is specific to your server model, and on some platforms it is
limited, irreversible, or not possible at all (see [How to fix it](#how-to-fix-it)).

This check runs during **pre-deployment validation** (the Deployment and Add Node readiness
checks), so the machine it evaluates is normally a **host being validated to become a cluster
node**, not an existing cluster member. The remediation is usually short (set the TPM to 2.0
in firmware and re-validate), but two cautions apply: a host being vetted may have been
**recycled from another project and could already have BitLocker enabled**, and the
cluster-drain precaution is needed only if the machine is already a live, deployed member.

### Validation scope and fidelity

This article is validated to **T3 / L1** only. The diagnostic commands and the current
validator source were checked read-only on Azure Local solution build 10.2610 with
Environment Checker module 10.2610.0.2039. No TPM, BIOS, firmware, Secure Boot,
BitLocker, or deployed-member state was changed.

A safe end-to-end failure injection is not available:

- A Hyper-V virtual TPM reports TPM 2.0. Removing the virtual TPM tests the separate
  presence check, not the TPM 1.2 branch in `Test-TpmVersion`.
- A real failure requires a physical TPM that reports 1.2. Changing a shared hardware
  TPM can clear keys, consume a finite vendor switch allowance, be one-way, or be
  impossible on a fixed module.
- Therefore, a VM cannot faithfully reproduce the TPM 1.2 failure, and shared physical
  lab hardware must not be changed merely to manufacture it.

### Terms used in this article

| Term | Meaning |
| --- | --- |
| TPM | Trusted Platform Module, the hardware or firmware root of trust used to protect keys and measurements. |
| TPM 1.2 / TPM 2.0 | Different TCG specification generations. Azure Local requires TPM 2.0. |
| PTT / fTPM | Intel Platform Trust Technology or AMD firmware TPM, firmware implementations of a TPM. |
| Measured boot | Recording boot-component measurements in the TPM so later attestation can detect unexpected changes. |
| Key protector | A mechanism, such as a TPM-sealed BitLocker protector, that unlocks encrypted data only when its conditions are met. |

## Where this failure appears

You can see this failure in two places, the Azure portal and the machine itself. Both
show the same underlying result.

### In the Azure portal

This check runs during the deployment validation step. When you deploy Azure Local from
the portal (or with a deployment template), the **Validation** phase runs the
environment checks and lists any that fail:

1. Open the Azure Local deployment for your cluster and go to its **Validation**
   results (the deployment surfaces these before it proceeds to apply).
2. In the list of checks, this one appears under its display name, **TPM Version**, with
   a **Critical** severity.
3. Select the failing check to see the per-machine detail, which names the machine whose
   TPM is not reporting version 2.0.

### On the machine

Two on-box sources carry the result.

**Run the single validator (fastest).** The Environment Checker module ships on every
Azure Local machine, so you can run this one Hardware check directly and read the result
in a few seconds. Use `-Include Test-TpmVersion` to run only this check, so you do not
have to run the full Hardware validation suite:

```powershell
$r = Invoke-AzStackHciHardwareValidation -Include Test-TpmVersion -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

You can also read the underlying values directly:

```powershell
# Direct presence / enabled-state verification.
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled

# The version this check evaluates. It compares the FIRST comma-separated segment
# of SpecVersion to '2.0' (for example "2.0, 0, 1.59" passes; "1.2, ..." fails).
(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm).SpecVersion
```

A machine whose TPM reports a non-2.0 version returns `Status` of `FAILURE` and a detail
line of the form:

```
Machine: AzL-Node-01, Class: Tpm, Manufacturer ID: 1314145024 Tpm version is 1.2. Expected 2.0
```

**Event log (per machine).** The Environment Checker writes every check result to the
**AzStackHciEnvironmentChecker** event log, located at
`C:\Windows\System32\winevt\Logs\AzStackHciEnvironmentChecker.evtx`. Each result is the
JSON body of an **Event ID 17205** entry. To read this check's most recent result on a
machine:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    Where-Object { $_.Message -match 'AzStackHci_Hardware_Test_Tpm_Version' } |
    Select-Object -First 1 -ExpandProperty Message
```

In both sources the result for this check looks like this:

```json
{
  "Name": "AzStackHci_Hardware_Test_Tpm_Version",
  "Title": "Test TPM Version",
  "DisplayName": "Test TPM Version AzL-Node-01",
  "Severity": "Critical",
  "Status": "FAILURE",
  "Description": "Checking TPM for desired version (2.0)",
  "TargetResourceName": "Machine: AzL-Node-01, Class: Tpm, Manufacturer ID: 1314145024",
  "Remediation": "https://aka.ms/hci-envch",
  "AdditionalData": {
    "Source": "Version",
    "Resource": "1.2",
    "Detail": "Machine: AzL-Node-01, Class: Tpm, Manufacturer ID: 1314145024 Tpm version is 1.2. Expected 2.0",
    "Status": "FAILURE"
  }
}
```

> **A note on names across surfaces.** The portal shows the aggregated display name
> **TPM Version**, while the per-machine result JSON and the event log carry the verbose form
> **Test TPM Version `<machine>`**. The underlying `Name`,
> `AzStackHci_Hardware_Test_Tpm_Version`, is the same on both, so if you are matching strings
> between the portal and the on-box output, expect the two forms.

### Component log and report files

The Environment Checker also writes its own artifacts under
`%USERPROFILE%\.AzStackHci`. Check the account that ran the validation for:

- `AzStackHciEnvironmentChecker.log`
- `AzStackHciEnvironmentReport.json`
- `AzStackHciEnvironmentReport.xml`

Search the report files for `AzStackHci_Hardware_Test_Tpm_Version`. These files can
lag a targeted `-Include` run until the next full validation, so use the direct
validator result or Event ID 17205 when you need the freshest on-box result.

### Where this check is not evident

- **Cluster logs from `Get-ClusterLog`:** this pre-deployment validator result does not appear there because TPM version is not a failover-cluster event.
- **Failover Cluster Manager:** this failure does not appear as a failed clustered role, resource, or node.
- **Windows Admin Center on a standalone host:** the specific Environment Checker result does not appear there. Run the on-box PowerShell check in this article.
- **Windows Admin Center in the Azure portal:** the specific result does not appear there. Use the deployment Validation view or the on-box sources above.

## How to fix it

This check runs during **pre-deployment validation**, so the machine it flags is normally a
**host being prepared to become a cluster node**, not a running cluster member: there is
usually no cluster to keep in quorum. Do not assume the host is otherwise "clean", though.
A host being vetted may have been **recycled from another project and could already have
BitLocker enabled**, and a TPM change trips an encrypted volume into recovery, so check for
BitLocker before you touch firmware (step 2). The cluster-drain precaution only applies in
the uncommon case that the machine is already a live, deployed cluster member.

The TPM specification version is a firmware and hardware property, so the change is made in
the machine's firmware setup (or with the vendor's management tooling), not from Windows.
**Before you change anything, read these two warnings:**

- **Switching a TPM clears it.** Moving a TPM between specification versions (for example
  1.2 to 2.0) re-provisions the module and **erases the keys it holds**. Any key sealed to
  that TPM, including a **BitLocker** key protector, is invalidated by the change.
- **It is vendor-specific and may be limited or impossible.** Some platforms allow a
  reversible firmware switch (sometimes with a documented limit on how many times it can be
  done), some allow only a one-way move, and some ship a **fixed module that cannot be
  switched at all** and would have to be replaced. Consult your hardware vendor's TPM
  documentation for your exact model before proceeding. The switch limit (the toggle-count
  cap) is documented per model in the server's BIOS/firmware or TPM configuration guide,
  usually under a "TPM switching", "TPM provisioning", or "Change TPM mode" topic (for
  example in Dell iDRAC/BIOS, HPE iLO/UEFI, or Lenovo XClarity/UEFI documentation); some
  platforms also surface the remaining count in the BIOS TPM menu or the vendor's
  server-management tooling.

### Before you start: decide whether and how this can be fixed (and who does it)

The single most platform-variable fact is whether your exact server model can switch to TPM
2.0 at all, so settle that first. Read the current state (step 1 below, non-disruptive), confirm
BMC remote-console access, then consult your hardware vendor's TPM documentation for the exact
model. Use this table before scheduling downtime:

| What your hardware reports / the vendor says | What it means | Owner | Planning window | What to do |
| --- | --- | --- | --- | --- |
| TPM already reports **2.0** | This check should pass | Azure Local administrator | About 10 minutes for read-only confirmation | Re-confirm with step 1; if it still fails, see [When to escalate](#when-to-escalate) |
| TPM present, reports **1.2**, vendor says it is **reversibly switchable** | A firmware switch is possible, but it clears the TPM | Server / firmware admin; Windows admin confirms BitLocker | Use an approved maintenance window; firmware menus, reboot time, and post-check time vary by OEM | Confirm externally escrowed recovery evidence for every protected volume, confirm the remaining switch allowance if the OEM limits it, then follow the procedure |
| TPM **1.2**, switch is **one-way or limited** | You may be unable to return to the prior state, or each switch consumes a finite allowance | Server / firmware admin with written OEM confirmation | Treat as a controlled hardware change, not a routine reboot | Obtain the exact OEM procedure and approval before suspending BitLocker or taking the host down |
| TPM is a **fixed module** that cannot report 2.0 | There is no firmware setting that can satisfy the validator | Hardware vendor and procurement | Hardware replacement lead time is OEM and supply-chain dependent | Replace the module or server with an Azure Local qualified configuration |
| **No TPM present** | Not deployable; both this version check and `Test-TpmProperties` can be silent, so verify presence directly | Hardware vendor and procurement | Hardware replacement lead time is OEM and supply-chain dependent | Confirm the qualified configuration and add or replace the required hardware |

**Do not start any disruptive change until you have confirmed all three:** the switch is
supported on your exact model, **every protected BitLocker volume has an externally escrowed
recovery-password protector**, and (if this machine is already a deployed cluster member) it
has been **drained** first. A TPM switch clears the module and is sometimes irreversible, so
if any of the three is unknown, stop and confirm.

> **Setting expectations:** a firmware switch is usually quick, but a fixed-module or
> unsupported-hardware case means a hardware change or replacement with real lead time and
> possible procurement. Surface that to the customer early so the deployment schedule reflects it.

> **OEM constraint:** do not infer that a setting exists because another model from the same
> vendor exposes one. TPM behavior is model-specific. Some systems support a reversible switch
> with a finite counter, some support only a one-way TPM 2.0 transition, and some use a fixed
> TPM with no version selector. The OEM must identify the exact firmware menu or management-tool
> property, whether it is writable, whether the action is reversible, and any remaining switch
> count. If the documentation or tooling does not expose those facts, stop and open an OEM case.

### 1. Confirm the current TPM state

Establish what the machine actually reports before you touch firmware:

```powershell
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled
(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm).SpecVersion
```

- If `TpmPresent` is `False`, the machine has no usable TPM. Neither this version check
  nor `Test-TpmProperties` reliably fails for an absent TPM, so treat the direct result
  as a validator coverage gap. The machine is not deployable without a TPM. This is a
  hardware action, not a firmware setting.
- If a TPM is present but `SpecVersion` starts with something other than `2.0`, continue
  below.

For a rack or add-node batch, use the same read-only probe across the candidate hosts:

```powershell
function Get-AzureLocalTpmReadiness {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$ComputerName)

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $tpm = Get-Tpm
        $cim = Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            TpmPresent   = $tpm.TpmPresent
            TpmReady     = $tpm.TpmReady
            TpmEnabled   = $tpm.TpmEnabled
            SpecVersion  = if ($cim) { [string]$cim.SpecVersion } else { $null }
        }
    } | Sort-Object ComputerName
}
```

Call the function with the candidate host names from your deployment plan. A null
`SpecVersion` is not a TPM 2.0 pass; verify presence directly with `Get-Tpm` or
`Win32_Tpm`.

### 2. Check for BitLocker, and suspend it if present

Do this even on a fresh pre-deployment host. A host you are vetting may have been **recycled
from a previous project with BitLocker already enabled**, and a TPM version change clears the
module, which invalidates the TPM-sealed BitLocker key. If a protected volume is left armed,
**the next boot after the change stops at the BitLocker recovery screen** and asks for the
48-digit recovery password, which can strand the machine.

```powershell
# [READ-ONLY] Before running this block, open the authorized external escrow system.
# For each protected volume, confirm that the escrow record contains BOTH the same
# recovery-password protector ID and its associated 48-digit recovery password.
# Then enter only those externally verified protector IDs below. Do not paste recovery
# passwords into this script.
$externallyVerifiedRecoveryProtectorIds = @(
    # Example: '{00000000-0000-0000-0000-000000000000}'
)

$verifiedIds = @(
    $externallyVerifiedRecoveryProtectorIds |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim().Trim([char[]]'{}').ToUpperInvariant() } |
        Select-Object -Unique
)

$allBitLockerVolumes = @(Get-BitLockerVolume -ErrorAction Stop)
$protectedVolumes = @(
    $allBitLockerVolumes |
        Where-Object {
            [string]$_.VolumeStatus -ne 'FullyDecrypted' -or
            @($_.KeyProtector).Count -gt 0
        }
)

$bitLockerPreflight = @(
    foreach ($volume in $protectedVolumes) {
        $recoveryProtectors = @(
            $volume.KeyProtector |
                Where-Object { [string]$_.KeyProtectorType -eq 'RecoveryPassword' }
        )
        $localRecoveryIds = @(
            $recoveryProtectors |
                ForEach-Object {
                    ([string]$_.KeyProtectorId).Trim().Trim([char[]]'{}').ToUpperInvariant()
                } |
                Where-Object { $_ } |
                Select-Object -Unique
        )
        $escrowConfirmedIds = @(
            $localRecoveryIds |
                Where-Object { $verifiedIds -contains $_ }
        )

        $result = if ([string]$volume.ProtectionStatus -eq 'Unknown') {
            'STOP: BitLocker protection state is unknown'
        } elseif ($localRecoveryIds.Count -eq 0) {
            'STOP: no recovery-password protector'
        } elseif ($escrowConfirmedIds.Count -eq 0) {
            'STOP: external escrow not confirmed'
        } else {
            'READY: externally verified recovery protector'
        }

        [pscustomobject]@{
            MountPoint                    = $volume.MountPoint
            VolumeStatus                  = $volume.VolumeStatus
            ProtectionStatus              = $volume.ProtectionStatus
            LocalRecoveryProtectorIds     = $localRecoveryIds -join ', '
            EscrowConfirmedProtectorIds   = $escrowConfirmedIds -join ', '
            Result                        = $result
        }
    }
)

if ($protectedVolumes.Count -eq 0) {
    Write-Host 'READY: no encrypted or protected BitLocker volumes were found.'
} else {
    $bitLockerPreflight |
        Format-Table MountPoint, VolumeStatus, ProtectionStatus,
            LocalRecoveryProtectorIds, EscrowConfirmedProtectorIds, Result -AutoSize
}

$blockedVolumes = @(
    $bitLockerPreflight |
        Where-Object { $_.Result -notlike 'READY:*' }
)
if ($blockedVolumes.Count -gt 0) {
    throw 'STOP: one or more protected volumes lack confirmed external recovery evidence. Do not change TPM firmware.'
}
```

If no encrypted or protected volume is returned, there is nothing to suspend; go to step 3.
Otherwise, the table must report **READY** for every returned mount point, including a volume
that is already suspended and reports `ProtectionStatus = Off`.
The script does not query your escrow system. A local recovery-password protector, by itself,
does not prove that its password is stored externally. The **READY** result means only that
an operator supplied a protector ID after independently confirming the matching protector ID
and 48-digit password in the authorized escrow system. Do not continue if any record is absent,
stale, inaccessible, or does not match.

Suspend every returned volume with `-RebootCount 0` so the suspension holds across the
firmware change and reboot. The block persists the pre-change protection state under
`ProgramData`, so step 5 can restore only the volumes that were armed before this procedure:

```powershell
$suspensionRecordPath = Join-Path $env:ProgramData (
    'AzureLocalTSG\TpmVersion-BitLocker-Suspended.json'
)
$suspensionRecordDirectory = Split-Path -Parent $suspensionRecordPath
New-Item -ItemType Directory -Path $suspensionRecordDirectory -Force | Out-Null

$suspensionRecord = @(
    $protectedVolumes | ForEach-Object {
        [pscustomobject]@{
            MountPoint = $_.MountPoint
            ProtectionStatusBefore = [string]$_.ProtectionStatus
            VolumeStatusBefore = [string]$_.VolumeStatus
            RecordedAtUtc = [DateTime]::UtcNow.ToString('o')
        }
    }
)
$suspensionRecord |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $suspensionRecordPath -Encoding UTF8

foreach ($mountPoint in $suspensionRecord.MountPoint) {
    Suspend-BitLocker -MountPoint $mountPoint -RebootCount 0 -ErrorAction Stop
}

Get-BitLockerVolume |
    Where-Object { $suspensionRecord.MountPoint -contains $_.MountPoint } |
    Select-Object MountPoint, ProtectionStatus, VolumeStatus

Write-Host "Persistent BitLocker suspension record: $suspensionRecordPath"
```

Every listed volume must report `ProtectionStatus = Off` before you enter firmware setup.
If the preflight or suspension block throws, stop before step 3 and resolve the recovery or
BitLocker issue first.

### 3. Enable the TPM and set it to TPM 2.0 in firmware

> If this machine is already a deployed, encrypted cluster member, do **not** reboot it into
> firmware yet. Follow [If the machine is already a deployed cluster member](#if-the-machine-is-already-a-deployed-encrypted-cluster-member) first so you take the node down safely.

1. Reboot the machine and enter firmware setup (the key varies by vendor, commonly `F2`,
   `F10`, `Del`, or via the BMC / iDRAC / iLO / XClarity remote console).
2. Locate the **TPM** (sometimes shown as "Security Device", "Trusted Computing", or
   "PTT/Intel Platform Trust Technology" / "AMD fTPM") settings.
3. Make sure the TPM is **enabled** and visible to the operating system.
4. If the platform supports selecting the TPM specification version and the TPM is in 1.2
   mode, set it to **2.0** (often labelled "TPM Device Version", "TCG Spec Version", or
   similar), following your vendor's documented procedure. **Heed the warnings above**: the
   switch clears the TPM and may be limited or one-way on your model.
5. Save and exit, and let the machine boot back into the OS.

The exact menu names and the availability of a version switch are vendor-specific. If your
platform's TPM is a fixed module that cannot report 2.0, it cannot be remediated in firmware
and the module (or machine) must be brought to spec by your hardware vendor; confirm the
machine is on the Azure Local supported hardware list.

### 4. Confirm the TPM now reports version 2.0

```powershell
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled
(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm).SpecVersion
```

The first segment of `SpecVersion` should now be `2.0`.

### 5. Resume BitLocker (only if you suspended it in step 2)

```powershell
$suspensionRecordPath = Join-Path $env:ProgramData (
    'AzureLocalTSG\TpmVersion-BitLocker-Suspended.json'
)
if (-not (Test-Path -LiteralPath $suspensionRecordPath -PathType Leaf)) {
    throw 'The BitLocker suspension record from step 2 was not found. Stop and determine the pre-change protection state before resuming any volume.'
}
$suspensionRecord = @(
    Get-Content -LiteralPath $suspensionRecordPath -Raw |
        ConvertFrom-Json
)
$mountPointsToResume = @(
    $suspensionRecord |
        Where-Object { $_.ProtectionStatusBefore -eq 'On' } |
        ForEach-Object MountPoint
)

foreach ($mountPoint in $mountPointsToResume) {
    Resume-BitLocker -MountPoint $mountPoint -ErrorAction Stop
}

$finalBitLockerState = @(
    Get-BitLockerVolume |
    Where-Object { $suspensionRecord.MountPoint -contains $_.MountPoint } |
    Select-Object MountPoint, ProtectionStatus, VolumeStatus
)
$finalBitLockerState | Format-Table -AutoSize

$resumeFailures = @(
    $finalBitLockerState |
        Where-Object {
            $mountPointsToResume -contains $_.MountPoint -and
            [string]$_.ProtectionStatus -ne 'On'
        }
)
if ($resumeFailures.Count -gt 0) {
    throw 'One or more volumes did not return to ProtectionStatus On. Keep the suspension record and resolve BitLocker before closing the change.'
}

Remove-Item -LiteralPath $suspensionRecordPath -Force -ErrorAction Stop
```

Resuming allows the TPM-based protector to reseal against the new measured-boot state.
Every volume whose recorded `ProtectionStatusBefore` was `On` must return to
`ProtectionStatus = On`. A volume that was already suspended remains suspended, preserving
its prior maintenance state. Confirm again that each previously verified protector ID and
recovery password remains available in the authorized escrow system.

### If the machine is already a deployed, encrypted cluster member

Because this is a pre-deployment check, it does not normally fire on a machine that is
already a deployed cluster node: the machine must have reported TPM 2.0 to deploy, and the
version does not change on its own. But if you are changing the TPM on a machine that is
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

$nodes = @(Get-ClusterNode -ErrorAction Stop)
$target = @($nodes | Where-Object Name -eq $node)
if ($target.Count -ne 1 -or $target[0].State -ne 'Up') {
    throw "Expected one Up target node named $node."
}
if (@($nodes | Where-Object { $_.Name -ne $node -and $_.State -ne 'Up' }).Count -gt 0) {
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
    $nodes | Where-Object {
        $_.State -eq 'Up' -and
        $_.NodeWeight -gt 0 -and
        ($null -eq $_.DynamicWeight -or $_.DynamicWeight -gt 0)
    }
)
$remainingVotes = @($votingNodes | Where-Object Name -ne $node).Count + $witnessVote
$requiredVotes = [math]::Floor(($votingNodes.Count + $witnessVote) / 2) + 1
if ($remainingVotes -lt $requiredVotes) {
    throw "Pausing $node would leave $remainingVotes vote(s); $requiredVotes are required."
}

$virtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
if ($virtualDisks.Count -eq 0) {
    throw 'No virtual disks were returned. Storage health is unverified.'
}
$unhealthy = @(
    $virtualDisks | Where-Object {
        $states = @($_.OperationalStatus)
        $_.HealthStatus -ne 'Healthy' -or
        $states.Count -eq 0 -or
        @($states | Where-Object { [string]$_ -ne 'OK' }).Count -gt 0
    }
)
if ($unhealthy.Count -gt 0) {
    $unhealthy | Select-Object FriendlyName, HealthStatus, OperationalStatus
    throw 'One or more virtual disks are not Healthy/OK.'
}
if (@(Get-StorageJob).Count -gt 0) {
    throw 'Wait for all storage jobs to finish before draining the node.'
}

Suspend-ClusterNode -Name $node -Drain -Wait
Get-ClusterNode -Name $node | Select-Object Name, State
$remainingVmGroups = @(
    Get-ClusterGroup | Where-Object {
        [string]$_.OwnerNode -eq $node -and $_.GroupType -eq 'VirtualMachine'
    }
)
if ($remainingVmGroups.Count -gt 0) {
    $remainingVmGroups | Select-Object Name, OwnerNode, State
    throw 'The drain is incomplete because virtual-machine groups remain on the node.'
}
```

Proceed only after the node is `Paused` and the virtual-machine query returns no rows.
Then run steps 2 through 5 above. Finally bring the node back and let storage resync
before the next one:

```powershell
Resume-ClusterNode -Name $node
do {
    Start-Sleep -Seconds 15
    $jobs = @(Get-StorageJob)
} while ($jobs.Count -gt 0)
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus
```

Repeat for each remaining member, one node at a time, so the cluster always keeps quorum and
storage resiliency.

## Verify the fix

Re-run the single validator:

```powershell
$r = Invoke-AzStackHciHardwareValidation -Include Test-TpmVersion -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

A machine whose TPM reports version 2.0 returns `Status` of `SUCCESS`. Once every machine
you are deploying reports success, re-run the deployment validation; the **TPM Version**
check should now pass and deployment can proceed.

## When to escalate

Open a support case if any of the following are true:

- `Win32_Tpm` reports `SpecVersion` starting with `2.0`, but the **TPM Version** check
  still fails during deployment validation.
- The firmware has no option to enable a TPM or to select TPM 2.0, or the platform's TPM
  is a fixed module that cannot report 2.0. TPM 2.0 is an Azure Local hardware requirement,
  so confirm the machine is on the Azure Local supported hardware list, and engage your
  hardware vendor if the module must be replaced.
- The machine has no TPM at all (`TpmPresent` is `False`); this is a hardware requirement
  that cannot be satisfied in firmware.
- The machine stops at the BitLocker recovery screen after the change and the recovery key
  is not available.

::: audience-css

# Source Articles

- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- [Azure Local security features and baseline](https://learn.microsoft.com/azure/azure-local/concepts/security-features)
- [Trusted Platform Module (TPM 2.0) overview](https://learn.microsoft.com/windows/security/hardware-security/tpm/trusted-platform-module-overview)
- [Get-Tpm](https://learn.microsoft.com/powershell/module/trustedplatformmodule/get-tpm)
- [Suspend-BitLocker before firmware changes](https://learn.microsoft.com/powershell/module/bitlocker/suspend-bitlocker)
- [Suspend-ClusterNode (pause and drain a node)](https://learn.microsoft.com/powershell/module/failoverclusters/suspend-clusternode)
- [Resume-ClusterNode](https://learn.microsoft.com/powershell/module/failoverclusters/resume-clusternode)

:::
