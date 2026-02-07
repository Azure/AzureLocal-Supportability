# SBE Update Fails with "Cannot validate argument on parameter 'DeployADLess'"

## Overview

If a cluster was initially deployed (or brownfield-upgraded) with versions earlier than 2408, then after updating it to 2601, subsequent SBE update may fail with the error "Cannot validate argument on parameter 'DeployADLess'". 

## Symptoms

For a cluster on 2601, SBE update fails with the message (any partner OEM may be impacted):
 
```    
 Cannot validate argument on parameter 'DeployADLess'. 
The argument "[DEPLOYADLESS]" does not belong to the set "true,false," specified by the ValidateSet attribute. 
Supply an argument that is in the set and then try the command again.  
at TestHardwarePluginUsed, C:\NugetStore\Microsoft.AzureStack.Role.SBE.10.2601.1002.2027\content\Classes\SBE\SBE.psm1: line 766,
```

## Root Cause

DeployADLess parameter entry was introduced in version 2408, but is only applicable to clusters deployed on this version or later. For earlier clusters, update process did not insert the entry to CloudParameters. 

2601 introduced some new SBE scripts that depends on the value of this parameter. In the absence of the parameter, the value becomes the placeholder literal string '[DEPLOYADLESS]'. This value is unexpected by the script and thus fails the update. 


## Resolution

The following script may be run from any host node. After running the script, resume update. 

```Powershell
$ErrorActionPreference = "Stop"
Import-Module -Name ECEClient -Verbose:$false -DisableNameChecking -ErrorAction SilentlyContinue     
    
$eceClient = Create-ECEClusterServiceClient
$eceParamsXml = [XML]($eceClient.GetCloudParameters().GetAwaiter().GetResult().CloudDefinitionAsXmlString)

# Only add if we cannot get the parameter.
if (-not ($eceParamsXml.SelectSingleNode("//Category[@Name='Domain']//Parameter[@Name='DeployADLess']")))
{
    # Add the DeployADLess parameter
    Write-Output "Adding DeployADLess parameter to CloudParameters."
    $parametersUpdateDefinition = New-Object Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.CloudParametersUpdateDescription
    $parametersUpdateDefinition.Type = "AddElement"
    $parametersUpdateDefinition.BaseElementXPath = "//Category[@Name='Domain']"
    $parametersUpdateDefinition.UpdateXml = @"
<Parameter Name="DeployADLess" Type="bool" Value="false" AllowedValues="" Reference="[{DEPLOYADLESS}]" />
"@
    $null = $eceClient.UpdateCloudParameters($parametersUpdateDefinition).GetAwaiter().GetResult()
    Write-Output "Validating add DeployADLess parameter"
    $null = $ececlient.InvalidateCloudDefinitionCache().GetAwaiter().GetResult()
    $eceParamsXml = [XML]($eceClient.GetCloudParameters().getAwaiter().GetResult().CloudDefinitionAsXmlString)
    if (-not ($eceParamsXml.SelectSingleNode("//Category[@Name='Domain']//Parameter[@Name='DeployADLess']")))
    {
        throw "Failed to add DeployADLess parameter."
    }
    Write-Output "Added DeployADLess parameter to CloudParameters."
}
else
{
    Write-Warning "DeployADLess parameter already exists."
}
```
