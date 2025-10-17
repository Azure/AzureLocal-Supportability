# SBE fails health check with content integrity issues

IMPORTANT Check your Azure local version as the scenarios will differ by version:
* 2503 and older - can experience all 3 scenarios
* 2504 and newer - should only experience scenario 2 (do not use the mitigation script!)

# Symptoms
Once customers invoke `Start-SolutionUpdate` (either with or without `-PrepareOnly`) for an update that includes a new SBE, this may cause the **SBE Test SolutionExtensionModule Health Check** test to fail with an exception message that includes `SolutionExtension content failed integrity check`. Depending on the scenario, this health check failure will be observed in different locations:
- The (daily) system health check reports the failure - see scenario 1 or 2 below.
- The (pre-update) update readiness health check reports the failure - see scenario 3 below.

In either case, the process for viewing and mitigating the failure is similar. The following guide describes how to view both the system and update readiness health checks in the Portal or via PowerShell:
[Troubleshoot solution updates for Azure Local, version 23H2 - Azure Local | Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2?view=azloc-24112#using-azure-portal)


### Scenario 1: exposed by "preparing" before updating
Typically, a scenario of using the `-PrepareOnly` option to "prepare" in advance for an update can expose this issue. If your process includes at least 24 hours delay between preparation and completion of the update you may observe the issue:
1. Early in the week (e.g. Monday) make a call like the following to validate readiness to install an update:
`Get-SolutionUpdate -Id <ResourceId> | Start-SolutionUpdate -PrepareOnly`
2. Review the passing results and decide on a good day (e.g. Friday or Saturday) to schedule a maintenance window to install the update.
3. As part of a best practice, prior to starting the update (on Saturday), you check the daily system health check results (from Friday night) and observe the issue.

**Tip:** Preparing before installing an update is still a best practice.  Prior to resolution of the issue described in this guide, you can immediately follow the mitigation steps as soon as you finish preparing (On Monday, after step 2 is done).

### Scenario 2: exposed by updates taking several retries
Even if you begin the update immediately (don't ever use the `-PrepareOnly` parameter), this issue may also materialize if your update requires one or more retries to complete such as in a scenario like the below:  

1. You use the portal or PowerShell to immediately start an update that includes an SBE on Monday morning:
`Get-SolutionUpdate -Id <ResourceId> | Start-SolutionUpdate`
2. The update fails just before staff leave for the day and there is a plan to resume the update (after attempting to troubleshoot) the next day.
3. On Tuesday, the update issue is triaged and resolved.
4. As part of a best practice, prior to restarting the update (on Tuesday), you check the daily system health check results (from Monday night) and observe the issue.

### Scenario 3: exposed by switching which update you are installing
If you start to prepare to install update A, but then opt to switch to installing update B, this issue may materialize in a way that **REQUIRES the mitigation of fixing the environment variable**.  This is unique to this scenario (scenario 1 and 2 can opt to ignore the failures if you choose) because only this scenario causes the pre-update (update readiness) tests to fail.

1. Initially make a call like the following to validate readiness to install an update that includes an SBE (or is a SBE-only update):
`Get-SolutionUpdate -Id redmond/SBE4.1.2411.17 | Start-SolutionUpdate -PrepareOnly`
2. You later decide to switch, without ever installing the update with the SBE, to installing a monthly (Microsoft-only) "Cumulative" update:
`Get-SolutionUpdate -Id redmond/Solution10.2408.2.7 | Start-SolutionUpdate`
3. You observe this issue with the pre-update tests failing as reported by `Get-SolutionUpdate`

# Issue Validation
The output of Get-SolutionUpdateEnvironment lists a failing HealthCheckResult entry similar to the following with 2 key details in AdditionalData property:
- `SolutionExtension content failed integrity check`  errors for reasons other than the integrity check may be unrelated to this guide.
- The path should failing integrity checks should contain `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\SBE\Installed\Content\`. Exceptions not containing `SBE\Installed\Content` in the path may be for other issues (not discussed in this guide).


```
HealthCheckSource  : PreUpdate\Medium\SBEHealth\b9b93b63
Name               : AzStackHci_SBEHealth_Test-SolutionExtensionModule_xxxxx
DisplayName        : SBE Test SolutionExtensionModule Health Check
Tags               : {}
Title              : SBE Test SolutionExtensionModule Health Check
Status             : FAILURE
Severity           : CRITICAL
Description        : Validate SolutionExtension module exists and supports health tests
Remediation        : https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-tool-troubleshoot#rerun-deploym
                     ent
TargetResourceID   : xxxxx
TargetResourceName : xxxxx
TargetResourceType : SBEHealth
Timestamp          : 1/22/2025 12:53:13 AM
AdditionalData:

Key   : Detail
Value : The SolutionExtension module could not be validated. An exception occurred while validating the
        SolutionExtension module:  + SolutionExtension content failed integrity check in
        'C:\CloudContent\Microsoft_Reserved\Update\SBECache\4.x.xxxx.xx\Configuration\SolutionExtension'
        At
        C:\NugetStore\Microsoft.AzureStack.Role.SBE.10.2411.0.2017\content\Helpers\SBESolutionExtensionHelper.psm1:150
        char:13

        +             throw "SolutionExtension content failed integrity check i ...
        +             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            + CategoryInfo          : OperationStopped: (SolutionExtensi...utionExtension':String) [], RuntimeException
            + FullyQualifiedErrorId : SolutionExtension content failed integrity check in
        'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\SBE\Installed\Content\Configuration\SolutionExtension'
```

Note: The path to the `SolutionExtension` directory listed just after `SolutionExtension content failed integrity check in` in the above message can be used to confirm the scenario.
* Scenario 1 and 2 - The path will start with `C:\ClusterStorage`
* Scenario 3 - The path will contain `SBECache\4.x.xxxx.xx` where the x.xxxx.xx part is the version of the SBE included in update A (and not update B). Note: for this scenario the path can start with a `D:\` path if your systems have a D drive.

# Cause
Start-SolutionUpdate health checks were supposed to **temporarily modify** the `SBEStagedMetadata` machine environment variable to reflect the location of the metadata for the new, to be installed, SBE update. This allows the pre-update health checks to run using the newer SBE logic.

The issue is caused by health modification environment variable being done **permanently** instead of being **temporary** as per the intended design (to return the environment variable to the default path when the health check completes).

The (daily) system health check runs using the older (installed) SBE files because the newer update is not yet installed. Because the update preparation health check did not return the environment variable to it's prior value, this causes the system health check to experience a mismatch between having older SBE content (e.g. the installed SBE scripts and files) and newer SBE metadata (reflecting expectations for new SBE content).

This mismatch of _**old content**_ with _**newer metadata**_ results in a content integrity failure.

# Mitigation Details for Scenario 1
If you have confirmed this issue is only observed in the system health check (scenario 1), you should ignore the failure. To proceed while ignoring the system health check failure you can use `Start-SolutionUpdate` with it's normal syntax.

# Mitigation Details for Scenario 2
If this is **Scenario 2** you should just ignore the failure.  As soon as the new SBE finishes updating the failure will go away on its own (in the next daily check).

**DO NOT RUN THE SCRIPT** below as it may cause the current update to fail!

# Mitagation Details for Scenario 3
If you have confirmed this is a case of scenario 3 you can use the following steps to correct the bad environment variable value.

**IMPORTANT - You should only use this script if ALL of the following are true:**
* The installed version of Azure Local is 10.2503.x or older
* You are ABSOLUTELY SURE this is scenario 3 as described above
   * There should be no update that has actually been started (e.g. `Get-SolutionUpdate` does not list any update with a status of `Installing` or `InstallationFailed`)
   * The cluster started to prepare (download or health check) update A and then there was a change to instead try to install update B BEFORE ever starting to actually install update A.
   * The second update you have attempted to start (update B in this scenario), is reporting the State of `HealthCheckFailed` when `Get-SolutionUpdate -Id redmond/<update b value>` is called
   (e.g. `Get-SolutionUpdate -Id redmond/Solution12.2510.1002.83`)
   * The `HealthCheckResult` of that `Get-SolutionUpdate` matches the Issue Validation described above.
   For example:
   `(Get-SolutionUpdate -Id redmond/Solution12.2510.1002.83).HealthCheckResult | ?{$_.Status -eq "FAILURE"}` contains the result that mentions both:
      * `SolutionExtension content failed integrity check in`
      * The path to the mentioned SolutionExtension directory includes `SBECache`.  For example, if the HealthCheckResult failure mentions a path like this (where x.xxxx.xx are replaced with a SBE version value) then this IS scenario 3:
      'C:\CloudContent\Microsoft_Reserved\Update\SBECache\4.x.xxxx.xx\Configuration\SolutionExtension'

If the path mentioned in the HealtCheckResult does NOT mention `SBECache` this is NOT scenario 3.

**IMPORTANT - Do NOT run the below script unless you match ALL the criteria above**

1. Run the script below on any cluster node to reset the environment variable to the default value on all nodes. Specify the normal AD deployment user (the LCM user as prompted during the cloud deployment process).

```Powershell
$cred = Get-Credential
Invoke-Command -Credential $cred -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    $defaultPath = "C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\SBE\Installed\metadata"
    if ($false -eq (Test-Path -Path $defaultPath)) {
        $sbeConfigPath = Get-ASArtifactPath -NugetName "Microsoft.AzureStack.SBEConfiguration" 3>$null 4>$null
        $defaultPath = Join-Path -Path $sbeConfigPath -ChildPath "content"
    }
    [System.Environment]::SetEnvironmentVariable("SBEStagedMetadata", $defaultPath, "Machine")
}
Write-Host ("Updated 'SBEStagedMetadata' to " + [System.Environment]::GetEnvironmentVariable("SBEStagedMetadata", "Machine"))
```

2. Once the script has been run, you can directly call the daily system health check to confirm the issue has been resolved using:
`Invoke-SolutionUpdatePrecheck -SystemHealth`

3. Wait a few minutes to allow the system health check to run and then check the result using `Get-SolutionUpdateEnvironment`

For help viewing the new system health check results see:
[Troubleshoot solution updates for Azure Local, version 23H2 - Azure Local | Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2?view=azloc-24112#using-azure-portal)
