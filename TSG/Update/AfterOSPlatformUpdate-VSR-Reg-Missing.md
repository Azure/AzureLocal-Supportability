TSG: Registry path 'SYSTEM\CurrentControlSet\Services\VSR' not found during AfterOSPlatformUpdate

**Issue:**
Type 'AfterOSPlatformUpdate' of Role 'ComposedImageUpdate' raised an exception: Exception calling 'OnAfterOSSolutionUpdate' with '1' argument(s): 'Registry path 'SYSTEM\\CurrentControlSet\\Services\\VSR' not found.' at AfterOSPlatformUpdate.

**Mitigation:**
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
If further issues persist, please provide logs and additional context for troubleshooting.
