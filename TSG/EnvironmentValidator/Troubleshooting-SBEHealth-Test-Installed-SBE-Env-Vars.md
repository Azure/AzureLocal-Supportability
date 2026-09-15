# AzStackHci_SBEHealth_Test-Installed-SBE-Env-Vars

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Installed-SBE-Env-Vars</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Installed Solution Builder Extension environment variables consistency ("Validate Installed SBE Env Vars")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-AzStackHciSBEHealth</code> emits <code>Test-Installed-SBE-Env-Vars</code> during pre-update validation</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Warning</strong>: the check flags an inconsistent installed-SBE state so you can reconcile it. It does not fail the check or block the operation, but the mismatch should be cleared before the next update.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>The machine environment variables that record the installed Solution Builder Extension (<code>SBEInstalledContent</code> and <code>SBEInstalledMetadata</code>), together with the SBE version read from <code>oemMetadata.xml</code>, must be internally consistent: either a complete installed SBE (both set), or no SBE at all (both unset).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Pre-update SBE health validation (update readiness), on solutions that ship a Solution Builder Extension.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Quick fix

If you just want the short version: this warning means the machine environment variables
that record the **installed** Solution Builder Extension (SBE) are in a half-set,
mismatched state on this node, usually left behind by an interrupted or partial SBE
update. Reconcile it by re-running the Solution Builder Extension update to completion so
the platform re-populates those variables consistently (**"Update to latest available
Solution Builder Extension to restore consistent SBE state"**), then re-run the pre-update
check. This is not a quick variable edit: the read-only check takes minutes, but the
supported repair is a cluster maintenance operation that may download or re-stage partner
content across nodes and may drain or restart nodes according to the update plan. Reserve
the normal solution-update maintenance window and confirm workload impact before starting.
Full detail and how to verify the fix are below.

> **Customer summary:** One or more nodes do not agree on the recorded installed-SBE state.
> We will collect the per-node evidence, schedule the SBE update in a maintenance window,
> and verify that every node reports a complete installed SBE or a deliberate no-SBE state.

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content that ships
alongside the Azure Local solution: drivers, firmware, and a partner module that can
contribute health tests during deployment and updates. When an SBE is installed, the
platform records where it lives on the node in two **machine environment variables**:

- `SBEInstalledContent`: the path to the installed SBE content.
- `SBEInstalledMetadata`: the path to the installed SBE metadata (which contains
  `oemMetadata.xml`, the file the SBE **version** is read from).

### Glossary

- **Staged SBE:** partner content downloaded or unpacked into an update workspace. Staged
  content is not necessarily the SBE that the node records as installed.
- **Installed SBE:** the content and metadata paths recorded by the two machine-scoped
  environment variables. This is the state this check evaluates.
- **Content and metadata:** content is the partner payload, such as drivers, firmware, and
  modules; metadata includes `oemMetadata.xml`, which carries the version used by this check.
- **Machine-scoped environment variable:** a system-wide value stored for the computer, not
  just for the account running PowerShell. The values are evaluated independently on each
  cluster node.
- **Pre-update or system health check:** a readiness evaluation. It reports SBE state but does
  not itself install, repair, or re-stage the SBE.

During **pre-update** validation, the SBE health check reads those two variables and the
derived version, and reports the installed-SBE state as one of three outcomes:

- **Installed (SUCCESS).** Both variables are set: that pairing is the installed signal. The
  node has a complete installed SBE. The SBE version shown in the detail is read from
  `oemMetadata.xml` under the metadata path and is informational; it defaults to `1.0` when
  that file is absent, so a missing version does not by itself change this outcome. The detail
  reads *"Detected SBE `<version>` is installed."*
- **No SBE (SUCCESS).** Both variables are unset. The implementation can also emit this
  detail when its `1.0` version fallback is still in effect for a partial path combination,
  so this result alone does not prove that no SBE files remain. The detail reads *"No SBE
  installed."* and the path and metadata evidence above must be checked.
- **Inconsistent (WARNING).** The variables are in a mismatched combination that is neither
  a complete install nor a clean "no SBE" (for example the content path is missing while
  the metadata path still points at a real SBE version). The detail reads *"Inconsistent
  SBE ENV vars!!"* and lists the content path, metadata path, and version it saw. The
  remediation is *"Update to latest available Solution Builder Extension to restore
  consistent SBE state."*

**Read the source semantics carefully.** `Test-AzStackHciSBEHealth` initializes the version
to `1.0`, reads `oemMetadata.xml` only when the metadata path is set and the file exists, and
then evaluates the paths and version. When both environment variables are present, that
installed branch wins even if the version remains the `1.0` fallback. When only one variable
is present and the version remains `1.0`, the validator can instead emit the *No SBE
installed* detail. A fallback version is therefore not proof that the metadata is complete:
inspect the paths, the file, and the version separately. The actionable persisted signal is
the `AdditionalData.Detail` text together with the numeric top-level `Severity`.

Only the **Inconsistent** outcome is actionable, and it is a **Warning**, not a hard
failure: the check does not block the deployment or update. It is an early guard. An
inconsistent installed-SBE state most often comes from an SBE stage or update that was
interrupted or only partially applied, leaving one variable updated and the other stale. If
that mismatch is carried into the next update it can cause downstream "new plus old" SBE
path problems, so the check surfaces it now so you can reconcile it first.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / update task, owned by the person
  running the update, together with the **hardware partner (OEM)** whose SBE is in use if
  the SBE itself needs to be re-staged. It is **not** a generic Windows task and **not** a
  networking task, so do not route it to the network team.
- **This is safe to investigate read-only.** Reading the check result, the event log, and
  the two environment variables changes nothing.
- **Separate the check from the repair.** The pre-update check and evidence collection are
  read-only. Re-running the SBE update is not: it can transfer or re-stage partner content
  across the cluster and can invoke node drains, reboots, workload moves, or temporary
  unavailability when required by the solution and SBE update plan. Do not promise zero
  runtime impact, and do not start it without the normal maintenance window.
- **Do not hand-edit these environment variables to "make the warning go away."** They are
  meant to be a faithful record of the installed SBE. Set them by hand and you can hide a
  real half-staged SBE and cause a later update to run against the wrong content. The
  supported fix is to reconcile the installed SBE itself (re-run the SBE update), which sets
  the variables correctly as a side effect.

### Ownership lanes

- **Cluster or update operator:** collect all-node evidence, identify the active SBE
  endpoint or package source, schedule the maintenance operation, and verify every node
  afterward.
- **OEM or hardware partner:** owns the partner package, `oemMetadata.xml`, manifest, and
  the expected SBE version. Involve the OEM when the package is incomplete, the metadata is
  invalid, or a completed update cannot restore a consistent state.
- **Network or proxy owner:** engage only when transfer evidence shows an egress, proxy,
  authentication, or bandwidth problem. A partial transfer alone is not enough to assign
  ownership without the endpoint and transfer error.
- **Azure Local update or Environment Validator support:** engage when a completed update
  leaves any node inconsistent, the serialized fields contradict the detail, or the
  warning recurs without a corresponding package or transfer problem.

## Where this failure appears

You can see this warning in the Azure portal, on the node, and in the Environment Checker's
component log and report files.

### In the Azure portal

When you run update readiness (or update validation) from the portal, the validation phase
runs the Environment Checker and surfaces SBE health results on the cluster's **Updates**
view. An inconsistent `Test-Installed-SBE-Env-Vars` appears there as a warning under the SBE
health checks, with the "Inconsistent SBE ENV vars" detail.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event
log as the JSON body of an **Event ID 17205** entry, and to the cluster-wide
`HealthCheckResult.*.json` on the infrastructure share. Read this check's most recent result
on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-Installed-SBE-Env-Vars*' } |
    Select-Object -First 1 Name,
        @{n='AdditionalDataStatus';e={$_.AdditionalData.Status}},
        @{n='SeverityCode';e={$_.Severity}},
        @{n='Detail';e={$_.AdditionalData.Detail}}
```

The `Name` on the node carries a domain prefix (`AzStackHci_SBEHealth_`) and can carry a node
suffix, so the query uses `-like '*Test-Installed-SBE-Env-Vars*'` (leading and trailing
wildcard) to match it. In this JSON the human-readable status and message live under
`AdditionalData` (the top-level `Status` and `Severity` are numeric enum fields, and the
top-level `Description` is a generic check description). This check keeps
`AdditionalData.Status = SUCCESS` even when the state is inconsistent. The persisted warning
is represented by the numeric top-level `Severity` warning value plus
`AdditionalData.Detail`; there is no `AdditionalData.Severity`. Do not search for
`Status = FAILURE` for this check. The reliable signal is `AdditionalData.Detail` reading
*"Inconsistent SBE ENV vars!! content: [...], metadata: [...], sbeVersion [...]"*, which tells
you exactly which paths and version the check saw.

You can also read the two environment variables directly on the node to see the mismatch:

```powershell
[pscustomobject]@{
    SBEInstalledContent  = [System.Environment]::GetEnvironmentVariable('SBEInstalledContent','Machine')
    SBEInstalledMetadata = [System.Environment]::GetEnvironmentVariable('SBEInstalledMetadata','Machine')
}
```

A consistent operational state should show **both** values populated with existing paths
(an installed SBE) or **both** empty (no SBE). The validator's `1.0` fallback can make a
partial record emit the no-SBE detail, so also check path existence and `oemMetadata.xml`
before declaring a node healthy.

These are **per-node** machine variables, so the state is evaluated on each node
independently: an inconsistency can exist on one node while the others are fine. Read the two
variables on each node to see which nodes are affected. You do not reconcile them node by node
by hand; re-running the Solution Builder Extension update (step 2) is a cluster-level operation
that re-stages the SBE and re-populates these variables consistently across the nodes.

Collect the per-node state in one pass from a node with cluster access. This captures the
machine variables, path evidence, the version file, and the most recent persisted result so
a clean result on one node cannot hide a warning on another:

```powershell
$nodes = (Get-ClusterNode).Name
Invoke-Command -ComputerName $nodes -ThrottleLimit 4 -ScriptBlock {
    $content = [System.Environment]::GetEnvironmentVariable('SBEInstalledContent', 'Machine')
    $metadata = [System.Environment]::GetEnvironmentVariable('SBEInstalledMetadata', 'Machine')
    $metadataFile = if ([string]::IsNullOrWhiteSpace($metadata)) {
        $null
    }
    else {
        Join-Path -Path $metadata -ChildPath 'oemMetadata.xml'
    }

    $version = '1.0 (validator fallback)'
    if ($metadataFile -and (Test-Path -LiteralPath $metadataFile)) {
        try {
            $xml = [xml](Get-Content -LiteralPath $metadataFile -Raw -ErrorAction Stop)
            $version = [string]$xml.UpdatePackageManifest.UpdateInfo.Version
            if ([string]::IsNullOrWhiteSpace($version)) {
                $version = '<empty Version>'
            }
        }
        catch {
            $version = "<parse error: $($_.Exception.Message)>"
        }
    }

    $eventResult = Get-WinEvent -LogName AzStackHciEnvironmentChecker `
        -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            try {
                $_.Message | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                # Ignore unrelated or malformed event payloads.
            }
        } |
        Where-Object { $_.Name -like '*Test-Installed-SBE-Env-Vars*' } |
        Select-Object -First 1

    [pscustomobject]@{
        Node                  = $env:COMPUTERNAME
        Content               = $content
        ContentPathExists     = [bool]($content -and (Test-Path -LiteralPath $content))
        Metadata              = $metadata
        MetadataPathExists    = [bool]($metadata -and (Test-Path -LiteralPath $metadata))
        OemMetadataFileExists = [bool]($metadataFile -and (Test-Path -LiteralPath $metadataFile))
        OemMetadataVersion    = $version
        AdditionalDataStatus  = $eventResult.AdditionalData.Status
        SeverityCode          = $eventResult.Severity
        Detail                = $eventResult.AdditionalData.Detail
    }
} | Sort-Object Node | Format-Table -Wrap
```

The command requires PowerShell remoting from the management node. If remoting is not
available, run the script block locally on each node and preserve the `Node` field. Treat
`AdditionalData.Detail`, `SeverityCode`, and the raw path evidence as one record; an empty
event result means that node has no matching persisted run yet, not that it is healthy.

### Component log files on disk

The Environment Checker also writes its own files under the running account's
`%USERPROFILE%\.AzStackHci\` folder: `AzStackHciEnvironmentChecker.log` and the
machine-readable `AzStackHciEnvironmentReport.json` (and, on some builds, `.xml`). These
files are local to the node and account that ran the checker. The report normally carries
the `SBEHealth` result array, while the text log carries the emitted detail:

```powershell
$logRoot = Join-Path $env:USERPROFILE '.AzStackHci'
Select-String -Path (Join-Path $logRoot 'AzStackHciEnvironmentChecker.log') `
    -Pattern 'Test-Installed-SBE-Env-Vars|Inconsistent SBE ENV vars' -Context 1,2

$report = Get-Content (Join-Path $logRoot 'AzStackHciEnvironmentReport.json') |
    ConvertFrom-Json
$report.SBEHealth |
    Where-Object { $_.Name -like '*Test-Installed-SBE-Env-Vars*' } |
    Select-Object Name,
        @{n='AdditionalDataStatus';e={$_.AdditionalData.Status}},
        @{n='SeverityCode';e={$_.Severity}},
        @{n='Detail';e={$_.AdditionalData.Detail}}
```

Use `AdditionalData.Detail` and the numeric `SeverityCode` in these files as well. The
inconsistent warning is not a `FAILURE` status in this check. If the report is absent,
collect the Event ID 17205 record and the cluster-wide `HealthCheckResult.*.json` instead.

**Where this does NOT appear.** This check's warning is not evident in the surfaces below,
so do not spend time looking for it there:

- **Cluster logs:** not evident in `Get-ClusterLog` output because this is an Environment
  Checker result, not a failover-cluster event.
- **Failover Cluster Manager:** not evident in `cluadmin.msc` because it is not a clustered
  role, resource, or node property.
- **Windows Admin Center (standalone host):** not evident in the standalone WAC host view
  for this check.
- **Windows Admin Center in the Azure portal:** not evident in the WAC-in-Azure view; use
  the Azure portal **Updates** blade or the node evidence above.

## Requirements

A consistent installed-SBE state is one of:

- **A complete installed SBE:** `SBEInstalledContent` and `SBEInstalledMetadata` are both set
  (that pairing is what the validator uses for its installed branch). Operationally, both
  paths should exist and `oemMetadata.xml` under the metadata path should supply a real version.
- **No SBE at all:** `SBEInstalledContent` and `SBEInstalledMetadata` are both unset.

**Do not collapse the validator's fallback into a package-health claim.** The source initializes
the version to `1.0`. With both variables present, the installed branch wins even when that
fallback remains. With only one variable present and the fallback still `1.0`, the validator
can emit *No SBE installed* instead of a warning. A variable mismatch with a parsed version
other than `1.0`, or an otherwise unresolved version after the metadata file is present, can
emit the Warning. The cross-node collection above distinguishes these cases and is the
authoritative evidence to attach to an escalation.

## Troubleshooting Steps

### 1. Read the warning detail and the two variables

Run the cross-node collection above first, then use the Event ID 17205 query (or open the
`HealthCheckResult.*.json`) on any node that needs more detail. Read `AdditionalData.Detail`,
the numeric `Severity`, and the two environment variables together. Confirm the mismatch
and note which side is stale: for example `SBEInstalledContent` empty while
`SBEInstalledMetadata` still points at a metadata directory that has a real
`oemMetadata.xml` version, or a content or metadata path that no longer exists on disk.
Record the component log/report paths when they are available.

### 2. Reconcile the installed SBE by re-running the update

Do not edit the environment variables by hand. Instead, re-run the **Solution Builder
Extension update** to completion so the platform re-stages the SBE and re-populates
`SBEInstalledContent` and `SBEInstalledMetadata` consistently. This is the verbatim
remediation the check gives: *"Update to latest available Solution Builder Extension to
restore consistent SBE state."*

- **Plan the operation.** This is a cluster maintenance action, not a read-only repair.
  It can transfer or re-stage partner content on multiple nodes and can invoke drains,
  reboots, workload moves, or temporary unavailability required by the update plan. Exact
  duration depends on the package, transfer path, node count, and current update state;
  there is no safe fixed time estimate. Use the normal solution-update maintenance window,
  and confirm the current update plan and workload protections before you start.
- **Establish the source before re-adding anything.** Record the endpoint used for SBE
  discovery so the update operator or OEM does not guess the channel:

  ```powershell
  (Get-SolutionDiscoveryDiagnosticInfo).Configuration.ComponentUris["SBE"]
  ```

  A default Microsoft-hosted `aka.ms` endpoint and a custom override imply different
  ownership and package paths. If the endpoint cannot be determined, stop and escalate
  rather than re-adding an unknown package.
- Re-add or re-download the SBE through the same channel you used to add it (the Azure Local
  update / Solution Builder Extension flow), and let the update finish rather than cancelling
  it partway.
- Confirm the SBE version matches what the cluster expects, and that the transfer completed
  (no partial extraction).
- If the referenced content or metadata **path does not exist** on disk, the earlier stage
  was incomplete. Re-stage the correct partner (OEM) package from your source, then re-run
  the update. If you did not stage this SBE yourself (most customers do not; the update or
  partner engineer, or the OEM, does), hand this off to them along with the two environment
  variable values and the SBE version. For the exact per-solution steps, see the Solution
  Builder Extension guidance under **Related**.

### 3. Re-run the pre-update check

Re-run the same **update readiness** check that first surfaced this warning, and let it
re-evaluate SBE health. If you are not sure what that means: in the Azure portal, open the
cluster's **Updates** page and run the update readiness (validation) check again; or on a node,
an administrator can trigger a fresh system health check with
`Invoke-SolutionUpdatePrecheck -SystemHealth`:

```powershell
# Trigger a fresh system health check (this re-runs the SBE health checks)
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then check the health state
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is required to re-run the health checks. A bare
`Invoke-SolutionUpdatePrecheck` does not re-evaluate them. The fresh check re-reads the two
environment variables and re-classifies the installed-SBE state. See the Azure Local update
troubleshooting guidance under **Related** for more on the readiness / precheck step.

### 4. Verify the fix

Run the cross-node collection again and require every expected node to report
`Test-Installed-SBE-Env-Vars` with an `AdditionalData.Detail` of either
*"Detected SBE `<version>` is installed."* or *"No SBE installed."* and no
*"Inconsistent SBE ENV vars"* detail. The persisted `AdditionalData.Status` can remain
`SUCCESS`; confirm the numeric top-level `Severity` is no longer the warning value and
that the content and metadata paths match the intended state. Re-reading only one node is
not sufficient.
If you re-ran the check with `-SystemHealth` (step 3), confirm the overall result with
`Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate` and check that
`HealthState` is `Success` (not `Failure`). In the portal, the SBE health warning clears on the
next validation pass.

## When to escalate

The operator owns the first fix: collecting evidence and re-running the SBE update to
completion (step 2) in a maintenance window. Route the next action by evidence:

- A **completed** SBE update still leaves the variables inconsistent. That points at a
  staging or update-engine problem rather than an interrupted run; escalate to Azure Local
  update or Environment Validator support with the per-node collection, the component log
  and report, the two environment variable values, the SBE version, and the Event ID 17205
  detail.
- The content or metadata path is set but points at a location that does not exist and cannot
  be re-created by re-running the update. Escalate to the hardware partner (OEM) to
  re-supply the correct SBE package. Include the endpoint or package source, the
  `oemMetadata.xml` evidence, and the affected nodes. The package must install so that, on
  every node, the end-state is consistent: `SBEInstalledContent` and
  `SBEInstalledMetadata` are both set to paths that exist, and the metadata path carries an
  `oemMetadata.xml` with a resolvable version.
- Repeated partial transfers with proxy authentication, endpoint, timeout, or bandwidth
  errors. Escalate to the network or proxy owner with the endpoint, transfer error, and
  affected node list. Do not assign a transfer problem to the OEM until the egress path
  has been checked.
- The sibling SBE health checks also warn or fail (see **Related**), which can indicate a
  broader SBE configuration problem rather than just a stale environment variable.

## Related

- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/azure/azure-local/manage/troubleshoot-deployment#restart-the-deployment-via-azure-portal
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-SolutionExtensionModule` (the staged SBE `SolutionExtension` module is present,
  integrity-intact, and signed), `Test-SBEPropertiesValid` (partner property values match the
  SBE manifest), and `Test-SBECredentialsValid` (SBE credentials in the secret store match the
  SBE manifest).
