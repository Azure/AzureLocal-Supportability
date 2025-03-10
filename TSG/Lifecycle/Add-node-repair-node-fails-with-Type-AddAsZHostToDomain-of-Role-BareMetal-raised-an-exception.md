# Symptoms

In scenario where a stamp has been upgraded from **2311 or earlier directly to 2408 or 2408.1**, add node and repair node operations will fail with the following error:

Type 'AddAsZHostToDomain' of Role 'BareMetal' raised an exception

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following error:


```
ActionPlanInstanceID: a542a185-4e82-4432-913f-4771ed0cc599 WarningMessage:[F0901-121]:Task: Invocation of interface 'AddAsZHostToDomain' of role 'Cloud\Infrastructure\BareMetal' failed:

Type 'AddAsZHostToDomain' of Role 'BareMetal' raised an exception:

Exception calling "GetCredential" with "1" argument(s): "Exception of type 'CloudEngine.Configurations.SecretNotFoundException' was thrown."
at AddAsZHostToDomain, C:\NugetStore\Microsoft.AzureStack.Solution.Deploy.CloudDeployment.10.2408.0.150\content\Classes\BareMetal\BareMetal.psm1: line 3362
at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2408.0.556\content\ECEWinService\InvokeInterfaceInternal.psm1: line 139
at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2408.0.556\content\ECEWinService\InvokeInterfaceInternal.psm1: line 134 - 9/5/2024 2:40:10 AM
```


# Cause

In 2402, the ECE store object "ActiveCreds" was created to dynamically store active credentials. In previous builds, this list was defined statically in code. During secret reload, if "ActiveCreds" object is not found in the store, the ECE agent uses a hard-coded "fallback list" of secrets. In 2408, the TemporaryDomainAdmin credential was added, but not added to the fallback list. So on updates from 2311 to 2408, the TemporaryDomainAdmin object is not loaded during secret store reload, and this credential is required for AddNode/RepairNode. This issue has been fixed in 2408.2.
 
# Mitigation Details

Run the following script to restore the values of ActiveCreds and TemporaryDomainAdmin in ECE secret store.


```Powershell
$eceClient = Create-ECEClientSimple
$credListValue = "ActiveCreds;AADAzureToken,LocalAdmin,CACertificateCred,DomainAdmin,DeploymentDomainAdmin,AzureStackSEDKey,RegistrationSP,RegistrationTokenCache,WitnessCredential,DefaultARBApplication,FCAKeys,InfraVmAdmin,InfraVmAdminPrior,TemporaryDomainAdmin"
$setting = [Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.EncryptedSetting]::new()
$setting.SettingValue = $credListValue
$eceClient.SetEncryptedSettingValue("ActiveCreds", $setting).Wait()


$setting = [Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.EncryptedSetting]::new()
$credential = Get-Credential # Get the tda credential
$setting.SettingValue = "$($credential.UserName);$($credential.GetNetworkCredential().Password)"
$eceClient.SetEncryptedSettingValue("TemporaryDomainAdmin", $setting).Wait()
```
