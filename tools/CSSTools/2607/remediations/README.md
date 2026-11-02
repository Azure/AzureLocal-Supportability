# Remediations

This folder documents the signed remediation scripts for the AzStack.Insights framework in the
`Microsoft.AzLocal.CSSTools` module. Remediations are validated, signed scripts that address issues
detected by insights.

> [!IMPORTANT]
> Only run a remediation when an insight explicitly provides guidance to run it. Remediations make
> changes to the system; review each remediation's description, expected impact, and whether a
> maintenance window is recommended before executing it.

## Running a remediation

Install and import the module, then run the remediation with `Invoke-AzsSupportInsightRemediation`:

```powershell
Install-Module -Name Microsoft.AzLocal.CSSTools -Force
Import-Module -Name Microsoft.AzLocal.CSSTools -Force

Invoke-AzsSupportInsightRemediation -ScriptName <RemediationName>
```

Remediations support `-Force` (skip confirmation) and `-SkipEnvironmentCheck`. They run locally on the
node they are invoked on and return a `RemediationObject` describing the outcome.

## Available remediations

| Remediation | Synopsis |
|-------------|----------|
| [ClearTrustedHostsWildcard](./ClearTrustedHostsWildcard.md) | Removes the wildcard ('*') entry from the WinRM client TrustedHosts list. |
| [DisableWindowsUpdate](./DisableWindowsUpdate.md) | Disables automatic Windows Update by configuring the appropriate registry settings under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`. |
| [IncreaseWmiQuotaConfig](./IncreaseWmiQuotaConfig.md) | Increases WMI Provider Host quota configuration to support more memory and handles for WMI providers. |
| [RemovedFailedUpdateEceActionPlans](./RemovedFailedUpdateEceActionPlans.md) | Removes failed ECE action plans from the system. |
| [RemoveFailoverClusterApiDll](./RemoveFailoverClusterApiDll.md) | Removes the stray Microsoft.NetworkController.FailoverClusterApi.dll from the HCIOrchestrator profile. |
| [RemoveHealthCheckFilesForUpdates](./RemoveHealthCheckFilesForUpdates.md) | Removes health check files created for updates from the system. |
| [RemoveIncompatibleAzCliExtensions](./RemoveIncompatibleAzCliExtensions.md) | Removes unmanaged (incompatible) Az CLI extensions from the current node so a solution update can proceed. |
| [ResetCredSSPConfiguration](./ResetCredSSPConfiguration.md) | Resets CredSSP authentication configuration to the correct state required for Azure Local operations. |
| [UnlockAzureLocalAccounts](./UnlockAzureLocalAccounts.md) | Remediates a specified Azure Local account by ensuring it exists, is not disabled, is a member of the correct groups, and is not locked. |
