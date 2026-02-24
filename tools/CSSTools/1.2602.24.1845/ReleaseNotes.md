This article describes the contents of the [Microsoft.AzLocal.CSSTools 1.2602.24.1845](https://www.powershellgallery.com/packages/Microsoft.AzLocal.CSSTools/1.2602.24.1845) module changes. This update includes improvements and fixes for the latest release of Microsoft.AzLocal.CSSTools that is supported to run on Azure Local deployments.

# Download the update
You can download the latest version of Microsoft.AzLocal.CSSTools by running `Update-Module -Name Microsoft.AzLocal.CSSTools` on each of the Azure Local cluster nodes. After you have downloaded the module, ensure you remove the current version from runspace by using `Remove-Module` and import the latest version using `Import-Module`.

```powershell
# update the current module directly from PowerShell Gallery
Update-Module -Name Microsoft.AzLocal.CSSTools

# remove the current version from the runspace in case it was already imported prior to update
Remove-Module -Name Microsoft.AzLocal.CSSTools

# load the latest version into the runspace
Import-Module -Name Microsoft.AzLocal.CSSTools
```

# What's new

We have introduced two new components called `KnownIssues` and `VirtualMachines` for our Support Module Insights. We have scaled to include an additional 36 analyzers (not include build analyzers) and 63 rules. To see a full list of tests performed, look at each Component:

- [AzureLocalServices](/tools/CSSTools/1.2602.23.2233/insights/AzureLocalServices.md)
- [HostCompute](/tools/CSSTools/1.2602.23.2233/insights/HostCompute.md)
- [HostNetwork](/tools/CSSTools/1.2602.23.2233/insights/HostNetwork.md)
- [HostStorage](/tools/CSSTools/1.2602.23.2233/insights/HostStorage.md)
- [OperatingSystem](/tools/CSSTools/1.2602.23.2233/insights/OperatingSystem.md)
- [Support.AksArc](/tools/CSSTools/1.2602.23.2233/insights/Support.AksArc.md)
- [VirtualMachines](/tools/CSSTools/1.2602.23.2233/insights/VirtualMachines.md)

In addition to some code and reliability fixes, we have added the following functionality.
- `Install-AzsSupportModule`: Used to distribute the current module to remote computers within your Azure Local environment.
- `Get-AzsSupportLcmDeploymentUserName`: Retrieves the deployment username from within Lifecycle Manager (LCM).
- `Get-AzsSupportBlocklistedDisk`: Gets all blocklisted physical disks from the cluster filter service.
- `Show-AzsSupportSDNStateSummary`: Checks the current status of SDN, including if FCNC is deployed and if SDN services are online.

A comprehensive list of all our functions can be found under [functions](/tools/CSSTools/1.2602.23.2233/functions)

# Contact Us
If you are encountering an issue, or need assistance, refer to [questions-or-feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback).
