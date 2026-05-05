# 2604 update fails with Previous CAU run status was Canceled

During Host OS updates on Azure Local 2604, if the first CAU (Cluster-Aware Updating) run fails or times out, subsequent retry attempts are terminated within approximately 10 minutes without making progress. The update fails with "Exceeded max CAU retries" despite the retries executing only a small portion of the CAU before terminating. This is caused by a leftover breadcrumb file that is not cleaned up between retry attempts, causing all wait-monitoring steps to be skipped.

## Symptoms

- An Azure Local cluster update on version 12.2604.x fails during the Host OS update phase.
- The first CAU run may fail or time out for any reason (e.g., node reboot timeout, storage health issue, transient failure).
- The retry attempt completes very quickly (~10 minutes) instead of the expected duration for a full CAU run.
- The update fails with the following error in ECE logs and the overall update exception message:

```
  Type 'EvalCauRetryApplicability' of Role 'CAU' raised an exception:
  CAU Run failed. Previous CAU run status was Canceled. Exceeded max CAU retries (2).
  Please investigate before retrying.
```

- Resuming the update results in the same rapid failure pattern.

## Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following behavior(s)

### Failure/Errors seen on Portal/CLI

See the error message associated with the update, which will contain this message:
```
CAU Run failed. Previous CAU run status was Canceled. Exceeded max CAU retries (2). Please investigate before retrying.
```

You should be able to see the failure pattern in the CAU reports.

```powershell
function GetCauError ($cauReport)
{
    $cauReportError = $cauReport.ClusterResult.ErrorRecordData
    $nodeResults = $cauReport.ClusterResult.NodeResults
    $cauReportStatus = $cauReport.ClusterResult.Status
    $overallErrorMessage = "The latest cluster update status is '$cauReportStatus'."
    if (($null -ne $cauReportError) -and ($null -ne $cauReportError.FullyQualifiedErrorId))
    {
        $fullyQualifiedErrorString = $cauReportError.FullyQualifiedErrorId
        $overallErrorMessage += " The overall FullyQualifiedErrorId is '$fullyQualifiedErrorString'."
    }

    foreach ($nodeResult in $nodeResults)
    {
        if ($nodeResult.Status -like "*Failed")
        {
            if (($null -ne $nodeResult.ErrorRecordData) -and ($null -ne $($nodeResult.ErrorRecordData).ExceptionData))
            {
                $nodeErrorMessage = $nodeResult.ErrorRecordData.ExceptionData
                $overallErrorMessage += " The node '$($nodeResult.Node.NodeName)' failed to update. The error message is '$nodeErrorMessage'."
            }
            else
            {
                $overallErrorMessage += " The node '$($nodeResult.Node.NodeName)' failed to update."
            }
            $failures = $nodeResult.InstallResults | Where-Object {$_.UpdateResultCode -eq "Failed"}
            $msg = ("Failed CAU updates on node $($nodeResult.Node.NodeName):`n" + ($failures | Format-List * | Out-String))
            $overallErrorMessage += $msg

            # create more compressed version to include in overall message
            $installFailMsg = (" Failed update list -- " + ( $failures | Select-Object -Property UpdateTitle, UpdateId, ErrorCode | ConvertTo-Json -Compress))
            $overallErrorMessage += $installFailMsg
        }
    }

    return $overallErrorMessage
}


$earliestRun = Get-SolutionUpdate  | ? State -eq "InstallationFailed" | ? Version -match "12.2604" | Get-SolutionUpdateRun | sort TimeStarted | select -First 1
if (-not $earliestRun) {
     Write-Warning "Unable to find the earliest run for a Solution update in InstallationFailed state matching the 2604 version."
} else {
    $reports = Get-CauReport -Detailed  | ? { $_.ClusterResult.StartTimestamp -gt $earliestRun.TimeStarted }
    $reports | % { $reportError = GetCauError $_; Write-Host "CAU run from $($_.ClusterResult.StartTimestamp) failure: $reportError" }   
}
```

Sample output is below. The first CAU run in this case contains the actual reason CAU failed the first time, while subsequent runs would just show the Canceled status.

```
CAU run from 04/28/2026 00:20:05 failure: The latest cluster update status is 'PartiallyFailed'. The node 'ASRR1N35R12U01' failed to update. The error message is 'System.Management.Automation.RemoteException: The requested operation cannot be completed because a resource has locked status.'. Failed update list --
CAU run from 04/28/2026 01:56:33 failure: The latest cluster update status is 'Canceled'.
```

### PowerShell script

Run the following on a cluster node to check for the leftover breadcrumb file:

```Powershell
# Check for the leftover MsuHostUpdate breadcrumb that causes wait steps to skip
$csvBasePath = $env:InfraCSVRootFolderPath
if (-not [string]::IsNullOrEmpty($csvBasePath))
{
    $breadcrumb = Join-Path -Path $csvBasePath -ChildPath "CloudMedia\MsuHostUpdate\Staged\Metadata\cauFailureInfo.txt"
    if (Test-Path -Path $breadcrumb)
    {
        Write-Warning "CONFIRMED: Leftover MsuHostUpdate breadcrumb found at: $breadcrumb"
        Write-Host "Content: $(Get-Content -Path $breadcrumb)"
        Write-Host ""
        Write-Host "This breadcrumb will cause all CAU wait steps to skip on retry."
    }
    else
    {
        Write-Host "No leftover MsuHostUpdate breadcrumb found. This issue may not apply."
    }
}
else
{
    Write-Warning "InfraCSVRootFolderPath environment variable is not set."
}
```

## Cause

**Breadcrumb path mismatch between cleanup and wait-step evaluation.**

When a Host OS update is performed via the HotfixPlugin CAU path (introduced in 2604), the SBE dynamic wait steps use `UpdateType="MsuHostUpdate"` and write their `cauFailureInfo.txt` breadcrumb to `<CSVBasePath>\CloudMedia\MsuHostUpdate\Staged\Metadata\`.

On retry, `InvokeCauRunForMsuUpdate` (CAU.psm1) only cleans up the **SBE-typed** breadcrumb at a different path (`SBEContentPaths.RelativePaths.CSVStagedMetadataPath`). The MsuHostUpdate breadcrumb is never cleaned up.

When the SBE dynamic wait steps are regenerated for the retry, each step's evaluation (`Expand-SingleCauStep`) finds the leftover `cauFailureInfo.txt` and returns "Skip". All wait steps (~nodes × stages) skip immediately in ~10 minutes of ECE overhead. `CauPostCheck` then sees the just-started CAU run still in progress and cancels it. `EvalCauRetryApplicability` sees "Canceled" status and exhausts the max retry count.

The SBE partner CAU path correctly calls `Repair-BeforeCauRetry` which handles this cleanup, but the CAU role's `EvalCauRetryApplicability` does not use that helper.

## Mitigation Details

First, check the details of the initial CAU failure (see `Issue Validation` section) and diagnose/remediate the underlying CAU failure. Then, when you are ready to re-try the CAU run, remove or rename the leftover breadcrumb file on a cluster node:

- Identify the breadcrumb file location
- Remove or rename it
- Resume the update (commented out line to resume is in the script below - uncomment if you intend to resume the update.)

```Powershell
# Run on any cluster node to remove the leftover breadcrumb and allow retry to work correctly

function GetCauError ($cauReport)
{
    $cauReportError = $cauReport.ClusterResult.ErrorRecordData
    $nodeResults = $cauReport.ClusterResult.NodeResults
    $cauReportStatus = $cauReport.ClusterResult.Status
    $overallErrorMessage = "The latest cluster update status is '$cauReportStatus'."
    if (($null -ne $cauReportError) -and ($null -ne $cauReportError.FullyQualifiedErrorId))
    {
        $fullyQualifiedErrorString = $cauReportError.FullyQualifiedErrorId
        $overallErrorMessage += " The overall FullyQualifiedErrorId is '$fullyQualifiedErrorString'."
    }

    foreach ($nodeResult in $nodeResults)
    {
        if ($nodeResult.Status -like "*Failed")
        {
            if (($null -ne $nodeResult.ErrorRecordData) -and ($null -ne $($nodeResult.ErrorRecordData).ExceptionData))
            {
                $nodeErrorMessage = $nodeResult.ErrorRecordData.ExceptionData
                $overallErrorMessage += " The node '$($nodeResult.Node.NodeName)' failed to update. The error message is '$nodeErrorMessage'."
            }
            else
            {
                $overallErrorMessage += " The node '$($nodeResult.Node.NodeName)' failed to update."
            }
            $failures = $nodeResult.InstallResults | Where-Object {$_.UpdateResultCode -eq "Failed"}
            $msg = ("Failed CAU updates on node $($nodeResult.Node.NodeName):`n" + ($failures | Format-List * | Out-String))
            $overallErrorMessage += $msg

            # create more compressed version to include in overall message
            $installFailMsg = (" Failed update list -- " + ( $failures | Select-Object -Property UpdateTitle, UpdateId, ErrorCode | ConvertTo-Json -Compress))
            $overallErrorMessage += $installFailMsg
        }
    }

    return $overallErrorMessage
}

$earliestRun = Get-SolutionUpdate  | ? State -eq "InstallationFailed" | ? Version -match "12.2604" | Get-SolutionUpdateRun | sort TimeStarted | select -First 1
if (-not $earliestRun) {
     throw "Unable to find the earliest run for a Solution update in InstallationFailed state matching the 2604 version."
} else {
    $reports = Get-CauReport -Detailed  | ? { $_.ClusterResult.StartTimestamp -gt $earliestRun.TimeStarted }
    $reports | % { $reportError = GetCauError $_; Write-Host "CAU run from $($_.ClusterResult.StartTimestamp) failure: $reportError" }   
}
  
$response = Read-Host "Have you examined the original CAU failure and remediated the underlying failure cause? (Y/N)"  
if ($response -match '^[Yy]$' ) {
    $csvBasePath = $env:InfraCSVRootFolderPath
    $breadcrumbPath = Join-Path -Path $csvBasePath -ChildPath "CloudMedia\MsuHostUpdate\Staged\Metadata\cauFailureInfo.txt"

    if (Test-Path -Path $breadcrumbPath)
    {
        $archiveName = "cauFailureInfo-$(Get-Date -Format 'yyyyMMdd-HHmmssZ').txt"
        Write-Host "Renaming breadcrumb to: $archiveName"
        Rename-Item -Path $breadcrumbPath -NewName $archiveName -Force
        Write-Host "Breadcrumb archived. You can now resume the update."
    }
    else
    {
        Write-Host "Breadcrumb not found at $breadcrumbPath - mitigation may not be needed."
    }

    # After running the above, resume the update:
    # Get-SolutionUpdate | where State -eq "InstallationFailed" | where Version -match "12.2604" | Start-SolutionUpdate
}
```
