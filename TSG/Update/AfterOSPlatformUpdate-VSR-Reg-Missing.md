# TSG | 23H2 | 11.2510.1002.87 update fails at 'SYSTEM\CurrentControlSet\Services\VSR' not found during AfterOSPlatformUpdate

# Symptoms
Customers would encounter an update failure with an error similar to:

```
Type 'AfterOSPlatformUpdate' of Role 'ComposedImageUpdate' raised an exception: Exception calling 'OnAfterOSSolutionUpdate' with '1' argument(s): 'Registry path 'SYSTEM\\CurrentControlSet\\Services\\VSR' not found.' at AfterOSPlatformUpdate.
```
  
# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm that you are seeing the error message above in the update portal.

# Mitigation Details
Please run these commands in PowerShell on all the nodes of your cluster and then retry update:

```powershell
mkdir C:\Windows\System32\AzureLocalImage
$DesiredValue = '{"SolutionVersion": "11.2510.1002"}'
$RegKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\VSR"
$Key = "VSRInfo"
New-Item -Path $RegKeyPath -Force | Out-Null
New-ItemProperty -Path $RegKeyPath -Name $Key -PropertyType String -Force | Out-Null
Set-ItemProperty -Path $RegKeyPath -Name $Key -Value $DesiredValue
```

After running these commands, retry the update operation.

---
