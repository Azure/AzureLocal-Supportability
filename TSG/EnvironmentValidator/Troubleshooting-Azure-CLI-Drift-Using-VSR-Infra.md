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
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "not-assessed",
    "last_validated": null,
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
| Applicability | Azure CLI core or extension drift; the remediation path requires `Remediate-AzCli` and access to the recipe's installation sources |
| Severity | Warning for the core CLI check; informational for extension checks |
| Execution surface | on-device |
| Validation | CLI inventory diagnostic exercised read-only on an x64 lab node (OS build 26100). Validator detection, remediation, and health-fault clearing have not been exercised for this article. |

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

- Core CLI: `Test Azure-Cli Module Version`, with Warning severity.
- Extension: `Test Azure-Cli Extension <name> Version`, with Informational
  severity, for extensions such as `arcappliance`, `customlocation`,
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

## Contributing factors

The validator's expected and discovered versions identify the mismatch.
A partial installation, interrupted upgrade, or manual upgrade is a possible
contributing factor, but the version mismatch alone does not establish which
operation introduced it. Retain installation errors and recent-change records.

## Preconditions

Before changing the CLI installation:

- Confirm an Azure CLI core or extension failure in the current node's validator
  output and record the expected versions.
- Use a new, elevated Windows PowerShell session on each affected node.
- Do not run remediation concurrently with deployment, an update, another
  installation, or automation that uses `az`.
- Confirm that the recipe's installation sources are reachable. Stop if the
  node cannot obtain the required packages.
- Obtain a maintenance window and a recovery plan approved by Microsoft Support.
  Replacing the CLI can interrupt management or automation operations using it.

## Mitigation details

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
align the installed CLI with the recipe. This article does not provide an
automatic rollback.

```powershell
$driftResult = Remediate-AzCli -Verbose
$driftResult
```

Inspect the returned result for completion or errors, then run
[Verify resolution](#verify-resolution). Stop if execution fails or the final
validator still reports drift. Do not repeatedly reinstall or upgrade `az`
without investigating the failure.

## Rollback and escalation

There is no automatic rollback for CLI remediation in this article. If import
fails, close the session; the installation has not been changed. If remediation
or verification fails, stop state-changing commands and contact Microsoft
Support with the before/after `az version` output, validator results, and
installation errors. Use only the recovery plan agreed before remediation,
not an arbitrary CLI or extension version.

## Verify resolution

**[READ-ONLY]** Repeat both commands under
[Issue validation](#issue-validation) on every affected node. Require:

- The core CLI and extensions match the current recipe.
- The validator returns the relevant checks with successful statuses.
- No Azure CLI core or extension check reports `FAILURE`.

No failure rows are insufficient if relevant checks did not run. Any missing,
unexpected, or failing result means resolution is not verified.

If a drift health fault was also present, check `Get-HealthFault` after the next
scheduled drift-detection run. The on-demand validator verifies the installed
state; it does not prove that a previously raised fault has already cleared.
Retry the update only after the matching checks succeed on all affected nodes.

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
- [PowerShell module-version validation](./Troubleshooting-Test-PowerShell-Module-Version.md)
