<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "Invoke-AzStackHciVSRDriftDetectionValidation"
  },
  "validation": {
    "fidelity_level": "L1",
    "technical_grade": null,
    "reproduction_substrate": "hardware",
    "automation_status": "not-assessed",
    "last_validated": "2026-11-06",
    "spec_ref": ""
  }
}
-->

# Troubleshooting Azure CLI drift against the Validated Solution Recipe

| Field | Value |
| --- | --- |
| Component | Environment Validator / Validated Solution Recipe (VSR) |
| Validator / test | `Invoke-AzStackHciVSRDriftDetectionValidation -PassThru` |
| Applicable products | Azure Local nodes with the VSR drift validator and `AzureLocalImageModule` installed |
| Applicability | Azure CLI core drift, with or without extension drift; the remediation path requires `Remediate-AzCli` and access to the recipe's installation sources. Extension-only drift does not use this remediation path. |
| Severity | Inspect the severity returned by each check; severity can vary by release. |
| Execution surface | on-device |
| Validation | Diagnostic commands and module import exercised on a physical x64 lab node (OS build 26100, Windows PowerShell 5.1) on 2026-11-06. The full drift validator returned 20 successful checks, including CLI core and four extensions; CLI inventory selected the x64 path. Remediation, failure detection, the x86 fallback on a live installation, and health-fault clearing remain untested. |

Do not infer applicability to disconnected, disaggregated, or multi-rack
deployments. If required commands or installation sources are unavailable,
stop and obtain release-specific guidance from Microsoft Support.

## Table of contents

- [Symptoms](#symptoms)
- [Issue validation](#issue-validation)
- [Contributing factors](#contributing-factors)
- [Preconditions](#preconditions)
- [Mitigation details](#mitigation-details)
- [Rollback and escalation](#rollback-and-escalation)
- [Verify resolution](#verify-resolution)
- [Administrator detection surfaces](#administrator-detection-surfaces)
- [Related documentation](#related-documentation)

## Symptoms

The Azure CLI (`az`), its extensions, or both do not match the node's Validated
Solution Recipe. The VSR defines the versions expected by the Azure Local
solution rather than the latest versions available from a package repository.

The Environment Validator drift check can report:

- Core CLI: `Test Azure-Cli Module Version`.
- Extension: `Test Azure-Cli Extension <name> Version`, for extensions such as `arcappliance`, `customlocation`,
  `k8s-extension`, or `stack-hci-vm`.

Example core-CLI failure text:

```text
Failed to discover installed version of AzCli on host [<node>]
Expected [2.85.0] but discovered [N/A].
Is it installed; can you run (az version)?
```

The version above is illustrative, not a version to install on every release.
Extension failures can report:

```text
Failed to parse installed version of '<name>' on host '<node>'. Got ''.
```

A health service drift alert may also be open. Inspect current faults with
`Get-HealthFault`, and correlate the reason, affected node, and expected versus
discovered versions with the validator output. Do not treat an unrelated fault
as permission to run Azure CLI remediation.

If core `az` is missing or undiscoverable, extension discovery may also fail.
Resolve core discovery first and re-run the validator before concluding that
each extension has an independent problem.

## Issue validation

**[READ-ONLY]** Risk is not applicable because these checks do not change the
installed CLI or extensions. Run them on the affected node before remediation.

```powershell
$results = @(Invoke-AzStackHciVSRDriftDetectionValidation -PassThru -ErrorAction Stop)
if ($results.Count -eq 0) {
    throw 'The validator returned no results; drift status is unknown.'
}
$results | Select-Object Name, Status, Severity, Description, Remediation
```

Inspect all returned results to confirm that the core CLI and the expected
extension checks actually ran. Empty results or no matching checks are an
unknown state, not a pass. Stop if the validator throws, returns an unexpected
status, or produces no relevant results.

Confirm the installed CLI version. Check the current x64 installation path first,
then the legacy x86 path. If both exist, this diagnostic uses the x64 installation:

```powershell
$azPaths = @(
    'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
    'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
)
$azPath = $azPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $azPath) {
    throw "Azure CLI executable was not found at either expected path: $($azPaths -join ', ')"
}
Write-Output "Azure CLI executable: $azPath"
Write-Output "AZURE_EXTENSION_DIR: $env:AZURE_EXTENSION_DIR"
& $azPath version
```

This diagnostic preserves the session's `AZURE_EXTENSION_DIR`; it does not
override the composed image's extension configuration. Before interpreting
extension versions, confirm that the displayed value points to the
release-supported managed extension directory. If it is unset, points elsewhere,
or the directory is missing, stop and investigate the image/session configuration.
Do not treat the resulting extension inventory as verified recipe state.

Compare the returned core and extension versions with the current node's recipe,
not with the latest upstream release. The core package is
`Microsoft.AzureStack.AzureCLI`. A missing executable means this installation
cannot be checked at either expected path; it is not, by itself, a verified
version mismatch.

Choose the remediation path from the current validator results:

| Core CLI check | Extension checks | Action |
| --- | --- | --- |
| `FAILURE` | Successful | Follow the core CLI remediation steps below. |
| `FAILURE` | One or more failures | Follow the core CLI remediation steps, then recheck extensions separately. |
| `SUCCESS` | One or more failures | Skip both remediation steps below. Do not reinstall the core CLI for extension-only drift. |

`Remediate-AzCli` remediates only the core CLI, not CLI extensions. For
extension-only drift or extension failures remaining after core remediation,
retain the validator details and follow the extension's `Remediation` field,
[Drift detection for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/manage/drift-detection),
and Microsoft Support guidance. This guide does not provide extension
installation or removal commands.

## Contributing factors

The validator's expected and discovered versions identify the mismatch.
A partial installation, interrupted upgrade, or manual upgrade is a possible
contributing factor, but the version mismatch alone does not establish which
operation introduced it. Retain installation errors and recent-change records.

## Preconditions

Before changing the CLI installation:

- Confirm `FAILURE` for the core CLI check, `AzStackHci_AzureCli_Version`, in
  the current node's validator output and record its expected version.
  Extension failures alone do not satisfy this precondition.
- Use a new, elevated Windows PowerShell session on each affected node.
- Do not run remediation concurrently with deployment, an update, another
  installation, or automation that uses `az`.
- Confirm that the recipe's installation sources are reachable. Stop if the
  node cannot obtain the required packages.
- Obtain a maintenance window and a recovery plan approved by Microsoft Support.
  Replacing the CLI can interrupt management or automation operations using it.

## Mitigation details

Run these steps only for confirmed core CLI drift, whether or not extension
drift is also reported. For extension-only drift, skip both steps.

### Step 1: Import the Azure Local Image module

**[LOW RISK]** This changes only the current PowerShell session.

```powershell
Import-Module AzureLocalImageModule -Force -ErrorAction Stop
```

The module is installed in the standard Windows PowerShell module path
(`C:\Windows\System32\WindowsPowerShell\v1.0\Modules\AzureLocalImageModule`).
If import fails, stop and verify the installation and `$env:PSModulePath`.
Confirm that `Remediate-AzCli` is available from this module before proceeding.
Closing the session discards its imports without changing installed software.

### Step 2: Run recipe-aware detection and remediation

**[HIGH RISK]** Run only after all preconditions are satisfied. The helper invokes
the VSR Infra drift-detection client for the `AzCli` category and attempts to
align the core CLI with the recipe. It does not remediate CLI extensions.
This article does not provide an automatic rollback.

```powershell
$driftResult = Remediate-AzCli -Verbose
$driftResult
```

Inspect the returned result for completion or errors, then run
[Verify resolution](#verify-resolution). Stop if execution fails or the final
validator still reports core CLI drift. Treat any remaining extension failures
separately as described under [Issue validation](#issue-validation).
Do not repeatedly reinstall or upgrade `az` without investigating the failure.

## Rollback and escalation

There is no automatic rollback for CLI remediation in this article. If import
fails, close the session; the installation has not been changed. If remediation
or verification fails, stop state-changing commands and contact Microsoft
Support with the before/after `az version` output, validator results, and
installation errors. Use only the recovery plan agreed before remediation,
not an arbitrary CLI or extension version.

## Verify resolution

**[READ-ONLY]** Repeat both commands under
[Issue validation](#issue-validation) on every affected node. To verify core
CLI remediation, require:

- The core CLI version matches the current recipe.
- The validator returns `AzStackHci_AzureCli_Version` with status `SUCCESS`.

No failure rows are insufficient if the core check did not run. A missing,
unexpected, or failing core result means core resolution is not verified.

Record extension results separately. Core CLI success does not establish that
extension drift is resolved, and `Remediate-AzCli` is not a fix for a remaining
extension failure. Follow the extension-specific guidance under
[Issue validation](#issue-validation), rather than rerunning core remediation.

If a drift health fault was also present, check `Get-HealthFault` after the next
scheduled drift-detection run. The on-demand validator verifies the installed
state; it does not prove that a previously raised fault has already cleared.
Before retrying an update, confirm core remediation on all affected nodes and
follow the actual pre-update health results. Informational extension drift alone
is not an update-blocking condition; do not make extension success a prerequisite
for retry solely on that basis. Follow the emitted severity and release-specific
guidance for other extension findings.

## Administrator detection surfaces

| Surface | Status | Evidence or validation gap |
| --- | --- | --- |
| PowerShell on a node | shown | The drift validator, `az version`, and correlated `Get-HealthFault` output described above. |
| Azure portal | absent | The current drift presentation in the portal has not been exercised for this article. |
| Windows event logs | absent | No drift-specific event query has been validated. |
| Cluster logs (`Get-ClusterLog`) | absent | No drift-specific cluster-log query has been validated. |
| Windows Failover Cluster Manager | absent | No drift-specific view has been validated. |
| Windows Admin Center (standalone) | absent | No drift-specific view has been validated. |
| Windows Admin Center in the Azure portal | absent | No drift-specific view has been validated. |
| Component / tool log files | absent | The validator and remediation log locations need validation on a supported release. |

`absent` denotes an uncharacterized surface, not proof that no signal exists.
These gaps and the untested commands require maintainer validation before
publication.

## Related documentation

- [Azure Local documentation](https://learn.microsoft.com/en-us/azure/azure-local/)
- [Drift detection for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/manage/drift-detection)
- [PowerShell module-version validation](./Troubleshooting-Test-PowerShell-Module-Version.md)
