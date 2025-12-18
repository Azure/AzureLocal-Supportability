# VM Startup Failure Due to Excessive Memory Consumption by MonitoringPlatformAgent (AzureEMP Service)

## Overview

Virtual Machines (VMs) may fail to start on all cluster nodes in Azure Local environments due to insufficient local memory resources. This is caused by excessive memory consumption by the MonitoringPlatformAgent (AzureEMP service), which leaves inadequate memory for VM startup operations.

## Symptoms

- VMs fail to start on all cluster nodes.
- Error messages indicating insufficient memory resources.
- High memory usage observed for the MonitoringPlatformAgent (AzureEMP service) process.
- VM creation and startup operations are blocked until memory usage is reduced.

## Issue Validation

To confirm that the scenario matches this known issue, verify the following behaviors:

### Failure/Errors Seen on Portal/CLI

- VM creation or startup fails with errors related to insufficient memory.
- Monitoring tools or task manager show high memory usage for the AzureEMP service.

### PowerShell Script

Use the following PowerShell commands to detect high memory usage and confirm the presence of the AzureEMP service:

```powershell
# Check memory usage for AzureEMP service
Get-Process -Name "MonitoringPlatformAgent" | Select-Object Name, WorkingSet

# Check status of AzureEMP service
Get-Service "AzureEMP"
```

## Cause

The root cause is excessive memory consumption by the MonitoringPlatformAgent (AzureEMP service), which leads to insufficient memory for VM startup. This is categorized as a capacity issue and is not attributed to any recent changes. Further investigation is required to determine the underlying cause and to implement resource constraints for the AzureEMP service.

## Mitigation Details

To mitigate the issue and restore VM creation capability, disable the metrics pipeline and stop the AzureEMP service using the following steps:

1. Disable the scheduled metrics pipeline task:
    ```powershell
    Get-ScheduledTask -taskpath "\Microsoft\AzureStack\Observability\" -taskname "Enable-MetricsPipelineAndDisableFromHealthAgent" | Disable-ScheduledTask
    ```

2. Stop the AzureEMP service:
    ```powershell
    Get-Service "AzureEMP" | Stop-Service
    ```

3. Delete the AzureEMP service:
    ```powershell
    sc.exe delete "AzureEMP"
    ```

After performing these steps, CPU and memory usage should decrease, allowing VM creation and startup to proceed.


If you wish to switch back to the old metrics pipeline in order to get metrics to monitor your stamp run the following:

```powershell
$svc = Get-WmiObject Win32_Service -Filter "Name='healthagent'"
$exe  = if ($svc.PathName -match '^\s*"(.*?)"') { $Matches[1] } else { ($svc.PathName -split '\s+', 2)[0] }
$configPath = Join-Path (split-path $exe -Parent) "config.json"
$config = get-content -path $configpath -raw | convertFrom-Json

if ($config -and $config.PrometheusPlugin -and $config.PrometheusPlugin.EnableAzureStackHciStandardMetrics -ne $true) 
{
    $service = Get-Service -Name HealthAgent -ErrorAction SilentlyContinue
    $service | stop-service

    $config.PrometheusPlugin.EnableAzureStackHciStandardMetrics = $true
    $config | ConvertTo-Json -Depth 100 | Out-File $configPath -ErrorAction Stop
    $service | Start-Service
    Write-Verbose "EnableAzureStackHciStandardMetrics is now enabled." -Verbose
}else {
    Write-Verbose "EnableAzureStackHciStandardMetrics is already enabled." -Verbose
    return
}

```
---

### Reference

1. [ICM 721487739: [Azure Local][B:#.####.#.##][O: ][C: ][AzureReg: ] VM failing to start](https://portal.microsofticm.com/imp/v3/incidents/details/721487739) – Incident summary and mitigation steps for VM startup failure due to AzureEMP service memory consumption.

---