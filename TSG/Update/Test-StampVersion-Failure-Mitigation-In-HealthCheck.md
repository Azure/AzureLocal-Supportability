# Overview

Environment Validator runs a Validated Recipe validator prior to Update. The test detects issues with inconsistencies between stamp version and services version.

# Symptoms

During pre-update validation, the Validated Recipe tests fail on Test PowerShell Module version.

Inspecting the Pre-Update health check results (the example is PowerShell but these results are available in the console)
```
```

Reveals the following failure:

```
"Name":  "AzStackHci_ValidatedRecipe_StampVersion"
"DisplayName":  "Test Azure Local Stamp Version"
"Tags":  {}
"Title":  "Test Azure Local Stamp Version"
"Status":  1,
"Severity":  2
"Description":  "Validating that the stamp version and services version is correct."
"Remediation":  "Please follow this TSG to correct the stamp version: https://aka.ms/azhci-tsg-stampversion"
"TargetResourceID":  "NODE01"
"TargetResourceName":  "NODE01"
"TargetResourceType":  "ValidatedRecipe",
"Timestamp":  "09/29/2025 22:58:07",
"AdditionalData":  {
                       "Detail":  "Checking version of Azure Stack HCI stamp on host [V-HOST1]. Got stamp version [12.2509.1001.22] and services version [10.2508.0.21]. There is a mismatch.The stamp version has a mismatch with services version. Please follow this TSG to correct the stamp version: https://aka.ms/azhci-tsg-stampversion",
                       "Status":  "FAILURE",
                       "TimeStamp":  "09/29/2025 22:58:07",
                       "Resource":  "Validated Assembly Recipe",
                       "Source":  "V-HOST1"
                   },
"HealthCheckSource":  "Manual\\Standard\\Medium\\ValidatedRecipe\\f33fc5c1"```
```

# Issue Validation

The validation can be run manually to verify and give us more information. Note: you can pass PsSession array to this cmdlet, the example just focusses on running locally.

```
$result = Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-StampVersion
```

The output can be viewed to confirm a failure state:

```
PS C:\> $result

HealthCheckSource  : Manual\Standard\Medium\ValidatedRecipe\9ba4f181
Name               : AzStackHci_ValidatedRecipe_StampVersion
DisplayName        : Test Azure Local Stamp Version
Tags               : {}
Title              : Test Azure Local Stamp Version
Status             : FAILURE
Severity           : CRITICAL
Description        : Validating that the stamp version and services version is correct.
Remediation        : Please follow this TSG to correct the stamp version: https://aka.ms/azhci-tsg-stampversion
TargetResourceID   : NODE01
TargetResourceName : NODE01
TargetResourceType : ValidatedRecipe
Timestamp          : 9/29/2025 11:19:24 PM
AdditionalData     : {[Detail, Checking version of Azure Stack HCI stamp on host [V-HOST1]. Got stamp version
                     [12.2509.1001.22] and services version [10.2508.0.21]. There is a mismatch.The stamp version has a
                     mismatch with services version. Please follow this TSG to correct the stamp version:
                     https://aka.ms/azhci-tsg-stampversion], [Status, FAILURE], [TimeStamp, 09/29/2025 23:19:24],
                     [Resource, Validated Assembly Recipe]...}
```

# Cause

There is an issue with timing in 2509 release that can cause 2509 stamp version to be incorrectly set on a 2508 services version that is running 2508 components.

# Mitigation Details

We will need to run this command

```
Import-Module ECEClient
$eceClient = Create-ECEClusterServiceClient
# Depending on the OS Version the version is different
$osMajorVersion = $([environment]::OSVersion.Version.Major.ToString())
$osMinorVersion = $([environment]::OSVersion.Version.Minor.ToString())
$osBuildVersion = $([environment]::OSVersion.Version.Build.ToString())
$is23H2 = (($osMajorVersion -eq "10") -and ($osMinorVersion -eq "0") -and ($osBuildVersion -eq "25398"))
if ($is23H2) {
  $stampVersion = "11.2508.1001.51"
} else {
  $stampVersion = "12.2508.1001.52"
}
$eceClient.SetStampVersion($stampVersion).GetAwaiter().GetResult()
$eceClient.InvalidateCloudDefinitionCache().GetAwaiter().GetResult()
```
