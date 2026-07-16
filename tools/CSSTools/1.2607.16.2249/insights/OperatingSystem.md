# OperatingSystem

This script checks the state of the operating system.

## Windows.System.OpState

This script checks the system's operational state.

| Rule | Synopsis |
| --- | --- |
| Windows.EventLog.System.Bugcheck | This script checks system bugcheck events in the last 7 days. |
| Windows.EventLog.System.UnexpectedReboot | This script checks the system for unexpected reboots in the last 7 days. |
| Windows.ActiveDirectory.GroupPolicy.Corruption | This script checks the header of the Group Policy file to ensure it is not corrupted. |
| Windows.System.Info | Retrieves the OS information details from the local machine. |
| Windows.System.OS.Support | Ensures that the OS version of the host is within the product support lifecycle guidelines |

## Windows.Security.OpState

This script checks the security operational state of the node.

| Rule | Synopsis |
| --- | --- |
| Windows.Security.SecureBoot.State | Checks if Secure Boot is enabled on the local machine. |
| Windows.Security.BitLocker.BootVolume | Checks if BitLocker is enabled on the boot volume (C:\). |

## Windows.RemoteManagement.OpState

This script checks the remote management operational state of the node.

| Rule | Synopsis |
| --- | --- |
| Windows.Security.CredSSP.Configuration | Checks if CredSSP authentication is correctly configured on the local machine. |
| Windows.RemoteManagement.TrustedHosts.Wildcard | Checks whether the WinRM client TrustedHosts list contains a wildcard ('*') entry. |

## AzStackHci.DiagnosticSettings.OsConfig.ConfigurationConsistency

Surfaces the cross-node OS configuration "Consistency Checks" produced by the
    AzStackHci.DiagnosticSettings module as Insights rules.

| Rule | Synopsis |
| --- | --- |
| AzStackHci.DiagnosticSettings.OsConfig.ConsistencyCheck | Maps a single cross-node OS configuration "Consistency Check" (as produced by
    Get-AzStackHciOsConfigSettings) onto an Insights rule result. |
| AzStackHci.DiagnosticSettings.OsConfig.HealthCheck | Maps a single OS configuration "health section" (as produced by Get-AzStackHciOsConfigSettings)
    onto an Insights rule result. |
| AzStackHci.DiagnosticSettings.OsConfig.InstalledProgramsInventory | Surfaces the per-node "Installed Programs" software inventory (as produced by Get-AzStackHciOsConfigSettings)
    as a single INFO Insights rule. |
| AzStackHci.DiagnosticSettings.OsConfig.DriverVersionsInventory | Surfaces the per-node device "Driver Versions" inventory (as produced by Get-AzStackHciOsConfigSettings)
    as a single INFO Insights rule. |


