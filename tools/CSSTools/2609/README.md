This article describes the Microsoft.AzLocal.CSSTools **2609 release train**, including its build and revision updates, supported to run on Azure Local deployments. The latest revision is [1.2609.30.2](https://www.powershellgallery.com/packages/Microsoft.AzLocal.CSSTools/1.2609.30.2).

# Download the update

Run `Update-Module` on each Azure Local cluster node. After the update is installed, remove any version already loaded in the current runspace and import the updated module.

```powershell
Update-Module -Name Microsoft.AzLocal.CSSTools
Remove-Module -Name Microsoft.AzLocal.CSSTools
Import-Module -Name Microsoft.AzLocal.CSSTools
```

# Navigation

| Reference | Summary |
| --- | --- |
| [Functions](functions/README.md) | Public module functions, including their parameters, usage, and examples. |
| [Insights](insights/README.md) | Insight components, analyzers, and rules used to assess Azure Local systems. |
| [Remediations](remediations/README.md) | Signed remediation scripts that address issues detected by insights. |
| [Scripts](scripts/README.md) | Signed support scripts for Microsoft CSS or Engineering-led support scenarios. |

# What's new

## 1.2609.30.2

Revision 1.2609.30.2 includes the following changes since 1.2609.30.1.

- Added the `AzureLocal.KI.SmbServer.EventLogPublisher` rule to the [Known Issues](insights/KnownIssues.md) checks for Azure Local 2601 through 2610, plus the opt-in [SetSmbServerEventLogPublisher](remediations/SetSmbServerEventLogPublisher.md) remediation for 24H2. The remediation applies or reverts the SMBServer crash workaround on the explicitly selected node, verifies the registry value, and records the result. It changes SMB-Server ETW tracing; an operator must reboot the node for the change to take effect.
- Contained unexpected WMI query and command-loading errors within the WMI timeout rule so they return `UNKNOWN` without interrupting the calling analyzer. Actual CIM timeout failures remain `FAILURE` with query-specific guidance.
- Corrected missing-disk handling in the PhysicalDisk analyzer: no non-primordial storage pool makes only the missing-disk rule `NOT_APPLICABLE`; empty PNP inventory or collection failures make that rule `UNKNOWN` without invalidating the other disk evaluations. See [Get-AzsSupportStorageMissingDisks](functions/Get-AzsSupportStorageMissingDisks.md).
- Isolated remote Insight runs in dedicated PowerShell sessions with a 15-minute idle timeout and cleanup of their jobs and sessions when the run exits, including error paths. [Invoke-AzsSupportCommand](functions/Invoke-AzsSupportCommand.md) can now use explicitly supplied sessions without creating or reusing other cached sessions.

## 1.2609.30.1

Revision 1.2609.30.1 is the initial release in the 2609 train and includes the following changes.

### Core Framework

No new public functions were added in this release.

`Set-AzsSupportPhysicalDiskIndicator` is now deprecated. Use the native storage cmdlets for physical disk indicator operations. A comprehensive list of public commands is available under [functions](functions/README.md).

### Detailed Changes

#### Insight Framework & Remediation

- Added the structured HTML report experience to single-node Insight runs so local and cluster-wide executions now present findings consistently.
- Preserved usable node results when another node writes errors or fails collection, while retaining the failed node diagnostics in the final report.
- Updated DiagnosticSettings integration to version 0.7.1 with clearer connectivity evidence, partial-result handling, OS configuration collection timing, and simplified assessment rendering.
- Expanded remediation reference content with operator prerequisites, impact details, supported-version guidance, and examples; remediation telemetry now records the `Force` and `SkipEnvironmentCheck` values used for each run.

#### New Insights Added

- Added `Windows.Security.ApplicationControl.PolicyMode` under the `OperatingSystem` component's `Windows.Security.OpState` analyzer to verify that Application Control is enforced on each Azure Local node.
- Added `Windows.Storage.VirtualDisk.ChildSpaceRedundancy` under the `HostStorage` component's `Windows.Storage.VirtualDisk` analyzer to detect child storage spaces whose resiliency does not match the parent virtual disk.

#### Networking

- Corrected RDMA validation for converged Network ATC deployments by mapping vSMB interfaces to the intended physical adapters and honoring the configured intent topology.
- Limited DCBX Willing evaluation to RDMA-enabled Network ATC adapters, documented the associated corrective action, and kept intentionally skipped checks from degrading analyzer health.
- Grouped RDMA and DCBX evidence into stable, structured properties for report rendering and downstream processing.
- Expanded host network data collection with an allowlisted ECE desired-state projection and a collection-completeness artifact that distinguishes present, empty, missing, unreadable, and failed outputs.

#### AKS Arc / MOC / ARB

- Updated the bundled Support.AksArc module to 1.3.144.
- Improved Azure Resource Bridge target discovery diagnostics and kept empty discovery results non-terminating on environments where the target is not present.
- Preserved the original MOC configuration retrieval failure and now emits a typed timeout when the operation exceeds its wall-clock limit.

#### Infrastructure & Modules

- Updated bundled diagnostics dependencies, including SdnDiagnostics 4.2609.24.2019 and AzStackHci.DiagnosticSettings 0.7.1.
- Prevented runtime installation of unmanaged Azure CLI extensions and centralized failure handling for the managed CLI context.
- Improved .NET SDK discovery and initialization for repository builds, and corrected generated build versions so single-digit minutes are zero-padded.
- Deprecated `Set-AzsSupportPhysicalDiskIndicator` and refreshed its public guidance to direct callers to supported replacement commands.

#### Bug Fixes & Misc

- Suppressed expected `UpdateAvailable` storage health faults so an available solution update no longer appears as an actionable storage warning.
- Distinguished missing registration objects from query failures and corrected registration failure-rate calculations.
- Fixed duplicate `ErrorAction` binding in the process-state rule and corrected invalid Insight status references that could interrupt evaluation.
- Treated access-denied ghost CSV enumeration as an indeterminate result, added diagnostic tracing, and reduced unreferenced ghost mount points to warnings until removal is explicitly requested.
- Fixed generated examples and function-help rendering, including the infrastructure-host example and fenced multi-line examples.

---

# Contact Us

For questions or assistance, see [questions or feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback).
