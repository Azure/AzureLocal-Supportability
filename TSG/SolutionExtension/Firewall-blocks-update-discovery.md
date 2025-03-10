# Update discovery issues - firewall blocking SBE manifest

# Symptoms

Attempting to check for solution updates in Azure Local using either the Portal or PowerShell can fail with various symptoms if the hardware vendor Solution Builder Extension (SBE) manifest endpoint is blocked by the customer firewall. As outlined below this endpoint rule is different depending on the system manufacturer as reported by BIOS.

Depending on the version of Azure Local installed the failure pattern will vary:
- Prior to 10.2405 (10.2402.* and older) symptoms may include:
   - `Get-SolutionUpdate` and other lifecycle management cmdlets (`Start-SolutionUpdate`, `Get-SolutionUpdateEnvironment`, `Add-SolutionUpdate`, and other `SolutionUpdate` related cmdlets) may throw an exception of type: `ConnectionFailureException`
   - `Get-SolutionUpdate` can return unexpected update states for SBE packages that have been imported (aka sideloaded) using the `Add-SolutionUpdate` cmdlet. For example, the update may report `State: HealthCheckFailed`.
- For version 10.2405 and newer symptoms may include:
   - `Get-SolutionUpdate` not reporting expected updates at all.  This is especially true for quarterly feature releases such as the 10.2408.0.x and 10.2502.0.x releases (the 10.2411.0.x release is different and is expected to be visible even if the firewall is blocking the manifest).
   - `Get-SolutionUpdate` not reporting expected hardware vendor SBE updates.
   - Azure portal not listing expected updates as available to install


# Issue Validation

Prior to version 10.2405, the most common symptom would be to see an exception like the below example when trying to use a `SolutionUpdate` related cmdlet:

```
Get-SolutionUpdateEnvironment : A WebException occurred while sending a RestRequest. WebException.Status:
ConnectFailure on
[https://clusternodeX.something.com:4900/providers/Microsoft.Update.Admin/updateLocations?api-version=2022-08-01](https://clusternodeX.something.com:4900/providers/Microsoft.Update.Admin/updateLocations?api-version=2022-08-01 "https://clusternodeX.something.com:4900/providers/microsoft.update.admin/updatelocations?api-version=2022-08-01")
At line:1 char:1
+ Get-SolutionUpdateEnvironment
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   + CategoryInfo          : NotSpecified: (:) [Get-SolutionUpdateEnvironment], ConnectionFailureException
   + FullyQualifiedErrorId : Microsoft.AzureStack.Common.Infrastructure.Http.Client.ErrorModel.ConnectionFailureExcep
  tion,Microsoft.AzureStack.Lcm.PowerShell.GetSolutionUpdateEnvironmentCmdlet
```

Regardless of the version of Azure Local installed, the SbeManifestResult property returned by the `Get-SolutionDiscoveryDiagnosticInfo` cmdlet can be used to determine if the Solution Builder Extension (SBE) update manifest published by your hardware vendor is being blocked:

A cluster that is unable to reach the manifest will report a Status of `ConnectionFailure` as shown below
```
[host1]: PS C:\> (Get-SolutionDiscoveryDiagnosticInfo).SbeManifestResult | FL *

ManifestSource : https://aka.ms/AzureStackSBEUpdate/Your-Manufacturer
Status         : ConnectionFailure
Description    : There was an exception reading the discovery manifest: An error occurred while sending the request..  
```

Conversely, a cluster is not impacted by this issue will report:
```
[host1]: PS C:\> (Get-SolutionDiscoveryDiagnosticInfo).SbeManifestResult | FL *

ManifestSource : https://aka.ms/AzureStackSBEUpdate/Your-Manufacturer
Status         : Ok
Description    : Successfully read the discovery manifest.
```
# Cause

Azure Local instances need to be able to access the online manifest from your hardware vendor to determine which solution updates and SBE updates should be listed as available for your cluster. Because Azure Local uses a validated solution recipe to track the combined set of updates available from both hardware vendors (their solution extension updates) and Microsoft, inability to access the hardware vendor specific manifest can actually cause both Azure Local solution updates and SBE updates to not list as available.

The most common cause of this issue is the firewall blocking access to one of the following addresses or the redirection target of one of those addresses.

By default, each Azure Local instance uses the BIOS reported manufacturer to determine which solution extension updates are available using a vendor-specific redirection URI (pick the address that matches your server Manufacturer or SBE family):

- https://aka.ms/AzureStackSBEUpdate/DataON
- https://aka.ms/AzureStackSBEUpdate/Dell
- https://aka.ms/AzureStackSBEUpdate/HitachiVantara
- https://aka.ms/AzureStackSBEUpdate/HPE
- https://aka.ms/AzureStackSBEUpdate/HPE-ProLiant-Standard
- https://aka.ms/AzureStackSBEUpdate/Lenovo
- https://aka.ms/AzureStackSBEUpdate/Manufacturer-as-reported-by-BIOS

Additionally, customers may elect to override the default SBE endpoint using the `Set-OverrideUpdateConfiguration -OverrideOemUpdateUri` cmdlet and may no longer be using the default endpoint.

Be sure to check the `ManifestSource` property returned by `Get-SolutionDiscoveryDiagnosticInfo` to determine the endpoint that your cluster is currently using:

```
[host1]: PS C:\> (Get-SolutionDiscoveryDiagnosticInfo).SbeManifestResult.ManifestSource

https://aka.ms/AzureStackSBEUpdate/Manufacturer-as-reported-by-BIOS
```

# Mitigation Details

Adjust your firewall rules to allow outbound https (port 443) access to the following 3 endpoints:

1. The redirection target of the uri reported by:
```
(Get-SolutionDiscoveryDiagnosticInfo).Configuration.ComponentUris["SBE"]
```
   - If `Get-SolutionDiscoveryDiagnosticInfo` fails with `ConnectionFailureException` determine the uri for your cluster using the list provided above.
2. **aka.ms**  - This redirects Azure Local instances to hardware vendor specific SBE manifest endpoints
3. **redirectiontool.trafficmanager.net**  - This is part of the Microsoft service that implements the aka.ms redirection

**TIP:** To determine the redirection target, you can browse to the ManifestSource uri (on another system) and note the URL that it redirects to in your browser address bar.

If in doubt, please review the documentation provided by your hardware vendor as part of the Solution Builder Extension (SBE) for guidance on firewall rules required to support their extension.
