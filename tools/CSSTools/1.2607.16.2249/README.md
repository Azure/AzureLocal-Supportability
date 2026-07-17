This article describes the contents of the latest [Microsoft.AzLocal.CSSTools](https://www.powershellgallery.com/packages/Microsoft.AzLocal.CSSTools) module changes. This update includes improvements and fixes for the latest release of Microsoft.AzLocal.CSSTools that is supported to run on Azure Local deployments. 

# Download the update

You can download the latest version of Microsoft.AzLocal.CSSTools by running `Update-Module -Name Microsoft.AzLocal.CSSTools` on each of the Azure Local cluster nodes. After you have downloaded the module, ensure you remove the current version from the runspace by using `Remove-Module` and import the latest version using `Import-Module`.

```powershell
# update the current module directly from PowerShell Gallery
Update-Module -Name Microsoft.AzLocal.CSSTools

# remove the current version from the runspace in case it was already imported prior to update
Remove-Module -Name Microsoft.AzLocal.CSSTools

# load the latest version into the runspace
Import-Module -Name Microsoft.AzLocal.CSSTools
```

# What's new

## Support Insights

The following insight rules are new and run within the existing [ControlPlaneOperations](insights/ControlPlaneOperations.md), [HostNetwork](insights/HostNetwork.md), [HostStorage](insights/HostStorage.md), [KnownIssues](insights/KnownIssues.md), [LifecycleOrchestration](insights/LifecycleOrchestration.md), [OperatingSystem](insights/OperatingSystem.md), and [VirtualMachines](insights/VirtualMachines.md) components. For the full component reference, see [insights](insights/README.md).

| New Rule | Synopsis |
| --- | --- |
| AzStackHci.DiagnosticSettings.AzureConnectionStatus | Reports this Azure Local node's Azure connection state: its cloud registration status (Get-AzureStackHCI), its Arc for Servers agent status (azcmagent), and whether the Arc machine has an Azure Private Link Scope. |
| AzStackHci.DiagnosticSettings.CrlRevocationOffline | Flags certificate revocation (CRL / OCSP) checks that could not be completed because the CA's revocation responder is unreachable from an Azure Local node. |
| AzStackHci.DiagnosticSettings.NetworkConnectivity | Evaluates the results of network connectivity tests to the required Azure Local endpoints. |
| AzStackHci.DiagnosticSettings.OsConfig.ConsistencyCheck | Maps a single cross-node OS configuration "Consistency Check" (as produced by Get-AzStackHciOsConfigSettings) onto an Insights rule result. |
| AzStackHci.DiagnosticSettings.OsConfig.DriverVersionsInventory | Surfaces the per-node device "Driver Versions" inventory (as produced by Get-AzStackHciOsConfigSettings) as a single INFO Insights rule. |
| AzStackHci.DiagnosticSettings.OsConfig.HealthCheck | Maps a single OS configuration "health section" (as produced by Get-AzStackHciOsConfigSettings) onto an Insights rule result. |
| AzStackHci.DiagnosticSettings.OsConfig.InstalledProgramsInventory | Surfaces the per-node "Installed Programs" software inventory (as produced by Get-AzStackHciOsConfigSettings) as a single INFO Insights rule. |
| AzStackHci.DiagnosticSettings.PrivateLinkConfiguration | Evaluates Azure Local Private Link configuration health from the connectivity test results. |
| AzStackHci.DiagnosticSettings.SslInspection | Flags TLS / SSL inspection (HTTPS interception) in front of Azure Local endpoints. |
| AzureLocal.KI.SDN.FailoverClusterApi.Unsigned | Detects a stray Microsoft.NetworkController.FailoverClusterApi.dll left in the HCIOrchestrator profile. |
| AzureLocal.LCM.RegistrationStatus | Detects an invalid or inactive Azure Local subscription/registration status that blocks solution update pre-checks. |
| AzureLocal.Update.AzCliIncompatibleExtensions | Detects unmanaged (incompatible) Az CLI extensions that block solution updates during UpdatePreRequisites. |
| AzureLocal.Update.CAU.MsuHostUpdateBreadcrumb | Checks for a leftover MsuHostUpdate CAU breadcrumb file that prevents update retries on 2604 builds. |
| AzureLocal.Update.OSConfigSecuredCoreEnforcement | Detects the OSConfig SetSecuredCore guest configuration SET document that causes SecuredCore enforcement failures during updates. |
| MocArb.ArbAzCliExtensionVersionFormat | Checks for Az CLI extensions with non-numeric version strings that block the Environment Validator. |
| MocArb.MocHostAgentLogStale | Detects a hung MOC Host Agent (mochostagent) service by checking for stale logs. |
| Windows.Hyperv.VM.MountedISO | Checks whether any virtual machines have an ISO image mounted to a virtual DVD drive. |
| Windows.Network.Dns.ResolveClusterNodes | Validates that all cluster node DNS names can be resolved from a specified DNS server. |
| Windows.Network.VMSwitch.MacSpoofingOnSRIOV | Detects VM network adapters with MAC address spoofing enabled that are connected to an SR-IOV (IOV) enabled VM switch. |
| Windows.RemoteManagement.TrustedHosts.Wildcard | Checks whether the WinRM client TrustedHosts list contains a wildcard ('*') entry. |
| Windows.Security.CredSSP.Configuration | Checks if CredSSP authentication is correctly configured on the local machine. |
| Windows.Storage.VolumeRecommendations.MaxVolumesPerCluster | Checks that the number of volumes in the cluster does not exceed the recommended maximum. |
| Windows.Storage.VolumeRecommendations.MinVolumesPerNode | Checks that the cluster has at least one volume per node. |
| Windows.Storage.VolumeRecommendations.ReserveCapacity | Checks that the storage pool has enough reserve capacity for in-place repairs. |
| Windows.Storage.VolumeRecommendations.VolumeSize | Checks that a volume does not exceed the recommended maximum size. |

## Insight Remediation

As issues are detected within the Insight framework, we can provide remediation guidance to execute `Invoke-AzsSupportInsightRemediation` commands that run validated, signed remediation scripts. We recommend only running these remediation scripts when insights provide guidance to run them. For the full list of remediations, see [remediations](remediations/README.md).

| New Remediation | Synopsis |
| --- | --- |
| [ClearTrustedHostsWildcard](remediations/ClearTrustedHostsWildcard.md) | Removes the wildcard ('*') entry from the WinRM client TrustedHosts list. |
| [RemoveFailoverClusterApiDll](remediations/RemoveFailoverClusterApiDll.md) | Removes the stray Microsoft.NetworkController.FailoverClusterApi.dll from the HCIOrchestrator profile. |
| [RemoveIncompatibleAzCliExtensions](remediations/RemoveIncompatibleAzCliExtensions.md) | Removes unmanaged (incompatible) Az CLI extensions from the current node so a solution update can proceed. |
| [ResetCredSSPConfiguration](remediations/ResetCredSSPConfiguration.md) | Resets CredSSP authentication configuration to the correct state required for Azure Local operations. |

## Core Framework

In addition to code and reliability fixes, the following public functions are new in this release.

- [Invoke-AzsSupportScript](functions/Invoke-AzsSupportScript.md): Invokes a signed AzsSupport script shipped with the Support Tools module. For the scripts it can run, see [scripts](scripts/README.md).
- [Test-AzsSupportSolutionInstalled](functions/Test-AzsSupportSolutionInstalled.md): Determines whether the Azure Local solution is present on the current system, so callers can adapt to plain HCI OS environments.

`Invoke-AzsSupportDiagnosticCheck` has been deprecated. A comprehensive list of all functions can be found under [functions](functions/README.md).

## Detailed Changes

### Insight Framework & Remediation

- Insight remediation telemetry introduced via a new `InsightRemediationEvent`, capturing remediation outcomes.
- Data emitted through the events channel improved for richer diagnostics.
- Support added for shipping signed scripts alongside the Support Tools module.
- CI Pester testing added for the Insight module, including Storage and Windows.Cluster test coverage.
- Fixed handling of a string-array `Component` parameter for remote `Invoke-AzsSupportInsight`.

### New Insights Added

- Integrated the `AzStackHci.DiagnosticSettings` module (0.6.8) as an Insights data source. A new `AzStackHci.DiagnosticSettings.NetworkConnectivity` analyzer in [ControlPlaneOperations](insights/ControlPlaneOperations.md) surfaces required-endpoint connectivity, TLS/SSL inspection, Private Link configuration, certificate-revocation (CRL/OCSP) reachability, and per-node Azure connection state. A new `AzStackHci.DiagnosticSettings.OsConfig.ConfigurationConsistency` analyzer in [OperatingSystem](insights/OperatingSystem.md) surfaces cross-node OS configuration consistency checks and health sections, plus per-node Installed Programs and Driver Versions inventory.
- `AzureLocal.LCM.RegistrationStatus` update subscription and registration precheck.
- Cluster Shared Volume block-redirect scoping corrected.
- MAC spoofing detection on SR-IOV VM switch ports.
- Hyper-V VM mounted-ISO detection.
- Windows.Storage analyzers condensed for clarity and performance.
- OSConfig SecuredCore enforcement failure detection.
- Storage volume recommendations analyzer with four new rules.
- Hung `mochostagent` detection rule.
- Incompatible Az CLI extension and non-numeric Az CLI extension version rules.
- WinRM TrustedHosts wildcard detection.
- Windows.RemoteManagement.OpState analyzer covering CredSSP and WinRM.
- DNS resolution check for cluster nodes.
- Cluster-Aware Updating (CAU) failure insight.
- SDN Network Controller Failover Cluster API unsigned-assembly detection (`AzureLocal.KI.SDN.FailoverClusterApi.Unsigned`) for the KnownIssues component on 2601 and later builds, with a paired [RemoveFailoverClusterApiDll](remediations/RemoveFailoverClusterApiDll.md) remediation to remove the stray file.
- Windows.System.OS.Support 23H2 test elevated to a Failure result.

### Networking

- Fixed an ARB VM VLAN ID validator false positive on SDN / ARC-SDN clusters.
- Removed the `-DnsOnly` parameter from name resolution.
- Updated the set of firewall endpoints probed.

### AKS Arc / MOC / ARB

- Fixed `ArbApplianceStatus` validator false positives and hardened the check.
- Added the MOC version to the `ErrorCode` for `MocNotOnLatestPatch`.
- Added defensive coding when locating ARB control-plane VMs.
- Updated the Support.AksArc module to 1.3.77.
- Fixed AKS Arc analyzer per-test isolation.

### Non-Solution (HCI OS) Support

- The module now detects whether the Azure Local solution is installed during import and operates in a reduced `HCI_OS` mode when it is not, recording the platform state (`HCI_OS` or `HCI_OS_AZLOCAL_SOLUTION`) on the module global.
- Added the [Test-AzsSupportSolutionInstalled](functions/Test-AzsSupportSolutionInstalled.md) function, with an optional `-Terminating` switch, so callers can branch on solution presence or fail fast on plain HCI OS.
- Analyzers now declare a `RequireAzLocalSolution` requirement so solution-only checks are skipped, rather than reported as failures, on plain HCI OS systems.
- Gated the `azcmagent` region probe on agent availability instead of solution-installed state.
- Ensured the OS solution is present before running update-validation checks that depend on it.

### Infrastructure & Modules

- Added a dependency on the `AzStackHci.DiagnosticSettings` module (0.6.8), consuming its structured `-PassThru` connectivity results, OsConfig health/consistency reports, and inventory data, with a non-fatal schema-version guard and race-free per-node detailed report collection on remote nodes.
- Improved loading of the AzStack Disconnected module.
- Introduced a centralized framework for importing and version-checking module dependencies, including a NetworkATC module requirement.
- Added versioning tags and updated the package source.
- Fixed relative path handling in the build pipelines.
- Removed `Add-Type` usage to prevent file locking.
- Added a threat modeling skill and an initial baseline security check.
- Enabled detection of newer support modules.

### Bug Fixes & Misc

- Deprecated `Invoke-AzsSupportDiagnosticCheck`.
- Fixed missing-disk detection on Hyper-V hosts by including VMBUS SCSI adapters.
- Fixed a null-valued expression error in `Get-AzsSupportPhysicalDisk` and related Missing Disks and DiskHealth analyzer failures.
- Fixed `ManagementEndpoint` not being populated from `context.json`.
- Fixed function examples and parameter definitions, and corrected a Pester test that was failing build validation.

---

# Contact Us

If you are encountering an issue, or need assistance, refer to [questions-or-feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback).
