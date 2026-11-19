# Symptoms
If update fails with one of the following errors:
```
Type 'AddDeploymentTypeParameter' of Role 'BareMetal' raised an exception: Property DeploymentLaunchType does not exist at path HKEY_LOCAL_MACHINE\Software\Microsoft\AzureStackStampInformation. at AddDeploymentTypeParameter, C:\NugetStore\Microsoft.AzureStack.Solution.Deploy.CloudDeployment.10.2503.0.9\content\Classes\BareMetal\BareMetal.psm1: line 5144 at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 139 at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 134 at <ScriptBlock>, <No file>: line 36_
```
```
Type 'UpdateArbAndExtensions' of Role 'MocArb' raised an exception: [[UpgradeArbAndExtensions] - Get SPN credentials from ECE Store if available] Token cache based deployment is not Supported. Please redeploy with SPN or CloudDeploy Command Arguments ------- --------- Login-AzureForMocarb {tenantId=9f13f438-aa96-4221-8069-d288c5fc3f3a, subcriptionId=e99de714-0273-4e67-a0e0... UpgradeArbAndExtensionsInternal {Parameters=CloudEngine.Configurations.EceInterfaceParameters} {} <ScriptBlock> {CloudEngine.Configurations.EceInterfaceParameters, MocArb, UpdateArbAndExtensions, C... Invoke-EceInterfaceInternal {CloudDeploymentModulePath=C:\NugetStore\Microsoft.AzureStack.Solution.Deploy.CloudDe... <ScriptBlock> {CloudEngine.Configurations.EceInterfaceParameters, 9dd1ffa3-ae32-0044-bb2a-d29d32aed... at at Trace-Error, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\Common\Tracer.psm1: line 63 at Login-AzureForMocarb, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbHelper.psm1: line 4059 at UpgradeArbAndExtensionsInternal, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbHelper.psm1: line 2523 at UpdateArbAndExtensions, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbLifeCycleManager.psm1: line 425 at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 139 at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 134 at <ScriptBlock>, <No file>: line 36 Command Arguments ------- --------- Login-AzureForMocarb {tenantId=9f13f438-aa96-4221-8069-d288c5fc3f3a, subcriptionId=e99de714-0273-4e67-a0e0... UpgradeArbAndExtensionsInternal {Parameters=CloudEngine.Configurations.EceInterfaceParameters} {} <ScriptBlock> {CloudEngine.Configurations.EceInterfaceParameters, MocArb, UpdateArbAndExtensions, C... Invoke-EceInterfaceInternal {CloudDeploymentModulePath=C:\NugetStore\Microsoft.AzureStack.Solution.Deploy.CloudDe... <ScriptBlock> {CloudEngine.Configurations.EceInterfaceParameters, 9dd1ffa3-ae32-0044-bb2a-d29d32aed... at at Trace-Error, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\Common\Tracer.psm1: line 63 at Login-AzureForMocarb, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbHelper.psm1: line 4179 at UpgradeArbAndExtensionsInternal, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbHelper.psm1: line 2523 at UpdateArbAndExtensions, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbLifeCycleManager.psm1: line 425 at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 139 at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 134 at <ScriptBlock>, <No file>: line 36 Command Arguments ------- --------- UpgradeArbAndExtensionsInternal {Parameters=CloudEngine.Configurations.EceInterfaceParameters} {} <ScriptBlock> {CloudEngine.Configurations.EceInterfaceParameters, MocArb, UpdateArbAndExtensions, C... Invoke-EceInterfaceInternal {CloudDeploymentModulePath=C:\NugetStore\Microsoft.AzureStack.Solution.Deploy.CloudDe... <ScriptBlock> {CloudEngine.Configurations.EceInterfaceParameters, 9dd1ffa3-ae32-0044-bb2a-d29d32aed... at Trace-Error, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\Common\Tracer.psm1: line 63 at UpgradeArbAndExtensionsInternal, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbHelper.psm1: line 3026 at UpdateArbAndExtensions, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbLifeCycleManager.psm1: line 425 at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 139 at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2503.0.881\content\ECEWinService\InvokeInterfaceInternal.psm1: line 134 at <ScriptBlock>, <No file>: line 36
```
# Issue Validation
Run the following commands to validate the issue:
```
Get-ItemProperty -Path "HKLM:\Software\Microsoft\AzureStackStampInformation" -Name DeploymentLaunchType
```
```

$eceClient = create-ececlusterserviceclient
$eceParamsXml = [XML]($eceClient.GetCloudParameters().getAwaiter().GetResult().CloudDefinitionAsXmlString)
$deploymentType = $eceParamsXml.SelectSingleNode("//Category[@Name='Setup']//Parameter[@Name='DeploymentType']")
$deploymentType
```
Both commands should return **CloudDeployment**. If the registry key does not exist, or if `$deploymentType` is empty or does not return **CloudDeployment**, follow the mitigation steps below.

# Cause
The `DeploymentLaunchType` registry key is set on all nodes during cluster deployment. For clusters deployed before this registry key was introduced (build 2306 and earlier), updates to build 2503 will fail. This issue also occurs if the registry key was deleted post-deployment for any reason.
# Mitigation Details

Run below commands to set the registry key and ECE parameter.

```
$path = "HKLM:\Software\Microsoft\AzureStackStampInformation"  
if (!(Test-Path $path)) {  
    New-Item -Path 'HKLM:\Software\Microsoft\AzureStackStampInformation' -Force  
}  
 New-ItemProperty -Path 'HKLM:\Software\Microsoft\AzureStackStampInformation' -Name 'DeploymentLaunchType' -PropertyType 'String' -Value "CloudDeployment" -Force

import-module ECEClient
$eceClient = create-ececlusterserviceclient
$eceParamsXml = [XML]($eceClient.GetCloudParameters().GetAwaiter().GetResult().CloudDefinitionAsXmlString)
$setup = $eceParamsXml.SelectSingleNode("//Category[@Name='Setup']")
$deploymentType = $setup.SelectSingleNode("//Parameter[@Name='DeploymentType']")
if ($deploymentType)  
{  
    $deploymentType.SetAttribute("Value", "CloudDeployment")  
    $eceCloudParametersDefinition = New-Object Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.CloudDefinitionDescription  
    $eceCloudParametersDefinition.ConfigurationName = 'AzureStack'  
    $eceCloudParametersDefinition.CloudDefinitionAsXmlString = $eceParamsXml.OuterXml  
    $null = $eceClient.ImportCloudParameters($eceCloudParametersDefinition).GetAwaiter().GetResult()  
}
``` 