## Symptoms
Solution Update failing after Solution Upgrade action plan.

## Root Cause

This error indicates that the **UpdateFOD** interface in the **ComposedImageUpdate** role failed as Composed Image is not used for OS Upgrade.

## Error
StackTrace:
CloudEngine.Actions.InterfaceInvocationFailedException: Type '**UpdateFOD**' of Role '**ComposedImageUpdate**' raised an exception:

**You cannot call a method on a null-valued expression.**
at UpdateFOD, C:\NugetStore\Microsoft.AzureStack.ComposedImage.Update.10.2504.0.3065\content\classes\ComposedImageUpdate.psm1: line 189
at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEAgent.Service.10.2506.0.989\content\pkg\Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Agent.Host\InvokeInterfaceInternal.psm1: line 163
at Invoke-EceInterfaceInternal, 



## Mitigation Steps

> **Note:** Perform these steps on **each affected node**.

1. Open an elevated PowerShell session.

2. Run the following script to create (if missing) and set the required registry key and value:

```powershell
# TSG Mitigation Script: Update 'COMPOSED_BUILD_ID' Registry Value

$ComposedImageRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ComposedBuildInfo\Parameters"
$ComposedBuildIdKey = "COMPOSED_BUILD_ID"
$ComposedBuildIdValue = "11.2504.0.3141"

if (!(Test-Path -Path $ComposedImageRegistryKeyPath))
{
    Write-Host "Creating registry key $($ComposedImageRegistryKeyPath) with key $($ComposedBuildIdKey)";
    New-Item -Path $ComposedImageRegistryKeyPath -Force | Out-Null;
    New-ItemProperty -Path $ComposedImageRegistryKeyPath -Name $ComposedBuildIdKey -PropertyType String -Force | Out-Null;
    Set-ItemProperty -Path $ComposedImageRegistryKeyPath -Name $ComposedBuildIdKey -Value $ComposedBuildIdValue
    Write-Host "Set registry with value $($ComposedBuildIdValue)"
}

```
3. Retry the Solution Update.
