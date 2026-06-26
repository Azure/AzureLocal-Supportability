# AzStackHci_Hardware_Test_Tpm_Version

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_Tpm_Version</strong> (aggregated as <code>AzStackHci_Hardware_TpmVersion</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>TPM Version</td>
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
    <td>Deployment, Add Node, and Upgrade (pre-deployment / readiness validation).</td>
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
> failure. Whether the TPM is **present and enabled** is covered by the companion check
> `AzStackHci_Hardware_TpmProperties` (`Test-TpmProperties`), which fails when a TPM is
> missing or disabled. If you are investigating a TPM problem, check both.

While this check is failing, deployment is blocked at the Hardware validation stage and
the machine cannot proceed. Unlike a software setting, the fix is a **firmware and
hardware** change that is specific to your server model, and on some platforms it is
limited, irreversible, or not possible at all (see [How to fix it](#how-to-fix-it)).

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
# Presence / enabled state (covered by Test-TpmProperties, shown here for context).
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

## How to fix it

The TPM specification version is a firmware and hardware property, so the fix is made in
the machine's firmware setup (or with the vendor's management tooling), not from Windows.
**Before you change anything, read the warnings in this section.** Unlike most validator
fixes, changing a TPM's version is platform-specific and has serious side effects:

- **Switching a TPM clears it.** Moving a TPM between specification versions (for example
  1.2 to 2.0) re-provisions the module and **erases the keys it holds**. Any key sealed to
  that TPM, including a **BitLocker** key protector, is invalidated by the change.
- **It is vendor-specific and may be limited or impossible.** Some platforms allow a
  reversible firmware switch (sometimes with a documented limit on how many times it can be
  done), some allow only a one-way move, and some ship a **fixed module that cannot be
  switched at all** and would have to be replaced. Consult your hardware vendor's TPM
  documentation for your exact model before proceeding.

The high-level order is: if the machine is an already-deployed cluster member, drain it
first; if it has BitLocker on, suspend BitLocker and confirm the recovery key is escrowed;
enable the TPM and set it to TPM 2.0 in firmware per your vendor's documentation; confirm;
resume BitLocker; and resume the node. Then re-run the check.

### 1. Confirm the current TPM state

Establish what the machine actually reports before you touch firmware:

```powershell
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled
(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm).SpecVersion
```

- If `TpmPresent` is `False`, the machine has no usable TPM. This version check will not
  fail (it only evaluates a present TPM), but `Test-TpmProperties` will, and the machine
  is not deployable without a TPM. This is a hardware action, not a firmware setting.
- If a TPM is present but `SpecVersion` starts with something other than `2.0`, continue
  below.

### 2. If the machine is an already-deployed cluster member, drain it first

If this machine has BitLocker on, it has almost certainly already been deployed into a
cluster (Azure Local turns on encryption during deployment). Changing the TPM requires a
reboot into firmware, which takes this node down, so drain it first and do **one node at a
time**. This is a [MEDIUM RISK] change: draining live-migrates VMs off the node, and the
node is unavailable until you resume it.

```powershell
# Confirm the cluster is healthy and can lose this one node before you start.
Get-ClusterNode | Select-Object Name, State          # every other node should be Up
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus  # all Healthy / OK
Get-StorageJob                                       # should be empty (no active repair/resync)
```

Only continue when every other node is `Up`, all virtual disks are Healthy, and
`Get-StorageJob` returns nothing. Then pause and drain this node so its VMs live-migrate
off:

```powershell
Suspend-ClusterNode -Name <node> -Drain
# Confirm the node is Paused and its roles have moved before you reboot it.
Get-ClusterNode -Name <node> | Select-Object Name, State   # State should be Paused
```

### 3. If the machine has BitLocker enabled, suspend it first

Changing the TPM alters (and in the version-switch case **clears**) the hardware root of
trust that BitLocker seals its key to. On a machine where **BitLocker is enabled, the next
boot after the change will stop at the BitLocker recovery screen** and ask for the 48-digit
recovery password, which can strand the machine. Azure Local enables data-at-rest
encryption (BitLocker) by default, so a machine that has already been deployed (or any
machine with drive encryption) is affected. A fresh, pre-deployment machine that has never
been encrypted is not.

If BitLocker is on, suspend it **before** you change firmware, and resume it **after** the
machine is back and the TPM is confirmed. Use `-RebootCount 0` so the suspend holds across
the firmware change and reboot until you explicitly resume it:

```powershell
# Are any volumes protected?
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, VolumeStatus

# Suspend each protected volume indefinitely (until you resume it).
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
# Repeat for any data volumes that report ProtectionStatus = On, for example:
# Suspend-BitLocker -MountPoint "C:\ClusterStorage\Volume1" -RebootCount 0
```

You will resume BitLocker in step 6, after the TPM is confirmed. **Confirm the recovery
key is available (escrowed) before you start**, because a TPM version switch clears the
module and the machine must be recoverable with the recovery key if anything is
interrupted.

### 4. Enable the TPM and set it to TPM 2.0 in firmware

1. Reboot the machine and enter firmware setup (the key varies by vendor, commonly `F2`,
   `F10`, `Del`, or via the BMC / iDRAC / iLO / XClarity remote console).
2. Locate the **TPM** (sometimes shown as "Security Device", "Trusted Computing", or
   "PTT/Intel Platform Trust Technology" / "AMD fTPM") settings.
3. Make sure the TPM is **enabled** and visible to the operating system.
4. If the platform supports selecting the TPM specification version and the TPM is in 1.2
   mode, set it to **2.0** (often labelled "TPM Device Version", "TCG Spec Version", or
   similar), following your vendor's documented procedure. **Heed the warnings in this
   section first**: the switch clears the TPM and may be limited or one-way on your model.
5. Save and exit, and let the machine boot back into the OS.

The exact menu names and the availability of a version switch are vendor-specific. If your
platform's TPM is a fixed module that cannot report 2.0, it cannot be remediated in
firmware and the module (or machine) must be brought to spec by your hardware vendor;
confirm the machine is on the Azure Local supported hardware list.

### 5. Confirm the TPM now reports version 2.0

```powershell
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled
(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm).SpecVersion
```

The first segment of `SpecVersion` should now be `2.0`.

### 6. Resume BitLocker (only if you suspended it in step 3)

```powershell
Resume-BitLocker -MountPoint "C:"
# And any data volumes you suspended, for example:
# Resume-BitLocker -MountPoint "C:\ClusterStorage\Volume1"
```

Resuming reseals the BitLocker key to the current TPM. If the TPM was cleared by the
version switch, make sure the volume re-protects cleanly and a fresh recovery key is
escrowed.

### 7. Resume the cluster node (only if you drained it in step 2)

Bring the node back into the cluster and let storage resync before you touch the next node.

```powershell
Resume-ClusterNode -Name <node>
# Wait for resync to finish before moving on; do not drain the next node until this clears.
Get-StorageJob                                       # wait until empty
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus   # back to Healthy
```

Repeat steps 1 through 7 for each remaining machine, one node at a time, so the cluster
always keeps quorum and storage resiliency.

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

## Related

- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- [Azure Local security features and baseline](https://learn.microsoft.com/azure/azure-local/concepts/security-features)
- [Trusted Platform Module (TPM 2.0) overview](https://learn.microsoft.com/windows/security/hardware-security/tpm/trusted-platform-module-overview)
- [Get-Tpm](https://learn.microsoft.com/powershell/module/trustedplatformmodule/get-tpm)
- [Suspend-BitLocker before firmware changes](https://learn.microsoft.com/powershell/module/bitlocker/suspend-bitlocker)
- [Suspend-ClusterNode (pause and drain a node)](https://learn.microsoft.com/powershell/module/failoverclusters/suspend-clusternode)
- [Resume-ClusterNode](https://learn.microsoft.com/powershell/module/failoverclusters/resume-clusternode)
