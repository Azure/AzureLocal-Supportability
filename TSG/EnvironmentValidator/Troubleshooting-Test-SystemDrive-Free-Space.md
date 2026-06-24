# AzStackHci_Hardware_Test_SystemDrive_Free_Space

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_SystemDrive_Free_Space</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Telemetry / health-scanner name</th>
    <td><strong>AzStackHci_Hardware_SystemDriveFreeSpace</strong> (same check; this is the name used in Azure telemetry and the health-fault scanner)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Test System Drive Free Space</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Hardware (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: this validator blocks deployment and update operations until the machine is back above the minimum.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Required free space</th>
    <td><strong>30 GB</strong> on the system drive (<code>C:</code>) of every machine.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Deployment, Add Node, and Update / Upgrade (pre-update health check).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Overview

This validator checks that the system drive (the `C:` drive) on each Azure Local
machine has enough free space for the platform to operate and to install updates.
It fails when free space on `C:` drops below the required minimum of **30 GB** on
any machine in the cluster.

A low system drive is a real problem, not just a warning. While the check is
failing:

- Solution (Azure Local) updates and upgrades are blocked at pre-update
  validation, so the cluster cannot be patched.
- Adding a machine to the cluster can fail validation.
- New Arc and Kubernetes extensions may fail to deploy.
- Existing workloads keep running, but the machine cannot be lifecycle-managed
  reliably, and a drive that fills to zero can destabilize the node.

## Where this failure appears

You can see this failure in two places, the Azure portal and the machine itself.
Both show the same underlying result.

### In the Azure portal

The check runs as part of the update readiness and system health checks, so it
shows up in Azure Update Manager:

1. Go to **Azure Update Manager > Resources > Azure Local**, or open the **Azure
   Local** resource and its **Updates** page.
2. In the system list, select the **Update readiness** status. A system that needs
   attention shows a **Critical** or **Warning** state.
3. Review the list of readiness checks. On current builds this appears as **System
   Drive Free Space** (earlier builds: **Test System Drive Free Space**).
4. Select the link under **Details**. The details pane shows the per-machine
   results and a **Remediation** link (`https://aka.ms/hci-envch`).

The portal does not show the raw JSON shown below. It renders the same result as a
row in the readiness check list, with the display name, the Critical severity, the
affected machine, and the remediation link.

This check is reported in two scenarios, and the results can differ between them
because each uses a different version of the validation logic:

- **System health checks**, which run once every 24 hours.
- **Update readiness checks**, which run after the update content is downloaded
  and before installation.

### On the machine

Two on-box sources carry the result.

**Event log (per machine).** The Environment Checker writes every check result to
the **AzStackHciEnvironmentChecker** event log, located at
`C:\Windows\System32\winevt\Logs\AzStackHciEnvironmentChecker.evtx`. Each result is
the JSON body of an **Event ID 17205** entry. To read this check's most recent
result on a machine:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    Where-Object { $_.Message -match 'AzStackHci_Hardware_(Test_SystemDrive_Free_Space|SystemDriveFreeSpace)' } |
    Select-Object -First 1 -ExpandProperty Message
```

**Pre-update health check result file (cluster-wide).** The pre-update health
check writes its full result set to the cluster infrastructure share:

```
C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System\HealthCheckResult.EnvironmentChecker.<timestamp>.json
```

This file is on cluster storage, so it is the same from any machine in the
cluster. The newest `HealthCheckResult.EnvironmentChecker.*.json` holds the latest
run. (A separate `HealthCheckResult.CheckCloudHealth.*.json` covers other checks
and does not contain this one.)

In both sources the result for this check looks like this:

```json
{
  "Name": "AzStackHci_Hardware_SystemDriveFreeSpace",
  "DisplayName": "System Drive Free Space",
  "Title": "System Drive Free Space",
  "Severity": "Critical",
  "Status": "FAILURE",
  "Description": "Checking System Drive Free Space",
  "TargetResourceType": "Disk",
  "TargetResourceName": "Machine: AzL-Node-01, Class: Disk, DriveLetter: C:",
  "Remediation": "https://aka.ms/hci-envch",
  "AdditionalData": {
    "Detail": "Checking Hostname AzL-Node-01 for free space on root folder path 'C:' 25 GB. Expected at least 30 GB.",
    "Status": "FAILURE",
    "Resource": "AzL-Node-01"
  }
}
```

> [!NOTE]
> The `Name`, `DisplayName`, and `Title` vary by build. Current builds emit the
> telemetry / health-scanner name shown above (`AzStackHci_Hardware_SystemDriveFreeSpace` /
> `System Drive Free Space`); earlier builds emit the env-checker name
> (`AzStackHci_Hardware_Test_SystemDrive_Free_Space` / `Test System Drive Free Space`). The
> `Detail` line is identical on both, and the `Get-WinEvent` filter above matches either name.

The `Detail` line is the key part. It names the machine (`AzL-Node-01` above), the
free space it found (25 GB), and the minimum it expected (30 GB). A passing result
has `Status` of `0` or `SUCCESS`; a failing result has a non-zero status or
`FAILURE`.

## Requirements

1. Each Azure Local machine must have at least **30 GB** free on its system drive
   (`C:`).
2. You run the steps below on the affected machine, signed in as an administrator,
   in a PowerShell session.

## Troubleshooting Steps

### 1. Confirm which machine is low

Check the free space directly on each machine:

```powershell
Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}},
                              @{n='UsedGB';e={[math]::Round($_.Used/1GB,1)}}
```

If `FreeGB` is below 30, this check will fail on that machine. To check every
machine in the cluster at once:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    [pscustomobject]@{ Node = $env:COMPUTERNAME
        FreeGB = [math]::Round((Get-PSDrive C).Free/1GB,1) }
} | Sort-Object FreeGB
```

### 2. Find what is using the system drive

Before deleting anything, see where the space went. These commands are read-only.

```powershell
# Largest top-level folders on C: (this recursive scan can take a minute or two)
Get-ChildItem C:\ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $b = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
          Measure-Object Length -Sum).Sum
    [pscustomobject]@{ Folder = $_.Name; GB = [math]::Round($b/1GB,2) }
} | Sort-Object GB -Descending | Select-Object -First 12

# How much the Windows component store (WinSxS) can reclaim
Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore

# Largest Windows event logs
Get-ChildItem C:\Windows\System32\winevt\Logs -File | Sort-Object Length -Descending |
    Select-Object -First 8 Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

On an Azure Local machine the usual large consumers are the Windows folder
(including the WinSxS component store), the monitoring agent cache
(`C:\GMACache`), Windows event logs, and the Windows Update download cache.

One specific cause worth ruling out is leftover Environment Checker package folders
piling up under the orchestrator's temp directory. If you see many folders there,
follow the dedicated guide:
[Known Issue: High Disk Space Usage in TEMP](./Known-Issue-High-Disk-Space-usage-in-TEMP.md).

### 3. Reclaim space safely

Work top to bottom. Tier 1 is safe and Microsoft-supported. Stop once the machine
is back above 30 GB free with some margin.

**Production safety at a glance.** None of the steps below require cluster downtime
or a reboot. A few need light coordination:

| Action | Safe while fully in production? |
| --- | --- |
| Tier 1a: WinSxS component cleanup | Yes, no reboot. It is IO and CPU intensive and can take several minutes, so prefer a quieter period. |
| Tier 1b: clear Windows Update cache | Yes, but not while a solution update or upgrade is in progress, because it briefly stops the Windows Update and BITS services. |
| Tier 1c: remove crash dumps | Yes, deletes files only. |
| Tier 1d: clear temporary files | Yes, deletes files only. |
| Tier 2: clear large event logs | Yes for uptime, but this erases diagnostic and audit history, and clearing the Security log has compliance implications. Export first. |
| Tier 3: platform-managed areas | Do not delete. Fixing the cause has no workload impact. |

If a machine is already near zero free space and at risk of dropping out of the
cluster, treat that one machine as a maintenance action: pause and drain it first
so its workloads move to other machines, then clean up, then resume. The cluster
stays in production throughout, because the workloads live-migrate.

```powershell
Suspend-ClusterNode -Name <node> -Drain    # move workloads off this machine
# ... run the cleanup steps below ...
Resume-ClusterNode  -Name <node>           # return the machine to service
```

#### Tier 1: safe to reclaim now

**a. Clean the Windows component store (WinSxS).** This removes superseded update
components and is fully supported. It is usually the largest safe win. Safe to run
while fully in production with no reboot; it is IO and CPU intensive and can take
several minutes to complete, so prefer a quieter period. A small number of packages
can need a reboot to finish, so if the analysis still reports reclaimable packages
afterward, a maintenance reboot completes the cleanup.

```powershell
Dism.exe /Online /Cleanup-Image /StartComponentCleanup
```

**b. Clear the Windows Update download cache.** Safe to clear; Windows re-downloads
what it needs. Do not run this while a solution update or upgrade is in progress,
because it briefly stops the Windows Update (`wuauserv`) and BITS services. Outside
an active update there is no workload impact.

```powershell
Stop-Service wuauserv, bits -ErrorAction Stop
try {
    Remove-Item 'C:\Windows\SoftwareDistribution\Download\*' -Recurse -Force -ErrorAction SilentlyContinue
} finally {
    Start-Service wuauserv, bits
}
```

**c. Remove crash dumps.** Collect them first only if you have an open support case
that needs them. Safe in production; this deletes files only.

```powershell
Remove-Item C:\Windows\MEMORY.DMP -Force -ErrorAction SilentlyContinue
Remove-Item C:\Windows\Minidump\* -Force -ErrorAction SilentlyContinue
Remove-Item C:\Windows\LiveKernelReports\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue
```

**d. Clear temporary files.** Safe in production; this deletes files only, and
files in use are skipped.

```powershell
Remove-Item C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
```

#### Tier 2: diagnostic logs (reclaim with care)

Large event logs such as `Microsoft-Windows-FailoverClustering%4Diagnostic` and
`Security` can each be 1 GB or more. They hold troubleshooting history and they
regrow to their configured maximum size, so clearing them is a temporary gain.
Clearing a log needs no reboot or downtime, but it erases troubleshooting and audit
history, and clearing the Security log has compliance implications, so treat it as
a data-retention decision.

If you do not need the history, clear the log directly:

```powershell
wevtutil clear-log 'Microsoft-Windows-FailoverClustering/Diagnostic'   # example
```

If you want to keep the history, export first, then clear. Write the export to a
volume other than `C:` or to a network share, because the export is the same size
as the log (often 1 GB or more), so writing it to `C:` would consume the very space
you are trying to reclaim. Delete the export once you confirm you no longer need it.

```powershell
$log  = 'Microsoft-Windows-FailoverClustering/Diagnostic'   # example
$dest = '<NON_C_DRIVE_OR_SHARE>'                             # e.g. E:\logbackup or \\server\share (must not be C:)
New-Item -ItemType Directory $dest -Force | Out-Null
wevtutil export-log $log (Join-Path $dest (($log -replace '/','_') + '.evtx')) /overwrite:true
wevtutil clear-log $log
```

Do not disable or permanently shrink platform diagnostic logs without guidance,
because they are needed to investigate cluster issues.

#### Tier 3: platform-managed areas (do not delete; find the cause)

Some large folders are managed by the platform. Deleting them can break monitoring
or updates, and it does not fix the underlying cause.

- **`C:\GMACache` (monitoring agent cache).** A large `GMACache`, especially
  `GMACache\TelemetryCache`, usually means the machine cannot upload telemetry to
  Azure, so the data backs up on disk. The fix is to restore outbound connectivity
  and the Arc connection so the cache drains on its own. Do not delete the cache to
  free space; that loses buffered data, and the folder simply refills while
  connectivity is broken.
- **`C:\Observability`, `C:\NugetStore`, `C:\ImageComposition`, `C:\CloudContent`,
  `C:\Agents`.** These hold platform logs, solution packages, and update content.
  They are managed and rotated automatically. Do not delete them. If one of them is
  unusually large, open a support case rather than removing files.

### 4. Verify the fix

First confirm the machine is back above the minimum:

```powershell
Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}}
```

Then re-validate. You have two options.

**Fast: run just this one validator.** The Environment Checker module ships on every
Azure Local machine, so you can run this single hardware check directly and get a
result back in a few seconds, without running the full pre-update health check:

```powershell
$r = Invoke-AzStackHciHardwareValidation -Include Test-SystemDriveFreeSpace -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

A healthy machine returns `Status` of `SUCCESS` and a detail line like
`Checking Hostname <NODE> for free space on root folder path 'C:' 56 GB. Expected at least 30 GB.`
This is the quickest way to confirm your cleanup worked on the machine you just
fixed. (`-Include Test-SystemDriveFreeSpace` runs only this check; drop the
`-Include` to run the full hardware validation.)

**Authoritative: re-run the pre-update health check.** This is what the portal
readiness view and the cluster-wide result file reflect, so run it to clear the
failure everywhere it is reported. It runs the full readiness check, so allow
several minutes for the results to refresh:

```powershell
Invoke-SolutionUpdatePrecheck
```

After the re-run, **Test System Drive Free Space** should report success. You can
confirm it in any of the places listed under [Where this failure
appears](#where-this-failure-appears): the portal readiness checks, the
`AzStackHciEnvironmentChecker` event log (Event ID 17205), or the newest
`HealthCheckResult.EnvironmentChecker.*.json` on the infrastructure share.

> **The portal can show a stale failure right after you reclaim space.** The
> portal readiness view and the `HealthCheckResult.EnvironmentChecker.*.json` file
> report the result of the *last* health check, so they keep showing the failure
> until that result is refreshed, either by the pre-update health check above or by
> the next scheduled periodic health check (roughly once a day). The fast targeted
> check reflects the machine's live free space immediately, so use it to confirm
> your fix and do not wait on the portal to update.

If it still fails, repeat step 2 to see what refilled the drive. A drive that
refills quickly is usually caused by a backed-up `GMACache` (a connectivity
problem) or a runaway log, not a one-time pile of files.

## When to escalate

Open a support case if any of the following are true:

- The drive refills faster than you can reclaim it, even after you fix outbound
  connectivity.
- A platform-managed folder (Tier 3) is the dominant consumer, and you cannot find
  a connectivity or update cause.
- The machine is at or near zero free space and will not boot or stay in the
  cluster.

## Related

- [Known Issue: High Disk Space Usage in TEMP](./Known-Issue-High-Disk-Space-usage-in-TEMP.md)
- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- Azure Local low-capacity requirements:
  https://aka.ms/azurelocallowcapacityrequirements
