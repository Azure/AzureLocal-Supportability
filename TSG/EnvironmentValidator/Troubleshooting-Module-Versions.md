# Overview

The Environment Checker PowerShell module is available inbox, externally from PSGallery and embedded in the image. The inbox version should take precedence, and an attempt is made to remove any versions that were not "inbox" prior to lifecycle events with automation.

If the PowerShell gallery version has been installed prior to deployment or some other lifecycle event, we recommend removing it after use.

Also, as a precaution, it can be worth quickly "cleaning" the module up when troubleshooting an issue to simplify any troubleshooting.

# Symptoms

In rare occasions a PowerShell module can fail to be removed, this can be due to file locking, something unexpected happened during installed, or other reasons.  The automation can fail to clean the modules and throw an exception during validation:

```
Type 'ValidateConnectivity' of Role 'EnvironmentValidator' raised an exception:
{
    "ExceptionType":  "text",
    "ErrorMessage":  "No match was found for the specified search criteria and module names \u0027AzStackHci.EnvironmentChecker\u0027.",
    "ExceptionStackTrace":  "at Uninstall-Module\u003cProcess\u003e, C:\\Program Files\\WindowsPowerShell\\Modules\\PowerShellGet\\2.2.5\\PSModule.psm1: line 12733\r\nat CleanEnvironmentValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 1230\r\nat EnvironmentValidatorImport, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 784\r\nat RunSingleValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 806\r\nat ValidateConnectivity, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 265\r\nat \u003cScriptBlock\u003e, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 147\r\nat Invoke-EceInterfaceInternal, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 142\r\nat \u003cScriptBlock\u003e, \u003cNo file\u003e: line 36"
}
```

# Issue Validation

If impacted, when the following PowerShell is run on a node, it returns modules which have been via Install-Module.

```
Get-Module -Name $moduleName -ListAvailable | Where-Object {$_.Path -like "*$($_.Version)*"}
```

# Mitigation Details

To clean up any modules not included in product code, run this PowerShell on all nodes:

```
$moduleName = "AzStackHci.EnvironmentChecker"
# Unload any previously loaded modules
$loadedModule = Get-Module -Name $moduleName | Where-Object {$_.Path -like "*$($_.Version)*"}
if ($loadedModule)
{
    Write-Host -Verbose "Loaded module(s) found for $($loadedModule.Name):"
    Write-Host ($loadedModule | Format-Table Name, Version, Path -AutoSize | Out-String)
    Write-Host "Unloading"
    $loadedModule | Remove-Module -Force
}

# Uninstall any modules installed from external
$installedModule = Get-Module -Name $moduleName -ListAvailable | Where-Object {$_.Path -like "*$($_.Version)*"}
if ($installedModule)
{
    Write-Host "Externally installed module(s) found for $($installedModule.Name):"
    Write-Host ($installedModule | Format-Table Name, Version, Path -AutoSize | Out-String)
    Write-Host "Uninstalling module(s)"
    $installedModule | Uninstall-Module -Force -ErrorAction SilentlyContinue
    foreach ($im in $installedModule)
    {
        Write-Host "Checking module still exists on disk..."
        if (Test-Path $im.ModuleBase -ErrorAction SilentlyContinue) {
            Write-Host "Removing old module files $($im.ModuleBase)"
            Remove-Item -Path $im.ModuleBase -Recurse -Force
        }else {
            Write-Host "Old module files not found at $($im.ModuleBase)"
        }
    }
} else {
    Write-Host "Nothing to uninstall"
}

# Check final module is our one.
$FinalModule = Get-Module -Name $moduleName -ListAvailable
Write-Host "Final installed module:"
Write-Host ($FinalModule | Format-Table Name, Version, Path -AutoSize | Out-String)
```

The output should contain a single module where the path is C:\Program Files\WindowsPowerShell\Modules\AzStackHci.Environment (without a version number leaf).