<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local lifecycle management using .NET 10"],
  "detector": {
    "type": "command",
    "signal": "dotnet.exe --list-runtimes; Get-Service ECEAgent; Get-ClusterGroup *orch*"
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

From elevated x64 PowerShell on a cluster node, run this **[READ-ONLY]** check to inspect each node:

```powershell
$ErrorActionPreference = 'Stop'
$nodes = (Get-ClusterNode).Name
$impacted_nodes = $()
foreach ($node in $nodes) {
    try {
        $impacted = Invoke-Command -ComputerName $node -ScriptBlock {
            $ErrorActionPreference = 'Stop'
            Write-Host "`nChecking node: $env:COMPUTERNAME"
            $foundIssue = $false
            $dotnet = Join-Path $env:ProgramW6432 'dotnet\dotnet.exe'
            $dotnet_exists = Test-Path -LiteralPath $dotnet -PathType Leaf
            if (!$dotnet_exists) {
                Write-Output "dotnet.exe is missing; issue detected on $env:COMPUTERNAME."
                $foundIssue = $true
            }

            $runtimes = @(& $dotnet --list-runtimes)
            if ($dotnet_exists -and -not ($runtimes -match '\s10\.0\.')) {
                Write-Output "Required .NET 10 runtime is missing; issue detected on $env:COMPUTERNAME."
                $foundIssue = $true
            }

            $service = Get-Service -Name 'ECEAgent'
            if ($service.Status -ne 'Running') {
                Write-Output "ECEAgent is $($service.Status) on $env:COMPUTERNAME; node could be impacted."
                $foundIssue = $true
            }

            if ($foundIssue) {
                Write-Host "Issues found on node $env:COMPUTERNAME"
            } else {
                Write-Host "No Issues found on node $env:COMPUTERNAME"
            }

            return $foundIssue
        }

        if ($impacted) {
            $impacted_nodes += @($node)
        }
    } catch {
        Write-Warning "Unable to assess node '$node': $($_.Exception.Message)"
    }
}

$hciOrc = Get-ClusterGroup -Name '*HCI Orchestrator*'
if ($hciOrc.State -ne 'Online') {
    Write-Output "HCI Orchestrator '$($hciOrc.Name)' on owner '$($hciOrc.OwnerNode)' is $($hciOrc.State); cluster could be impacted."
}
```

Review the output under each node name. A missing .NET 10 runtime confirms the runtime-loss issue but does not prove which installer caused it. A stopped `ECEAgent` or offline HCI Orchestrator means the node or cluster could be impacted; neither alone confirms runtime loss. A successful remote check adds the node to `$impacted_nodes` when it detects a missing .NET 10 runtime or a stopped `ECEAgent`; treat this as a candidate list, not an installer target list. If the x64 host is missing, the script still attempts to run it, which can fail before the node is added. The script also does not check `$LASTEXITCODE` after `--list-runtimes`, so verify the inventory command succeeds before relying on its result. The orchestrator query is cluster-wide and is not expected to show a running group on every node. If the `ECEAgent` service or orchestrator group is missing, contact Microsoft Support because this indicates a broader issue.

For .NET 8 you should only see that there is no .NET 8 runtimes installed.

## Recovery

The package-inspection and installer blocks run remotely on every node in `$impacted_nodes`; the diagnosis itself checks every cluster node and is read-only. Before running the installer block, review this candidate list and retain only nodes where the required .NET runtime is confirmed missing. A stopped `ECEAgent` alone means the node could be impacted, not that the runtime is missing. The installer block runs on every node left in the list, so do not include candidates without confirmed runtime absence. Installing the runtime does not require a restart.

`Get-ASArtifactPath` resolves the latest `Microsoft.DotNet10.Runtime.Installer` package. List its executable installers and confirm they are the expected package contents:

For .NET 8 you would use the 'Microsoft.DotNet8.Runtime.Installer' package name.

```powershell
foreach ($node in $impacted_nodes) {
    Invoke-Command -ComputerName $node -ScriptBlock {
        Write-Host "Inspecting the runtime package on $env:COMPUTERNAME"

        $ErrorActionPreference = 'Stop'

        $packagePath = Get-ASArtifactPath -NugetName 'Microsoft.DotNet10.Runtime.Installer' -ErrorAction Stop
        if (!$packagePath) {
            Write-Warning "The package 'Microsoft.DotNet10.Runtime.Installer' was not found on $($env:COMPUTERNAME). Stop and contact Microsoft Support."
            return
        }

        $installers = @(Get-ChildItem -LiteralPath $packagePath -Recurse -Filter '*.exe' -File -ErrorAction Stop)
        if ($installers.Count -eq 0) {
            Write-Warning "No executable installers were found on $($env:COMPUTERNAME). Stop and contact Microsoft Support."
            return
        }

        $installers | Select-Object FullName, @{ Name = 'ProductVersion'; Expression = { $_.VersionInfo.ProductVersion } }
    }
}
```

After confirming the installer list, run each executable with `/install /quiet /norestart`:

```powershell
foreach ($node in $impacted_nodes) {
    Invoke-Command -ComputerName $node -ScriptBlock {
        Write-Host "Installing the approved runtime on $env:COMPUTERNAME"

        $packagePath = Get-ASArtifactPath -NugetName 'Microsoft.DotNet10.Runtime.Installer' -ErrorAction Stop
        $installers = @(Get-ChildItem -LiteralPath $packagePath -Recurse -Filter '*.exe' -File -ErrorAction Stop)

        foreach ($installer in $installers) {
            $process = Start-Process -FilePath $installer.FullName -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                Write-Warning "Installer failed or requested a reboot (exit code $($process.ExitCode)). Stop and contact Microsoft Support."
                return
            }
        }
    }
}
```

Expected result: every installer exits with code `0`. Do not reboot or repeatedly retry if an installer fails or requests a reboot; preserve its exit code and contact Microsoft Support.

## Verification

Rerun the Diagnosis commands. Confirm the required x64 runtime is listed and `ECEAgent` and the orchestrator group are healthy. If either component is stopped or offline, start only the affected component using `Start-Service ECEAgent` and `Get-ClusterGroup "*HCI Orchestrator*" | Start-ClusterGroup` . If it does not start, please stop and contact Microsoft Support.

## Escalation

Contact Microsoft Support if the package is unavailable, an installer fails or requests a reboot, a required runtime remains missing, or a component remains unhealthy. Provide the Azure Local solution version, affected node, runtime listing, service and cluster-group status, installer names and exit codes, and any start/restart errors.

For background, see the Microsoft-maintained [ASP.NET Core issue 67128](https://github.com/dotnet/aspnetcore/issues/67128). It is not required to reproduce the issue before restoring a confirmed missing runtime.
