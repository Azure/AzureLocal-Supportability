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

Use this guide when a required .NET 10 runtime is missing on an Azure Local node and an update or lifecycle-management component fails to start.

## Table of contents

- [Symptoms](#symptoms)
- [Diagnosis](#diagnosis)
- [Recovery](#recovery)
- [Verification](#verification)
- [Escalation](#escalation)

## Symptoms

- The required x64 .NET 10 runtime is missing from the node.
- `ECEAgent` is not running, or HCI Orchestrator is not online or failed to start.

It was reported that .NET 10 was removed after updating from 10.0.6 to 10.0.15. We investigated and found that there was a known bug in older versions of the .NET installer in which after updating and logging out and back in two the old and new version of the installer would be removed.

To find the exact versions impacted we did internal testing and found that versions of .NET 10.0.10 and below had the issue. These were installed for Azure Local versions from 2604 to 2607 inclusive. You should only see the issue when updating to 2610 or 2611 as we changed how updates were done that expose this bug and will be fixed for 2701.

We have not validated that .NET 8 has the bug but just incase I have included some notes for each step on how to mitigate if you are missing .NET 8 and need it installed.

## Diagnosis

Run in elevated x64 PowerShell on the affected node:

```powershell
$ErrorActionPreference = 'Stop'
$dotnet = Join-Path $env:ProgramW6432 'dotnet\dotnet.exe'
if (Test-Path -LiteralPath $dotnet -PathType Leaf) {
    & $dotnet --list-runtimes
} else {
    Write-Output "x64 .NET host not found: $dotnet"
}
Get-Service -Name 'ECEAgent'
Get-ClusterGroup -Name '*orch*'
```

Confirm whether the component-required `.NETCore.App` or `AspNetCore.App` 10.0 runtime is listed. Record the service status and orchestrator group state and owner; include any failed start or restart error. If the service or cluster group is missing, stop and contact Microsoft Support because this indicates a broader issue.

For .NET 8 you should only see that there is no .NET 8 runtimes installed.

## Recovery

Run the recovery on the impacted nodes. Since all services are down you should not need a maintenance window since .NET does not require a restart and does not impact any services (since they are all failing to start).

`Get-ASArtifactPath` resolves the latest `Microsoft.DotNet10.Runtime.Installer` package. List its executable installers and confirm they are the expected package contents:

For .NET 8 you would use the 'Microsoft.DotNet8.Runtime.Installer' package name.

```powershell
$ErrorActionPreference = 'Stop'
$packagePath = Get-ASArtifactPath -NugetName 'Microsoft.DotNet10.Runtime.Installer' -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace([string]$packagePath) -or
    -not (Test-Path -LiteralPath $packagePath -PathType Container)) {
    throw 'The latest approved runtime package path was not found. Stop and contact Microsoft Support.'
}
$installers = @(Get-ChildItem -LiteralPath $packagePath -Recurse -Filter '*.exe' -File -ErrorAction Stop)
if ($installers.Count -eq 0) {
    throw 'No executable installers were found. Stop and contact Microsoft Support.'
}
$installers | Select-Object FullName, @{ Name = 'ProductVersion'; Expression = { $_.VersionInfo.ProductVersion } }
```

After confirming the installer list, run each executable with `/install /quiet /norestart`:

```powershell
foreach ($installer in $installers) {
    $process = Start-Process -FilePath $installer.FullName `
        -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru -ErrorAction Stop
    if ($process.ExitCode -ne 0) {
        throw "Installer failed or requested a reboot (exit code $($process.ExitCode)). Stop and contact Microsoft Support."
    }
}
```

Expected result: every installer exits with code `0`. Do not reboot or repeatedly retry if an installer fails or requests a reboot; preserve its exit code and contact Microsoft Support.

## Verification

Rerun the Diagnosis commands. Confirm the required x64 runtime is listed and `ECEAgent` and the orchestrator group are healthy. If either component is stopped or offline, start only the affected component using `Start-Service ECEAgent` and `Get-ClusterGroup "*HCI Orchestrator*" | Start-ClusterGroup` . If it does not start, please stop and contact Microsoft Support.

## Escalation

Contact Microsoft Support if the package is unavailable, an installer fails or requests a reboot, a required runtime remains missing, or a component remains unhealthy. Provide the Azure Local solution version, affected node, runtime listing, service and cluster-group status, installer names and exit codes, and any start/restart errors.

For background, see the Microsoft-maintained [ASP.NET Core issue 67128](https://github.com/dotnet/aspnetcore/issues/67128). It is not required to reproduce the issue before restoring a confirmed missing runtime.
