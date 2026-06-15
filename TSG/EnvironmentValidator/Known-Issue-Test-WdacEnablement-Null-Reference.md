# Known Issue: Test-WdacEnablement Fails with Null-Reference Error During Upgrade Validation

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Environment Validator (EnvironmentValidatorUpgrade)</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Upgrade (23H2 to 24H2 brownfield upgrade readiness validation)</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>10.2509.0.2010 and later</strong> (Fixed in 2607)</td>
  </tr>
</table>

## Overview

During upgrade readiness validation for Azure Stack HCI 23H2 to 24H2, the `Test-WdacEnablement` check may crash with a "You cannot call a method on a null-valued expression" error. This happens on brownfield clusters where a platform component has placed a supplemental WDAC policy file in the Code Integrity folder, but the standard inbox base policy is not present.

The error **does not indicate an actual WDAC enforcement problem**. The supplemental policy file is safe and expected - the validator simply does not handle this configuration correctly.

## Symptoms

The upgrade readiness validation fails with an error similar to:

```
[ERROR] [Invoke-AzStackHciUpgradeValidation] You cannot call a method on a null-valued expression.
[ERROR] [Invoke-AzStackHciUpgradeValidation] at <ScriptBlock>, AzStackHciUpgrade\AzStackHci.Upgrade.Helpers.psm1: line 1060
```

**Observable behaviors:**

- `Invoke-AzStackHciUpgradeValidation` fails at the WDAC enablement check
- The error references a "null-valued expression" - this is a code defect, not a real WDAC problem
- The cluster is healthy, operational, and does not have customer-configured WDAC enforcement
- The `root\Microsoft\Windows\CI` WMI namespace exists and is accessible

## Resolution

### Step 1: Confirm this is the issue

On each cluster node, check for GUID-named `.cip` files in the Code Integrity active policies folder:

```powershell
Get-ChildItem "$env:SystemRoot\System32\CodeIntegrity\CiPolicies\Active" -Filter *.cip |
    Where-Object { $_.Name -imatch "^\{[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\}\.cip$" } |
    Select-Object Name, Length, LastWriteTime
```

If this returns one or more `.cip` files but the system does not have customer-configured WDAC policies, you are hitting this known issue. The files are supplemental policies placed by a platform telemetry component and are safe to temporarily rename.

### Step 2: Temporarily rename the supplemental policy files

On **each cluster node** (not just the seed node), rename the supplemental `.cip` files so the validator no longer detects them:

```powershell
$cipPath = "$env:SystemRoot\System32\CodeIntegrity\CiPolicies\Active"
$cipFiles = Get-ChildItem -Path $cipPath -Filter *.cip |
    Where-Object { $_.Name -imatch "^\{[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\}\.cip$" }

foreach ($file in $cipFiles) {
    $backupName = $file.FullName + ".backup"
    Rename-Item -Path $file.FullName -NewName $backupName
    Write-Host "Renamed: $($file.Name) -> $($file.Name).backup"
}
```

> [!IMPORTANT]
> Do **not** delete the `.cip` files. Renaming them with a `.backup` extension is sufficient and reversible. These files are managed by a platform component and may be recreated during future operations.

### Step 3: Re-run upgrade readiness validation

After renaming the files on all nodes, re-run the upgrade validation:

```powershell
Invoke-AzStackHciUpgradeValidation
```

The `Test-WdacEnablement` check should now pass. If other validators fail, address those separately - this workaround only resolves the WDAC supplemental policy crash.

### Step 4: Verify and continue

After successful validation, you can proceed with the upgrade. The renamed `.backup` files do not need to be restored - the platform component will recreate them if needed during subsequent lifecycle operations.

To verify the current WDAC policy state after workaround:

```powershell
# Confirm no active GUID-named CIP files remain
Get-ChildItem "$env:SystemRoot\System32\CodeIntegrity\CiPolicies\Active" -Filter *.cip |
    Where-Object { $_.Name -imatch "^\{[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\}\.cip$" }
```

This should return no results, confirming the workaround is in place.

## Applicable Versions

- **Affected**: EnvironmentChecker 10.2509.0.2010 through 2606
- **Fixed in**: 2607 - the fix adds a null-check so supplemental-only policy configurations no longer crash the validator

## Related

- [Validate solution upgrade readiness for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/upgrade/validate-solution-upgrade-readiness)
- [Remove Windows Defender Application Control policies](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/deployment/disable-wdac-policies)
- [Troubleshooting updates for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2)
