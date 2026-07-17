This article describes the contents of the [Microsoft.AzLocal.CSSTools 1.2605.5.1611](https://www.powershellgallery.com/packages/Microsoft.AzLocal.CSSTools/1.2605.5.1611) module changes. This update includes improvements and fixes for the latest release of Microsoft.AzLocal.CSSTools that is supported to run on Azure Local deployments.

# Download the update
You can download the latest version of Microsoft.AzLocal.CSSTools by running `Update-Module -Name Microsoft.AzLocal.CSSTools` on each of the Azure Local cluster nodes. After you have downloaded the module, ensure you remove the current version from runspace by using `Remove-Module` and import the latest version using `Import-Module`.

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

We have introduced three new components called `ControlPlaneOperations`, `KnownIssues`, and `LifecycleOrchestration` for our Support Module Insights. In addition, we have added several new analyzers and rules. A complete list of the tests being performed can be found by reviewing the Components below.

| Component | Synopsis |
| --- | --- |
| [ControlPlaneOperations](/tools/CSSTools/1.2605.5.1611/insights/ControlPlaneOperations.md) | Checks the state of the Azure Local Control Plane services, such as Microsoft Onprem Cloud, Azure Resource Bridge, Arc Services, and AKS Arc. |
| [HostCompute](/tools/CSSTools/1.2605.5.1611/insights/HostCompute.md) | Checks the state of the host compute, including cluster node state. |
| [HostNetwork](/tools/CSSTools/1.2605.5.1611/insights/HostNetwork.md) | Checks the state of the host network, including Network ATC intent operational state. |
| [HostStorage](/tools/CSSTools/1.2605.5.1611/insights/HostStorage.md) | Checks the state of the host storage, including Cluster Shared Volumes. |
| [KnownIssues](/tools/CSSTools/1.2605.5.1611/insights/KnownIssues.md) | Checks for common known issues on the Azure Local environment. The analyzers executed depend on the installed version of Azure Local. |
| [LifecycleOrchestration](/tools/CSSTools/1.2605.5.1611/insights/LifecycleOrchestration.md) | Checks the state of the Azure Lifecycle and Orchestration services such as ECE, LCM, and Update. |
| [OperatingSystem](/tools/CSSTools/1.2605.5.1611/insights/OperatingSystem.md) | Checks the state of the operating system. |
| [VirtualMachines](/tools/CSSTools/1.2605.5.1611/insights/VirtualMachines.md) | Checks the state of virtual machines, including VM network adapter configuration. |


## Insight Remediation
With this most recent release, we have now expanded to shipping signed remediation scripts as code. As issues are detected within the Insight framework, we can provide remediation guidance to execute `Invoke-AzsSupportInsightRemediation` commands to run validated signed remediation scripts.

As we continue to onboard more diagnostics and issue checks, we will continue to expand these remediation scripts that can be used. We recommend to only run these remediation scripts if insights provide guidance to run them.

| Remediation | Synopsis |
| --- | --- |
| [DisableWindowsUpdate](/tools/CSSTools/1.2605.5.1611/remediations/DisableWindowsUpdate.md) | Disables automatic Windows Update by configuring the appropriate registry settings under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`. |
| [IncreaseWmiQuotaConfig](/tools/CSSTools/1.2605.5.1611/remediations/IncreaseWmiQuotaConfig.md) | Increases the WMI Provider Host quota configuration to support more memory and handles for WMI providers. |
| [RemovedFailedUpdateEceActionPlans](/tools/CSSTools/1.2605.5.1611/remediations/RemovedFailedUpdateEceActionPlans.md) | Removes failed `MAS Update` ECE action plans from the system. |
| [RemoveHealthCheckFilesForUpdates](/tools/CSSTools/1.2605.5.1611/remediations/RemoveHealthCheckFilesForUpdates.md) | Removes health check files created for updates from the system. |
| [UnlockAzureLocalAccounts](/tools/CSSTools/1.2605.5.1611/remediations/UnlockAzureLocalAccounts.md) | Remediates a specified Azure Local account by ensuring it exists, is not disabled, is a member of the correct groups, and is not locked. |

## Core Framework
In addition to some code and reliability fixes, we have added some new functions.
- [Get-AzsSupportEceManagementClusterName](/tools/CSSTools/1.2605.5.1611/functions/Get-AzsSupportEceManagementClusterName.md): Retrieves the name of the management cluster in the ECE infrastructure.
- [Invoke-AzsSupportInsightRemediation](/tools/CSSTools/1.2605.5.1611/functions/Invoke-AzsSupportInsightRemediation.md): Executes a specified remediation script for Azure Stack Insights.
- [Show-AzsSupportEnvironmentValidatorSummary](/tools/CSSTools/1.2605.5.1611/functions/Show-AzsSupportEnvironmentValidatorSummary.md): Retrieves and displays a comprehensive summary of environment validator results from the event log.

A comprehensive list of all our functions can be found under [functions](/tools/CSSTools/1.2605.5.1611/functions).


## Detailed Changes

### Insight Framework & Remediation

- Insight Remediation Framework introduced, with support for standardized remediation formatting.
- NOT_APPLICABLE status added to the insight framework.
- Component array support enabled for insights.
- **`-SkipHtmlReport`** switch added to `Invoke-AzsSupportInsight`.
- HTML report generation updated to handle array remediations and improved Cluster/Node HTML report.
- Environment variable scope fixed for remote runspaces.

### New Insights Added

- SDN Failover Cluster NC health tests
- SDN Server health tests
- Merged Cluster Networks network insight
- Excessive RSA MachineKeys insight
- Automatic Windows Updates on hosts
- Secure Boot and BitLocker security insights
- Storage insights continually improved
- 16 new MOC/ARB insights based on real-world customer cases
- SR-IOV consistency rule added
- NetAdapter name mismatch with VMNetworkAdapter insight
- ARB VM VLAN ID validation
- SCVMM cert check

### Networking

- SdnDiagnostics module to 4.2604.29.191
- Empty storage intent VLAN ID now warns; empty VLAN ID rule level changed to FAILURE.
- Net adapter exclusion methods expanded.

### AKS Arc / MOC / ARB

- Support.AksArc module updated to 1.3.28.
- Insights tests expanded for MocArb and Arc Services.
- ARB appliance status check skipped on disconnected clusters.
- Bug fix in "Validate ARB TCP Port 6443 Connectivity" MOC validator.

### Infrastructure & Modules

- AzLocal Disconnected module framework integrated.
- Support module now installs automatically to remote hosts.
- LCM Deploy User method simplified.

### Bug Fixes & Misc

- Terminating errors causing console crash resolved.
- PowerShell treating Insight ID as String instead of GUID fixed.
- Various code fixes in the 2604 release.
- Function typos and formatting problems fixed.

---

# Contact Us
If you are encountering an issue, or need assistance, refer to [questions-or-feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback).
