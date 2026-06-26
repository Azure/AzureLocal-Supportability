# AzStackHci_Hardware_Test_Secure_Boot

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_Secure_Boot</strong> (aggregated as <code>AzStackHci_Hardware_SecureBoot</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Secure Boot</td>
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

While this check is failing, deployment is blocked at the Hardware validation stage and
the machine cannot proceed. This is a pre-deployment gate (it runs during Deployment and
Add Node validation), so the machine it flags is normally a **host being validated to
become a cluster node**, not a running cluster member. The fix is usually short: check for
BitLocker, enable Secure Boot in firmware, and re-validate. Two cautions apply, though: a
host being vetted may have been **recycled from another project and could already have
BitLocker enabled** (a Secure Boot change trips it into recovery, so check first), and the
cluster-drain precaution is only needed if the machine is already a live, deployed member.

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
$r = Invoke-AzStackHciHardwareValidation -Include Test-SecureBoot -PassThru
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
  "DisplayName": "Secure Boot",
  "Title": "Secure Boot",
  "Severity": "Critical",
  "Status": "FAILURE",
  "Description": "Validates that UEFI Secure Boot is enabled on each machine by running Confirm-SecureBootUEFI. Secure Boot must be enabled before Azure Local deployment.",
  "TargetResourceName": "AzL-Node-01",
  "Remediation": "Enable UEFI Secure Boot in the machine firmware and re-run the check. The machine must be in UEFI boot mode for Secure Boot to apply.",
  "AdditionalData": {
    "Detail": "SecureBoot is 'False' on AzL-Node-01. Expected 'True'. Ensure SecureBoot is supported and enabled on AzL-Node-01.",
    "Status": "FAILURE"
  }
}
```

## Before you start: who does this, and confirm it is safe

- **Who owns this.** Enabling Secure Boot is a firmware change, so it is done by the **server
  or hardware administrator** with firmware / BMC (iDRAC / iLO / XClarity) access. The
  **Windows administrator** confirms and suspends BitLocker; the **network team** can provide
  BMC access but does not own this change. If you are first-line or temporary staff, do not
  change firmware without the machine's owner.
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
    ```

  - If this machine is **already a deployed cluster member** (encrypted or not), the firmware
    reboot takes a live node down, so drain it first (see [If the machine is already a deployed,
    encrypted cluster member](#if-the-machine-is-already-a-deployed-encrypted-cluster-member)).
    One node at a time.

## How to fix it

This check runs during **pre-deployment validation**, so the machine it flags is normally a
**host being prepared to become a cluster node**, not a running cluster member: there is
usually no cluster to keep in quorum. Do not assume the host is otherwise "clean", though.
A host being vetted may have been **recycled from another project and could already have
BitLocker enabled**, and a Secure Boot change is measured into TPM PCR 7, which trips an
encrypted volume into recovery, so check for BitLocker before you touch firmware (step 1).
The cluster-drain precaution only applies in the uncommon case that the machine is already
a live, deployed cluster member.

Secure Boot is a firmware (UEFI/BIOS) setting, so the change is made in the machine's
firmware setup, not from Windows.

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
If any volume is protected, **confirm its recovery key is escrowed first**, then suspend it
with `-RebootCount 0` so the suspend holds across the firmware change and reboot until you
explicitly resume it:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
# Repeat for any data volume that reports ProtectionStatus = On, for example:
# Suspend-BitLocker -MountPoint "D:" -RebootCount 0
```

### 2. Enable Secure Boot in firmware (UEFI/BIOS)

> If this machine is already a deployed, encrypted cluster member, do **not** reboot it into
> firmware yet. Follow [If the machine is already a deployed cluster member](#if-the-machine-is-already-a-deployed-encrypted-cluster-member) first so you take the node down safely.

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

The exact menu names are vendor-specific; consult your hardware vendor's documentation
for the precise location of the Secure Boot and boot-mode settings.

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

### If the machine is already a deployed, encrypted cluster member

Because this is a pre-deployment check, it does not normally fire on a machine that is
already a deployed cluster node. But if you are enabling Secure Boot on a machine that is
**already a live, encrypted cluster member** for any reason, add one precaution to the steps
above: the firmware reboot takes a running node down, so **drain it first** and do this
**one node at a time**.

This is a [MEDIUM RISK] change: draining live-migrates VMs off the node, and the node is
unavailable until you resume it.

```powershell
# Confirm the cluster is healthy and can lose this one node before you start.
Get-ClusterNode | Select-Object Name, State          # every other node should be Up
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus  # all Healthy / OK
Get-StorageJob                                       # should be empty (no active repair/resync)

# Only when the cluster is healthy, pause and drain this node so its VMs live-migrate off.
Suspend-ClusterNode -Name <node> -Drain
Get-ClusterNode -Name <node> | Select-Object Name, State   # State should be Paused
```

Then run steps 1 through 4 above (suspend BitLocker, enable Secure Boot, confirm, resume
BitLocker). Finally bring the node back and let storage resync before the next one:

```powershell
Resume-ClusterNode -Name <node>
Get-StorageJob                                       # wait until empty
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus   # back to Healthy
```

Repeat for each remaining member, one node at a time, so the cluster always keeps quorum and
storage resiliency.

## Verify the fix

Re-run the single validator:

```powershell
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
  confirm the machine is on the Azure Local supported hardware list.
- `Confirm-SecureBootUEFI` reports that the cmdlet is not supported on the platform even
  after you have set the machine to UEFI boot mode.
- The machine stops at the BitLocker recovery screen after the change and the recovery
  key is not available.

## Related

- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- [Azure Local security features and baseline](https://learn.microsoft.com/azure/azure-local/concepts/security-features)
- [Secure Boot (Windows hardware security)](https://learn.microsoft.com/windows-hardware/design/device-experiences/oem-secure-boot)
- [Suspend-BitLocker before firmware changes](https://learn.microsoft.com/powershell/module/bitlocker/suspend-bitlocker)
- [Suspend-ClusterNode (pause and drain a node)](https://learn.microsoft.com/powershell/module/failoverclusters/suspend-clusternode)
- [Resume-ClusterNode](https://learn.microsoft.com/powershell/module/failoverclusters/resume-clusternode)
