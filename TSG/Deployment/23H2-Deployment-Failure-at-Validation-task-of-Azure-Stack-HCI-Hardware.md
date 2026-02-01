# Symptoms

When deploying an Azure Local 23H2 instance via Azure Portal, you may hit a failure in the Validation task "Azure Stack HCI hardware" during the validation stage. If you click the "Error(View detail) of the above failed task, you will see the below exception.  

```Text

Type 'ValidateHardware' of Role 'EnvironmentValidator' raised an exception: {
"ExceptionType": "json", "ErrorMessage": { "Message": "Hardware requirements not met. 
Review output and remediate.", "Results": [ { "Name": 
"AzStackHci_Hardware_Test_Processor_Instance_Property_VMMonitorModeExtensions", 
"DisplayName": "Test Processor Property VMMonitorModeExtensions
```
or
```Text
{"code":"UpdateDeploymentSettingsDataFailed","message":"Deployment Settings validation failed.","details":
[{"code":"UpdateDeploymentSettingsDataFailed",""message":"Failed to create deployment
settings. \nValidation status is
{Name=Azure Stack HCI Hardware, Description=Check hardware requirements, FullStepIndex=3,
StartTimeUtc=xxx, EndTimeUtc=xxx, Status=Error, Exception=Type
'ValidateHardware' of Role 'EnvironmentValidator' raised an exception:\"Message\":  \"Hardware requirements not met. 
```

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, please go through below two steps:
## 1. Verify "Virtualization-based security (VBS)" setting
Run this cmdlet on each node to check the result:
```Powershell

$result = SystemInfo | Select-String "Virtualization-based security"
Write-Host "VBS: $result"
if ($result -eq "Virtualization-based security: Status: Not enabled" -or $result -eq "Virtualization-based security: Status: Enabled but not running") {
    Write-Host "The VBS issue is hit. You can follow the below mitigation details section to mitigate the issue"
}
else {
    Write-Host "No issue found in VBS setting" 
}
```
## 2. Verify Secure Boot setting
Run this cmdlet on each node to check the result:
```Powershell
$secureBootEnabled = Confirm-SecureBootUEFI
Write-Host "SecureBootEnable: $secureBootEnabled"
if ($secureBootEnabled -eq $false) {
    Write-Host "SecureBoot issue is hit. You can follow the below mitigation details section to mitigate the issue"
}
else {
    Write-Host "SecureBoot is enabled. No issue found in SecureBoot setting"
}
```
Note: if both steps don't detect any issue, this is not the issue addressed by this article. Please refer to [Evaluate the deployment readiness of your environment for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/manage/use-environment-checker?view=azloc-24113&tabs=connectivity)
# Cause
"Virtualization Technology" was not enabled on BIOS or SecureBoot is not enabled

# Mitigation Details
On each node where the issue is hit, follow below steps:

1. Validate that BIOS setting of "Virtualization Technology" is enabled. If not, enable it in BIOS.

2. Validate that SecureBoot is enabled. If not enable it in BIOS

3. Restart the node.

4. In the Azure Portal, retry the failed validation by clicking "Try Again" button in the deploy blade, or start the validation again if there is no "Try Again" option.
