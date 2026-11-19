UpdateOsBuildNumberInEce interface fails during Solution update because of inconsistent OS versions between nodes of the Azure Local failover cluster.

# Symptoms
Solution update fails with a message similar to the following. Note that node names and versions will differ by customer environment.

```
Type 'UpdateOsBuildNumberInEce' of Role 'OsUpdate' raised an exception:

Expected NODE02 to be on OS Build Number 10.0.25398.1128 but found 10.0.25398.1085.
```

Another possible error message, that we would see in Solution update 2503+ would be:

```
Type 'UpdateOsBuildNumberInEce' of Role 'OsUpdate' raised an exception:

Found different OS build number between cluster nodes: NODE2 is running on 10.0.25398.1128, NODE1 is running on 10.0.25398.1085.
```

# Issue Validation
The error message above is sufficient to identify the issue. A specific check to run on the stamp is to query the OS version across the cluster nodes from a PowerShell session:

```powershell
$nodes = Get-ClusterNode | % NodeName
Invoke-Command $nodes { $v = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\' -Name CurrentMajorVersionNumber, CurrentMinorVersionNumber, CurrentBuildNumber, UBR; "$(hostname): $($v.CurrentMajorVersionNumber).$($v.CurrentMinorVersionNumber).$($v.CurrentBuildNumber).$($v.UBR)" }
```

This should result in output similar to.
```
NODE1: 10.0.25398.1085
NODE2: 10.0.25398.1128
```

# Cause
Solution updates are intended to take Azure Local systems through tested transformations between validated recipes. When customers (intentionally, or unintentionally) apply updates out-of-band of this process, it can cause unexpected side effects that are not validated by Microsoft or our partners.

If you install OS updates that are higher than the OS version specified in a Solution recipe, but don't apply the same updates to all the nodes of the cluster, the UpdateOsBuildNumberInEce interface will identify this issue and cause the update action plan to fail.

# Mitigation Details
There are two possible mitigations that can be applied, depending on the situation:

1. Skip the failure
2. Patch all nodes to the same version. 

Please determine the right path forward based on the following primary considerations:

1. If the version difference is sufficiently high, skipping the failure may work now, but you may encounter the same error on subsequent Solution update installs.
2. Patching the nodes should be done with some care as OS updates require reboot of the cluster nodes. This should be ideally done during a maintenance window, and nodes should be paused before rebooting.

To help with analysis of which option is best, the following table summarizes the OS versions corresponding to each Solution update.


| Solution Version | OS version | OS update name |
|--|--|--|
| 10.2311.0.26 | 10.0.25398.531 | 11B (2023) |
| 10.2311.5.6 | 10.0.25398.830 | 4B |
| 10.2402.0.23 | 10.0.25398.709 | 2B |
| 10.2402.2.12 | 10.0.25398.830 | 4B |
| 10.2402.4.4 | 10.0.25398.950 | 6B |
| 10.2405.0.23 | 10.0.25398.887 | 5B |
| 10.2405.1.4 | 10.0.25398.950 | 6B |
| 10.2405.3.7 | 10.0.25398.1085 | 8B |
| 10.2408.0.29 | 10.0.25398.1085 | 8B |
| 10.2408.2.7 | 10.0.25398.1189 | 10B |
| 10.2411.0.24 | 10.0.25398.1251 | 11B |
| 10.2411.1.10 | 10.0.25398.1308 | 12B |
| 10.2411.2.12 | 10.0.25398.1369 | 1B |
| 10.2411.3.2 | 10.0.25398.1425 | 2B |
| 10.2503.0.13 | 10.0.25398.1486 | 3B |
| 11.2504.1001.19 | 10.0.25398.1551 | 4B |
| 11.2505.1001.22 | 10.0.25398.1611 | 5B (23H2) |
| 12.2505.1001.23 | 10.0.26100.4061 | 5B (24H2) |
| 11.2506.1001.28 | 10.0.25398.1668 | 6B (23H2) |
| 12.2506.1001.29 | 10.0.26100.4349 | 6B (24H2) |
| 11.2507.1001.9 | 10.0.25398.1732 | 7B (23H2) |
| 12.2507.1001.10 | 10.0.26100.4652 | 7B (24H2) |


## Option 1: Skip the failed step and resume the update.
Example: if the system is on a failed 10.2411.0.24 update with one node being on version 10.0.25398.1369, it might be worthwhile to skip the failed step if you are planning on installing the 10.2411.2.12 update fairly soon.

To skip the failed step, execute the following PowerShell script:
```powershell
$update = Get-ActionPlanInstances | where { $_.RuntimeParameters.updateId -ne $null } | sort EndDateTime | select -Last 1
if (-not $update) {
    throw "Couldn't find the latest 10.2408.0.29 update action plan"
}

# Change XML to mark UpdateOsBuildNumberInEce interface task as Skipped
$xml = [xml]($update.ProgressAsXml)
$interface = $xml.SelectNodes("//Task") | ? InterfaceType -eq "UpdateOsBuildNumberInEce"
$interface.Status = "Skipped"

# Save the modified XML
$modifiedPlanPath = Join-Path $env:TEMP "modifiedUpdate2408.0.xml"
$xml.Save($modifiedPlanPath)

# Start the new update
Invoke-ActionPlanInstance -ActionPlanPath $modifiedPlanPath -ExclusiveLock -Verbose
```

## Option 2: Update all nodes to the highest version present
Example: if the system is on an old build and has failed at installing the 10.2402.4.4 update, but one node got updated to version 10.0.25398.1308, it might make more sense to patch the remaining nodes to the same OS version level to ensure that subsequent Solution updates do not encounter the same failure.

The steps involved in patching the nodes might depend on your patching preferences. One option would be to use sconfig to update the nodes, while ensuring that the nodes are drained and resumed for every update.

###Step 1:
Suspend the cluster node and drain the workloads.
```powersehell
Suspend-ClusterNode -Name <Node Name> -Drain
```
Check suspend using `Get-ClusterGroup`. Nothing should be running on the target node.

### Step 2:
Run `SCONFIG` option 6.2 on the target node. See sconfig documentation here: [Configure a Server Core installation of Windows Server and Azure Local with the Server Configuration tool (SConfig) | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/server-core/server-core-sconfig#install-updates).

### Step 3:
After the target node has rebooted, wait for the storage repair jobs to complete by running `Get-Storage-Job` until there are no storage jobs or all storage jobs are completed.

### Step 4:
Resume the cluster node.
```powershell
Resume-ClusterNode -Name <Node Name> -Failback
```

After applying the steps in Option 2, resume the Solution update.
