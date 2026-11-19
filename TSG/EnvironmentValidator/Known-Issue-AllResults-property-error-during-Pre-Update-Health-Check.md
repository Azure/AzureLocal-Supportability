# Known Issue: "AllResults" property error during Pre-Update Health Check

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Environment Validator (EnvironmentValidatorPreUpdateJIT)</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Update (Pre-Update Readiness Check)</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>2601, 2602, 2603</strong> (Fixed in 2604, not released at time of writing)</td>
  </tr>
</table>

## Overview

During update readiness checks, the Environment Validator runs JIT (Just-In-Time) validators via the `EnvironmentValidatorPreUpdateJIT` interface. A known bug in versions 2601–2603 causes the Environment Validator itself to crash with an `AllResults` property error when **any** underlying validator throws an unexpected exception.

This error **masks the real validation failure**. The error message about `AllResults` is not the root cause — it is a secondary crash caused by a code defect in how exception results are collected.

## Symptoms

Pre-update readiness checks fail with the following error in the action plan:

```
CloudEngine.Actions.InterfaceInvocationFailedException: 
Type 'EnvironmentValidatorPreUpdateJIT' of Role 'EnvironmentValidator' raised an exception:

The property 'AllResults' cannot be found on this object. 
Verify that the property exists and can be set.

   at RunValidators, C:\NugetStore\AzStackHci.EnvironmentChecker.Deploy.10.2602.0.2003\content\Classes\EnvironmentValidator\EnvironmentValidator.psm1: line 1583
   at EnvironmentValidatorPreUpdateJIT, ...\EnvironmentValidator.psm1: line 87
```

**Observable behaviors:**

- Update readiness check fails at `EnvironmentValidatorPreUpdateJIT` step
- The error message references `AllResults` property — this is **not** the real failure
- The real validator exception is hidden behind this crash
- Any validator module (not just ArcIntegration) can trigger this error

## Root Cause

The `RunValidators` function collects results from each JIT validator. When a validator throws an unexpected exception, the code attempts to append exception results to the array of execution jobs using PowerShell member enumeration:

```powershell
# Line 1583 (2602) — THE BUG
$executionJobs.AllResults += $exceptionResults
```

`$executionJobs` is an **array** of `ExecutionJob` objects. PowerShell member enumeration allows *reading* `$array.Property` but does **not** support *writing* `$array.Property += value`. This causes the `PropertyAssignmentException` which masks the real validator failure.

> [!IMPORTANT]
> This bug is triggered by **any** validator that throws an exception during PreUpdateJIT — it is not specific to any single validator such as ArcIntegration.

## Resolution

### Step 1: Find the real validator exception

The real exception is captured in the Environment Validator progress file **before** the AllResults crash occurs. On the node that ran the `EnvironmentValidatorPreUpdateJIT` step, (find with `Get-ClusterGroup '*Orchestrator*' | Select OwnerNode`) open the progress file:

```powershell
# On the node where PreUpdateJIT ran
$progressPath = "$env:SystemDrive\CloudDeployment\MASLogs\AzStackHciEnvironmentProgress.json"
if (-not (Test-Path $progressPath))
{
    # Alternative location
    $progressPath = "C:\MASLogs\AzStackHciEnvironmentProgress.json"
}

# Find the validator(s) that actually failed
$progress = Get-Content $progressPath | ConvertFrom-Json
$progress | Where-Object { $_.Status -eq 'Error' } | Format-List Name, Command, Status, ExecutionDetail
```

Example output showing the **real** failure:

```
Name            : Arc Integration
Command         : Test-AzStackHciArcIntegration
Status          : Error
ExecutionDetail : Exception occurred (Test-AzStackHciArcIntegration): The provided account MSI@50342 
                  does not have access to subscription ID "b435cdaa-..."
```

The `ExecutionDetail` field contains the actual exception message from the validator that failed.

### Step 2: Remediate the underlying validator failure

Use the `ExecutionDetail` from Step 1 to identify and resolve the real issue. Common examples:

| Validator that threw | Typical causes |
|---|---|
| `Test-AzStackHciArcIntegration` | MSI permission issues, Az.Accounts version mismatch |
| `Test-AzStackHciNetwork` | Network adapter or switch configuration issues |
| `Test-AzStackHciDNS` | DNS resolution failures |
| `Test-AzStackHciHardware` | WMI/CIM query timeouts, missing drivers |
| `Test-AzStackHciConnectivity` | Endpoint unreachable, proxy misconfiguration |

Refer to the specific validator's TSG based on the validator name shown in the `Command` field.

### Step 3: Verify the fix and re-run readiness checks

After resolving the underlying validator issue, re-run the readiness checks using one of the following methods:

**Re-run system health checks (recommended first step):**

```powershell
# Trigger a fresh system health check
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then verify the health state
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm that `HealthState` is `Success` or `InProgress` (not `Failure`).


### Step 4: Verify the validator now passes

After the readiness checks complete, confirm the previously failing validator is no longer in error:

```powershell
# Check the update readiness results
$result = Get-SolutionUpdateEnvironment
$result.HealthCheckResult | Where-Object { $_.Status -ne "SUCCESS" } | Format-List Title, Status, Severity, Description, Remediation

# Verify no Environment Validator Exception results remain
$result.HealthCheckResult | Where-Object { $_.Title -eq "Environment Validator Exception" } | Format-List *
```

If the results are clean, the update can proceed.

## Related Issues

- [Troubleshooting MSI Does Not Have Access To Subscription](Troubleshooting-MSI-Does-Not-Have-Access-To-Subscription.md) — common ArcIntegration exception that can trigger this bug
- [Known Issue: This module requires Az.Accounts version 5.3.0](Known-Issue-This-module-requires-Az-Accounts-version-5-3-0.md) — module version issues can cause validator exceptions
- [Update Troubleshooting (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting) — general update readiness check troubleshooting
