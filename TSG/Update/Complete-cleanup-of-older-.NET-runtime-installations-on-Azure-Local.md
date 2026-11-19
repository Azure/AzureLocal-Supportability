# Complete cleanup of older .NET runtime installations on Azure Local

## Summary

Older .NET runtime files can remain on Azure Local nodes when post-update cleanup is pending. Completing a restart might not be sufficient: an administrator sign-in may be required to trigger the pending cleanup action.

The preferred resolution is to sign in interactively to each affected node using an administrator account. Remote RunOnce processing is an alternative if you have a large number of clusters or nodes. A final option of last resort is to delete the files manually, or through script.

## Symptoms

- Older .NET runtime patch-version folders remain after an update and the required restart.
- Multiple patch versions of the same runtime are present.

The presence of multiple versions alone does not establish that cleanup is required. Applications can require different .NET versions to be installed side by side.

## Before you begin

- Confirm that this issue applies to your Azure Local release.
- Complete the update and any required restart using the supported Azure Local maintenance procedure.
- Use an account with administrator rights on each affected node.
- Record the installed runtime versions before making changes.
- For remote execution, use your organization's approved PowerShell remoting configuration and administrative access.

> **Important:** Do not remove an older major version solely because a newer major version is installed. Applications and platform components may still require it.

## Option 1: Sign in as an administrator

1. Identify each affected Azure Local node.
2. Sign in interactively to the node using an account that is a member of the local Administrators group.
3. Allow the pending RunOnce cleanup action to execute.
4. Verify that the intended obsolete patch-version artifacts have been removed and required runtimes remain installed.
5. Validate the health of affected services and applications.

Repeat these steps on each affected node. Signing in to one node does not process RunOnce on other nodes.

## Option 2: Process RunOnce remotely

For environments with many nodes, interactive sign-in to every node may be impractical. The following procedure invokes the 64-bit RunOnce executable and, when present, the 32-bit executable through PowerShell remoting. This is equivalent to logging in as an administrator.

> **Caution:** RunOnce processing is not limited to .NET cleanup. Other eligible pending RunOnce actions may also execute. User-specific actions run in the remote session's account context, which may differ from an interactive sign-in.
>
> Review pending actions and their impact before proceeding. Validate the procedure on one representative node before considering a wider rollout.

Replace the example names with your approved target nodes:

```powershell
$servers = @('Node01', 'Node02')

Invoke-Command -ComputerName $servers -ScriptBlock {
    # Process eligible RunOnce actions using the 64-bit executable.
    & "$env:SystemRoot\System32\runonce.exe" /Explorer

    # Process eligible RunOnce actions using the 32-bit executable, if present.
    $runOnce32 = "$env:SystemRoot\SysWOW64\runonce.exe"

    if (Test-Path -LiteralPath $runOnce32 -PathType Leaf) {
        & $runOnce32 /Explorer
    }
}
```

Command completion alone does not establish that .NET cleanup succeeded. Verify the runtime inventory and remaining artifacts on every target node.

## Option 3: Manually remove obsolete runtime folders (last resort)

Use manual removal only after the exact obsolete versions have been reviewed and confirmed safe to remove. For installer-managed installations, deleting folders is not a general substitute for uninstalling .NET.

The shared-runtime location is:

```text
C:\Program Files\dotnet\shared\Microsoft.NETCore.App\<Version>
C:\Program Files\dotnet\shared\Microsoft.AspNetCore.App\<Version>
C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\<Version>
```

If you know the exact version that is impacting you then you can use this to find the machines that are impacted. In addition, there is a single line that you can uncomment if you want to have the script do the cleanup. I would first do this with the line commented out and once you feel confident then you can run it with the line uncommented. Please read the paragraph after the script to understand what you should do before you delete to ensure you do not delete the wrong thing.

```powershell
$version = "<Exact version you want to check. example: 10.0.15>" 
# Replace these
$servers = @("ServerA", "ServerB") 

[string[]]$folders = @(
    "C:\Program Files\dotnet\shared\Microsoft.NETCore.App\$($version)",
    "C:\Program Files\dotnet\shared\Microsoft.AspNetCore.App\$($version)",
    "C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\$($version)"
)

Invoke-Command -ComputerName $servers -ScriptBlock {
    param([string[]]$folders)
        Write-Verbose "Checking folders on $($env:COMPUTERNAME) ; Folders to check: $($folders -join ', ')" -Verbose
        foreach($folder in $folders) {
            if (Test-Path $folder) {
                Write-Verbose "$($env:COMPUTERNAME) is impacted found folder: $($folder)" -Verbose

                # IF YOU ARE VERY CONFIDENT YOU CAN UNCOMMENT OUT THE FOLLOWING LINE TO DO THE CLEANUP
                # Remove-Item $folder -Recurse -Force
            }
        }
} -ArgumentList @(,$folders)
```

Before removing a version folder:

1. Confirm that a newer patch is installed within the same major/minor version line, runtime family, and architecture.
2. Confirm that applications and platform components no longer require the exact older version, including applications configured not to roll forward.
3. Confirm that the runtime is not currently in use.
4. Follow the approved maintenance and recovery procedure.
5. Remove only the specific obsolete version folder that has been approved for removal.
6. Complete the verification steps in this article.

Do not:

- Remove an entire runtime-family directory.
- Remove an older major version merely because a newer major version exists.
- Delete SDKs, host components, or unrelated .NET files.
- Force deletion of files that remain in use.

An automated deletion script is intentionally not provided. Removal requires environment-specific dependency checks; identifying an older version does not establish that it is safe to delete.

If there is uncertainty about a version or its dependencies, contact Microsoft Support before removing it.

## Verify installed runtimes

Where the relevant .NET host is installed, collect its runtime inventory:

```powershell
dotnet --list-runtimes
```

Record the runtime family, version, and installation path. Check each relevant architecture and installation root; a single invocation might not describe every .NET installation on the node.

### Collect inventory remotely

The following example collects runtime information from the default 64-bit installation. It does not perform cleanup.

```powershell
$servers = @('Node01', 'Node02')

$inventory = Invoke-Command -ComputerName $servers -ScriptBlock {
    $dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'

    if (-not (Test-Path -LiteralPath $dotnet -PathType Leaf)) {
        throw 'The default 64-bit .NET host was not found. Check the installation path and architecture.'
    }

    $runtimeList = & $dotnet --list-runtimes

    if ($LASTEXITCODE -ne 0) {
        throw ".NET runtime inventory failed with exit code $LASTEXITCODE."
    }

    foreach ($line in $runtimeList) {
        [pscustomobject]@{
            Node    = $env:COMPUTERNAME
            Runtime = $line
        }
    }
}

$inventory | Select-Object Node, Runtime
```

Review errors for each node. Missing output or a connection failure is not evidence that a runtime is absent or that cleanup succeeded.

To filter successfully collected results for an exact version:

```powershell
$versionToCheck = '8.0.12'
$versionPattern = '^\S+\s+' + [regex]::Escape($versionToCheck) + '\s+\['

$inventory |
    Where-Object { $_.Runtime -match $versionPattern } |
    Select-Object Node, Runtime
```

This filter identifies matching entries only within the inventory successfully collected. It does not inspect other architectures or installation roots.

## Which versions should remain?

Evaluate each runtime family, architecture, and major/minor version line separately. For example, evaluate `8.0.x` patch versions separately from `10.0.x`.

An older patch is a cleanup candidate only when a replacement patch is installed and the older patch is confirmed no longer required. Applications configured to require an exact version need additional review.

The following examples are illustrative, not a list of affected versions:

| Versions in the same runtime family and architecture | Potential cleanup candidate, subject to dependency review | Retain |
|---|---|---|
| `10.0.14`, `10.0.15`, `8.0.32` | `10.0.14` | `10.0.15`, `8.0.32` |
| `8.0.32`, `10.0.15` | None based on this comparison | Both |
| `9.0.10`, `10.0.15` | None based on this comparison | Both |

**Do not remove .NET 8 or .NET 9 solely because .NET 10 is installed.**

Retaining a required major version does not remove the need to keep it on an appropriate supported and serviced release.

## Manual removal

If deferred cleanup does not complete, contact Microsoft Support before manually removing runtime folders.

Do not:

- Remove an entire runtime-family directory.
- Remove a major version merely because a newer major version exists.
- Delete SDKs, host components, or unrelated .NET files.
- Force deletion of files that remain in use.

For installer-managed installations, deleting folders is not a general substitute for the appropriate supported uninstall procedure.

## Verify cleanup

After attempting cleanup:

1. Compare the runtime inventory and remaining version folders with the pre-cleanup record.
2. Confirm that only the intended obsolete patch versions were removed.
3. Confirm that required runtimes remain installed.
4. Validate the health of affected services and applications.

## If cleanup does not complete

Collect the following for Microsoft Support:

- Azure Local release and update version.
- Affected node names.
- Runtime inventories before and after the attempt.
- Relevant remaining runtime-folder paths.
- Whether the update and required restart completed.
- Whether an interactive administrator sign-in occurred on each node.
- Which cleanup method was attempted.
- Command output, errors, and relevant installer logs.

Share diagnostic information through your approved support channel.

## References

- [Run and RunOnce registry keys](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys)
- [Remove the .NET runtime and SDK](https://learn.microsoft.com/en-us/dotnet/core/install/remove-runtime-sdk-versions)
