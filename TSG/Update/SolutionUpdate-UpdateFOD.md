## Symptoms
Solution Update failing after Brownfield action plan.

## Root Cause

This error indicates that the **UpdateFOD** interface in the **ComposedImageUpdate** role failed as Composed Image is not used for Brownfield.

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
