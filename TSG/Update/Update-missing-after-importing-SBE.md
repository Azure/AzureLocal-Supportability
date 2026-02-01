# Solution update "missing" after importing SBE with Add-SolutionUpdate

# Symptoms
A solution update (e.g. `10.2408.0.29`) that was previously in the AdditionalContentRequired State is missing from `Get-SolutionUpdate` list after the `Add-SolutionUpdate` call to add (aka import) a SBE.

# Issue Validation
See below for a generic scenario and validate that a scenario similar to steps 1-3 has occurred. 

## Step 1 - Update available in AdditionalContentRequired state:

```
PS C:\Users\lcmuser> $Update = Get-SolutionUpdate | Where-Object {$_.State -ne "Installed"} 
PS C:\Users\lcmuser> $Update | ft DisplayName, PackageType, Version, SbeVersion, State

DisplayName                      PackageType Version      SbeVersion     State
-----------                      ----------- -------      ----------     -----
SBE_Contoso_Gen3_4.1.2412.5      SBE      4.1.2412.5      4.1.2412.5     AdditionalContentRequired
Azure Local 2411 bundle      Solution   10.2411.0.24      4.1.2412.5     AdditionalContentRequired
```
This is normal and part of the expected flow for SBE updates as discussed at [Solution Builder Extension updates on Azure Local, version 23H2 - Azure Local | Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension?view=azloc-24113#discover-solution-builder-extension-updates-via-powershell).

## Step 2 - Wrong SBE imported (probably older or wrong family)
Instead of the requested `4.1.2412.5` SBE that was listed as required, users may mistakenly download and call Add-SolutionUpdate with either:
- An older SBE version of the same family of the requested version (e.g. it matches the server hardware, but is older SBE version)
- A newer SBE that doesn't match the hardware (e.g. different family from same vendor) that doesn't include the original SBE `4.1.2312.5` in the manifest 

For the case of this example, assume the older SBE_Contoso_Gen3_4.1.2407.1 SBE was imported with Add-SolutionUpdate.
 
## Step 3 - Solution update "disappears"
The updates that were previously listed in AdditionalContentRequired state are replaced with only a listing of the update that was added in step 2.

In the most typical case of this scenario, ONLY the SBE added in step 2 will be listed and it will have the `HasPrequisite` state:
```
PS C:\Users\lcmuser> $Update = Get-SolutionUpdate | Where-Object {$_.State -ne "Installed"} 
PS C:\Users\lcmuser> $Update | ft DisplayName, PackageType, Version, SbeVersion, State

DisplayName                      PackageType Version      SbeVersion     State
-----------                      ----------- -------      ----------     -----
SBE_Contoso_Gen3_4.1.2407.1      SBE      4.1.2407.1      4.1.2407.1     HasPrerequisite
```

But it may also list the state as `Ready` state depending on the specifics of what solution versions supported by the SBE that was added in step 2 .

**IMPORTANT:** The primary symptom is that the previously listed updates (including the 10.2411.0.24 Solution Update) are now missing from the Get-SolutionUpdate output.

# Cause
The Azure Local Update Service treats the imported update content (the SBE that was imported via Add-SolutionUpdate) as a *partial override* to the online update discovery manifests. This override to the online manifests is by design to enable individual clusters to bypass the default updates published online (e.g. as part of pre-release testing, a private hotfix release, etc).

**Note:** "Update discovery manifests" list all available updates and which solution updates they are applicable to (e.g. SBE v3 works with solution update v2 and so on). These manifests define the supported validated recipes for Azure Local and are used to assure only the **latest supported combinations** of SBE and Azure Local are listed as "Solution" update options. 

## Why the solution update is missing
The update service re-evaluates which updates are available based on the new local manifest it has been provided by `Add-SolutionUpdate`. In the case that the wrong (older) SBE is imported, the Solution update may longer be available if there is no longer a clearly supported scenario to install it.  In most cases the following results in the update being hidden:
- older imported manifest indicates the older SBE v1 is supported for solution update X
- online manifest indicates a newer SBE v2 is supported for solution update X

In this case, the solution update is hidden because the update service is unable to clearly guide the user to a known valid
solution update given the conflict between the local and online SBE update manifests as listed above.  In light of this conflict, only the imported SBE (in this case SBE v1) is listed as an option until after that SBE-only update is installed (after which there will no longer be a conflict and the missing solution update will potentially return).

## Why the listed SBE is `HasPrerequisite` state
Additionally, the `HasPrequisite` state for the imported SBE is caused if that SBE doesn't support installation on the current Azure Local version and instead was required to be installed as part of a combined SBE + Azure Local solution update.  As outlined above, the conflicting solution update information has caused the solution update to be hidden so the imported SBE is only considered Ready to install if the Azure Local version that is currently installed is supported by the imported SBE.

**Scenario A: the imported SBE state is `HasPrequisite`**
- CurrentVersion (as reported by `Get-SolutionUpdateEnvironment`) = 10.2405.3.7
- Imported SBE manifest indicates it supports installing with 10.2408.*.* and 10.2411.*.*

Because the imported SBE doesn't support 2405.* and the solution update option is not available (due to conflicting manifests) this SBE has HasPrequisite state (to indicate 2408.* or newer is needed before that SBE can install).

**Scenario B: the imported SBE state is `Ready`** 
- CurrentVersion (as reported by `Get-SolutionUpdateEnvironment`) = 10.2405.3.7
- Imported SBE manifest indicates it supports installing with 10.2405.*.* and 10.2408.*.*

Because the imported SBE indicates it supports 2405.*, the imported SBE is able to be installed.


# Mitigation Details
The easiest solution to be able to install the missing solution update is to use `Add-SolutionUpdate` to import the originally requested SBE as was reported in Step 1 of the scenario above.  

In that example, importing the SBE_Contoso_Gen3_4.1.2412.5 files will cause the solution update option to return (this time in the `Ready` state).

If the information of which SBE to download is not known to restore the cluster the following process can be used to return to the Step 1 state:

1. Get the URI for the online SBE manifest:
If your cluster has 10.2408.x or newer version installed, you can directly extract the URI from the following syntax:
```
$diagnosticInfo = Get-SolutionDiscoveryDiagnosticInfo 3>$null 4>$null
$diagnosticInfo.Configuration.ComponentUris["SBE"]
```

If your cluster has a version lower than 10.2408.x (e.g. 10.2405.3.7), just select the URI from the following list that corresponds to your server manufacturer:
- https://aka.ms/AzureStackSBEUpdate/DataON
- https://aka.ms/AzureStackSBEUpdate/Dell
- https://aka.ms/AzureStackSBEUpdate/HitachiVantara
- https://aka.ms/AzureStackSBEUpdate/HPE   (use this if you have any other HPE model than DL380 Gen11 Integrated System)
- https://aka.ms/AzureStackSBEUpdate/HPE-ProLiant-Standard  (use this if you have a DL380 Gen11 Integrated System)
- https://aka.ms/AzureStackSBEUpdate/Lenovo

2. Download the XML file (using your browser or preferred mechanism)
Note: that URI will likely be a `https://aka.ms` based redirection address that will redirect to your hardware vendor's manifest publishing endpoint.

3. On any node, copy the downloaded online manifest XML file to replace the existing file under `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\Manifests`

4. Call `Get-SolutionUpdate` wait ~2 minutes and then call it again.  At this point the missing updates should have returned (in `AdditionalContentRequired` state again)

5. Follow the normal documented process to use `Add-SolutionUpdate` to add the requested SBE (the right one this time):
https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension?view=azloc-24113#discover-solution-builder-extension-updates-via-powershell
