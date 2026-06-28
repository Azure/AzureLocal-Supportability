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
> failure. Whether the TPM is **present and enabled** is covered by the companion check
> `AzStackHci_Hardware_TpmProperties` (`Test-TpmProperties`), which fails when a TPM is
> missing or disabled. If you are investigating a TPM problem, check both.

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

> **A note on names across surfaces.** The portal shows the aggregated display name
> **TPM Version**, while the per-machine result JSON and the event log carry the verbose form
> **Test TPM Version `<machine>`**. The underlying `Name`,
> `AzStackHci_Hardware_Test_Tpm_Version`, is the same on both, so if you are matching strings
> between the portal and the on-box output, expect the two forms.

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
2.0 at all, so settle that first. Read the current state (step 1 below, non-disruptive), then
consult your hardware vendor's TPM documentation for your model and use this table to decide
the path and the owner **before** any disruptive change:

| What your hardware reports / the vendor says | What it means | Who owns the action | What to do |
| --- | --- | --- | --- |
| TPM already reports **2.0** | This check should pass | No change needed | Re-confirm with step 1; if it still fails, see [When to escalate](#when-to-escalate) |
| TPM present, reports **1.2**, vendor says it is **switchable to 2.0** | A firmware switch is possible (it clears the TPM) | Server / firmware admin; Windows admin confirms BitLocker | Escrow the BitLocker key first, then follow [How to fix it](#how-to-fix-it) |
| TPM **1.2**, switch is **one-way or limited** (for example a toggle-count cap) | You can switch but cannot easily go back | Server / firmware admin **with hardware-vendor sign-off** | Confirm with the vendor, then treat it as a one-time change |
| TPM is a **fixed module** that cannot report 2.0 | Cannot be fixed in firmware | Hardware vendor (OEM) | Engage the OEM; the module or machine must be brought to spec. Expect lead time |
| **No TPM present** | Not deployable (this version check will not fail, but `Test-TpmProperties` will) | Hardware vendor (OEM) plus procurement | Confirm the machine is on the Azure Local supported hardware list; add or replace the TPM |

**Do not start any disruptive change until you have confirmed all three:** the switch is
supported on your exact model, the **BitLocker recovery key is escrowed**, and (if this machine
is already a deployed cluster member) it has been **drained** first. A TPM switch clears the
module and is sometimes irreversible, so if any of the three is unknown, stop and confirm.

> **Setting expectations:** a firmware switch is usually quick, but a fixed-module or
> unsupported-hardware case means a hardware change or replacement with real lead time and
> possible procurement. Surface that to the customer early so the deployment schedule reflects it.

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

### 2. Check for BitLocker, and suspend it if present

Do this even on a fresh pre-deployment host. A host you are vetting may have been **recycled
from a previous project with BitLocker already enabled**, and a TPM version change clears the
module, which invalidates the TPM-sealed BitLocker key. If a protected volume is left armed,
**the next boot after the change stops at the BitLocker recovery screen** and asks for the
48-digit recovery password, which can strand the machine.

```powershell
# Are any volumes protected? (On a truly clean, never-encrypted host this is empty.)
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, VolumeStatus
```

If every volume reports `ProtectionStatus = Off`, there is nothing to suspend; go to step 3.
If any volume is protected, **confirm its recovery key is escrowed first**, then suspend it
with `-RebootCount 0` so the suspend holds across the firmware change and reboot until you
explicitly resume it:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
# Repeat for any data volume that reports ProtectionStatus = On, for example:
# Suspend-BitLocker -MountPoint "D:" -RebootCount 0
```

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
Resume-BitLocker -MountPoint "C:"
# And any data volume you suspended, for example:
# Resume-BitLocker -MountPoint "D:"
```

Resuming reseals the BitLocker key to the new TPM. Because the version switch cleared the
module, make sure each volume re-protects cleanly and a fresh recovery key is escrowed.

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
# Confirm the cluster is healthy and can lose this one node before you start.
Get-ClusterNode | Select-Object Name, State          # every other node should be Up
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus  # all Healthy / OK
Get-StorageJob                                       # should be empty (no active repair/resync)

# Only when the cluster is healthy, pause and drain this node so its VMs live-migrate off.
Suspend-ClusterNode -Name <node> -Drain
Get-ClusterNode -Name <node> | Select-Object Name, State   # State should be Paused
```

Then run steps 2 through 5 above (suspend BitLocker, change firmware, confirm, resume
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
