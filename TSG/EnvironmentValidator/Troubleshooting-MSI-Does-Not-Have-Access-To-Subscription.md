# Overview

Environment Validator runs an ArcIntegration validator prior to Deployment, Upgrade and Update. In some small cases the validator is unable to run stating ```The provided account MSI@50342 does not have access to subscription```

# Symptoms

During deployment, upgrade or pre-update validation the ArcIntegration validator throws an exception.

## PreUpdate
Inspecting the Pre-Update health check results (the example is PowerShell but these results are available in the console)
```
Get-SolutionUpdateEnvironment | Select-Object -ExpandProperty HealthCheckResult | Where-Object Status -ne 'Success'
```

Reveals the following failure:

```
Name               : Environment Validator Exception
DisplayName        : Environment Validator Exception - Test-AzStackHciArcIntegration
Tags               : {}
Title              : Environment Validator Exception
Status             : ERROR
Severity           : CRITICAL
Description        : Exception caught in Test-AzStackHciArcIntegration validator.
Remediation        : Raise a case with Microsoft support
TargetResourceID   : Test-AzStackHciArcIntegration
TargetResourceName : Test-AzStackHciArcIntegration
TargetResourceType : Environment Validator
Timestamp          : 5/27/2025 2:59:37 PM
AdditionalData     : {}
HealthCheckSource  : Manual\Standard\Medium\ValidatedRecipe\414d1985
```

This is a catch all result if validators experience an exception.

## Deployment / Upgrade

Deployment and Upgrade showing an exception similar to the following:

Note: ValidateArcIntegration in deployment or ValidateUpgradeArcIntegration in upgrade

```
Type 'ValidateArcIntegration' of Role 'EnvironmentValidator' raised an exception:

{
    "ExceptionType":  "text",
    "ErrorMessage":  "The provided account MSI@50342 does not have access to subscription ID \"b435cdaa-9520-4fea-a096-137af3e71223\". Please try logging in with different credentials or a different subscription ID. If a subscription is not specified, please check the configs by `Get-AzConfig`.",
    "ExceptionStackTrace":  "at Invoke-AzStackHciArcIntegrationValidation, C:\\Program Files\\WindowsPowerShell\\Modules\\AzStackHci.EnvironmentChecker\\AzStackHciArcIntegration\\AzStackHci.ArcIntegration.psm1: line 166\r\nat Test-AzStackHciArcIntegration, C:\\Program Files\\WindowsPowerShell\\Modules\\AzStackHci.EnvironmentChecker\\AzStackHciArcIntegration\\AzStackHciArcIntegration.psm1: line 164\r\nat \u003cScriptBlock\u003e, \u003cNo file\u003e: line 1\r\nat RunSingleValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2509.0.2010\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 1168\r\nat ValidateArcIntegration, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2509.0.2010\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 721\r\nat \u003cScriptBlock\u003e, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 165\r\nat Invoke-EceInterfaceInternal, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 160\r\nat \u003cScriptBlock\u003e, \u003cNo file\u003e: line 50"
}
```

# Mitigation
There are two possible issues that can cause this:

1) Az.Accounts PS Module is correct
2) Role Assignment for Azure Stack HCI Device Management Role is not correct.

## If any other version of Az.Accounts apart from 4.0.2 is installed on the nodes follow the below steps:
***
1. Uninstall all the versions of az.accounts on all nodes
```
Uninstall-Module az.accounts  -allversions
```
3. Retry update from portal

## If the only version of Az.Accounts is 4.0.2 on the system, check access control
***
1. Login to azure portal and Go to Resource group in which Azure Local resource is present.
2. Select 'Access Control (IAM)'
3. Select 'Add Role Assignment'
4. Select 'Azure Stack HCI Device Management Role'
5. Select  'Managed Identity'
6. Select 'Select Members'
7. Select 'Machine - Azure Arc (<Name of the node>)' under Managed Identity
8. Enter machine name "\<Name of the nodes that belong to the cluster>"
9. Select the machine "\<Name of the nodes that belong to the cluster>"
10. Assignment Type = "Permanent"
11. Select "review and assign"
12. Repeat step 5 to 11 to assign "Azure Stack HCI Connected InfraVMs" on the nodes of the cluster.
