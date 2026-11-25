<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local lifecycle management using .NET 10"],
  "detector": {
    "type": "command",
    "signal": "dotnet.exe --list-runtimes; Get-Service ECEAgent; Get-ClusterGroup *orch*"
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "manual",
    "last_validated": null,
    "spec_ref": ""
  }
}
-->

# Troubleshoot a missing .NET 10 runtime on Azure Local

The Enterprise Cloud Engine (ECE) Agent service or Azure Stack HCI Orchestrator cluster role is stopped, fails to start, or fails to restart, and the .NET 10 runtime required by the component is missing. Use this guide to check runtime availability and service health, then restore the runtime from the Azure Local artifact.

> **Important:** A service that is still running does not prove its runtime is still installed. Do not restart a healthy service or reboot a node just to test for this issue.

## Table of contents

- [Article metadata](#article-metadata)
- [Executive triage summary](#executive-triage-summary)
- [Symptoms and scope](#symptoms-and-scope)
- [Where this appears](#where-this-appears)
- [Preconditions and stop gates](#preconditions-and-stop-gates)
- [Diagnosis](#diagnosis)
- [Background](#background)
- [Mitigation](#mitigation)
- [Rollback](#rollback)
- [Verification](#verification)
- [Escalation and evidence package](#escalation-and-evidence-package)
- [Prevention and monitoring](#prevention-and-monitoring)
- [Future test automation metadata](#future-test-automation-metadata)
- [Related documentation](#related-documentation)

## Article metadata

| Field | Value |
| --- | --- |
| Component | Update / lifecycle management |
| Applicable products | Azure Local nodes whose lifecycle management components require .NET 10 |
| Supported versions | Release-specific applicability must be confirmed by Microsoft Support against the installed solution version and its runtime artifact; no Azure Local release range has been validated for this guide |
| Deployment modes | Run locally on each applicable node; connected or disconnected operation requires the approved runtime artifact to be available locally. Other deployment modes are not validated |
| Audience / primary owner | Azure Local administrator, with Microsoft Support for package approval and assisted recovery |
| Applicable scenarios | Post-update or steady-state runtime loss; lifecycle management service startup failure |
| Severity / customer impact | High when lifecycle management is unavailable; deployment, repair, or update operations can be blocked. Virtual machine downtime is not established by this symptom alone |
| Execution surface | on-device |
| Risk summary | Runtime installation: [HIGH RISK], because there is no supported automatic rollback to the missing-runtime state. Require Microsoft Support approval and an agreed maintenance window |
| Validation status | Draft: static review only (L0); live Azure Local detection, recovery, and uncharacterized administrator surfaces require validation before publication |

## Executive triage summary

| Question | Answer |
| --- | --- |
| What is broken? | A required .NET 10 shared runtime is missing, potentially preventing lifecycle management services from starting |
| Fastest safe next action | Run the read-only runtime inventory below on each affected node |
| Who should act? | An administrator with local elevated PowerShell access and cluster permissions |
| Downtime or workload risk | Read-only checks do not change state. Installing shared runtimes and starting orchestration components can affect management operations; coordinate with workload owners |
| Escalate immediately if | Cluster health is degraded, the artifact is unavailable or unapproved, or a component still fails after runtime restoration |

## Symptoms and scope

- `Get-Service ECEAgent` reports a status other than `Running`, or an attempted start/restart has failed.
- `Get-ClusterGroup *orch*` shows the Azure Stack HCI Orchestrator role as `Offline` or `Failed`, or the role has failed to come online.
- The runtime inventory shows no shared runtimes, or other .NET versions are present but the required .NET 10 runtime is absent.

This guide covers modern .NET shared runtimes, not .NET Framework. A missing Software Development Kit (SDK), a `dotnet` command missing from `PATH`, or a stopped service alone does not establish that the runtime is missing. A runtime may be present while a service has a different startup problem.

## Where this appears

`shown` identifies a specific detection surface, not a claim that the commands have been exercised on an affected Azure Local system. `absent` identifies an uncharacterized surface and remains a publication gap; it does not mean that no signal exists.

| Administrator surface | State | Signal / evidence to capture |
| --- | --- | --- |
| PowerShell on an Azure Local node | shown | Timestamped runtime inventory, `Get-Service ECEAgent`, and `Get-ClusterGroup *orch*` output from Diagnosis |
| Windows Failover Cluster Manager | shown | Roles > Azure Stack HCI Orchestrator Service Cluster Group: role state and owner node; corroborates role availability, not runtime loss |
| Windows event logs | absent | Capture existing startup/restart errors from the System and Application logs for the incident window; no issue-specific provider or event identifier has been validated |
| Cluster logs using `Get-ClusterLog` | absent | No runtime-loss-specific cluster-log signature has been validated |
| Azure portal | absent | No issue-specific portal signal has been validated |
| Windows Admin Center (standalone host) | absent | No issue-specific tool or alert has been validated |
| Windows Admin Center in the Azure portal | absent | No issue-specific tool or alert has been validated |
| Component / tool log files on disk | absent | No stable component-log path or runtime-loss-specific signature has been validated; retain installer logs produced during mitigation |

## Preconditions and stop gates

All diagnosis and verification commands are **[READ-ONLY]**; risk is not applicable because they do not change state.

| Gate | Expected result | Stop condition |
| --- | --- | --- |
| Permissions | Elevated 64-bit PowerShell on the target Azure Local node; permissions to query and manage the cluster role | Missing elevation, cluster access, or required cmdlets |
| Applicability | Microsoft Support confirms that the affected component requires .NET 10 and identifies the supported runtime families, architectures, and versions | Component requirements or solution applicability are unknown |
| Workload safety | No conflicting deployment, repair, or update operation; workload owner and Microsoft Support approve the recovery window | An operation is active, impact is unclear, or approval is missing |
| Cluster health | `Get-ClusterNode` shows expected nodes `Up`; `Get-VirtualDisk` shows expected disks healthy and attached; cluster administrator confirms quorum and redundancy are healthy | Unexpected node, disk, quorum, or redundancy state; do not infer safety from node state alone |
| Recovery material | Microsoft Support has agreed a recovery plan because returning to a missing runtime is not a safe rollback | Recovery plan or maintenance approval is missing |
| Runtime artifact | `Get-ASArtifactPath` is available and resolves the approved `Microsoft.DotNet10.Runtime.Installer` package for this solution | Package unavailable, ambiguous, or not approved; do not substitute a public download or install an SDK |
| Hardware / firmware | Not changed by this procedure | A separate hardware or firmware fault requires its own investigation |

## Diagnosis

### 1. Check installed runtimes on each affected node

Run this **[READ-ONLY]** block in elevated 64-bit PowerShell. It invokes the standard x64 and x86 hosts explicitly instead of relying on `PATH`. Capture the node name, time, raw runtime listing, and summary.

```powershell
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess) {
    throw 'Open 64-bit PowerShell before continuing.'
}

Get-Date -Format o
$env:COMPUTERNAME
$hosts = @(
    @{ Architecture = 'x64'; Path = "$env:ProgramW6432\dotnet\dotnet.exe" }
    @{ Architecture = 'x86'; Path = "${env:ProgramFiles(x86)}\dotnet\dotnet.exe" }
)

$runtimeInventory = foreach ($hostEntry in $hosts) {
    $hostPresent = Test-Path -LiteralPath $hostEntry.Path -PathType Leaf
    $runtimes = @()
    if ($hostPresent) {
        $runtimes = @(& $hostEntry.Path --list-runtimes)
        if ($LASTEXITCODE -ne 0) {
            throw "Runtime inventory failed for $($hostEntry.Path). Stop and collect the error."
        }
    }

    Write-Host "`n$($hostEntry.Architecture): $($hostEntry.Path)"
    $runtimes | ForEach-Object { Write-Host $_ }
    [pscustomobject]@{
        Architecture = $hostEntry.Architecture
        HostPresent = $hostPresent
        NoSharedRuntimesListed = ($runtimes.Count -eq 0)
        NET10CorePresent = (@($runtimes | Where-Object { $_ -match '^Microsoft\.NETCore\.App 10\.0\.' }).Count -gt 0)
        NET10AspNetCorePresent = (@($runtimes | Where-Object { $_ -match '^Microsoft\.AspNetCore\.App 10\.0\.' }).Count -gt 0)
    }
}
$runtimeInventory | Format-Table -AutoSize
```

**Expected healthy result:** The runtime family and architecture required by the affected component are present at a supported version, for example `Microsoft.NETCore.App 10.0.<patch>` for a component requiring that shared framework. If the component also requires ASP.NET Core, confirm `Microsoft.AspNetCore.App 10.0.<patch>` as well. The x86 runtime is not required merely because the script checks it.

**Expected affected result:** `HostPresent` is `False`, or `NoSharedRuntimesListed` is `True`, for the required architecture; alternatively, the relevant `NET10...Present` field is `False` even though other .NET versions remain installed. `Microsoft.NETCore.App` and `Microsoft.AspNetCore.App` are different runtime families; one does not prove the other is installed.

**Stop / branch:** A host execution error is inconclusive, not proof of absence. These checks cover only standard machine-wide locations: if the component uses a custom runtime path or bundles its own runtime, have Microsoft Support inspect that location before concluding that .NET is missing. If the required runtime is present and supported, investigate another startup cause rather than reinstalling under this guide. If it is missing, continue with the service checks.

### 2. Check ECE Agent and orchestrator health

Run on each affected node; the service query is node-local, while the cluster-group query shows cluster-wide roles and their current owner.

```powershell
$ErrorActionPreference = 'Stop'
Get-Date -Format o
$env:COMPUTERNAME
$eceAgent = Get-Service -Name 'ECEAgent' -ErrorAction Stop
$eceAgent | Format-Table Name, Status -AutoSize
if ($eceAgent.Status -ne 'Running') {
    Write-Warning "ECEAgent is not running on $env:COMPUTERNAME. Status: $($eceAgent.Status)."
}

$orchestratorGroups = @(Get-ClusterGroup -Name '*orch*' -ErrorAction Stop)
if ($orchestratorGroups.Count -eq 0) {
    throw 'No matching cluster group was found. Confirm the role name with Microsoft Support.'
}
$orchestratorGroups | Format-Table Name, State, OwnerNode -AutoSize
foreach ($group in $orchestratorGroups) {
    if ($group.State -ne 'Online') {
        Write-Warning "Cluster group '$($group.Name)' is not online. State: $($group.State)."
    }
}
```

**Expected healthy result:** `ECEAgent` is `Running` on each applicable node and the intended orchestrator cluster group is `Online`. Verify the exact role name; the wildcard may return unrelated groups. A clustered orchestrator service is not expected to run on every node simultaneously.

**Expected affected result:** `ECEAgent` is stopped or the orchestrator group is offline/failed. Record any error from a previous failed start or restart, with its time. Do not restart healthy components to produce an error.

**Stop / branch:** Missing services, missing roles, access failures, and transitional states require investigation; they are not equivalent to a stopped component. If the required runtime is missing, mitigate even when services still appear healthy, because a later start could fail. If the runtime is present, a stopped service alone does not authorize runtime installation. For a logon/account-lockout error, see the [account-lockout guide](../Security/TSG-Azure-Local-HCI-ECEAccount-Lockout.md).

## Background

A .NET installer defect can remove the latest runtime as well as an older runtime when `RemovePreviousVersion` is configured as `nextSession`. The reported sequence involves **two subsequent administrator sign-ins**: the first processes the older runtime's deferred uninstall and schedules the newer runtime's removal; the second processes that removal. Restarting and signing in can trigger this sequence, but two reboots alone are not the requirement.

For more information, see the Microsoft-maintained issue [dotnet/aspnetcore#67128](https://github.com/dotnet/aspnetcore/issues/67128). The maintainer's August 28, 2026 explanation notes that previously shipped installers can still schedule removal of a newer runtime even after a fix is available. Do not infer safety from the issue being closed or from installing a newer version alone.

The issue is background, not a required diagnostic test. Local inventory confirms runtime availability; service output confirms management-component availability. Runtime loss can contribute to startup failure, but those observations alone do not prove which installer removed it. A customer does not need to reproduce the bug or establish the sign-in history before recovering a confirmed missing, required runtime.

## Mitigation

### 1. Restore the approved runtime [HIGH RISK]

**Pre-check / approval:** Complete all stop gates and confirm the missing runtime family and architecture. Microsoft Support must approve the package contents and recovery plan before installation. Run locally on one affected node at a time during the agreed maintenance window; do not fan out installation across the cluster.

**Impact:** These installers change machine-wide shared runtimes used by management components and potentially other applications. `/norestart` suppresses a requested restart; it does not mean that installation has no workload impact or never needs a reboot.

First resolve and inspect the artifact with this **[READ-ONLY]** block:

```powershell
$ErrorActionPreference = 'Stop'
$packagePaths = @(Get-ASArtifactPath -NugetName 'Microsoft.DotNet10.Runtime.Installer' -ErrorAction Stop)
if ($packagePaths.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$packagePaths[0])) {
    throw 'Expected exactly one runtime artifact path. Stop and contact Microsoft Support.'
}
$nugetPath = [string]$packagePaths[0]
if (-not (Test-Path -LiteralPath $nugetPath -PathType Container)) {
    throw "Runtime artifact directory does not exist: $nugetPath"
}
$installers = @(Get-ChildItem -LiteralPath $nugetPath -Recurse -Filter '*.exe' -File -ErrorAction Stop |
    Sort-Object FullName)
if ($installers.Count -eq 0) {
    throw 'The runtime artifact contains no executable installers.'
}
foreach ($installer in $installers) {
    $signature = Get-AuthenticodeSignature -LiteralPath $installer.FullName -ErrorAction Stop
    if ($signature.Status -ne 'Valid' -or
        $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(,|$)') {
        throw "Installer signature is not valid and Microsoft-signed: $($installer.FullName)"
    }
}
$installers | Select-Object FullName, @{ Name = 'ProductVersion'; Expression = { $_.VersionInfo.ProductVersion } }
```

**Expected result:** Exactly one approved package directory, containing the expected Microsoft-signed installer executables. Compare the complete list, versions, runtime families, and architectures with Microsoft Support's approved package contents. A valid signature alone does not establish that an executable is the correct installer. Stop if anything is missing, unexpected, untrusted, or incompatible. If signature validation cannot complete offline, stop and request an approved verification path; do not bypass the check.

After approval, run the following **[HIGH RISK]** block in the same PowerShell session. It waits for each installer and checks its exit code rather than assuming that launching it means installation succeeded.

```powershell
$ErrorActionPreference = 'Stop'
if (@($installers).Count -eq 0) {
    throw 'Run artifact inspection and obtain approval before installation.'
}
foreach ($installer in $installers) {
    Write-Host "Installing $($installer.FullName)"
    $process = Start-Process -FilePath $installer.FullName `
        -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru -ErrorAction Stop
    Write-Host "Installer exit code: $($process.ExitCode)"
    if ($process.ExitCode -eq 3010) {
        throw 'Installation requires a reboot. Stop; coordinate a supported node-maintenance plan with Microsoft Support before continuing.'
    }
    if ($process.ExitCode -ne 0) {
        throw "Installer failed or returned an unexpected result ($($process.ExitCode)). Stop and collect installer logs."
    }
}
```

**Expected result:** Every approved installer exits with `0`. Immediately rerun Diagnosis step 1 and confirm the expected supported runtime versions. If installation fails, requests a reboot, or leaves the required runtime missing, stop; do not start components, retry repeatedly, or reboot automatically. Preserve each completed installer's result because earlier installers may already have changed state.

**Rollback:** There is no supported automatic rollback to the missing-runtime state. Do not uninstall the recovered runtime, delete runtime directories, or remove registry entries. Follow the support-approved recovery plan described in Rollback.

### 2. Start only the affected management components [MEDIUM RISK]

**Pre-check / impact:** Only continue after runtime verification succeeds on the affected node and, for the orchestrator role, its current owner node. Confirm all safety gates still hold. Starting these components can resume management work; obtain approval before doing so. Leave already healthy components running.

For an `ECEAgent` service that was stopped on this node:

```powershell
$ErrorActionPreference = 'Stop'
$eceAgent = Get-Service -Name 'ECEAgent' -ErrorAction Stop
if ($eceAgent.Status -eq 'Stopped') {
    Start-Service -Name 'ECEAgent' -ErrorAction Stop
    $eceAgent.WaitForStatus('Running', [TimeSpan]::FromSeconds(60))
}
$eceAgent.Refresh()
if ($eceAgent.Status -ne 'Running') {
    throw "ECEAgent did not reach Running. Current status: $($eceAgent.Status). Stop and escalate."
}
Get-Service -Name 'ECEAgent' -ErrorAction Stop
```

For an offline/failed orchestrator role, run this once from a cluster node. Confirm that the exact role name below matches Diagnosis step 2; never start every wildcard match.

```powershell
$ErrorActionPreference = 'Stop'
$groupName = 'Azure Stack HCI Orchestrator Service Cluster Group'
$group = Get-ClusterGroup -Name $groupName -ErrorAction Stop
if ($group.State -eq 'Offline' -or $group.State -eq 'Failed') {
    Start-ClusterGroup -Name $groupName -Wait 60 -ErrorAction Stop | Out-Null
}
$group = Get-ClusterGroup -Name $groupName -ErrorAction Stop
if ($group.State -ne 'Online') {
    throw "Orchestrator group did not reach Online. Current state: $($group.State). Stop and escalate."
}
$group | Format-Table Name, State, OwnerNode -AutoSize
```

**Expected result:** `ECEAgent` reaches `Running` and the intended orchestrator role reaches `Online`. Any start error, timeout, renewed failure, or failed customer-approved restart means recovery is incomplete: preserve the exact error and escalate. Do not force restarts, stop dependent services, or loop attempts.

**Rollback:** Do not automatically stop a recovered component, because it may already be processing work. If starting it causes unexpected impact, stop further recovery actions and have Microsoft Support assess active operations before approving any reversal.

## Rollback

| Action | Failure / rollback trigger | Recovery plan | Verification |
| --- | --- | --- | --- |
| Install runtime | Unexpected exit code, reboot request, missing runtime after installation, or new application impact | Stop further installers and preserve results/logs. Microsoft Support selects a supported repair or recovery path; there is no safe automatic undo to the missing-runtime state | Rerun runtime inventory, component health checks, and workload checks after the support-directed action |
| Start stopped components | Start failure, timeout, recurrence, or new management impact | Stop the procedure, not healthy services. Have Microsoft Support assess active operations and direct any required reversal; do not independently stop the cluster role | Capture service/role state and confirm workload health with the owner |

## Verification

All checks here are **[READ-ONLY]**; risk is not applicable.

1. Immediately after installation, rerun Diagnosis step 1 on every repaired node. Confirm the component's required runtime families, architectures, and supported versions, not just the presence of `dotnet.exe`.
1. After any approved component start, rerun Diagnosis step 2. Confirm `ECEAgent` is `Running` on each applicable node and the orchestrator group is `Online`; record its owner.
1. Confirm `Get-ClusterNode` and `Get-VirtualDisk` still show the expected healthy state. Have the administrator check quorum and redundancy and have workload owners confirm application availability.
1. Confirm the affected management operation can proceed through its normal supported workflow. Resuming a failed deployment or update is a separate state-changing action and requires its own operation-specific approval; it is not automatic in this guide.
1. Recheck runtime and component health after the next already-planned administrator sign-in or maintenance event. Do not create additional sign-ins or reboots to reproduce the issue. If the runtime disappears again, preserve evidence and escalate rather than repeatedly reinstalling.

Recovery is not complete if the runtime is present but a component remains stopped, the role remains offline/failed, or customer impact remains. Lack of recurrence before the next maintenance event is not proof that deferred removal cannot recur.

## Escalation and evidence package

Contact Microsoft Support if a stop gate is met, requirements or artifact selection are unclear, installation fails, a reboot is requested, a service fails to start/restart, or the runtime disappears again. Include:

- Azure Local solution version and operating system build; affected node roles and customer impact.
- Incident time window, runtime inventory before/after, service states on affected nodes, orchestrator group state and owner, and exact startup/restart errors.
- Artifact identity, installer names/versions/signature results, exit codes, and installer logs from the executing account's temporary directory for the installation window.
- Existing System/Application events around the failure and recent maintenance/sign-in history if available. Installer removal history can help explain recurrence, but is not a prerequisite to restoring a missing runtime.

Share evidence through the support case, not a public issue. Remove credentials, tokens, and unnecessary personal or environment-specific identifiers.

## Prevention and monitoring

Check runtime presence and component health before and after planned maintenance. Coordinate the supported .NET servicing baseline with Microsoft Support. Do not change `RemovePreviousVersion` policy, delete `RunOnce` values, or manually run pending uninstall commands under this guide; those actions require separate review of deferred removals and workload impact.

## Future test automation metadata

| Field | Value |
| --- | --- |
| Detector type / signal | `command`; runtime inventory plus `Get-Service ECEAgent` and `Get-ClusterGroup *orch*` |
| Inject strategy | Manual validation on an isolated supported Azure Local lab; do not remove production runtimes to inject a failure |
| Mitigation selector | Mitigation steps 1 and 2, gated by support approval |
| Safety floor | Confirmed component requirements, approved artifact, healthy cluster, maintenance approval, and support-directed recovery plan |
| Rollback check | Runtime inventory, service/role state, and workload-owner verification after support-directed recovery |
| Reproduction substrate / fidelity level | `none` / `L0`; no live environment exercised |
| Technical grade / automation status | `null` / `manual` |
| Spec reference / last validated | Empty / `null`; no TSG-FORGE report or qualifying live validation |

## Related documentation

- [Install .NET on Windows: choose when previous versions are removed](https://learn.microsoft.com/en-us/dotnet/core/install/windows#choose-when-previous-versions-are-removed)
- [Check installed .NET versions](https://learn.microsoft.com/en-us/dotnet/core/install/how-to-detect-installed-versions)
- [The dotnet command and runtime inventory](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet)
- [Troubleshoot ECE Agent or orchestrator account lockout](../Security/TSG-Azure-Local-HCI-ECEAccount-Lockout.md)
