<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Issue Validation reports OlderThanOneDay greater than 0: folders named AzStackHci.EnvironmentChecker.* inside a folder with a random name such as abcd1234.xyz under C:\\Users\\HCIOrchestrator\\AppData\\Local\\Temp, last changed more than one day ago"
  }
}
-->

# Known Issue: High Disk Space Usage in TEMP

## Table of contents

- [Symptoms](#symptoms)
- [Cause](#cause)
- [Where you can see this problem](#where-you-can-see-this-problem)
- [Issue Validation](#issue-validation)
- [Mitigation Details](#mitigation-details)
- [Verify the fix](#verify-the-fix)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)

| | |
| --- | --- |
| Component | Environment Checker (Environment Validator) |
| Severity | Warning. The folders use disk space on the system drive (`C:`). They do not stop the node or its workloads, but if they fill the drive, the [system drive free space check](./Troubleshooting-Test-SystemDrive-Free-Space.md) fails and blocks updates. |
| Workload impact of the fix | None. The fix deletes leftover temporary folders only. It does not restart services or nodes, and it needs no maintenance window. |
| Who can fix it | An administrator of the Azure Local nodes. This is not a hardware or network issue. |
| Time | A few minutes per node. |

## Symptoms

Multiple folders exist in ```C:\Users\HCIOrchestrator\AppData\Local\Temp``` containing AzStackHci.EnvironmentChecker nuget contents.

TEMP here is the temporary files folder of the `HCIOrchestrator` account. Each leftover folder has a random name made of eight letters or numbers, a dot, and three letters or numbers (for example `abcd1234.xyz`), and contains a folder named `AzStackHci.EnvironmentChecker.<version>` with a full copy of the Environment Checker module. Over many updates, these folders can use a large amount of space on the system drive.

`HCIOrchestrator` is not a placeholder. It is the local account that Azure Local creates on each node to run the Azure Stack HCI Orchestrator Service (see [ECEAgentService or HCIOrchestrator account is locked out](../Security/TSG-Azure-Local-HCI-ECEAccount-Lockout.md)). The path is the same on every node; use it exactly as written.

## Cause

When Azure Local runs the Environment Checker health checks for a solution update, it uses the Environment Checker version in the update package. Earlier builds copied that package into a new folder with a random name in the `HCIOrchestrator` account's TEMP folder each time, and never removed it.

Current builds use one reusable folder named `AzStackHci.EnvironmentChecker.NugetsForUpdate` instead. When they run these checks, they also remove random-named folders that are more than one day old, but only from the TEMP folder on the node where the Azure Stack HCI Orchestrator Service is running at the time. Folders on the other nodes stay until the service runs these checks there, or until you remove them with the steps below, so check every node. The steps are safe on any build, so you do not need to know which build added this change.

On current builds, the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder can be present after an update. It is expected, and the steps below do not count or remove it.

## Where you can see this problem

| Administrator surface | Status | What to check |
| --- | --- | --- |
| PowerShell on each node | Shown | Run the [Issue Validation](#issue-validation) script. |
| Deployment and update logs (`C:\CloudDeployment\Logs`) | Shown | Each time the Environment Checker from an update package is unpacked, `EnvironmentValidatorFull.<date>.log` records `Installing AzStackHci.EnvironmentChecker to <folder>.` On a build without the fix, `<folder>` is one of these random-named folders. |
| Azure portal | Not evident | No system health check looks for these folders, so the portal does not list them. If they fill the system drive, the Updates page shows the [system drive free space check](./Troubleshooting-Test-SystemDrive-Free-Space.md) instead. |
| Windows event logs | Not evident | No event names these folders. |
| Cluster logs (`Get-ClusterLog`) | Not evident | The folders are not a cluster resource, so the cluster log does not record them. |
| Failover Cluster Manager | Not evident | The folders do not change any cluster role, resource, or node state. |
| Windows Admin Center on a standalone host | Not evident | The folders raise no Health Service fault, so the cluster Alerts list does not show them. |
| Windows Admin Center in the Azure portal | Not evident | The folders raise no Health Service fault, so the cluster Alerts list does not show them. |

## Issue Validation

To confirm the scenario that you are encountering is the issue documented in this article, run this script on **each node** in an elevated Windows PowerShell session (**Run as administrator**). Any administrator account on the node works; you do not need to sign in as `HCIOrchestrator`. To check every node from one session, run the script inside `Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock { ... }`; the `Node` value shows which node each result is from.

```PowerShell
$tempPath = 'C:\Users\HCIOrchestrator\AppData\Local\Temp'
$randomFileNameRegex = '^[a-z0-9]{8}\.[a-z0-9]{3}$'
$inspectionErrors = [System.Collections.ArrayList]::new()
$leftoverFolders = @(Get-ChildItem -LiteralPath $tempPath -Recurse -Filter 'AzStackHci.EnvironmentChecker.*' -Directory -ErrorAction SilentlyContinue -ErrorVariable +inspectionErrors |
    ForEach-Object { Get-Item -LiteralPath (Split-Path -Path $_.FullName -Parent) -ErrorAction SilentlyContinue -ErrorVariable +inspectionErrors } |
    Where-Object { $_.Name -match $randomFileNameRegex } |
    Sort-Object -Property FullName -Unique)
$olderThanOneDay = @($leftoverFolders | Where-Object { ((Get-Date) - $_.LastWriteTime).TotalDays -ge 1 })
$removableBytes = ($olderThanOneDay | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable +inspectionErrors } | Measure-Object -Property Length -Sum).Sum
[pscustomobject]@{
    Node              = $env:COMPUTERNAME
    InspectionErrors  = $inspectionErrors.Count
    FirstError        = if ($inspectionErrors.Count -gt 0) { $inspectionErrors[0].Exception.Message } else { '' }
    LeftoverFolders   = $leftoverFolders.Count
    OlderThanOneDay   = $olderThanOneDay.Count
    RemovableSizeGB   = [math]::Round(($removableBytes / 1GB), 2)
    SystemDriveFreeGB = [math]::Round(((Get-PSDrive -Name 'C').Free / 1GB), 2)
}
```

The script counts only the leftover folders that [Mitigation Details](#mitigation-details) can remove: random-named folders that contain an `AzStackHci.EnvironmentChecker.*` folder. It does not count the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder. It changes nothing.

- If `InspectionErrors` is more than `0`, the script could not read everything under TEMP, so the counts below can be too low. Do not use them to decide that the issue is absent or fixed. `FirstError` shows the first problem, for example access denied or a path that does not exist. Run the script again from an elevated session. If `FirstError` says the TEMP path does not exist, this node has no `HCIOrchestrator` TEMP folder and the issue is not present. Otherwise, if the errors persist, see [When to contact Microsoft support](#when-to-contact-microsoft-support).
- If `OlderThanOneDay` is more than `0`, this issue is present on the node. `RemovableSizeGB` is the space that the mitigation frees. Note it and `SystemDriveFreeGB`, and continue with [Mitigation Details](#mitigation-details) on this node.
- If `InspectionErrors` is `0`, `OlderThanOneDay` is `0`, and `LeftoverFolders` is `0`, this issue is not present on the node. Do not continue.
- If `OlderThanOneDay` is `0` but `LeftoverFolders` is more than `0`, the folders were changed in the last day and a running update can still be using them. Do not remove them now; run the script again tomorrow.

## Mitigation Details

On each node where `OlderThanOneDay` is more than `0`, run the following script in an elevated Windows PowerShell session. Use the script rather than deleting folders in TEMP by hand: it removes only the folders that match this issue.

**Changes:** deletes each random-named folder (for example `abcd1234.xyz`) under `C:\Users\HCIOrchestrator\AppData\Local\Temp` that contains an `AzStackHci.EnvironmentChecker.*` folder and was last changed more than one day ago. It does not change folders changed in the last day, folders with other names, the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder, the installed Environment Checker module, services, or workloads. The deleted folders cannot be restored, and Azure Local does not use them again, so there is nothing to roll back.

```PowerShell
$nugetName = 'AzStackHci.EnvironmentChecker'
$tempPath = 'C:\Users\HCIOrchestrator\AppData\Local\Temp'
$tempNugetFolders = Get-ChildItem -Path $tempPath -Recurse -Filter "$nugetName.*" -Directory -ErrorAction SilentlyContinue
foreach ($tnf in $tempNugetFolders)
{
    try
    {
        $randomFileNameRegex = '^[a-z0-9]{8}\.[a-z0-9]{3}$'
        $tnfParent = Split-Path -Path $tnf.FullName -Parent
        $parentFolderName = Split-Path -Path $tnfParent -Leaf
        if (-not ($parentFolderName -match $randomFileNameRegex))
        {
            Write-Host "Skipping removal of temp nuget folder $tnfParent as it does not match expected pattern."
            continue
        }
        $allowedAgeDays = 1
        $age = (Get-Date) - (Get-Item -Path $tnfParent | ForEach-Object LastWriteTime)
        if ($age.TotalDays -lt $allowedAgeDays)
        {
            Write-Host "Skipping removal of temp nuget folder $tnfParent as its last write time was $($age.TotalDays) days ago, which is less than $allowedAgeDays days."
            continue
        }
        Write-Host "Removing temp nuget folder $tnfParent"
        Remove-Item -Path $tnfParent -Recurse -Force -ErrorAction Stop
    }
    catch
    {
        Write-Host "Unable to remove temp nuget folder. Exception: $($_.Exception.GetType().FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

Expected output (no output means that the script found no `AzStackHci.EnvironmentChecker.*` folders):

- One `Removing temp nuget folder <folder>` line for each folder that it deletes.
- `Skipping removal of temp nuget folder <folder> as it does not match expected pattern.` means the script found an `AzStackHci.EnvironmentChecker.*` folder whose parent folder does not have a random name, and left it alone. If the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder is present, you see this line for it and for the TEMP folder itself. Neither one is removed.
- `Skipping removal ... less than 1 days.` means that folder was changed in the last day. It is left in place.
- `Unable to remove temp nuget folder` (in red) means a file in that folder is in use or access was denied. Run the script again later. If the same folder still cannot be removed, see [When to contact Microsoft support](#when-to-contact-microsoft-support).

This is the same rule that current builds use to remove these folders automatically, but they apply it only on the node where the Azure Stack HCI Orchestrator Service is running at the time.

## Verify the fix

Run the [Issue Validation](#issue-validation) script again on the same node, or on every node with `Invoke-Command` as described there.

- `InspectionErrors` is `0`.
- `OlderThanOneDay` is `0`.
- `SystemDriveFreeGB` is higher than before, by about the `RemovableSizeGB` value that you noted.

If `OlderThanOneDay` is still more than `0`, run the mitigation script again and read its red `Unable to remove` lines. Repeat [Issue Validation](#issue-validation) and [Mitigation Details](#mitigation-details) on each remaining node.

If the folders build up again after later updates, first check whether the cluster runs a build with the fix. Builds with the fix create the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder directly in `C:\Users\HCIOrchestrator\AppData\Local\Temp` on the node where the Azure Stack HCI Orchestrator Service runs the update checks, and earlier builds never create it. After an update, run this on each node; it returns `True` on a node that has the folder:

```PowerShell
Test-Path -LiteralPath 'C:\Users\HCIOrchestrator\AppData\Local\Temp\AzStackHci.EnvironmentChecker.NugetsForUpdate'
```

- If it returns `False` on every node, the cluster is on a build without the fix. Repeat these steps after each update until the cluster runs a build with the fix.
- If it returns `True` on any node, the cluster is on a build with the fix. Folders left from earlier updates can stay on the other nodes until you remove them once with these steps. New random-named folders that are more than one day old on a node that has the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder, or new folders that come back on every node after each update, are not expected. Do not keep repeating the cleanup; see [When to contact Microsoft support](#when-to-contact-microsoft-support).

## When to contact Microsoft support

Contact Microsoft support if any of these happen:

- The same folder still cannot be removed after you run the script again later.
- `OlderThanOneDay` is still more than `0` after the mitigation script reports no errors.
- `InspectionErrors` stays above `0` when you run Issue Validation again from an elevated session.
- On a build with the fix (a node has the `AzStackHci.EnvironmentChecker.NugetsForUpdate` folder), new random-named folders more than one day old appear on a node that has that folder, or new folders come back on every node after each update.

Include the Issue Validation output from before and after the mitigation, the mitigation script output, and the solution version from `Get-SolutionUpdateEnvironment`.
