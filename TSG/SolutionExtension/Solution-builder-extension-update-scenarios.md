# Introduction
This troubleshooting guide will assist engineers with the basics of troubleshooting for solution builder extension (SBE) issues during updates.
- For for a general overview on solution builder extension, see the [Solution builder extension overview guide](./Solution-builder-extension-overview.md).
- For help troubleshooting solution builder extension deployment issues, See the detailed [Solution builder extension deploy scenarios guide](./Solution-builder-extension-deploy-scenarios.md).

# SBE Update Flow
The general update flow is documented at https://learn.microsoft.com/en-us/azure-stack/hci/update/update-phases-23h2 to discuss the phases from a customer perspective.  This is expanded on in the [SBE specific documentation for discovery](https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension#discover-solution-builder-extension-updates) which expands on how to filter updates on the `PackageType` to determine if the update is a solution update vs a SBE-only update 

Following the high level flow, see below for phase specific guidance:

|**Steps (in order)**| **Scenarios that might fail** |**Tips to Remediate**|
|--|--|--|
| Discovery | - update doesn't show up as ready or at all<br /> - Get-SolutionUpdate* fails | - Review partner solution extension release notes or the `SBE_Discovery_*.xml` and check that the cluster meets the required package version requirements in the `<ValidatedConfigurations>` entry.<br /> - Call `Get-SolutionDiscoveryDiagnosticInfo`<br />- Call `Get-SolutionUpdate` again.<br > - Confirm the update service is online using `Get-ClusterResource -Name *Update*`.  If it is not online you can use `Start-ClusterResource` to attempt to start it again; however, this is not a normal situation and Micrsoft Support may be required. |
| Download | - Download of SBE fails   | See Download Connector issues below.  |
| Preparation | -SBE zip file package has is invalid<br /> -Extraction of any update file fails (in case of "Solution") update | Investigate zip files in the directory matching the update being installed under `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\Packages` to confirm the zip file hashes are as expected. If not, delete the zip files attempt `Start-SolutionUpdate` again (repeating `Add-SolutionUpdate` prior to that if it was originally needed to add additional content files for the update). |
| HealthCheck | -SBE update readiness health checks fail | - Review healthcheck results and remediate as per [Troubleshoot readiness checks](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2#troubleshoot-readiness-checks)<br /> - See [SBE specific HealthCheck known issue guides](./HealthCheck-known-issues) in the same folder as this guide. |
| OS or Services Update | - Any step after the update starts installing prior to reaching the SBE steps.<br /> - Any `CAU` role step that doesn't also include `SBE` in the `InterfaceType` name.  | Troubleshoot as a non-SBE issue. The [known issues](https://learn.microsoft.com/en-us/azure-stack/hci/release-information-23h2) for solution update version that is installed (or being installed) should be consulted.  |
| SBE Update | See below "Major SBE update steps" | See below scenarios |
| SBE Update Wrap up  | - Update SBE version in ECE<br /> - Remove per-node local `SBECache` directory  | These steps aren't expected to fail, but they do, the SBE is fully installed and the cluster should be in a good state.  Contact Microsoft support for help finalizing the cleanup tasks. |

# Major SBE update steps
The major steps to "update" the solution builder extension are executed in a sequential block as described below.

1. Update the SBE WDAC policy supplement
2. Run CAU preparation hooks that can do "anything" (but typically install/register CAU plugins)
3. Use CAU scan to determine if a CAU run will be needed to install updates
4. Start and monitor the SBE CAU run (installs firmware and drivers and reboot each node in rolling update)
5. Check `Get-CauReport` to confirm the update was successful, if not attempt a retry of the `Invoke-CauRun` until we reach max retries
6. Run Post-CAU SBE "completion" hooks that can do "anything" (but typically uninstall plugins, configure new BIOS/BMC settings)
7. Update the Storage Spaces Direct supported components XML document which will initiate a drive firmware rollout (if needed).
8. Wait for drive firmware rollout to finish (if one was started)

# Scenario: Download Connector Issues
For solution extensions that implement the `DownloadConnector` capability, the installed (older) extension will be used to download the requested (newer) extension. Depending on the extension implementation, this could be an issue with credentials, partner endpoint access, or bug in partner solution extension.

If additional details are needed beyond the reported DownloadFailure exception message you can first locate the most recent action plan instance for the SbeDownload:

```
Get-ActionPlanInstances | where-object {$_.actionTypeName -eq "sbeDownload"} | FT InstanceId, State, EndDateTime

# pick the most recent one and use the InstanceId GUID to get the verbose log from it
$helperModule = Join-Path -Path (Get-ASArtifactPath -NugetName Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Client.Deployment) -ChildPath "content\RefreshVMHelpers.psm1"

Import-Module $helperModule -Force

# Generate a report of events logged by that action plan (in this example w/ InstanceId being 0dd5e575-91ea-4d2e-b890-87db7d1b7687)

Get-ActionPlanInstanceLog -actionPlanInstanceID 0dd5e575-91ea-4d2e-b890-87db7d1b7687 > LogVerbose.txt

```

# Scenario: CAU Scan issues
[Same guidances as for deployment](./Solution-builder-extension-deploy-scenarios.md), but note that in addition to the Scan performed prior to starting the CAU run, the CAU run itself will repeat the CAU scan after each subsequent node reboot during the run. This additional scan is performed to confirm that following the installation of the update and the reboot that the expected (updated) firmware or driver version is reported.

If an exception like the following is observed it this generally indicates that there is an issue with the updates being installed (e.g. firmware update isn't being installed during the reboot) because it is the scan step inside of the CAU run failing:
```
CAU run failed on node xxxxx. Details: Microsoft.ClusterAwareUpdating.ClusterUpdateException: The xxxxxxxPlugin plug-in reported a failure while attempting to scan ...
```
We can see this is the scan during the run and not the scan prior to the run because the exception started with "CAU run failed" and thus such failures should be investigated with the mindset of why did the Scan after the updates were installed fail to see the new versions.

# Scenario: CAU Run issues
The CAU run is where the same plugins that were used in the scan are invoked to "install" the list of updates that were detected in the scan as needing an update.  

## Files to help triage CAU runs
If you have access to the cluster there are some files under `c:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\SBE\Staged\metadata` that may help to triage.
- `cauScanOutput.json` - The output from the Invoke-CauScan listed the updates the CAU run will attempt to update.
- `CAURunAttempts.json` - The output from the Invoke-CauRun calls listing the syntax of how the runs were invoked, the RunId for each attempt, and how many total attempts have been made.

## Retries and resuming CAU runs
The action plan uses dynamic steps and a trailing interface called `EvalCauRetryAttempts` to enable retries as well as close monitoring of the progress of the CAU run for the SBE updates. Following an initial CAU run failure the action plan will try to clean things up (`Invoke-CauRun -ForceRecovery`) and then retry the exact same syntax for an additional `Invoke-CauRun` attempt.  If that second attempt fails it will fail with `max retries exceeded`.  Assuming support or the customer thinks they have triaged the failure and have resolved it, calling `Start-SolutionUpdate` again or resuming via the portal will re-initiate the same `Invoke-CauRun` 1 time more for each resume (instead of the 2 initial tries) until the overall maximum retry attempts of 6 are reached.  At that point, Microsoft support will be needed to enable further retries.

## Typical CAU run issues by InterfaceType

- `SBEPartnerInvokeCAURun` - (often **CAU** or **Cluster** Issue) Failures in this interface mean an immediate failure trying to call `Invoke-CauRun` which typically will be caused by there being something general wrong with the cluster (1 more nodes paused, cluster name or cluster ip resources offline, etc).  Start triage looking for issues with `Get-ClusterNode`, `Get-ClusterResource`, or `Test-Cluster`.
- `SBEPartnerWaitForCauNodeStage` - This interface will be called many times to monitor the node as it progresses through the CAU run on each node ([see here](https://learn.microsoft.com/en-us/windows-server/failover-clustering/cluster-aware-updating#BKMK_OVER) for details).
  - A timeout in the wait steps (where the ECE action plan times out) typically indicates the partner CAU plugin is stuck and unable to complete the update.  **HW Partner Support** should be engaged in next steps to prevent damage to the servers (e.g. you don't want to forcefully reboot or remove power if firmware is in the process of being flashed).
     * **WARNING the CAU run is probably still running** - Because CAU runs themselves are being deployed with NO TIMEOUT in the SBE action plan it is VERY likely that if SBE times out that the CAU run is still going. Have the customer call Get-CauRun (several times over a minute) to assure it reports `RunNotInProgress` before you assume the CAU run has finished. 
      * We have seen several failure patterns where CAU gets stuck in an infinite install/reboot loop, especially for driver updates.
         * There is currently a known issue with the driver update plugins that can get stuck in this loop if someone bypasses the SBE and installs a driver newer than the SBE.
        * Similar driver update plugin loops can be seen if there are both older and newer version of the SAME driver in an SBE by accident. This must be fixed by requesting an updated SBE from the HW partner.
  - A Get-CauRun communication failure during the wait steps (e.g. `WinRM` or `CIM` failures) can indicate that the cluster IP address is slow in coming online after a reboot (or similar).  Microsoft support should be contacted in such cases.
  - If there is a BitLocker recovery key prompt that occurs during a reboot this indicates an issue in the partner SBE in their `CAUPlugins/PreUpdateScript.ps1` which is supposed to suspend BitLocker protection for the duration of the CAU run install maintenance window.
- `EvalCauRetryAttempts` - (often **HW Partner** issue) Failures in this stage mean that the end of the CAU run was reached and in most cases this means the issue will be reported by `Get-CauReport -Last -Detailed`. 
  - A specific type of failure reported by this still will be CAU timing out due to a node taking more than 1 hour to restart (`(ClusterUpdateException) Failed to restart "v-Host1": The timeout limit (01:00:00) was reached.`). Because CAU runs involve a lot of restarts this could be due to a HW fault (check the BMC) or due to an issue with a windows service restarting (CAU doesn't consider the restart done until all auto-start services are started).  Investigation may be needed to determine if there is an auto-start service that is slow or failing start.
  - In cases where the CAU run finishes and `Get-CauReport` reports a failure an investigation should be driven based on the details in that report to investigate the lower level logs from the failing plugin as appropriate.

# Scenario: Drive FW update issues

One of the last SBE steps updates the S2D supported components document, or `StorageDisks.xml`. If drive target firmware is specified in this document, it also determines if the target firmware is required for the specific cluster configuration and if so monitors S2D drive firmware update for completion.

For routing and analysis, there are 2 major types of tasks done to update the drive firmware:
1. Evaluation and preparation logic to determine if any updates for drive FW are needed and to stage the drive FW locally on each node. 
2. The `UpdateDriveFW` interfaceType step where the update to the `StorageDisks.xml` file is provided to S2D and the action plan waits for the firmware update rollout. If this step fails the issue is potentially related to a hardware or drive firmware image issue.

#### Details on `UpdateDriveFW` type issues
**Note:** If this step fails due to a timeout it is likely that the S2D drive firmware update process is still running so do not assume it has stopped just because the update has an InstallFailed status or the action plan has failed.

If this step fails, it is typically either due to a firmware binary failing to apply to one or more disks, or a disk not reporting the correct (or any) firmware version after the firmware binary is applied. The detailed logging for the firmware update process is in the EvtxLogs with `Microsoft-Windows-Health` in the name and with provider ID "29d1f3ee-dbcf-44e9-b0cc-085bfa362499". The following PowerShell block will show the relevant information:

```
$provider = '{29d1f3ee-dbcf-44e9-b0cc-085bfa362499}'

$filterXml = @" 
<QueryList> 
<Query Id="0"> 
<Select Path="Microsoft-Windows-Health/Diagnostic"> 
and 
*[EventData[Data[@Name='Provider'] and (Data=$provider)]] 
</Select> 
<Select Path="Microsoft-Windows-Health/Operational"> 
and 
*[EventData[Data[@Name='Provider'] and (Data=$provider)]] 
</Select> 
</Query> 
</QueryList> 
"@  

$events = Get-WinEvent -FilterXml $filterXml 
```
