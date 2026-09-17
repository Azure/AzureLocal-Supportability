---
ArticleType: "TSG"
Article_ID: "20260917160001"
Title: "AzStackHci_Hardware_Test_SystemDrive_Free_Space"
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
  ID: 38356876
Tags: ["Validation", "Windows Update", "Solution Update", "Cloud Deployment"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory PickleFactory metadata, audience scoping, and current article layout without changing technical guidance. |

:::

# AzStackHci_Hardware_Test_SystemDrive_Free_Space

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_SystemDrive_Free_Space</strong></td>
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

The **30 GB** value is an operational headroom floor, not space reserved for
workloads. Windows servicing and component cleanup, update staging and rollback,
temporary files, event logs, and Azure Local management agents all need working
space while an operation is in progress. Existing VMs may continue running while
the check is failing, but the management plane can no longer safely stage updates,
add nodes, or deploy extensions. If the drive reaches zero, the node itself can
become unstable.

A low system drive is a real problem, not just a warning. While the check is
failing:

- Solution (Azure Local) updates and upgrades are blocked at pre-update
  validation, so the cluster cannot be patched.
- Adding a machine to the cluster can fail validation.
- New Arc and Kubernetes extensions may fail to deploy.
- Existing workloads keep running, but the machine cannot be lifecycle-managed
  reliably, and a drive that fills to zero can destabilize the node.

This is primarily an operating-system and platform-capacity check, not proof of a
failed physical disk. If a newly provisioned machine is below 30 GB before any
workload is placed, or space cannot be restored without deleting platform-managed
content, compare the system-drive layout with the validated deployment or OEM
configuration and escalate to the deployment or hardware owner. Do not replace
hardware based on this validator alone.

## Quick path and expected duration

For a one-time low-space condition, plan for several minutes to measure the
consumer, run one or two Tier 1 actions, and run the targeted validation. DISM
and the full system-health precheck can take longer. If the drive refills during
or soon after cleanup, stop repeating cleanup and treat it as a longer
connectivity, logging, or platform-consumer investigation.

The common first pass is:

```powershell
# 1. Check the current headroom
Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}}

# 2. Reclaim superseded Windows components
Dism.exe /Online /Cleanup-Image /StartComponentCleanup

# 3. Check again before moving to the next tier
Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}}
```

If the final value is still below 30 GB, continue with the consumer inventory
and the tiered actions below. Do not delete platform-managed folders to force the
number over the threshold.

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

### Other administration surfaces

- **Cluster logs (`Get-ClusterLog`):** This validator result does not appear as a
  dedicated cluster-log fault. Use cluster logs only to investigate drain,
  membership, or node-stability symptoms.
- **Failover Cluster Manager (`cluadmin.msc`):** The check does not appear as a
  dedicated clustered role or resource fault. Use the node state and workload
  ownership views to confirm a drain, not to diagnose the 30 GB result.
- **Windows Admin Center on a standalone host:** The check does not appear as a
  dedicated validator result. Use the node PowerShell commands and the component
  logs listed below.
- **Windows Admin Center in the Azure portal:** The check does not appear as a
  dedicated WAC result. Use the Azure portal **Updates** and **Update readiness**
  views described above.
- **Component and tool log files:** The check does appear in
  `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and the
  corresponding `AzStackHciEnvironmentReport.json` or `.xml` on the node where
  the validator runs. `C:\CloudDeployment\Logs` and `C:\MASLogs` can provide
  surrounding action-plan context.

## Requirements

1. Each Azure Local machine must have at least **30 GB** free on its system drive
   (`C:`).
2. You run the steps below on the affected machine, signed in as an administrator,
   in a PowerShell session.
3. If you must drain an already deployed cluster member, confirm the cluster is
   healthy enough to lose that node temporarily and that the remaining nodes have
   capacity for its workloads.

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
| Tier 1c: remove crash dumps and WER reports | Yes, after the evidence-preservation gate; deletes files only. |
| Tier 1d: clear temporary files | Yes, deletes files only. |
| Tier 2: clear large event logs | Yes for uptime, but this erases diagnostic and audit history, and clearing the Security log has compliance implications. Export first. |
| Tier 3: platform-managed areas | Do not delete. Fixing the cause has no workload impact. |

If a machine is already near zero free space and at risk of dropping out of the
cluster, treat that one machine as a maintenance action: pause and drain it first
so its workloads move to other machines, then clean up, then resume. The cluster
can stay in production because the workloads live-migrate, but the drain consumes
capacity on the remaining nodes and can fail if the cluster is already degraded
or lacks headroom. Do not start cleanup until the drain has completed.

```powershell
Suspend-ClusterNode -Name <node> -Drain -Wait    # wait for live migration and drain completion
Get-ClusterNode -Name <node> | Select-Object Name, State
Get-ClusterGroup |
    Where-Object { $_.OwnerNode.Name -eq '<node>' -and $_.GroupType -eq 'VirtualMachine' } |
    Select-Object Name, OwnerNode, State
# ... run the cleanup steps below ...
Resume-ClusterNode  -Name <node>           # return the machine to service
```

Proceed only when the target node is `Paused` and no virtual-machine cluster
group remains owned by it. If the installed Failover Clustering module does not
support `-Wait`, run the drain without that switch and poll the two commands
above until the same conditions are true. If a workload cannot move, stop and
resolve the cluster-capacity or live-migration issue before reclaiming space.

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

**c. Preserve then remove crash dumps and WER reports.** These files can explain
why the drive filled or provide evidence for an existing incident. Before
deleting them, check the active IcM, SR, or support case with its owner. If a case
exists, the node recently rebooted or bugchecked, or you are unsure, preserve the
files and do not delete them. Copy them to a non-`C:` volume or network share,
verify the copy, and only then run the deletion block. If the copy or hash
verification fails, leave the originals in place and use another Tier 1 action.

```powershell
$evidenceDestination = '<NON_C_DRIVE_OR_SHARE>'  # must not be C:
$evidenceRoot = Join-Path $evidenceDestination (
    "SystemDriveEvidence_{0}_{1}" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMddHHmmss')
)
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

$evidencePaths = @(
    'C:\Windows\MEMORY.DMP',
    'C:\Windows\Minidump',
    'C:\Windows\LiveKernelReports',
    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
)

foreach ($path in $evidencePaths) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination $evidenceRoot -Recurse -Force -ErrorAction Stop
    }
}

Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File |
    Get-FileHash -Algorithm SHA256
```

```powershell
# Run only after the evidence copy completed and the case/evidence check is clear.
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

**Run Tier 1 across all nodes at once.** For at-scale deployment prep, fan the Tier 1
reclamation out to every machine in the cluster with a single `Invoke-Command` instead of
repeating it node by node. For example, the WinSxS component cleanup (Tier 1a, the largest
safe win):

```powershell
# -ThrottleLimit caps how many nodes run this IO/CPU-intensive cleanup at once, so the
# cluster does not spike all at once; the returned per-node exit code confirms success
# (0 = succeeded). Raise the throttle only if the cluster has headroom.
Invoke-Command -ComputerName (Get-ClusterNode).Name -ThrottleLimit 2 -ScriptBlock {
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup
    [pscustomobject]@{ Node = $env:COMPUTERNAME; ExitCode = $LASTEXITCODE }
} | Sort-Object Node | Format-Table -AutoSize
```

Wrap any of the Tier 1 a-d commands the same way. Do not fan out the Windows Update cache
clear (Tier 1b) while a solution update or upgrade is in progress, because it briefly stops
the `wuauserv` and BITS services on every node.

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
  and the Arc connection so the cache drains on its own. Concretely, that means
  restoring the node's outbound HTTPS (TCP 443) to the Azure Arc and Azure Local
  service endpoints (see the [Azure Local firewall and outbound connectivity
  requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements))
  and confirming the Arc agent is connected (`(azcmagent show -j | ConvertFrom-Json).status`
  returns `Connected`). Do not delete the cache to
  free space; that loses buffered data, and the folder simply refills while
  connectivity is broken.

  Use this quick node-side check before handing the issue to the network or
  connectivity owner:

  ```powershell
  Test-NetConnection management.azure.com -Port 443 |
      Select-Object ComputerName, RemotePort, TcpTestSucceeded
  (azcmagent show -j | ConvertFrom-Json) |
      Select-Object status, lastStatusChange
  ```

  `TcpTestSucceeded` should be `True` and the Arc status should be `Connected`.
  This is a first signal, not a replacement for checking every endpoint in the
  firewall requirements.
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

The targeted include name is the validator name used by this guide. Result names
in the event log and portal can differ by build, as described above. If a build
does not accept the targeted include, run the full hardware validation and filter
for either `SystemDriveFreeSpace` or `Test_SystemDrive_Free_Space`; a missing
targeted result is not evidence that the check passed.

**Authoritative: re-run the pre-update health check.** This is what the portal
readiness view and the cluster-wide result file reflect, so run it to clear the
failure everywhere it is reported. It runs the full readiness check, so allow
several minutes for the results to refresh:

```powershell
# Trigger a fresh system health check. The switch is required to re-run the checks.
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then verify that the result is current and healthy.
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is what re-runs the health checks; a bare
`Invoke-SolutionUpdatePrecheck` does not re-evaluate them. After the re-run,
**Test System Drive Free Space** should report success. You can
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

## Glossary

- **Component store (WinSxS):** Windows' serviced component repository. DISM
  removes superseded components while retaining the versions needed for the
  current operating system and supported rollback paths.
- **BITS:** Background Intelligent Transfer Service, used with Windows Update to
  transfer update content. Stopping it briefly is why the update-cache cleanup
  must not run during an active solution update.
- **`GMACache` / `TelemetryCache`:** Buffered monitoring data waiting to upload.
  It is a symptom of an upload or connectivity problem, not disposable platform
  clutter.
- **Management plane:** The Azure Local update, deployment, Arc, and extension
  workflows that validate and service the cluster. These workflows can be blocked
  even while existing VM workloads continue to run.

## When to escalate

Open a support case if any of the following are true:

- The drive refills faster than you can reclaim it, even after you fix outbound
  connectivity.
- A platform-managed folder (Tier 3) is the dominant consumer, and you cannot find
  a connectivity or update cause.
- The machine is at or near zero free space and will not boot or stay in the
  cluster.

::: audience-css

# Source Articles

- [Known Issue: High Disk Space Usage in TEMP](./Known-Issue-High-Disk-Space-usage-in-TEMP.md)
- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- Azure Local low-capacity requirements:
  https://aka.ms/azurelocallowcapacityrequirements

:::
