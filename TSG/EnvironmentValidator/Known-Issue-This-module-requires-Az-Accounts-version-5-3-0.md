# Symptoms

Having the right version of Az PS Modules is paramount to a successful Azure Local deployment, in some cases misaligned versions can lead to seemingly conflicting errors between validators. 

One such error is from ClusterWitness Validation:

```
Type 'ValidateClusterWitness' of Role 'EnvironmentValidator' raised an exception:

{
    "ExceptionType":  "text",
    "ErrorMessage":  "This module requires Az.Accounts version 5.3.0. An earlier version of Az.Accounts is imported in the current PowerShell session. Please open a new session before importing this module. This error could indicate that multiple incompatible versions of the Azure PowerShell cmdlets are installed on your system. Please see https://aka.ms/azps-version-error for troubleshooting information.",
    "ExceptionStackTrace":  "at \u003cScriptBlock\u003e, \u003cNo file\u003e: line 8"
}
```

This is misleading, because the Az.Storage module is later than it should be and thus complaining that Az.Accounts need to be updated.  When in fact a dependency module needs to be downgraded.



# Issue Validation

To confirm the scenario that you are encountering is the issue documented in this article, please run this script on the first node of the cluster:
```PowerShell
# These are the versions required up to Azure Local 2511
$RequiredModules = @{
    'Az.StackHCI' = '2.5.0'
    'Az.Accounts' = '4.0.2'
    'Az.Resources' = '7.8.0'
    'Az.Storage' = '8.1.0'
}

# Check
foreach ($module in $RequiredModules.GetEnumerator()) {
    $RequiredModuleName = $module.Key
    $RequiredModuleVersion = $module.Value
    Write-Host "---------Checking $RequiredModuleName is exactly version $RequiredModuleVersion ------------"
    
    # Get all versions of the required module
    $installedModules = @()
    $installedModules = @(Get-Module -Name $RequiredModuleName -ListAvailable)

    # Check if the required version is installed and it is the only version installed
    # if it is, output success in green
    # if not output the current versions and their Installed locations in red
    if ($installedModules.Count -eq 1 -and $installedModules[0].Version.ToString() -eq $RequiredModuleVersion) {
        Write-Host "$RequiredModuleName version $RequiredModuleVersion is correctly installed." -ForegroundColor Green
    }
    else {
        Write-Host "$RequiredModuleName version $RequiredModuleVersion is NOT correctly installed. Current installed versions:" -ForegroundColor Red
        foreach ($mod in $installedModules) {
            Write-Host "Version: $($mod.Version) InstalledLocation: $($mod.InstalledLocation)" -ForegroundColor Red
        }
    }
    Write-Host "---------------------------------------------------------------------------------- `n"
}
```

It will indicate which modules should be in place and which should not.

# Mitigation Details

Clear the PowerShell environment, leaving only the required modules. For each module that failed in the above output, run the following:

## Az.StackHCI

```PowerShell
$RequiredModuleName = 'Az.StackHCI'
$RequiredModuleVersion = '2.5.0'
# Get all versions of the required module, this should look the same as as above
Get-InstalledModule -Name $RequiredModuleName -AllVersions

#Uninstall all but the required version
Get-InstalledModule -Name $RequiredModuleName -AllVersions | Where-Object { $_.Version -ne $RequiredModuleVersion } | ForEach-Object { 
    Uninstall-Module -Name $RequiredModuleName -RequiredVersion $_.Version -Force
}

# if the required version was not present in the first command's output, install it.
Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Force -Repository PSGallery -AllowClobber

# Verify only the required version is installed
Get-InstalledModule -Name $RequiredModuleName -AllVersions
```

## Az.Accounts
```PowerShell
$RequiredModuleName = 'Az.Accounts'
$RequiredModuleVersion = '4.0.2'
# Get all versions of the required module, this should look the same as as above
Get-InstalledModule -Name $RequiredModuleName -AllVersions

#Uninstall all but the required version
Get-InstalledModule -Name $RequiredModuleName -AllVersions | Where-Object { $_.Version -ne $RequiredModuleVersion } | ForEach-Object { 
    Uninstall-Module -Name $RequiredModuleName -RequiredVersion $_.Version -Force
}

# if the required version was not present in the first command's output, install it.
Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Force -Repository PSGallery -AllowClobber

# Verify only the required version is installed
Get-InstalledModule -Name $RequiredModuleName -AllVersions
```

## Az.Resources
```PowerShell
$RequiredModuleName = 'Az.Resources'
$RequiredModuleVersion = '7.8.0'
# Get all versions of the required module, this should look the same as as above
Get-InstalledModule -Name $RequiredModuleName -AllVersions

#Uninstall all but the required version
Get-InstalledModule -Name $RequiredModuleName -AllVersions | Where-Object { $_.Version -ne $RequiredModuleVersion } | ForEach-Object { 
    Uninstall-Module -Name $RequiredModuleName -RequiredVersion $_.Version -Force
}

# if the required version was not present in the first command's output, install it.
Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Force -Repository PSGallery -AllowClobber

# Verify only the required version is installed
Get-InstalledModule -Name $RequiredModuleName -AllVersions
```

## Az.Storage
```PowerShell
$RequiredModuleName = 'Az.Storage'
$RequiredModuleVersion = '8.1.0'
# Get all versions of the required module, this should look the same as as above
Get-InstalledModule -Name $RequiredModuleName -AllVersions

#Uninstall all but the required version
Get-InstalledModule -Name $RequiredModuleName -AllVersions | Where-Object { $_.Version -ne $RequiredModuleVersion } | ForEach-Object { 
    Uninstall-Module -Name $RequiredModuleName -RequiredVersion $_.Version -Force
}

# if the required version was not present in the first command's output, install it.
Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Force -Repository PSGallery -AllowClobber

# Verify only the required version is installed
Get-InstalledModule -Name $RequiredModuleName -AllVersions
```

## Verify the setting 
Verify the modules are correct with the first script.

# Cause

An out of band installation of a later module has pushed up the version of a dependency module.

# Next action

Rerun validation from the portal.