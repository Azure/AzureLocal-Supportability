# Symptoms

When registering an Azure Local Instance node to Arc, you may hit a failure during installing the extension AzureEdgeLifecycleManager. If you view the details of the failure, you will see the below exception.  

```Text

Extension failed during enable. Enable command timed out. Extension Message: Device initialization is in progress.
Extension Error: Transcript started, output file is C:\MASLogs\Install-LCMController_20250220-123624Z.log
VERBOSE: Suppressed Warning Unknown category for 'NuGet'::'GetDynamicOptions': 'Provider'
VERBOSE: Loading module from path 
'C:\NugetStore\Microsoft.AzureStack.Solution.LCMControllerWinService.10.2411.2.824\content\LCMControllerWinService\DeploymentScripts\LogmanHelpers.psm1'.
```

# Issue Validation

To confirm the scenario that you are encountering is the issue documented in this article, please run this cmdlet on each node to check the result:
```PowerShell

$CrlUrls = "crl3.digicert.com", "crl4.digicert.com", "ocsp.digicert.com"
$AnyCrlBlocked = $false
$Port = 80

foreach ($url in $CrlUrls) {
    Write-Host "Check connectivity to: '$url'"
    $reponse = Test-NetConnection -ComputerName $url -Port $Port

    if ($reponse.TcpTestSucceeded -eq $false) {
        $AnyCrlBlocked = $true

        Write-Host -ForegroundColor Red "Failed to connect to $url at port: $Port"
    } else {
        Write-Host "Succeeded in connecting to $url"
    }
}

if ($AnyCrlBlocked -eq $false) {
    Write-Host -ForegroundColor Green "Succeeded in connecting to the three CRL sites. This indicates the issue you hit is NOT the one captured in this document. Please skip below steps"
}
```
If you see the message "Failed to connect to ...", follow the below mitigation details to resolve the issue. Otherwise, if you do see the message "Succeeded in connecting to the three CRL sites", please skip the below sections.
 

# Cause

Installing the extension AzureEdgeLifecycleManager requires to access the CRL sites to validate the packages. When these sites are blocked in the firewall, the installation will fail. You can check the full list of [Required firewall URLs for Azure Local deployments](https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements#:~:text=one%20firewall%20potentially.-,Required%20firewall%20URLs%20for%20Azure%20Local%20deployments,-Azure%20Local%20instances)
  

# Mitigation Details

You can follow the below steps to resolve the issue.
1. Configure your firewall according to [Required firewall URLs for Azure Local deployments](https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements#:~:text=one%20firewall%20potentially.-,Required%20firewall%20URLs%20for%20Azure%20Local%20deployments,-Azure%20Local%20instances) and make sure to allow the access to the three sites: "crl3.digicert.com", "crl4.digicert.com" and "ocsp.digicert.com". After the change, you can run the above issue validation steps to confirm the connectivity to these sites.

2. Log into the Azure Local node where installing the extension failed, and Use the below Powershell cmdlets to remove the failed extension AzureEdgeLifecycleManager and install it again.

Remember to replace the "\<ResourceGroup\>", "\<SubscriptionId\>" and "\<Region\>" with your values. And you may need to log into your Azure account before executing the below cmdlets.
```Powershell

Remove-AzConnectedMachineExtension -MachineName $env:COMPUTERNAME -Name "AzureEdgeLifecycleManager" -ResourceGroupName <ResouceGroup> -SubscriptionId <SubscriptionId>

New-AzConnectedMachineExtension -MachineName $env:COMPUTERNAME -Name "AzureEdgeLifecycleManager" -ResourceGroupName <ResouceGroup> -SubscriptionId <SubscriptionId> -Location <Region> -Publisher "Microsoft.AzureStack.Orchestration" -ExtensionType "LcmController"

```
