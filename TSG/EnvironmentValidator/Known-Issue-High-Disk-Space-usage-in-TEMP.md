# Known Issue: High Disk Space Usage in TEMP

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width:180px;">ArticleType</th>
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
    <th style="text-align:left;">Component</th>
    <td><strong>Environment Checker extraction content under the HCIOrchestrator profile</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Warning</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td><strong>Deployment, Add Node, and update readiness when local TEMP growth is observed</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Execution surface</th>
    <td><strong>On-device PowerShell on each affected node</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Owner and handoff</th>
    <td><strong>Cluster administrator for scoped cleanup; CSS or the Environment Validator owner when the gates fail</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td><strong>[LOW RISK]</strong> inventory and preview; <strong>[MEDIUM RISK]</strong> deletion of an eligible extraction parent only after the documented gates pass</td>
  </tr>
</table>

## Overview

Environment Checker and related deployment or readiness activity can leave versioned
NuGet extraction folders under the HCIOrchestrator profile's local TEMP directory.
When those folders accumulate, they consume local system-drive space. This guide
provides a read-only inventory, a dry-run manifest, and a guarded cleanup path that
targets only an eligible extraction parent under the exact TEMP root.

The cleanup is local to one node. It does not repair storage pools, change cluster
configuration, stop services, or modify network, firmware, OEM, or workload data.
The one-day age check is a safety heuristic, not proof that a folder is inactive.

## Symptoms

Look for one or more of these symptoms on the affected node:

- Multiple directories whose names begin with
  `AzStackHci.EnvironmentChecker.` exist below
  `C:\Users\HCIOrchestrator\AppData\Local\Temp`.
- The system drive has less free space than expected, and the inventory below
  attributes some of the usage to those extraction parents.
- A deployment, Add Node, or update-readiness operation reports a local capacity
  problem after the TEMP folders have accumulated.

Folder count alone does not establish that cleanup is safe. Use the inventory to
capture each parent path, last-write age, estimated size, and system-drive free
space before deciding whether to reclaim anything.

## Impact, scope, and success criteria

| Item | Guidance |
|---|---|
| Customer impact | The folders can reduce system-drive headroom and may contribute to a capacity-related readiness or deployment failure. This article does not establish a universal free-space threshold. |
| Service or workload effect | The documented cleanup does not stop services, drain nodes, change CSVs, touch virtual machines, or alter customer data. A locked or active folder must remain untouched. |
| Maintenance need | Perform the apply step on one node at a time after confirming that no deployment, update, precheck, or Environment Checker operation is active. |
| Success criteria | The reviewed candidate list is empty after cleanup, the exact TEMP root contains no eligible extraction parent, and the post-cleanup system-drive measurement is no lower than the pre-cleanup measurement. |
| Ownership | The cluster administrator owns the local cleanup. Route a blocked deletion, unexplained low space, or a failed readiness check to CSS or the Environment Validator owner with the evidence bundle below. |
| Effort | Read-only inventory is normally short. Review, cleanup, and revalidation are performed serially per node. Do not fan out deletion in parallel. |

## Before you start

1. Use an elevated PowerShell session on the node. If the node is part of a
   cluster, obtain the node list with `Get-ClusterNode` and process nodes
   serially. For a host that is not yet a cluster member, run the same steps
   locally.
2. Confirm that no deployment, Add Node, update, pre-update health check, or
   Environment Checker operation is using the TEMP path. Review the current
   action plan and readiness state before setting the apply confirmation in the
   cleanup script. Do not stop a service to make deletion succeed.
3. Capture the read-only inventory and preserve its JSON output. The inventory
   is the dry-run manifest. Review every candidate path and skip any path that
   is newer than one day, outside the exact TEMP root, a reparse-point tree,
   inaccessible, or associated with an active operation.
4. Do not broaden the path, change the parent-name pattern, use a drive-root
   delete, take ownership of a locked file, or delete a child folder directly.
   If the script reports an access or lock error, preserve the error and escalate
   it rather than retrying with a more forceful command.

## Issue validation

Run this read-only inventory on each affected node. It reports the exact root,
candidate parents, last-write age, estimated bytes, skipped paths, and system-drive
free space. It does not remove anything.

```powershell
$ErrorActionPreference = 'Stop'
$nugetName = 'AzStackHci.EnvironmentChecker'
$tempPath = Join-Path $env:SystemDrive 'Users\HCIOrchestrator\AppData\Local\Temp'
$parentNamePattern = '^[a-z0-9]{8}\.[a-z0-9]{3}$'
$minimumAgeDays = 1

if (-not (Test-Path -LiteralPath $tempPath -PathType Container))
{
    throw "The expected TEMP directory was not found: $tempPath"
}

$tempRoot = (Get-Item -LiteralPath $tempPath -Force).FullName.TrimEnd('\')
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
if (-not $disk)
{
    throw "Could not read free space for $($env:SystemDrive)."
}

$candidates = @()
$skipped = @()
$seenParents = @{}
$matchingFolders = @(Get-ChildItem -LiteralPath $tempRoot -Recurse -Filter "$nugetName.*" -Directory -Force -ErrorAction SilentlyContinue)

foreach ($folder in $matchingFolders)
{
    try
    {
        $parentPath = Split-Path -LiteralPath $folder.FullName -Parent
        $parent = Get-Item -LiteralPath $parentPath -Force -ErrorAction Stop
        $parentFullName = $parent.FullName.TrimEnd('\')

        if ($parentFullName -eq $tempRoot -or -not $parentFullName.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase))
        {
            $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'outside exact TEMP root' }
            continue
        }
        if ($parent.Name -notmatch $parentNamePattern)
        {
            $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'parent name does not match the expected extraction pattern' }
            continue
        }
        if ($seenParents.ContainsKey($parentFullName))
        {
            continue
        }
        $seenParents[$parentFullName] = $true

        $ageDays = ((Get-Date) - $parent.LastWriteTime).TotalDays
        if ($ageDays -lt $minimumAgeDays)
        {
            $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = "parent is newer than $minimumAgeDays day(s)" }
            continue
        }
        if (($parent.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        {
            $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'parent is a reparse point' }
            continue
        }

        $entries = @(Get-ChildItem -LiteralPath $parentFullName -Recurse -Force -ErrorAction Stop)
        if (@($entries | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 }).Count -gt 0)
        {
            $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'tree contains a reparse point' }
            continue
        }

        $bytes = [int64]0
        foreach ($entry in @($entries | Where-Object { -not $_.PSIsContainer }))
        {
            $bytes += [int64]$entry.Length
        }

        $candidates += [pscustomobject]@{
            NugetFolder = $folder.FullName
            ParentPath = $parentFullName
            LastWriteTimeUtc = $parent.LastWriteTimeUtc
            AgeDays = [math]::Round($ageDays, 2)
            EstimatedBytes = $bytes
        }
    }
    catch
    {
        $skipped += [pscustomobject]@{
            Path = $folder.FullName
            Reason = "inventory failed: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
        }
    }
}

[pscustomobject]@{
    ObservedAtUtc = (Get-Date).ToUniversalTime()
    TempRoot = $tempRoot
    CandidateCount = $candidates.Count
    Candidates = @($candidates)
    Skipped = @($skipped)
    SystemDriveFreeBytes = [int64]$disk.FreeSpace
    SystemDriveFreeGiB = [math]::Round(([int64]$disk.FreeSpace / 1GB), 2)
} | ConvertTo-Json -Depth 7
```

An empty candidate list is not proof that the system drive is healthy. It means
that this specific folder pattern was not found under the exact TEMP root. If
free space remains low, investigate other consumers with the standard OS and
storage diagnostics instead of widening this cleanup.

### Serial per-node inventory

For a deployed cluster, use this read-only loop from an elevated PowerShell
session to report every currently-up node. It does not delete anything. A node
with an operation signal is reported and skipped for apply; review that node
again after the operation ends. The operation-signal list is a reason to defer,
not proof that a process is safe to stop.

```powershell
$nodes = @(Get-ClusterNode | Where-Object { $_.State -eq 'Up' } | Select-Object -ExpandProperty Name)
if ($nodes.Count -eq 0)
{
    throw 'No Up cluster nodes were found.'
}

foreach ($node in $nodes)
{
    try
    {
        $result = Invoke-Command -ComputerName $node -ScriptBlock {
            $tempPath = Join-Path $env:SystemDrive 'Users\HCIOrchestrator\AppData\Local\Temp'
            $nugetName = 'AzStackHci.EnvironmentChecker'
            $busyProcessNames = @(
                'DeploymentLauncherService.exe',
                'LcmController.exe',
                'Microsoft.AzureStack.HciOrchestratorService.WinSvcHost.exe'
            )
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
            $operationSignals = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
                Where-Object {
                    ($busyProcessNames -contains $_.Name) -and
                    ($_.CommandLine -match '(?i)EnvironmentChecker|PreUpdate|SolutionUpdate|Deployment|Update')
                } |
                Select-Object -ExpandProperty Name -Unique)
            $matchingFolders = @(Get-ChildItem -LiteralPath $tempPath -Recurse -Filter "$nugetName.*" -Directory -Force -ErrorAction SilentlyContinue)

            [pscustomobject]@{
                Node = $env:COMPUTERNAME
                TempPath = $tempPath
                CandidateCount = $matchingFolders.Count
                CandidateParents = @($matchingFolders | ForEach-Object { Split-Path -LiteralPath $_.FullName -Parent } | Sort-Object -Unique)
                OperationSignals = @($operationSignals)
                SystemDriveFreeGiB = if ($disk) { [math]::Round(([int64]$disk.FreeSpace / 1GB), 2) } else { $null }
            }
        }

        if (@($result.OperationSignals).Count -gt 0)
        {
            Write-Host "SKIP apply on $($result.Node): operation signal(s) $($result.OperationSignals -join ', ')." -ForegroundColor Yellow
        }
        $result
    }
    catch
    {
        Write-Error "Inventory failed on ${node}: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    }
}
```

Use the detailed inventory and guarded apply block on each reported node. After
all nodes are clean, rerun the readiness check that originally exposed the
condition. This loop intentionally does not run deletion remotely or in
parallel.

## Where this failure appears

- **PowerShell on the node:** the read-only inventory above is the authoritative
  local view for this issue. It shows candidate parents, age, estimated bytes,
  skipped paths, and system-drive free space.
- **Component / tool log files:** when a deployment or readiness operation wrote
  supporting evidence, inspect the running account's
  `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and
  `AzStackHciEnvironmentReport.json` or `.xml`. These files are supporting
  evidence only; the current scratch validation did not verify a real-candidate
  log entry.
- **Azure portal:** this folder-level condition does not appear in the Azure
  portal as a TEMP directory listing. The portal may show a later generic
  readiness or capacity failure, but use node PowerShell for the folder evidence.
- **Windows event logs:** this cleanup condition does not record a dedicated
  Windows event log entry or Event ID. Preserve any separate readiness event as
  supporting evidence, not as proof that a particular TEMP folder is stale.
- **Cluster logs:** this condition is not evident in the cluster logs because it
  is local file-system usage, not a failover-cluster event.
- **Failover Cluster Manager:** the condition is not evident in Failover Cluster
  Manager because it is not a clustered role, resource, or node-membership
  state.
- **Windows Admin Center on a standalone host:** the condition is not evident in
  Windows Admin Center on a standalone host; use the node inventory instead.
- **Windows Admin Center in Azure:** the condition is not evident in Windows
  Admin Center in Azure; use the node inventory instead.

## Mitigation details

The apply script below intentionally defaults to preview mode. It writes a
manifest, reports matching long-running orchestration processes for operator
review, and refuses to delete anything until both gates are changed explicitly:

- `$PreviewOnly = $false` is set only after the manifest has been reviewed.
- `$ConfirmedNoActiveOperation = $true` is set only after deployment, update,
  precheck, and Environment Checker activity has been ruled out.

The process list is a safety signal, not proof that an operation is active or
inactive. The script does not stop processes and does not claim to prove that
every file handle is closed. If a delete fails because a file is locked or
inaccessible, the script records the exception and leaves the parent in place.

```powershell
$ErrorActionPreference = 'Stop'
$nugetName = 'AzStackHci.EnvironmentChecker'
$tempPath = Join-Path $env:SystemDrive 'Users\HCIOrchestrator\AppData\Local\Temp'
$parentNamePattern = '^[a-z0-9]{8}\.[a-z0-9]{3}$'
$minimumAgeDays = 1
$PreviewOnly = $true
$ConfirmedNoActiveOperation = $false
$manifestPath = Join-Path $env:TEMP 'AzStackHci-EnvironmentChecker-TEMP-cleanup-manifest.json'
$busyProcessNames = @(
    'DeploymentLauncherService.exe',
    'LcmController.exe',
    'Microsoft.AzureStack.HciOrchestratorService.WinSvcHost.exe'
)

function Get-TempCleanupInventory
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$NugetName,
        [Parameter(Mandatory = $true)]
        [string]$TempPath,
        [Parameter(Mandatory = $true)]
        [string]$ParentNamePattern,
        [Parameter(Mandatory = $true)]
        [int]$MinimumAgeDays
    )

    if (-not (Test-Path -LiteralPath $TempPath -PathType Container))
    {
        throw "The expected TEMP directory was not found: $TempPath"
    }

    $tempRoot = (Get-Item -LiteralPath $TempPath -Force).FullName.TrimEnd('\')
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    if (-not $disk)
    {
        throw "Could not read free space for $($env:SystemDrive)."
    }

    $candidates = @()
    $skipped = @()
    $seenParents = @{}
    $matchingFolders = @(Get-ChildItem -LiteralPath $tempRoot -Recurse -Filter "$NugetName.*" -Directory -Force -ErrorAction SilentlyContinue)

    foreach ($folder in $matchingFolders)
    {
        try
        {
            $parentPath = Split-Path -LiteralPath $folder.FullName -Parent
            $parent = Get-Item -LiteralPath $parentPath -Force -ErrorAction Stop
            $parentFullName = $parent.FullName.TrimEnd('\')

            if ($parentFullName -eq $tempRoot -or -not $parentFullName.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'outside exact TEMP root' }
                continue
            }
            if ($parent.Name -notmatch $ParentNamePattern)
            {
                $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'parent name does not match the expected extraction pattern' }
                continue
            }
            if ($seenParents.ContainsKey($parentFullName))
            {
                continue
            }
            $seenParents[$parentFullName] = $true

            $ageDays = ((Get-Date) - $parent.LastWriteTime).TotalDays
            if ($ageDays -lt $MinimumAgeDays)
            {
                $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = "parent is newer than $MinimumAgeDays day(s)" }
                continue
            }
            if (($parent.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
            {
                $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'parent is a reparse point' }
                continue
            }

            $entries = @(Get-ChildItem -LiteralPath $parentFullName -Recurse -Force -ErrorAction Stop)
            if (@($entries | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 }).Count -gt 0)
            {
                $skipped += [pscustomobject]@{ Path = $parentFullName; Reason = 'tree contains a reparse point' }
                continue
            }

            $bytes = [int64]0
            foreach ($entry in @($entries | Where-Object { -not $_.PSIsContainer }))
            {
                $bytes += [int64]$entry.Length
            }

            $candidates += [pscustomobject]@{
                NugetFolder = $folder.FullName
                ParentPath = $parentFullName
                LastWriteTimeUtc = $parent.LastWriteTimeUtc
                AgeDays = [math]::Round($ageDays, 2)
                EstimatedBytes = $bytes
            }
        }
        catch
        {
            $skipped += [pscustomobject]@{
                Path = $folder.FullName
                Reason = "inventory failed: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject]@{
        ObservedAtUtc = (Get-Date).ToUniversalTime()
        TempRoot = $tempRoot
        CandidateCount = $candidates.Count
        Candidates = @($candidates)
        Skipped = @($skipped)
        SystemDriveFreeBytes = [int64]$disk.FreeSpace
        SystemDriveFreeGiB = [math]::Round(([int64]$disk.FreeSpace / 1GB), 2)
    }
}

$activeProcesses = @()
$processProbeError = $null
try
{
    $activeProcesses = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
        Where-Object { $busyProcessNames -contains $_.Name } |
        Select-Object Name, ProcessId, CommandLine)
}
catch
{
    $processProbeError = "$($_.Exception.GetType().FullName): $($_.Exception.Message)"
}

$before = Get-TempCleanupInventory -NugetName $nugetName -TempPath $tempPath -ParentNamePattern $parentNamePattern -MinimumAgeDays $minimumAgeDays
$before | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Manifest written to $manifestPath"
Write-Host "Candidate count: $($before.CandidateCount)"
$before.Candidates | Format-Table ParentPath, AgeDays, EstimatedBytes, LastWriteTimeUtc
$before.Skipped | Format-Table Path, Reason
if ($processProbeError)
{
    Write-Host "Process probe failed: $processProbeError" -ForegroundColor Yellow
}
else
{
    $activeProcesses | Format-Table Name, ProcessId, CommandLine -Wrap
}

if ($PreviewOnly)
{
    Write-Host 'Preview only. No folders were removed.'
}
else
{
    if (-not $ConfirmedNoActiveOperation)
    {
        throw 'STOP: set ConfirmedNoActiveOperation to true only after reviewing the action plan and process evidence.'
    }
    if ($processProbeError)
    {
        throw 'STOP: the process safety probe failed, so cleanup cannot proceed.'
    }

    $results = @()
    foreach ($candidate in @($before.Candidates))
    {
        try
        {
            Remove-Item -LiteralPath $candidate.ParentPath -Recurse -Force -ErrorAction Stop
            $results += [pscustomobject]@{
                ParentPath = $candidate.ParentPath
                Action = 'Removed'
                EstimatedBytes = $candidate.EstimatedBytes
                Error = $null
            }
        }
        catch
        {
            $message = "$($_.Exception.GetType().FullName): $($_.Exception.Message)"
            Write-Warning "Unable to remove $($candidate.ParentPath): $message"
            $results += [pscustomobject]@{
                ParentPath = $candidate.ParentPath
                Action = 'Preserved'
                EstimatedBytes = $candidate.EstimatedBytes
                Error = $message
            }
        }
    }

    $after = Get-TempCleanupInventory -NugetName $nugetName -TempPath $tempPath -ParentNamePattern $parentNamePattern -MinimumAgeDays $minimumAgeDays
    $after | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath ($manifestPath + '.after.json') -Encoding UTF8
    [pscustomobject]@{
        BeforeCandidateCount = $before.CandidateCount
        AfterCandidateCount = $after.CandidateCount
        BeforeFreeBytes = $before.SystemDriveFreeBytes
        AfterFreeBytes = $after.SystemDriveFreeBytes
        Results = @($results)
        After = $after
    } | ConvertTo-Json -Depth 8
}
```

The apply path removes only the parent selected by the exact root, parent-name,
age, and reparse-point gates. It de-duplicates parents when multiple matching
NuGet folders exist under one extraction. It never removes a drive root or a
child outside the selected parent.

## Verify the fix

Run the read-only inventory again on the same node, then repeat it on every node.
Confirm all of the following:

1. The candidate count is zero, or every remaining path is listed under
   `Skipped` with an actionable reason.
2. The post-cleanup free-space value is not lower than the pre-cleanup value.
3. Any `Preserved` result has its full exception type and message recorded in the
   evidence bundle. Do not retry a locked path by stopping services or weakening
   the path guards.
4. If the issue was observed during update readiness, trigger a fresh system
   health check and verify the resulting state:

   ```powershell
   Invoke-SolutionUpdatePrecheck -SystemHealth
   Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
   ```

   The expected state is `Success` or `InProgress`, not `Failure`. Use the
   operation-specific readiness command when this article was not the original
   failure.
5. If free space remains low while this inventory is empty, stop using this
   cleanup and investigate the other system-drive consumers with the standard
   OS and storage diagnostics.

## Evidence bundle and escalation

Keep the following for CSS or the Environment Validator owner when the issue is
not resolved:

- The before and after JSON manifests.
- Node name, UTC timestamps, OS build, system-drive free-space values, candidate
  paths, estimated bytes, skipped reasons, and preserved exception messages.
- The readiness or action-plan result that motivated the cleanup, if applicable.
- The process review output. State explicitly whether any process was stopped,
  which this guide requires to be none.

Escalate instead of deleting when the TEMP path is missing, the process probe
fails, the parent is newer than one day, a reparse point is present, inventory
cannot read the tree, a file is locked, the candidate count is zero but system
space is still low, or the readiness failure persists after revalidation.

## Scope boundaries

This is a local TEMP extraction issue, not a network or hardware diagnosis. Do
not change NIC, DNS, RDMA, firewall, firmware, BIOS, BMC, storage-controller,
CSV, virtual-machine, or OEM settings as part of this procedure. If the
evidence points to network behavior, route it to the network owner. If it points
to physical media or firmware health, route it to the OEM or hardware owner.
If the evidence points to another system-drive consumer, route it to the OS and
storage troubleshooting path.

## Validation fidelity

The current review established static PowerShell structure and a scratch-only
validation of the detector's exact TEMP root, parent-name pattern, one-day age
gate, recursive deletion shape, and residue checks. The lab guest had zero real
matching folders, so no platform-managed or customer-like candidate was deleted,
no service was stopped, and no real reclaimed-space threshold was measured.
This evidence supports the documented safety boundaries, but it is not a live
proof of customer-like cleanup or a claim that every extraction is stale.