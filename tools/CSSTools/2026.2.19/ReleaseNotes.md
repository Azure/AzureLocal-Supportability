This article describes the contents of the Microsoft.AzLocal.CSSTools 1.2602.19.## module changes. This update includes improvements and fixes for the latest release of Microsoft.AzLocal.CSSTools that is supported to run on Azure Local deployments.

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


# Known Issues


# Contact Us
If you are encountering an issue, or need assistance, refer to [questions-or-feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback).
