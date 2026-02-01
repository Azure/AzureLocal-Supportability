
# [2411.2][2411.3]  AzureStackOSConfig ConfigureSecurityBaseline failure during deployment on Azure Stack Local OEM license devices due to license corruption on nodes.


# Symptoms

If
- you are going to update to Azure Local 2411.2 or 2411.3 release but update hasn't started yet
- and you are working on OEM licensed devices

please go ahead to the mitigation details section. You'll need to apply the mitigation steps to avoid potential issues.

If you saw a failure during
- Deployment of Azure Local 2411.2 or 2411.3
- Update to Azure Local 2411.2 or 2411.3

The symptom could be a failure at `Apply security settings on servers` step with the following error message:
```
Type 'ConfigureSecurityBaseline' of Role 'AzureStackOSConfig' raised an exception: [ConfigureSecurityBaseline] ConfigureSecurityBaseline failed on xxx with exception: -> Failed to apply OSConfiguration enforcement for ASHCIApplianceSecurityBaselineConfig on xxx after 5 attempts
```

# Issue Validation

If you are at pre-2411.3 update stage, please skip this section and go to mitigation details section.

If you saw failures, please confirm the issue happened:
- During **Azure Local 2411.2** or **Azure Local 2411.3** deployment
- Or during solution update to **Azure Local 2411.2** or **Azure Local 2411.3** 

And 
- The devices in this cluster are **Azure Stack Local OEM license** devices.

If the above condition all matches, please go to one of the nodes. Go to `D:\CloudContent\MASLogs\ASSecurityOSConfigLogs` (Or for some environments: `C:\CloudContent\MASLogs\ASSecurityOSConfigLogs`) and check the latest `ASOSConfig_SetASOSConfigDocInternal_*.log` file. There should be failures like 
```
...
WARNING:     Setting: InteractiveLogon_SmartCardRemovalBehavior. State: failed. Error: 0xc004f012.
WARNING:     Setting: WinlogonCachedLogonsCount. State: failed. Error: 0xc004f012.
WARNING:     Setting: Audit_AuditTheUseOfBackupAndRestoreprivilege. State: failed. Error: 0xc004f012.
...
```

If you encounter errors with error code **0xc004f012**, or **0x8000ffff**, and observe 88 or at least 80 total policy failures (as indicated in the failure report summary in the same log file), the issue is validated.

# Mitigation Details

All following mitigation steps are applicable to:

- Update to Azure Local 2411.3 release (most common case)
- Update to Azure Local 2411.2 release. If you are on 2411.0 or 2411.1 release, you should skip 2411.2 update, follow this TSG and then use 2411.3 release instead. **This TSG should be applied before updating to 2411.3**.
- Azure Local 2411.3 release deployment*
- Azure Local 2411.2 release deployment* 
 
\* As of July, 2025 you should not use Azure Local 2411.2 or 2411.3 release for deployment. Use latest available Azure Local release instead.

## Preparation

#### Deplyment failed scenario
1. Please **reimage** all of the hosts that are going to be part of the cluster **with most-recent Azure Local 2411.3 image**.
2. Install driver after reimaging the servers. Install the driver package provided by your server vendor.

#### Update failure scenario
If you have already seen and validated the issue using this TSG, you will need to repair every single node.

Please follow the repair node document [here](https://learn.microsoft.com/en-us/azure/azure-local/manage/repair-server?view=azloc-2506) on one of the nodes. Node repair should be done one at a time. Follow the instructions and have document step 2 done (i.e., OS and driver installed). Please do not proceed to document step 3 (i.e., Arc registration) at this time.

#### Pre-2411.3 update scenario
If you are planning to update to Azure Local 2411.3 release and update haven't yet started, please follow the mitigation steps section provided below.

## Mitigation Steps

The below steps should be applied on
- All hosts for **Deployment** and **Pre-2411.3 update** scenarios. 
- The specific node being repaired for **Update failure** scenario.

#### Steps 
1. Once preparation for your scenario is done, please execute the below commands.
``` Powershell
$downloadLocationOfZip  = "C:\DownloadKIRTMP"
mkdir $downloadLocationOfZip -Force
```

2. Download the remediation package [here](https://azurestackreleases.download.prss.microsoft.com/dbazure/AzureStackHCI/Update/10.2411.3.2/DeployKIRNuget.zip) and copy to `C:\DownloadsKIRTMP`.

3. Execute the below commands.
``` Powershell
$downloadLocationOfZip  = "C:\DownloadKIRTMP"
mkdir C:\KIRPackage -Force
Expand-Archive $downloadLocationOfZip\DeployKIRNuget.zip C:\KIRPackage -f
```
4. Run the DeployKIRNuget.ps1 file in the downloaded package on **all** hosts.
``` Powershell
C:\KIRPackage\DeployKIRNuget.ps1
```
5. Verify that under `C:\NugetStore`, there is a folder called `Microsoft.AS.KIR.10.2411.3.3`.

6. Proceed with the remaining steps.
   - For **Deployment** scenario, procced with Arc registration and normal deployment workflow.
   - For **Update failure** scenario, please follow the repair node doc and proceed. Once this node is repaired, please follow the same steps for all other nodes one by one. Once all nodes are repaired, please resume the failed solution update.
   - For **Pre-2411,.3 update** scenario, please follow the normal update workflow to start solution update.
