# Overview
For disconnected clusters, Update of the Azure Local cluster to 2604 or 2605 may fail during 'ShouldUpdateMocPreSSU' if the existing MOC version is not at the required version or above. The following update error message may be used to identify and match the issue.

This TSG does not apply to connected clusters. 

**Example error message:**

```
Type 'ShouldUpdateMocPreSSU' of Role 'UpdateBootstrap' raised an exception:

Unable to locate MOC staging helper script for disconnected cluster.
at ShouldUpdateMocPreSSU,
...
```
---

# Cause
There is a mismatch between the MOC content staging helper script path and its actual location in the nuget that contains the script. 

---

# Mitigation Steps 
The mitigation will copy the helper script to the fixed location so the orchestration can correctly reference it.

From any host node:
```powershell
Import-Module CloudCommon
$latestBootstrapNugetPath = Get-ASArtifactPath Microsoft.AS.UpdateBootstrap
$nugetName = Split-path $latestBootstrapNugetPath -Leaf

Import-Module FailoverClusters
$nodes = (Get-ClusterNode).Name
foreach ($node in $nodes)
{
    $currentScriptPath = "\\$node\C$\NugetStore\$nugetName\content\Roles\UpdateBootstrap\Update-MocHotfixOffline.ps1"
    if (-not (Test-Path $currentScriptPath))
    {
        Write-Warning "Cannot find $currentScriptPath, skipping to next node."
        continue
    }

    $destinationParentPath = "\\$node\C$\NugetStore\$nugetName\content\Classes\Roles"
    if (-not (Test-Path $destinationParentPath))
    {
        $null = mkdir $destinationParentPath
    }

    $destinationPath = Join-Path $destinationParentPath Update-MocHotfixOffline.ps1
    Copy-Item $currentScriptPath $destinationPath -Force
    Write-Verbose -Verbose "Fixed script location on $node."
}
```

Then retry the update.

---

If the update failure persists after mitigation attempt, please contact Microsoft support.

---
