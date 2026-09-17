---
ArticleType: "KI"
Article_ID: "20260917143654"
Title: "Known issue: `AllResults` property error during Pre-Update Health Check"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
EngineeringStatus: "Fixed"
FixedInBuild:
  OS: []
  SolutionMinorBuild: ["2604"]
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated"]
  OEM: ["All"]
  OS: ["24H2"]
  SolutionMinorBuild: ["2601", "2602", "2603"]
Component: "Environment Validator"
Engineering_ID:
  Source: "ADO PR"
  ID: 14146509
Tags: ["Solution Update", "Lifecycle Manager", "Validation", "Diagnostics", "Log Collection"]
---
[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|------|---------|---------|
| 2026-09-17 | 1.0 | Added source-validated 2604 disposition, safe diagnostics, and mandatory PickleFactory metadata and layout. |

:::

# Known issue: `AllResults` property error during Pre-Update Health Check

# Symptoms

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width:180px;">ArticleType</th>
    <td><code>KI</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><code>['Engineering', 'CSS', 'OEM Partners', 'External']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.Product</th>
    <td><code>Azure Local</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.OEM</th>
    <td><code>['All']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Environment Validator, <code>EnvironmentValidatorPreUpdateJIT</code>, and <code>RunValidators</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical when reproduced</strong>: the pre-update health check is blocked and the secondary exception can hide the validator that needs remediation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected versions</th>
    <td>Environment Checker deploy packages in the 2601, 2602, and 2603 release lines that contain the legacy array-level <code>AllResults</code> assignment.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Fixed versions</th>
    <td>The source correction is in the 2604 release line and later. Confirm the installed <code>AzStackHci.EnvironmentChecker.Deploy</code> package before applying this known-issue disposition.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Running virtual machines and cluster storage can continue serving workloads. The failed readiness check blocks update progression until the underlying validator problem is resolved and the health check completes successfully.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 15-30 minutes to identify the package and hidden validator exception, plus the time required by the validator-specific remediation and a new system health check.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The Azure Local update or Environment Validator owner performs initial triage. Route the case to networking, identity, hardware, or another owner only when the recovered validator detail identifies that domain.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td><strong>[LOW RISK]</strong> collect the package, progress, health-result, event, and log evidence. <strong>[LOW RISK]</strong> rerun the system health check after the underlying issue is fixed. <strong>[HIGH RISK]</strong> do not bypass readiness, alter Environment Checker code, or replace files in <code>C:\NugetStore</code>.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validation boundary</th>
    <td>This article was validated offline against current product source and the fixing history. No lab failure, mitigation, or live-cluster recovery is claimed.</td>
  </tr>
</table>

**Decision summary**

The `AllResults` message is a secondary failure. It is not the validator problem
that must be fixed.

1. **[LOW RISK]** Run the collection block below from an elevated Windows
   PowerShell session. It records the active Environment Checker deploy package,
   the current progress-file path and timestamp, and every validator row in
   `Error` or `Failed`.
2. Check the package release line:
   - **2601-2603:** this known issue applies when the stack contains the exact
     `AllResults` property-assignment message. Use `ExecutionDetail` to find and
     remediate the underlying validator.
   - **2604 or later:** the array-assignment defect is fixed. Do not classify a
     current failure as this legacy known issue. Investigate the emitted
     validator result or exception directly.
   - **Unknown or unparseable package:** stop and collect evidence for Microsoft
     Support. Do not infer the release from the solution name alone.
3. **[LOW RISK]** Complete the validator-specific remediation. Do not rerun the
   precheck merely to reproduce the same unresolved failure.
4. **[LOW RISK]** Rerun `Invoke-SolutionUpdatePrecheck -SystemHealth`, wait for a
   terminal state, and require `HealthState` to be `Success` or `Warning`.
   `InProgress` is not a final success state.
5. **[HIGH RISK]** Do not start the solution update while `HealthState` is
   `Failure` or while a critical health result remains.

**Failure signature**

The update readiness action plan fails at
`EnvironmentValidatorPreUpdateJIT` with an error similar to:

```text
CloudEngine.Actions.InterfaceInvocationFailedException:
Type 'EnvironmentValidatorPreUpdateJIT' of Role 'EnvironmentValidator' raised an exception:

The property 'AllResults' cannot be found on this object.
Verify that the property exists and can be set.

at RunValidators, C:\NugetStore\AzStackHci.EnvironmentChecker.Deploy.10.2602.0.2003\content\Classes\EnvironmentValidator\EnvironmentValidator.psm1: line 1583
```

The defining signature is the property-assignment exception from
`RunValidators` in a 2601-2603 Environment Checker deploy package. A generic
validator exception without that signature is a different failure.

**How the legacy failure behaves**

The affected code built an array of execution-job objects and then attempted to
append exception results through array member enumeration:

```text
$executionJobs.AllResults += $exceptionResults
```

PowerShell can enumerate `$executionJobs.AllResults` for reading, but an
assignment through that array-level expression does not update one concrete job
object. The assignment throws and masks the validator exception that was already
recorded in the progress data.

The 2604 source correction attaches the generated exception result to the
specific failed job:

```text
$exception.AllResults += $exceptionResultObject
```

Current `RunValidators` code keeps each job's results on that job, flattens
`$executionJobs.AllResults`, removes null entries, writes the combined result
file, parses the results, and then rethrows the first blocking validator
exception. The underlying validator failure remains visible instead of being
replaced by the legacy array-assignment error.

**Terms**

- **Pre-update health check** is the system health evaluation that must complete
  before a solution update proceeds.
- **JIT validator** is a validator selected at run time for the current lifecycle
  operation.
- **Orchestrator owner node** is the cluster node that owns the orchestrator
  group and writes the current Environment Validator progress file.
- **Progress file** is
  `AzStackHciEnvironmentProgress.json`. Current source writes one row per
  validator with `Name`, `Description`, `Status`, `Command`, `ModuleName`,
  `StartTime`, `EndTime`, `DurationSeconds`, `FailedResult`, and
  `ExecutionDetail`.
- **ExecutionDetail** is the progress-row field that carries an unexpected
  validator exception. It is distinct from `AdditionalData.Detail`, which is
  used by persisted health-check result objects.
- **Terminal health state** is `Success`, `Warning`, or `Failure`.
  `InProgress` means the new health check has not finished.

**Where this failure appears**

| Admin surface | What to expect |
|---|---|
| PowerShell on an Azure Local node | **Shown**: the collection block reports the package release, owner node, progress file, failed command, module, status, and `ExecutionDetail`. |
| Azure portal | **Shown**: the Azure Local cluster Updates experience reports the failed pre-update health check or action-plan exception. The portal can show the secondary `AllResults` text rather than the hidden validator exception. |
| Windows event logs | **Shown when persisted**: Environment Checker Event ID 17205 can contain an `Environment Validator Exception` result. Use it for timestamp correlation. An absent event is a data gap, not proof that the failure did not occur. |
| Cluster logs from `Get-ClusterLog` | The `RunValidators` PowerShell exception is **not evident in cluster logs** as a quorum, storage, membership, or clustered-resource event. |
| Windows Failover Cluster Manager | The exception is **not evident in Failover Cluster Manager** as a failed node, role, or resource. |
| Windows Admin Center on a standalone host | The exact `RunValidators` exception and progress row are **not evident in Windows Admin Center on a standalone host**. Use node PowerShell and the component logs. |
| Windows Admin Center in the Azure portal | The hidden validator detail is **not evident in Windows Admin Center in the Azure portal**. Use the Azure Local Updates experience for lifecycle correlation and node PowerShell for the progress data. |
| Component or tool log files on disk | **Shown**: preserve the current `AzStackHciEnvironmentProgress.json`, `AzStackHciEnvironmentChecker.log`, Environment Checker report JSON or XML, and the related `C:\CloudDeployment\Logs` action-plan logs. |

# Issue Validation

## Errors or Failures

Use the package release, exact action-plan signature, progress-file freshness,
and every problem row to determine whether the legacy known issue applies.
Multiple problem rows are independent underlying validator failures and must all
be retained.

## PowerShell Detection Script

Run this **[LOW RISK]** read-only collection from an elevated Windows
PowerShell session on a cluster node. It queries every distinct orchestrator
owner node and writes one local JSON evidence file. It does not start an update
or rerun validation.

```powershell
$ErrorActionPreference = 'Stop'
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$evidencePath = Join-Path (Get-Location) "AllResults-triage-$timestamp.json"

$orchestratorGroups = @(
    Get-ClusterGroup |
        Where-Object { $_.Name -like '*Orchestrator*' }
)
if ($orchestratorGroups.Count -eq 0) {
    throw 'No orchestrator cluster group was found.'
}

$ownerNodes = @(
    $orchestratorGroups |
        ForEach-Object { $_.OwnerNode.Name } |
        Sort-Object -Unique
)

$evidence = foreach ($ownerNode in $ownerNodes) {
    Invoke-Command -ComputerName $ownerNode -ScriptBlock {
        $candidatePaths = @()
        if (-not [string]::IsNullOrWhiteSpace($env:LocalRootFolderPath)) {
            $candidatePaths += Join-Path $env:LocalRootFolderPath `
                'MASLogs\AzStackHciEnvironmentProgress.json'
        }
        $candidatePaths += @(
            "$env:SystemDrive\CloudDeployment\MASLogs\AzStackHciEnvironmentProgress.json"
            "$env:SystemDrive\MASLogs\AzStackHciEnvironmentProgress.json"
        )

        $progressFiles = @(
            $candidatePaths |
                Select-Object -Unique |
                Where-Object { Test-Path -LiteralPath $_ } |
                ForEach-Object { Get-Item -LiteralPath $_ } |
                Sort-Object LastWriteTimeUtc -Descending
        )
        if ($progressFiles.Count -eq 0) {
            throw "No Environment Validator progress file was found on $env:COMPUTERNAME."
        }

        $progressFile = $progressFiles[0]
        $progress = @(
            Get-Content -LiteralPath $progressFile.FullName -Raw |
                ConvertFrom-Json
        )
        $problemRows = @(
            $progress |
                Where-Object {
                    $_.Status -in @('Error', 'Failed') -or
                    $_.ExecutionDetail -match 'Exception occurred'
                } |
                Select-Object Name, Description, Status, Command, ModuleName,
                    StartTime, EndTime, DurationSeconds, ExecutionDetail
        )

        $deployPackages = @(
            Get-ChildItem -LiteralPath "$env:SystemDrive\NugetStore" `
                -Directory `
                -Filter 'AzStackHci.EnvironmentChecker.Deploy.*' `
                -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTimeUtc -Descending
        )
        $deployPackage = $deployPackages | Select-Object -First 1
        $releaseLine = $null
        if ($deployPackage -and
            $deployPackage.Name -match '\.(?<Release>26\d{2})\.') {
            $releaseLine = [int]$Matches.Release
        }

        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            ObservedAtUtc = [DateTime]::UtcNow.ToString('o')
            DeployPackage = if ($deployPackage) {
                $deployPackage.Name
            }
            else {
                $null
            }
            ReleaseLine = $releaseLine
            ProgressPath = $progressFile.FullName
            ProgressLastWriteUtc = $progressFile.LastWriteTimeUtc.ToString('o')
            ProgressRowCount = $progress.Count
            ProblemRows = $problemRows
        }
    }
}

$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath
$evidence |
    Select-Object Node, DeployPackage, ReleaseLine, ProgressPath,
        ProgressLastWriteUtc, ProgressRowCount |
    Format-List
$evidence.ProblemRows | Format-List
Write-Host "Evidence file: $evidencePath"
```

**Stop gates**

- **No `ProblemRows`:** stop. Confirm that `ProgressLastWriteUtc` matches the
  failed precheck. A stale or incomplete progress file is not evidence of a
  clean run.
- **More than one problem row:** retain every row. Remediate each underlying
  validator before rerunning the health check.
- **`ReleaseLine` is 2601, 2602, or 2603 and the action-plan stack has the exact
  `AllResults` signature:** continue with this article.
- **`ReleaseLine` is 2604 or later:** stop using the legacy-known-issue
  disposition. The current code preserves the validator result. Investigate the
  reported command and detail directly.
- **`ReleaseLine` is empty:** preserve the evidence and escalate. Do not edit a
  package directory to force a version match.

**Route the underlying validator**

The `Command`, `ModuleName`, and `ExecutionDetail` values determine ownership.
The examples below are routing aids, not permission to change unrelated state.

| Recovered validator or detail | Next owner and action |
|---|---|
| Arc Integration, MSI, subscription access, or Azure authentication | Azure Local identity or Arc owner. Use [Troubleshooting MSI Does Not Have Access To Subscription](Troubleshooting-MSI-Does-Not-Have-Access-To-Subscription.md). |
| Az.Accounts or PowerShell-module import/version text | Environment Validator or update owner. Use [Known issue: This module requires Az.Accounts version 5.3.0](Known-Issue-This-module-requires-Az-Accounts-version-5-3-0.md). |
| DNS resolution, proxy, TLS, or endpoint reachability | Network owner. Use the DNS or connectivity TSG that matches the recovered command and detail. |
| Network adapter, intent, or switch configuration | Network owner. Preserve the adapter and validator evidence before changing host or switch configuration. |
| Hardware, driver, WMI, or CIM failure | Azure Local platform owner first. Involve the OEM only when the detail identifies a hardware, firmware, driver, WMI, or CIM condition. |
| Unknown command, empty detail, or no matching TSG | Microsoft Support and the Environment Validator product group. Do not guess a remediation from the `AllResults` text. |

**Collect support evidence**

Run this **[LOW RISK]** block on each owner node after the first collection. It
writes a compact JSON summary in the current directory and identifies the
component-log paths to preserve. It does not change the cluster.

```powershell
$ErrorActionPreference = 'Stop'
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$summaryPath = Join-Path (Get-Location) "AllResults-support-$timestamp.json"

$updateEnvironment = Get-SolutionUpdateEnvironment
$eventLog = Get-WinEvent -ListLog '*AzStackHciEnvironmentChecker*' `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1
$events = @()
if ($eventLog) {
    $events = @(
        Get-WinEvent -FilterHashtable @{
            LogName = $eventLog.LogName
            Id = 17205
            StartTime = (Get-Date).AddDays(-2)
        } -ErrorAction SilentlyContinue |
            Select-Object -First 20 TimeCreated, Id, LevelDisplayName, Message
    )
}

$componentPaths = @()
if (-not [string]::IsNullOrWhiteSpace($env:LocalRootFolderPath)) {
    $componentPaths += Join-Path $env:LocalRootFolderPath 'MASLogs'
}
$componentPaths += @(
    "$env:SystemDrive\CloudDeployment\MASLogs"
    "$env:SystemDrive\CloudDeployment\Logs"
    "$env:SystemDrive\MASLogs"
)

$summary = [pscustomobject]@{
    Node = $env:COMPUTERNAME
    ObservedAtUtc = [DateTime]::UtcNow.ToString('o')
    HealthState = $updateEnvironment.HealthState
    HealthCheckDate = $updateEnvironment.HealthCheckDate
    NonSuccessHealthResults = @(
        $updateEnvironment.HealthCheckResult |
            Where-Object { $_.Status -notin @('Success', 'SUCCESS') } |
            Select-Object Title, Status, Severity, Description, Remediation,
                @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
    )
    EnvironmentValidatorExceptions = @(
        $updateEnvironment.HealthCheckResult |
            Where-Object { $_.Title -eq 'Environment Validator Exception' } |
            Select-Object Title, Status, Severity, Description, Remediation,
                @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
    )
    EventLog = if ($eventLog) { $eventLog.LogName } else { $null }
    Events17205 = $events
    ExistingComponentPaths = @(
        $componentPaths |
            Select-Object -Unique |
            Where-Object { Test-Path -LiteralPath $_ }
    )
}

$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath
$summary | Format-List
Write-Host "Support summary: $summaryPath"
```

Preserve the two generated JSON files and the existing component paths. Include
the full action-plan exception, package name, progress timestamp, every problem
row, current health results, and Event ID 17205 records when present.

# Root Cause

The affected `RunValidators` implementation attempted to assign exception
results through the array-level expression
`$executionJobs.AllResults += $exceptionResults`. PowerShell member enumeration
supports reading that expression, but the assignment did not target one
execution-job object and raised the secondary property error.

The 2604 correction attaches the generated exception result to the specific
failed execution job. Current code then flattens the per-job result collections,
writes and parses the combined results, and rethrows the first blocking
validator exception after preserving its diagnostic result.

# Internal Root Cause

::: audience-engineering

The correcting change is ASZ-EnvironmentValidator PR `14146509`, merged as
commit `590250d7203950d10516be8b08c2832e81bdbc22`. Its title identifies the
2604 release line. The change removes the array-level assignment and adds the
exception result to `$exception.AllResults`, where `$exception` is the concrete
failed execution-job object.

Current main source also writes the progress-file fields documented in this
article and preserves an `Environment Validator Exception` result before
rethrowing the first blocking exception.

:::

# Mitigation Details

**2601-2603**

1. **[LOW RISK]** Remediate every validator identified by the current progress
   rows. The `AllResults` text has no independent configuration fix.
2. **[HIGH RISK]** Do not modify `EnvironmentValidator.psm1`, copy a newer module
   into `C:\NugetStore`, delete progress files, or bypass the health check.
3. After the underlying issue is fixed, rerun the system health check under
   **Verify the fix**.
4. Plan an update to the 2604 release line or later through the supported
   solution-update process. The newer code removes this masking defect for
   future validator exceptions.

**2604 and later**

Do not apply a legacy workaround. Current code records an
`Environment Validator Exception` result with the failed command and detail,
writes the combined result set, and then rethrows the blocking exception. Use
that result to resolve the actual validator failure.

**Verify the fix**

Run this **[LOW RISK]** block after every underlying validator issue is
remediated. `Invoke-SolutionUpdatePrecheck -SystemHealth` starts a new health
check. It does not start the solution update or move workloads.

```powershell
$ErrorActionPreference = 'Stop'
$before = Get-SolutionUpdateEnvironment
$beforeDate = $before.HealthCheckDate

Invoke-SolutionUpdatePrecheck -SystemHealth

$deadline = (Get-Date).AddHours(2)
do {
    Start-Sleep -Seconds 30
    $current = Get-SolutionUpdateEnvironment
    Write-Host ("HealthState={0}; HealthCheckDate={1}" -f
        $current.HealthState, $current.HealthCheckDate)

    $newResult = $null -ne $current.HealthCheckDate -and
        ($null -eq $beforeDate -or $current.HealthCheckDate -gt $beforeDate)
    $terminal = $current.HealthState -in @('Success', 'Warning', 'Failure')
} until (($newResult -and $terminal) -or (Get-Date) -ge $deadline)

if (-not ($newResult -and $terminal)) {
    throw 'The health check did not reach a new terminal result within two hours.'
}
if ($current.HealthState -notin @('Success', 'Warning')) {
    throw "HealthState is $($current.HealthState). The readiness check is not clear."
}

$blockingResults = @(
    $current.HealthCheckResult |
        Where-Object {
            $_.Status -notin @('Success', 'SUCCESS') -and
            $_.Severity -in @('Critical', 'CRITICAL')
        }
)
$validatorExceptions = @(
    $current.HealthCheckResult |
        Where-Object { $_.Title -eq 'Environment Validator Exception' }
)

if ($blockingResults.Count -gt 0 -or $validatorExceptions.Count -gt 0) {
    $blockingResults |
        Format-List Title, Status, Severity, Description, Remediation
    $validatorExceptions |
        Format-List Title, Status, Severity, Description, Remediation,
            @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail }}
    throw 'Critical health results or Environment Validator exceptions remain.'
}

Write-Host 'PASS: the new health check reached a non-failing terminal state.'
```

Success requires all of the following:

- `HealthCheckDate` advanced from the value captured before the rerun.
- `HealthState` reached `Success` or `Warning`.
- No critical non-success health result remains.
- No `Environment Validator Exception` result remains.
- On 2601-2603, the action plan no longer reports the `AllResults` property
  assignment error.

# Escalation

Escalate to Microsoft Support and the Environment Validator product group when
any of these conditions is true:

- the exact `AllResults` property-assignment signature occurs on a confirmed
  2604-or-later deploy package;
- the progress file is missing, stale, malformed, or contains an empty
  `ExecutionDetail`;
- the recovered validator has no applicable TSG or the documented remediation
  does not clear the current result;
- the new system health check does not reach a terminal state within two hours;
- a critical result or `Environment Validator Exception` remains after the
  underlying issue is remediated.

Provide the two generated JSON files, the complete action-plan exception, the
Environment Checker deploy package name, the relevant component logs, and the
exact time the new precheck was started.

# Internal Escalation

::: audience-engineering

Route a confirmed 2604-or-later recurrence with the exact legacy
property-assignment signature to the Environment Validator product group.
Include the installed deploy package, complete action-plan exception, progress
JSON, health-result JSON, Event ID 17205 records when present, and the UTC
precheck start and completion times. Reference Engineering ID `14146509` so the
current path can be compared with the fixing change.

:::

# Related Content

- [Troubleshooting MSI Does Not Have Access To Subscription](Troubleshooting-MSI-Does-Not-Have-Access-To-Subscription.md)
- [Known issue: This module requires Az.Accounts version 5.3.0](Known-Issue-This-module-requires-Az-Accounts-version-5-3-0.md)
- [Troubleshooting External Connectivity Failures in Environment Checker](Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md)
- [Troubleshooting Connectivity Test DNS](Troubleshooting-Connectivity-Test-Dns.md)
- [Update troubleshooting](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting)

::: audience-css

# Source Articles

- [Update troubleshooting](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting)

::: audience-engineering

- ASZ-EnvironmentValidator:
  `src/AzStackHci/AzStackHci.EnvironmentChecker/Deploy/Classes/EnvironmentValidator/EnvironmentValidator.psm1`
- ASZ-EnvironmentValidator:
  `src/AzStackHci/AzStackHci.EnvironmentChecker/AzStackHci.EnvironmentChecker.Operations.psm1`
- ASZ-UpdateService:
  `src/UpdateResourceProvider/LcmPowerShell/Docs/Invoke-SolutionUpdatePrecheck.md`

:::

:::
