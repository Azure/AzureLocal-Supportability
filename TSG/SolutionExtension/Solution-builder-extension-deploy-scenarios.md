# Introduction
This troubleshooting guide will assist engineers with the basics of troubleshooting for solution builder extension (SBE) issues during deployment.
- For for a general overview on solution builder extension, see the [Solution builder extension overview guide](./Solution-builder-extension-overview.md).
- For help troubleshooting solution builder extension update issues, see the [Solution builder extension update scenarios guide](./Solution-builder-extension-update-scenarios.md).

# SBE Deployment Flow
The SBE package is in several ways between the end of bootstrap until the end of deployment. See below for a high level overview.

1. Predeployment SBE steps
   - LCM Extensions installs SBE role
   - Portal provides deployment config to LCM extension
   - EnvironmentChecker runs SBE "Deployment" health checks (along with many other non-SBE checks)
   - User presented with EnvironmentChecker results including the results of partner authored SBE checks and built-in SBE role checks.
2. Early Deployment (before even the first deployment progress step is shown in the portal)
   - ExtractOEMContents.ps1 validates staged c:\SBE and extracts on seed node under c:\CloudDeployment
   - Deployment process runs the SBE "Deployment" Health checks (again).  This covers the ARM api case where the same checks weren't done prior to deployment starting
3. Later Deployment (after the cluster and storage are configured)
   - Copy extracted SBE from under C:\CloudDeployment on seed node to CSV at `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\SBE\Staged`
   - Run SBE deployment action plan steps.  With exception of not doing CAU run this will be almost identical to SBE update action plan. Steps in that plan include actions that can generally be described as:
     1. Add SBE WDAC policy supplement
     2. Run various partner PowerShell hooks (each of which can do "anything")
     3. Use CAU scan to determine if updates are needed.
     4. Set SBE version as appropriate:
        - If updates are needed, set SBE version to 4.0.0.0.  This identifies a SBE was present during deployment, but that all of the drivers or firmware from that SBE are not installed yet and thus **an immediate SBE update to the same version SBE (or newer) is recommended.**
        - If no updates are needed, set the SBE version to the actual version of SBE that was staged and deployed from C:\SBE.
        - If no SBE was present (nothing at C:\SBE), the SBE version will still be at it's default value 2.1.0.0.   


## Scenario: `ExtractOEMContents.ps1` failures
This extract script is responsible for confirming the SBE staged at `C:\SBE` is:
- Trusted based on signature and hash checks
- Matches the system model
- Is supported by the solution version being deployed
- SBE contents structure aligns with the appropriate solution extension specification for the solution version being deployed

### Identifying scenario
This failure is very early in the deployment when we are doing the validation (before the validation or deployment action plans). If the validation fails with an issue extracting the SBE, the most recent log with information to look at will be at `C:\MASLogs\Lcm_Controller_Start_Validate_Scheduled_job_*.log`. In the case of an `ExtractOEMContents.ps1` failure the output of the extraction script is in `Lcm_Controller_Start_Validate_Scheduled_job_*.log` between these statements:
```
VERBOSE: Validating input parameters.

<log messages from ExtractOEMContents.ps1>

VERBOSE: Scale units count
```
### Common reasons for this type of failure:
1. `C:\SBE` doesn't have all 3 files (user or partner didn't copy files properly).
2. One of the files under `C:\SBE` has been tampered with (invalidating signature or package hash check).
3. The SBE for the wrong model of system was placed at `C:\SBE` (e.g. user or parter staged SBE for familyA when the model of server belongs to familyB) Check the <SupportedModels> portion of the SBE_Discovery*.xml file to identify correct family if wrong *.zip file was staged.

The resolution to all of the above is to download the latest matching SBE files (2 XML and 1 zip) and place them on the 1st node at `C:\SBE`.

...
> [!CAUTION]
>
> **This type of failure could be the result of an attacker trying to introduce malicious files!** Work with the customer to assure this is not an attack (e.g. is a case of copying wrong files or corruption during file transfer) before proceeding to workaround by staging valid files at `C:\SBE`.
> - Potential (single cluster) root cause could be something less concerning like user error or a corrupted download if the files were placed by the user.
> - Potential (wide-spread) root cause could be a partner image or image installation issue. Given the broad impact partner should work quickly to address their issue and, if necessary, provide release notes to customers on how to workaround.

## Scenario: Validation fails a "SBEHealth" test

One of the advanced capabilities of solution extensions is they allow partners to author their own health checks. In the portal, SBE health check issues will be reported in the "Azure Stack SBE Health" entry as shown at:
https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deploy-via-portal#validate-and-deploy-the-system

If such solution extension implemented tests prior to deployment they should be addressed based on their Severity (e.g. if *CRITICAL* it must be fixed) as per the partner provided *Remediation* guideance.  Because these checks are partner provided, partner documentation and known issues should be consulted as appropriate.

## Scenario: Deployment failures in action plan

Once the deployment action plan starts, the `C:\CloudDeployment\logs\CloudDeployment.*.log` file(s) on the first node can be consulted if additional information is desired (to have more context around the exception message reported in the portal).

### Identifying deployment failure scenario is SBE related
First confirm the action plan failed on a SBE step. This can be easily identified by "SBE" or "SBEPartner" being mentioned in the deployment exception as reported by the means being used to monitor the deployment (using the Deployments tool under the Cluster Resource in the portal is recommended).

### SBE Content Integrity Issues

You can identify this scenario by error messages that have `Test-SBEContentIntegrity` in the exception stack trace. In an effort to prevent injection attacks or failures due to modification of SBE content after it is extracted from the SBE zip file, content integrity checks are performed regularly throughout the SBE action plan steps. This failure indicates something has added, removed, or modified files to one of the following locations (look at the exception message for which one):
- `c:\CloudDeployment\ExtractedSBE` - only used up until shortly after the cluster is configured
- `c:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\SBE\Staged\Content` - Once populated this can never be tampered with
- `d:\CloudContent\Microsoft_Reserved\Update\SBECache\<sbe version>` - Will only exist while an SBE action plan or healthcheck is running.  Replace `d:\` with `c:\` for systems that don't have a `d:` drive.

Check the `C:\CloudDeployment\logs\CloudDeployment.*.log` files for details on which files have been added/removed to gain insight into the root cause of this exception.

Before proceeding with the less concerning repairs discussed below, **assume there was an attack** and carefully evaluate the failure with that mindset.  The most concerning type of error is a hash mismatch which would indicate a file being modified.  Assume the files were modified with malicious intent and proceed to carefully try to determine what was modified.  If the error is due to extra or missing files it is could be one of the non-malicious scenarios below.

The most common integrity check issues can be caused by a partner script creating a log file at the wrong path, expanding files into a reserved location, or other bugs that are not a security incident.  In such cases the issue should be investigated and pursued as a partner bug via a support case for the hardware partner.

Next most likely will be caused by a customer removing the files (thinking they don't need to be there).  In such cases the files can be restored from the one of the other paths (e.g. cloudMedia copy is fine, but the SBECache was modified) or from the original SBE zip file that was used to populate those paths originally.  Customer should be reminded these are reserved location and should not be edited.

### CAU Scan Failures
During deployment, if an SBE includes any CAU plugins, an `Invoke-CauScan` call will be executed to determine if there are any missing updates.  The expectation for HCI Integrated Systems and premier solutions that the latest firmware and drivers (matching the SBE) will be pre-instaled using partner specific automation or imaging and thus, the CAU scan should not only succeed, but report there is nothing to install in such cases. 

**NOTE:**If any updates (from the SBE) are needed, this will be represented by the SBE version being reported as `4.0.0.0` instead of the actual SBE version (to allow that same version to be installed as an SBE-update after the deployment). This is not a failure, just a potential result from a deployment where our design intent to avoid reboots during deployment limits us from doing the CAU run to resolve the situation direclty in the deployment process.

In the case that there is a failure during the scan step you may see an error message that aligns to this format:
```
SBE CAU Scan failed. The Microsoft.HardwareUpdatePlugin (2) plug-in reported a failure while attempting to scan for applicable updates on node "xxx" Additional information reported by the plug-in: ...
```
Key takeways from the above message:
- The `(2)` indicates there were at least 2 instances of the `Microsoft.HardwareUpdatePlugin` used and the ones that listed 2nd in the `Invoke-CauScan` commandline is the one that failed. Lack of a number following the plugin name (e.g. no `(2)` or `(3)`) indicates it is the first plugin of that name tha tfailed. The presense of a numerical entry like `(2)` or lack of it will indicate if it is the 1st or 2nd call to that plugin that is failing.
- The `...` portion of the message is the extent of the details that will be returned for the exception by CAU itself.  To get further details you will need to look at the plugin's side of the logs.
- Because this is a `Microsoft.HardwareUpdatePlugin` is referenced we know there will be at least 1 more layer of details available by checking the `c:\Observability\OEMDiagnostics\*.etl` files. You can use an approparite ETL log viewer or use `Get-ASEvent` to view such files as discussed above. 

**Note:** SBE steps use the numerical index to control the order plugins are called.  If you check the infra share at `...cloudmedia\SBE\Installed\Content\CAUPlugins` there will be directories called `01` and other numbers as shown below. The index controls the order, so without looking any further, the `(2)` in the message above would indicate the failure is with the plugin defined in the `02-Custom` directory.

![sbe-cauplugins-example-dir.png](./images/sbe-cauplugins-example-dir.png)

If the failure occurs in the plugin this is typically an issue with plugin automation, the payload being installed (e.g. FW or drivers files), or a BMC configuration error (e.g. Many SBE CAU plugins rely on the BMC USB pass-through NIC to install firmware). The correction of any of these issues will likely require support engagement with SBE publisher (the hardware vendor) to resolve, but you may be able to find the root cause or at least identify a documented known issue by looking at the `c:\Observability\OEMDiagnostics\*.etl` files if the failure is with the `Microsoft.HardwareUpdatePlugin`.

Issues seen in this space to date:
- Scan fails because it can't reach the BMC via USB nic (fix - manually configure BMC properly)
- Scan fails due to exception in partner logic (fix - get a new SBE from partner)
- Scan fails due to HardwareUpdatePlugin COM server connection error (fix - stop/start the com service as listed below).
```
$comServerService = Get-Service -Name HardwareComServer -ErrorAction SilentlyContinue
if ($comServerService -ne $null)
{
    $comServerService | Stop-Service
    Start-Sleep -Seconds 5
    $comServerService | Start-Service
}
```