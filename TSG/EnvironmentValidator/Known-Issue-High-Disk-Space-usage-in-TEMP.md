# Symptoms

Multiple folders exist in ```C:\Users\HCIOrchestrator\AppData\Local\Temp``` containing AzStackHci.EnvironmentChecker nuget contents.

# Issue Validation

To confirm the scenario that you are encountering is the issue documented in this article, please run this script:
```PowerShell
$nugetName = 'AzStackHci.EnvironmentChecker'
$tempPath = 'C:\Users\HCIOrchestrator\AppData\Local\Temp'
$tempNugetFolders = Get-ChildItem -Path $tempPath -Recurse -Filter "$nugetName.*" -Directory -ErrorAction SilentlyContinue
$tempNugetFolders.Count
```
If it returns a number of folders the nuget may be taking up space, follow the mitigation steps below to resolve the issue on the node. 

# Mitigation Details

On each node where the issue exists, run the following script:

```PowerShell
$nugetName = 'AzStackHci.EnvironmentChecker'
$tempPath = 'C:\Users\HCIOrchestrator\AppData\Local\Temp'
$tempNugetFolders = Get-ChildItem -Path "$env:TEMP" -Recurse -Filter "$nugetName.*" -Directory -ErrorAction SilentlyContinue
foreach ($tnf in $tempNugetFolders)
{
    try
    {
        $randomFileNameRegex = '^[a-z0-9]{8}\.[a-z0-9]{3}$'
        $tnfParent = Split-Path -Path $tnf.FullName -Parent
        $parentFolderName = Split-Path -Path $tnfParent -Leaf
        if (-not ($parentFolderName -match $randomFileNameRegex))
        {
            Write-Host "Skipping removal of temp nuget folder $tnfParent as it does not match expected pattern."
            continue
        }
        $allowedAgeDays = 1
        $age = (Get-Date) - (Get-Item -Path $tnfParent | ForEach-Object LastWriteTime)
        if ($age.TotalDays -lt $allowedAgeDays)
        {
            Write-Host "Skipping removal of temp nuget folder $tnfParent as its last write time was $($age.TotalDays) days ago, which is less than $allowedAgeDays days."
            continue
        }
        Write-Host "Removing temp nuget folder $tnfParent"
        Remove-Item -Path $tnfParent -Recurse -Force -ErrorAction Stop
    }
    catch
    {
        Write-Host "Unable to remove temp nuget folder. Exception: $($_.Exception.GetType().FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
```