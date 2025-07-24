# Azure Local - Troubleshoot Outbound Network Connectivity

## Overview

Azure Local requires outbound / egress network connectivity from the management network of your Azure Local instances to a list of public endpoints. Network connectivity to these endpoints is required for Azure Local to use Azure as a reliable management and control plane, such as for initial deployment, updates and workload provisioning operational capabilities. Allowing connectivity to the list of endpoints is a prerequisite for deployment, but ongoing connectivity to the list of endpoints is vital for support, manageability and licensing compliance.

For additional information on Azure Local Firewall requirements, please review - [Azure Local Firewall documentation](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements).

## Symptoms

Integrating Azure Local into your existing Firewall and/or Proxy Server infrastructure can be challenging depending on your organization's network security policies, such as requirements to define a strict access control list of the URL endpoints that are allowed to communicate from your Azure Local instance(s) "management network" to the required public endpoints.

There are several symptoms or issues that will occur if the required endpoints are not accessible from the Azure Local instance(s), below are just a few examples:

1. Azure Local instance cloud deployment and/or update operations fail with network failure or timeout.
1. Physical machines show their "Azure Arc" status as "Disconnected" in Azure portal experience (_Arc agent not connected_).
1. Deployment of new Azure Local VMs fails with RPC failure in Azure portal as the ARM deployment status.
1. Updates fail at "update ARB and extensions" step with "SSL: CERTIFICATE_VERIFY_FAILED" shown in Azure portal update blade.
1. There are many other network related issues that could occur when the required endpoints are not accessible from the management (_physical machines and ARB_) network address space.

## Issue Validation

Azure Local includes built-in automation modules that are executed as part of Solution Update Readiness and Environment Checker modules, both of these modules include connectivity tests that validate network connectivity status to critical endpoints. The output of these can be viewed locally using PowerShell, or using Azure portal during updates.

> Note: For examples of how to use and view the output of Azure Local "Solution Update Environment" and "Environment Checker" built-in modules, see the [Appendix section](#appendix) at the bottom of this article.

If you are finding it difficult to isolate the cause of the network related issue(s) or failure(s), and are experiencing issues as described in 'Symptoms' section, you can follow the steps in the 'Mitigation Details' below to gain further insights and diagnostic data to validate the required endpoints are accessible from your on-premises network.

## Mitigation Details

To help with troubleshooting or root causing network connectivity issues, you can use the **Test-AzureLocalConnectivity** function which is included in the **AzStackHCI.DiagnosticSettings** module. This function can help automate testing that connectivity is working correctly from Azure Local physical machines to the required public endpoints. The function supports Arc Gateway scenarios and has an [-AzureRegion] parameter to allow testing against a specific Azure region that matches your Azure Local instance deployment.

The 'Test-AzureLocalConnectivity' function has a dependency on the Azure Local Environment Checker module being installed, which is installed by default on all Azure Local physical machines. If Environment Checker module (_AzStackHci.EnvironmentChecker_) is not installed on the device running the connectivity test, you will be prompted to install the module first. The device used to install the AzStackHCI.DiagnosticSettings module and test connectivity must have access to the PowerShell Gallery, in order to download the module (_nuget package_) to install it.

To install the AzStackHCI.DiagnosticSettings module to perform connectivity tests for a support or troubleshooting scenario, use the commands below:

**To install the AzStackHCI.DiagnosticSettings** module to enable you to perform connectivity tests for a support or troubleshooting scenario, you can use the commands below:

```Powershell
# Install the AzStackHCI.DiagnosticSettings module, this can be on an Azure Local physical machine (recommended), or any device inside your network (if it is using the same firewall / proxy configuration as your Azure Local instance).
Install-Module -Name "AzStackHci.DiagnosticSettings" -Repository PSGallery

# Test Azure Local Connectivity for a specific target Azure region.
# /// ACTION: Update <AzureRegionName> and <YourKeyVaultName> to match the values of your Azure Region and Key Vault.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net"

# Optional parameters for more detailed output, add: "-Verbose" and "-Debug" to the function above, which will output full diagnostic level responses from the remote endpoint web server. 
# The output from the function is automatically saved in the PowerShell transcript.

```

For the most recent / up to date list of supported Azure regions review the ["Azure requirements" - System requirements for Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/system-requirements-23h2?view=azloc-24113#azure-requirements) article. At the time of publishing this article, the list of valid Azure Region names for Azure Local include:

* "EastUS", "WestEurope", "AustraliaEast", "CanadaCentral", "CentralIndia", "JapanEast", "SouthCentral", "SouthEastAsia"

If you would like to test an individual public endpoint using PowerShell for troubleshooting or support purposes, you can use the "**Test-Layer7Connectivity**" function with the "-Debug" switch. Example syntax is shown below:

```Powershell

# Install the "AzStackHci.DiagnosticSettings" module

Install-Module -Name "AzStackHci.DiagnosticSettings" -Repository PSGallery

# To test an individual endpoint (after installing the module), with Verbose and Debug output, use the "Test-Layer7Connectivity" function, as shown below:
$url = 'https://graph.microsoft.com/v1.0/'
Test-Layer7Connectivity -url $url -port 443 -Verbose -Debug

```

## Share test results with Microsoft (Optional)

The 'Test-AzureLocalConnectivity' function includes an option to upload the test results to Microsoft, this is controlled by a User Prompt that asks if you would like to **Upload the Transcript file and CSV file to Microsoft**. If you **answer "Y"** to the prompt, the function will automatically upload the output files to Microsoft, the transfer uses the built-in log transfer method that secure protocols, more information on the upload process is available [here](https://learn.microsoft.com/azure/azure-local/manage/collect-logs?view=azloc-24113&tabs=powershell#about-on-demand-log-collection).

If you are working with Microsoft customer service and support (CSS), and have a support request (SR) case open, you could share some of the "Share Test Results" log upload text output that shows your cluster's "AEORegion", "ARODeviceARMResourceUri" and "CorrelationId" with the SR case owner.

## Demo and example output

Example output is shown in the animated GIF image below, which shows an interactive console demo.

The primary source of information is **copying / exporting the CSV output file** and Transcript file that are saved on the node (_or device running the 'Test-AzureLocalConnectivity' function_) to your laptop or desktop PC to open the CSV output in Excel, or another CSV file viewer.

Click here to [**view an example CSV file output**](./Example_AzureLocal_ConnectivityTest_EastUS_computer-name_2025-04-01-11-15-59.csv)

![Test-AzureLocalConnectivity Demo](./images/Test-AzureLocalConnectivity_Demo.gif)

### **Test-AzureLocalConnectivity function parameters for syntax**

````PowerShell
    [CmdletBinding()]

    param (

        [ValidateSet("EastUS", "WestEurope", "AustraliaEast", "CanadaCentral", "CentralIndia", "JapanEast", "SouthCentral", "SouthEastAsia")]

        [string]$AzureRegion,

        [System.Uri]$KeyVaultURL,

  

        [Parameter(Mandatory=$false, Position=2, HelpMessage="Optional switch to ONLY test URLs that do NOT support Arc Gateway, default is to test all URLs")]

        [switch]$ArcGatewayDeployment,

  

        [Parameter(Mandatory=$false, Position=3, HelpMessage="Optional parameter to specify a custom Arc Gateway URL to test connectivity, including the https:// prefix, for example: 'e.g. 'https://1be59945-12c0-4cda-9580-84a66a1120a0.gw.arc.azure.com'")]

        [System.Uri]$ArcGatewayURL,

  

        [Parameter(Mandatory=$false, Position=4, HelpMessage="Optional parameter to specify a custom DNS Name for the NTP Time Server, this should NOT include a http:// or https:// prefix, e.g. 'yourtimeserver.fqdn'")]

        [ValidateLength(1, 255)]

        [string]$NTPTimeServer,

  

        [Parameter(Mandatory=$false, Position=5, HelpMessage="Optional switch to include tests for TCP Connectivity, for scenarios such as not using a Proxy.")]

        [switch]$IncludeTCPConnectivityTests,

  

        [Parameter(Mandatory=$false, Position=6, HelpMessage="Optional switch to exclude testing Redirected URLs.")]

        [switch]$ExcludeRedirectedUrls,

  

        [Parameter(Mandatory=$false, Position=7, HelpMessage="Optional switch to exclude testing manually defined subdomains for Wildcard endpoints.")]

        [switch]$ExcludeWildcardTests,

  
        [Parameter(Mandatory=$false, Position=8, HelpMessage="Optional switch to exclude uploading the test results to Microsoft.")]

        [switch]$ExcludeUploadResults,

  
      [Parameter(Mandatory=$false, Position=9, HelpMessage="Optional parameter to return '`$Results' array object in PowerShell, for further processing.")]

         [switch]$PassThru
    )

````

## Appendix

### Environment Checker Connectivity Tests

To view the output from Azure Local **Environment Checker** Connectivity Validation tests, use the PowerShell command below:

````PowerShell
Invoke-AzStackHciConnectivityValidation -PassThru | Where-Object -Property Status -eq FAILURE | Sort-Object TargetResourceName | Format-Table TargetResourceName -Autosize
````

For additional information for how to use Azure Local Environment Checker module, review the [Troubleshooting External Connectivity Failures in Environment Checker](/TSG/EnvironmentValidator/Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md) article.

And the Microsoft Learn article is here: [Readiness of your environment for Azure Local - "Run readiness checks" section](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker?view=azloc-24113&tabs=connectivity#run-readiness-checks).

### Solution Update Environment Tests

To view the output from **all tests** included Azure Local **Solution Update Readiness**, which includes connectivity validation and tests for critical public endpoints, use the PowerShell command below:

````PowerShell
# Check Solution Update Environment
$Result = Get-SolutionUpdateEnvironment

# View "not equal to SUCCESS" alerts
$Result.HealthCheckResult | Where-Object {$_.Status -ne "SUCCESS"} | Format-List Title, Status, Severity, Description, Remediation

# Create "C:\Temp" folder, if it does not exist
if(-not(Test-Path "C:\Temp\")) { New-Item -Path "C:\Temp\" -Type Directory | Out-Null }

# Output to Text format
$Result.HealthCheckResult | Out-File "C:\Temp\HealthResult-$((Get-Cluster).Name).txt"

# Output to JSON format
$Result.HealthCheckResult | ConvertTo-Json -Depth 10 | Out-File "C:\Temp\HealthResult-$((Get-Cluster).Name).json"

````

For additional information for how to analyze and understand the **$Results.HealthCheckResult** array, refer to this article: [Solution Update Readiness Checker - "using PowerShell" section](https://learn.microsoft.com//azure/azure-local/update/update-troubleshooting-23h2?view=azloc-24113#using-powershell).

## How to get additional support

If you need assistance with connectivity, please open a Support Request (SR) case with Microsoft CSS support using Azure portal.
