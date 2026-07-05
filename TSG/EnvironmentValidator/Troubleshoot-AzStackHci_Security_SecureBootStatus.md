# AzStackHci_Security_SecureBootStatus

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) security check that reports each node's **Secure Boot 2023 certificate rollout** posture (the CVE-2023-24932 / BlackLotus mitigation, tied to the 2011 Secure Boot certificates expiring in June 2026).
> - **Owner:** delivered and orchestrated by the Azure Local platform update; some hardware also needs an OEM BIOS/UEFI firmware update. It is not an Azure Local software defect and the fix is not a manual per-node registry edit.
> - **Impact:** a security-posture gap, not an outage. Nodes keep booting and running; some Secure Boot protections are limited once the 2011 certificates expire.
> - **Read the Detail, not the Status:** this validator is informational and always reports a SUCCESS status. The actionable state is in the result **Detail**, see the detection note below.

## Overview

This check reports whether each node has completed the **2023 Secure Boot certificate update**. A node is healthy when its Windows Boot Manager is updated to the Windows UEFI CA 2023 signed version and in use, and all four expected certificates are installed:

- **Windows UEFI CA 2023** (in the Secure Boot `db`)
- **Microsoft UEFI CA 2023** (in `db`)
- **Microsoft Option ROM UEFI CA 2023** (in `db`)
- **Microsoft Corporation KEK 2K CA 2023** (in the `KEK`)

- **Severity:** Informational. The check does not fail with an error status; it reports posture. See the detection note.
- **When it runs:** the Environment Checker runs this check during **pre-deployment readiness** and during the **pre-update health check**. Starting with Azure Local release 2604, the pre-update prechecks verify that the Secure Boot certificates and the CVE-2023-24932 mitigation are in place, so in practice you will most often see this surface as part of a pre-update readiness run. It is not tied to a single node reboot; it reflects the cluster's current certificate posture whenever the checker runs.
- **Read the Detail, not the Status (IMPORTANT).** This validator always reports a SUCCESS status, so a filter that looks for a non-success status finds nothing. A node needs attention when its **Detail** shows a certificate `Installed: False`, or a `Boot Manager Update Status` other than `BootManagerUpdatedAndInUse`. The steps below read the Detail.
- **Who owns the fix.** The 2023 certificates are installed by the Azure Local platform update's built-in orchestration (a Cluster-Aware Updating plugin), delivered starting with the 2603 Solution Update, and by OEM BIOS/UEFI firmware where the hardware requires it. The operator's role is to apply the Solution Update (and any required OEM firmware) and confirm completion, not to hand-edit Secure Boot registry values.

## Requirements

- Administrative (local administrator) access to each Azure Local node.
- The cluster on Azure Local Solution Update **2603 or later** (the release that carries the Secure Boot mitigation orchestration).
- For some hardware, the latest OEM BIOS/UEFI firmware (see the OEM minimum-BIOS note in remediation).
- The BitLocker recovery key for every node, backed up before any firmware or Secure Boot change (`manage-bde -protectors -get $env:SystemDrive`). Secure Boot changes are measured-boot changes and can trigger BitLocker recovery.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

Because this check always reports a SUCCESS status, confirm it by reading the result **Detail**, not the status. Read the newest health-check result file and flag any node whose Detail shows a certificate `Installed: False` or a Boot Manager status other than `BootManagerUpdatedAndInUse`:

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
$latest = $null
if ($base) {
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $latest) {
    Write-Warning "No HealthCheck result on this node; use the on-node check below or read the AzStackHciEnvironmentChecker event log (Event ID 17205)."
}
else {
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -eq 'AzStackHci_Security_SecureBootStatus' } |
        ForEach-Object {
            $d = $_.AdditionalData.Detail
            [pscustomobject]@{
                NeedsAttention = ($d -match 'Installed:\s*False') -or ($d -notmatch 'BootManagerUpdatedAndInUse')
                Detail = $d
            }
        }
}
```

The same record is on the Windows event log as Event ID 17205 in `AzStackHciEnvironmentChecker` (read `AdditionalData.Detail` the same way), and in the Azure portal on the cluster's **Updates** tab when a pre-update health check fails.

**Cross-check with the product completion cmdlet.** The Azure Local Secure Boot cmdlet reports the same posture the validator reads and is the authoritative per-node completion check:

```powershell
Test-AzSSecureBootUpdateCompleted -Verbose
```

`True` means the Secure Boot update is complete on that node; `False` means at least one item is not finished. The `-Verbose` output lists the same components the validator checks: `WindowsUEFICAInstalled`, `MicrosoftUEFICAInstalled`, `MicrosoftOptionROMUEFICAInstalled`, `KEKInstalled`, and `BootEFISignerUpdated`. On nodes without that cmdlet, read the registry instead:

```powershell
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing\' -Name UEFICA2023Status
```

`Updated` means complete; `InProgress` or `NotStarted` means at least one item is outstanding.

### 2. What it looks like: example failure signatures

The Detail is a single composite line. Representative non-healthy examples:

```
Boot Manager Update Status: BootManagerUpdatedAndInUse. Windows UEFI CA cert Installed: True. Microsoft UEFI CA cert Installed: False. Microsoft Option ROM UEFI CA cert Installed: False. KEK cert Installed: True.
```

```
Boot Manager Update Status: BootManagerNotUpdated. Windows UEFI CA cert Installed: Unknown. Microsoft UEFI CA cert Installed: Unknown. Microsoft Option ROM UEFI CA cert Installed: Unknown. KEK cert Installed: Unknown.
```

```
An error occurred while checking Secure Boot status: Access denied while querying UEFI variables
```

What each state means:

- **A certificate `Installed: False`**: that 2023 certificate has not yet been added to the node's UEFI database. The rollout has not completed on this node (most commonly because the node has not yet gone through the 2603+ Solution Update, or its firmware has not applied the update, see remediation Case A).
- **`BootManagerNotUpdated`**: the updated (Windows UEFI CA 2023 signed) boot manager has not been applied yet.
- **`BootManagerUpdatedButUnableToDetermineInUseStatus`**: the updated boot manager is present but not yet confirmed in use; this usually clears after a reboot.
- **Certificates `Unknown` with an error line**: the check could not read the UEFI variables (for example access-denied); resolve the read error, then re-evaluate.

A healthy node reads: `Boot Manager Update Status: BootManagerUpdatedAndInUse` with all four certificates `Installed: True`.

### 3. Identify the affected nodes

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    if (Get-Command Test-AzSSecureBootUpdateCompleted -ErrorAction SilentlyContinue) {
        [pscustomobject]@{ Completed = [string](Test-AzSSecureBootUpdateCompleted) }
    }
    else {
        $s = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing\' -Name UEFICA2023Status -ErrorAction SilentlyContinue
        [pscustomobject]@{ Completed = "UEFICA2023Status=$($s.UEFICA2023Status)" }
    }
} | Sort-Object PSComputerName | Select-Object PSComputerName, Completed
```

Nodes that return `False` (or a `UEFICA2023Status` other than `Updated`) are the ones to remediate.

### 4. Consequences if you do not fix this

There is no imminent impact: nodes keep booting and running. The cluster is not yet on the 2023 Secure Boot certificate baseline, so it remains exposed to the CVE-2023-24932 (BlackLotus) Secure Boot bypass class, and once the 2011 certificates expire (June 2026) some Secure Boot related functions become limited. The finding will keep surfacing in readiness and pre-update health checks until the rollout completes.

### 5. Remediation

On Azure Local the 2023 Secure Boot certificates are installed by the **platform update's built-in orchestration**, not by a manual per-node registry edit. Do not hand-edit `AvailableUpdates`; drive the fix through the Solution Update and, where required, OEM firmware. The two guides linked below own the detailed, validated procedure; this section summarizes it for this validator.

1. **Apply Azure Local Solution Update 2603 or later.** The update runs a Cluster-Aware Updating plugin that installs the 2023 certificates node by node, sequences the required reboots, and gates on safety (Secure Boot enabled, BitLocker handled). Use planned maintenance windows and validate on one node per hardware model first. Solution updates retry the Secure Boot certificate update on a best-effort basis across releases.

2. **If a node stays incomplete because of its BIOS version (Case A):** some OEM models require a minimum BIOS version before the certificates can be installed. Confirm the model and BIOS version, and apply the OEM BIOS/UEFI firmware update if it is below the minimum:

   ```powershell
   (Get-CimInstance -Class Win32_BIOS).SMBIOSBIOSVersion
   ```

   Apply Secure Boot updates and BIOS/UEFI firmware updates in separate maintenance steps, not on the same reboot. See the canonical Secure Boot TSG (linked below) for the per-OEM minimum-BIOS table and the firmware-update prerequisites.

3. **If a node stays incomplete because it needs another reboot (Case B):** the number of reboots required is not deterministic. Reboot the node (drained) and re-check, or wait for the next Solution Update to continue.

**Background and step-by-step remediation (read these):**

- [Troubleshooting guide: Azure Local UEFI 2023 Secure Boot Update](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/Security/TSG-Azure-Local-UEFI-2023-Secure-Boot-Update.md): the step-by-step completion checks, the per-OEM minimum-BIOS table, and the reboot/BIOS cases.
- [Manage Secure Boot updates (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-secure-boot-updates): how Azure Local orchestrates the rollout, monitoring, and the recommended before/during/after workflow.

**Risk:** [MEDIUM RISK] the rollout is a measured-boot change with reboots and a BitLocker-recovery risk if the recovery key is not backed up; the DBX revocation stage is irreversible while Secure Boot stays enabled, so let the platform orchestration sequence it and follow the canonical TSG rather than forcing it by hand.

### 6. Verification: prove the failure cleared

On each remediated node, confirm the product completion cmdlet now returns `True`:

```powershell
Test-AzSSecureBootUpdateCompleted -Verbose
```

All five components (`WindowsUEFICAInstalled`, `MicrosoftUEFICAInstalled`, `MicrosoftOptionROMUEFICAInstalled`, `KEKInstalled`, `BootEFISignerUpdated`) should report as done, and `UEFICA2023Status` in the registry should read `Updated`. Then re-run the pre-update health check so the validator re-evaluates cluster-wide:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` with a current `HealthCheckDate`, then re-read the Detail (Step 1). A healthy node reports `Boot Manager Update Status: BootManagerUpdatedAndInUse` with all four certificates `Installed: True`.

> **Note:** the Azure portal readiness view and the cluster-wide health-check result refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a targeted per-node re-test, so confirm the fix on-node with `Test-AzSSecureBootUpdateCompleted` rather than waiting on the portal.
