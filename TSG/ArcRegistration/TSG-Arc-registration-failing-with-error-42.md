<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {"type": "manual", "signal": "Bootstrap Arc registration error 42"}
}
-->

# Troubleshoot Azure Arc registration failing with exit code 42

## Table of contents

- [Symptoms](#symptoms)
- [Error](#error)
- [Potential causes](#potential-causes)
- [1. Az.Accounts version on the system is incorrect](#1-azaccounts-version-on-the-system-is-incorrect)
- [2. ARM access token is expired](#2-arm-access-token-is-expired)
- [3. ARM access token is passed incorrectly](#3-arm-access-token-is-passed-incorrectly)
- [4. Permissions, policy, or quota (HTTP 403 or a policy or quota error)](#4-permissions-policy-or-quota-http-403-or-a-policy-or-quota-error)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)
- [Validation status of this article](#validation-status-of-this-article)
- [Revision history](#revision-history)

## Symptoms
Registering an Azure Local machine with Azure Arc (`Invoke-AzStackHciArcInitialization`) fails with exit code 42.

**Severity:** High. New-node registration blocks deployment or adding that node.
This error alone does not establish an outage on existing nodes.

## Error

```text
Bootstrap reported error: A ArcAgentConnectionException error occurred with the message: 'AZCMAgent command failed with error:  >> exitcode: 42. Additional Info: See https://aka.ms/arc/azcmerror'
```

The quoted `exitcode: 42` is the Azure Connected Machine agent process exit
code, which the agent documents as "Failed to create Azure resource" with the
remediation "Check subscription permissions and resource quota". Its
corresponding `AZCM0042` error means that creation of the Azure Arc-enabled
server resource failed, not that Az.Accounts is necessarily wrong.
Read the accompanying error before choosing a fix; permissions and resource
creation failures also require investigation
([agent exit codes](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard#agent-exit-codes)).

When Azure rejects the access token itself, `azcmagent.log` shows these lines
together for the failed attempt:

```text
AZCM0042: Failed to Create Resource
get resource failed with status code 401
```

A 401 points to the token: expired, issued for a different tenant, or not a
plain-text ARM token. Passing an unconverted Az.Accounts 5.x token produces this
pattern, because the registration command receives the text
`System.Security.SecureString` instead of the token. A 403, a
`RequestDisallowedByPolicy` code, or a quota error code points to permissions,
policy, or quota instead; see
[cause 4](#4-permissions-policy-or-quota-http-403-or-a-policy-or-quota-error).
A 429 (throttling) or a 5xx status (service failure) points to neither; retry
later as described in the table below, with a fresh token and, if needed, the
temporary role assignment again.

### Which section to follow

Read the status code of the failed attempt in `azcmagent.log` first:

| The failed attempt shows | Follow | Who acts |
| --- | --- | --- |
| `status code 401` | [Section 1](#1-azaccounts-version-on-the-system-is-incorrect) (module check), then [sections 2 and 3](#3-arm-access-token-is-passed-incorrectly): mint a new plain-text token and retry | The node administrator, with a token from an identity that holds the required roles |
| `httpStatusCode:403`, the code `RequestDisallowedByPolicy`, or a quota error code such as `QuotaExceeded` | [Section 4](#4-permissions-policy-or-quota-http-403-or-a-policy-or-quota-error). The fix is the permission, policy, or quota; do not change modules or the token's source or format to work around it. After the fix, the retry still needs a valid token: if it was cleared or has 10 minutes or less left, repeat the sign-in and token steps in section 3 first | The subscription owner makes any role, provider, or policy change |
| `429` (too many requests) | Azure Resource Manager throttled the request ([throttling](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling)). Wait for the `Retry-After` interval if the log shows one, otherwise a few minutes, then retry the initialization. Do not change modules, roles, or policies to fix the throttling. A retry with a token (section 3, option 1) is a new attempt: repeat [option 1](#3-arm-access-token-is-passed-incorrectly), steps 1 to 3, before it to get a fresh token and, if that option needs it, the temporary role assignment again, and clean up again afterward as in step 4. A device code retry (option 2) needs only a new sign-in. | The node administrator |
| A 5xx status, such as 500, 502, 503, or 504 | A transient service failure. Retry the initialization later and check [Azure Service Health](https://learn.microsoft.com/en-us/azure/service-health/overview) for the region. Do not change modules, roles, or policies to fix the service failure. A retry with a token (section 3, option 1) is a new attempt: repeat [option 1](#3-arm-access-token-is-passed-incorrectly), steps 1 to 3, before it to get a fresh token and, if that option needs it, the temporary role assignment again, and clean up again afterward as in step 4. A device code retry (option 2) needs only a new sign-in. If it persists, [contact Microsoft support](#when-to-contact-microsoft-support) | The node administrator; Microsoft support if it persists |
| Another 4xx status | Read the error code on the same line. If it does not name an authorization, policy, or quota error, [contact Microsoft support](#when-to-contact-microsoft-support) | Microsoft support |
| The section 1 block prints `UNKNOWN-STOP` | [Contact Microsoft support](#when-to-contact-microsoft-support) | Microsoft support |
| A different exit code, such as 26 (network error) | Not this article. Use the [agent exit codes](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard#agent-exit-codes) and [network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements) | Depends on the code; for 26, the network administrator |

### Version-dependent behavior

The recipe check in section 1 decides which row applies to the machine being
registered. Do not infer the requirement from the cluster's target solution
version, from an installed module, or from the `11.x` versus `12.x` train alone.

| Node's image recipe | Applicable images and behavior | What to do |
| --- | --- | --- |
| Requires Az.Accounts 4.0.2 | Older image recipes can require 4.0.2 on either OS train, including older recipes that do not record a package type. A newer installed module can change the token type expected by an older registration script; error 42 alone does not prove this is the cause. | Use the guarded 4.0.2 path in section 1, then request and pass a plain-text ARM token using sections 2 and 3. |
| Requires Az.Accounts 5.x or later | Newer image recipes require the newer module. `(Get-AzAccessToken).Token` is a `SecureString` by default starting with 5.0.0. An unconverted token is not a valid replacement for the plain-text token parameter. | Keep the product modules. Check expiry and convert the token using sections 2 and 3; do not downgrade to 4.0.2. |
| Missing or unrecognized recipe information | The recipe file is missing, lists no Az.Accounts package or more than one, names a package type other than `PowerShellModule`, or requires a version other than 4.0.2 or 5.x and later. The installed module inventory cannot establish the image requirement. | Stop without changing modules and contact Microsoft support. |

See [Azure PowerShell secret handling](https://learn.microsoft.com/en-us/powershell/azure/protect-secrets)
for the token-type change and [Azure Local release information](https://learn.microsoft.com/en-us/azure/azure-local/release-information-23h2)
for release support status. The module requirement remains a per-node recipe check.

### Where this problem appears

- **PowerShell on the node:** The initialization command reports bootstrap failure and `ArcAgentConnectionException`; `Get-ArcBootstrapStatus` reads the bootstrap status without retrying registration.
- **Azure portal:** Check the intended resource group under **Azure Arc > Machines** for the expected machine. When resource creation fails, the machine does not appear there; absence alone does not identify a token problem. Check the subscription, resource group, filters, and permissions before concluding it was not created.
- **Windows event logs:** Not characterized; validation did not establish whether this failure is recorded in any Windows event log. Use the PowerShell status above and the log files below instead; bootstrap diagnostics are Event Tracing for Windows (ETW) trace files named `Microsoft-AzureStack-Bootstrap-Diagnostics-EventSource-<timestamp>.etl` in the bootstrap logs directory.
- **Windows Admin Center (standalone host):** If an existing connection to the server is available, use its **PowerShell** tool to run `Get-ArcBootstrapStatus`; read the same bootstrap status rather than interpreting an unrelated server-health alert as error 42.
- **Component / tool log files:** The agent's `%ProgramData%\AzureConnectedMachineAgent\Log\azcmagent.log` records each connection attempt, including the `AZCM0042` and status code lines shown above; `himds.log` records heartbeat and identity activity ([agent log locations](https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#windows-agent-installation-details)). The bootstrap logs directory `%SystemRoot%\System32\Bootstrap\Logs` holds the `.etl` trace files, `arcInstallLog-<timestamp>.txt`, and `setup.log`; setup logs describe installation, not necessarily the registration failure. Match timestamps to the failed attempt and remove tokens or other secrets before sharing diagnostics.

For a new machine that is not yet registered or clustered:

- **Cluster logs:** not applicable to the pre-cluster registration failure on a node that has not joined a cluster.
- **Failover Cluster Manager:** not applicable to the pre-cluster registration failure because the affected machine is not yet a clustered node or role.
- **Windows Admin Center in Azure:** not applicable before this machine is connected to Azure Arc; this experience requires an Arc-connected machine ([requirements](https://learn.microsoft.com/en-us/windows-server/manage/windows-admin-center/azure/manage-arc-hybrid-machines#hybrid-machine-requirements)).

## Potential causes
1. Az.Accounts version on the system is incorrect.
2. ARM access token is expired.
3. ARM access token is passed incorrectly.
4. Permissions, policy, or quota (HTTP 403 or a policy or quota error).

## 1. Az.Accounts version on the system is incorrect

### Issue Validation
Run this cmdlet on each affected node to list available versions and their folders:
`Get-Module -ListAvailable -Name Az.Accounts | Select-Object Version, ModuleBase`

Az.Accounts 5.0.0 changed the default `(Get-AzAccessToken).Token` from plain text to
`SecureString` ([Azure PowerShell secret handling](https://learn.microsoft.com/en-us/powershell/azure/protect-secrets)).
Version 5.x is required by newer image recipes; its presence alone is not a module
version error. Convert the token as shown in section 3 instead of downgrading it.
For image/servicing version evidence, read
`(Get-Content -LiteralPath C:\ImageComposition\VSRInfo.json -Raw | ConvertFrom-Json).SolutionVersion`.
The recipe's Az.Accounts version, not this display value, controls the workaround.

### Resolution

Run the complete block below in an elevated Windows PowerShell 5.1 session on the
node being registered (right-click **Windows PowerShell** and select **Run as
administrator**; do not use PowerShell 7). The release check reads the node's own
image recipe, which does not require a deployed cluster. The check reads the node's current recipe,
which reflects its installed image, including any image update applied during
registration. Rerun this block after any reboot that registration triggers. It keeps every installed version when the
recipe requires 5.x or later. Only a recipe explicitly requiring 4.0.2 permits
removal of newer versions; older versions and 4.0.2 are preserved. If the recipe
is missing, ambiguous, or different, it stops without changing any modules.
On the 4.0.2 path, every check that can be made in advance runs before the block
installs or removes anything. It stops with `No changes were made` if a newer
Az.Accounts version is loaded in the session, if any other available module
declares in `RequiredModules` or `ModuleList` that it needs an Az.Accounts version
newer than 4.0.2, or if any newer Az.Accounts copy is not the copy that
`Install-Module` recorded in the all-users module folder
(`%ProgramFiles%\WindowsPowerShell\Modules`). That last check applies even when a
copy has the same version as one installed with `Install-Module`. It also stops
with `No changes were made` if the repository named in `$Repository` is not
registered, or does not have each newer version that the block would remove (so
that the rollback below can restore it from there) and, when 4.0.2 is not
already available, 4.0.2. Only after these
checks pass does the block install 4.0.2 and remove newer versions. It then
verifies the result; that final verification runs after the changes, so if it
fails, its message lists what was installed and uninstalled and how to roll back.
`Uninstall-Module -Force` skips PowerShellGet's dependency check, and current Az
modules declare their Az.Accounts minimum under `ModuleList`, so both lists are
read.

**[HIGH RISK]**

**Changes:** On the 4.0.2 path only, this installs 4.0.2 first if missing and
uninstalls newer Az.Accounts versions, printing `ARC42-INSTALLED` after it
installs 4.0.2 and each version and path as `ARC42-REMOVING` before it removes
it. It does not uninstall other modules or
register the node, but other modules that need a removed version stop loading.
Installing 4.0.2, and restoring a removed version with the rollback below, needs
access to the repository named in `$Repository`. Do not run this legacy
path during deployment or solution servicing.

> [!WARNING]
> Removing a newer Az.Accounts version breaks any module that requires it: importing
> that module fails with `This module requires Az.Accounts version ...`. The block
> stops with `No changes were made` when an available module declares such a
> requirement, but it cannot detect a module that loads Az.Accounts without
> declaring it. The removal is undone only by reinstalling each printed version
> with the rollback command below, which needs access to the repository named in
> `$Repository`.

**Choose the repository first.** Leave `$Repository` set to `'PSGallery'` unless
your organization requires an approved internal repository; in that case, set it
to that repository's registered name (`Get-PSRepository` lists them), and use the
same name in the rollback command. With the PowerShell Gallery, the node needs
HTTPS access to `www.powershellgallery.com` and to the download hosts
`cdn.powershellgallery.com` and `cdn.oneget.org`
([network access to the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/getting-started#network-access-to-the-powershell-gallery)).
The block's repository check uses `Find-Module`, which confirms that a version is
listed in the repository but not that the node can download it, so confirm that
those hosts are allowed before you run the block. If a download fails, the
installation of 4.0.2 fails before any version is removed.

**Paste or run the whole block at once, not line by line.** It runs as one unit
so that a failed check stops everything after it, and its
`$ErrorActionPreference` setting does not carry over into the session.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    # Leave 'PSGallery' unless your organization requires an approved internal repository.
    $Repository = 'PSGallery'
    try {
        $recipePath = Join-Path $env:SystemRoot 'System32\AzureLocalImage\OSImageRecipe.xml'
        [xml]$recipe = Get-Content -LiteralPath $recipePath -Raw -ErrorAction Stop
        $accounts = @($recipe.SelectNodes('/BuildInfo/Packages/Package[Name="Az.Accounts"]'))
        $packageType = [string]$accounts[0].PackageType
        if ($accounts.Count -ne 1 -or ($packageType -and $packageType -ne 'PowerShellModule')) {
            throw 'The image recipe does not identify exactly one Az.Accounts module.'
        }
        $required = [version]([string]$accounts[0].Version)
        if ($required -lt [version]'5.0.0' -and $required -ne [version]'4.0.2') {
            throw 'This recipe is not eligible for the 4.0.2 workaround.'
        }
    } catch {
        Write-Output 'ARC42-MODULE-GATE: UNKNOWN-STOP'
        throw
    }
    if ($required -ge [version]'5.0.0') {
        Write-Output 'ARC42-MODULE-GATE: KEEP-MODULES'
    } else {
        if (@(Get-Module -Name Az.Accounts | Where-Object { $_.Version -gt [version]'4.0.2' }).Count) {
            throw 'A newer Az.Accounts version is loaded. Start a fresh PowerShell session.'
        }
        $available = @(Get-Module -ListAvailable -Name Az.Accounts)
        if (@($available | Where-Object { $_.Version -gt [version]'4.0.2' }).Count) {
            $dependents = @(Get-Module -ListAvailable | Where-Object { $_.Name -ne 'Az.Accounts' } | Where-Object {
                @(@($_.RequiredModules) + @($_.ModuleList) | Where-Object {
                    $name = if ($_ -is [string]) { $_ } elseif ($_.Name) { [string]$_.Name } else { [string]$_.ModuleName }
                    $need = @($_.RequiredVersion, $_.Version, $_.ModuleVersion | Where-Object { $_ })
                    $name -eq 'Az.Accounts' -and $need.Count -and
                        (-not ([string]$need[0] -as [version]) -or [version][string]$need[0] -gt [version]'4.0.2')
                }).Count })
            if ($dependents.Count) {
                $dependents | ForEach-Object { Write-Output "ARC42-DEPENDENT: $($_.Name) $($_.Version) at $($_.ModuleBase)" }
                throw 'The modules listed above require Az.Accounts newer than 4.0.2. No changes were made.'
            }
        }
        # Uninstall-Module removes only the copy that Install-Module recorded, so every newer copy
        # must be that recorded copy, in the all-users module folder. PowerShellGet 2.x returns
        # Version as a string, so cast before comparing.
        $galleryCopies = @(Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction SilentlyContinue)
        $allUsersPath = "$env:ProgramFiles\WindowsPowerShell\Modules\"
        $newer = @($available | Where-Object { $_.Version -gt [version]'4.0.2' } | Sort-Object Version)
        $unmanaged = @($newer | Where-Object {
            $base = ([string]$_.ModuleBase).TrimEnd('\')
            $version = $_.Version
            -not $base.StartsWith($allUsersPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not @($galleryCopies | Where-Object {
                [version][string]$_.Version -eq $version -and ([string]$_.InstalledLocation).TrimEnd('\') -eq $base
            }).Count })
        if ($unmanaged.Count) {
            throw ('Uninstall-Module cannot remove these newer Az.Accounts copies. No changes were made: ' +
                (($unmanaged | ForEach-Object { "$($_.Version) at $($_.ModuleBase)" }) -join '; '))
        }
        # The rollback restores each removed version from $Repository, so it must have every version
        # this block removes, and 4.0.2 if it must be installed. A missing build number counts as 0.
        $full = { param([version]$v) [version]::new($v.Major, $v.Minor, [math]::Max($v.Build, 0), [math]::Max($v.Revision, 0)) }
        $needed = @($newer | ForEach-Object { $_.Version })
        if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' -and ([string]$_.ModuleBase).StartsWith($allUsersPath, [StringComparison]::OrdinalIgnoreCase) })) { $needed += [version]'4.0.2' }
        if ($needed.Count) {
            try { Get-PSRepository -Name $Repository -ErrorAction Stop | Out-Null } catch {
                throw "The repository $Repository is not registered on this machine. No changes were made."
            }
            $notFound = @($needed | Sort-Object -Unique | Where-Object {
                $want = $_
                $found = @()
                try { $found = @(Find-Module -Name Az.Accounts -RequiredVersion $want.ToString() -Repository $Repository -ErrorAction Stop) } catch { $found = @() }
                -not @($found | Where-Object { (& $full ([string]$_.Version)) -eq (& $full $want) }).Count })
            if ($notFound.Count) {
                throw ("Az.Accounts $($notFound -join ', ') is not available in $Repository, so it could not be " +
                    'installed or restored from there. No changes were made.')
            }
        }
        # Every check above runs before any change. The checks below verify the changes.
        $installed = $false
        if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' -and ([string]$_.ModuleBase).StartsWith($allUsersPath, [StringComparison]::OrdinalIgnoreCase) })) {
            Install-Module -Name Az.Accounts -RequiredVersion 4.0.2 -Scope AllUsers `
                -Repository $Repository -Force -ErrorAction Stop | Out-Null
            $installed = $true
            Write-Output 'ARC42-INSTALLED: Az.Accounts 4.0.2'
            $available = @(Get-Module -ListAvailable -Name Az.Accounts)
        }
        if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' -and ([string]$_.ModuleBase).StartsWith($allUsersPath, [StringComparison]::OrdinalIgnoreCase) })) {
            throw 'Az.Accounts 4.0.2 is not in the all-users module folder after installation; nothing was removed.'
        }
        foreach ($module in $newer) {
            Write-Output "ARC42-REMOVING: Az.Accounts $($module.Version) at $($module.ModuleBase)"
        }
        $removed = [System.Collections.Generic.List[string]]::new()
        $problem = $null
        try {
            foreach ($version in @($newer | ForEach-Object { $_.Version } | Sort-Object -Unique)) {
                Uninstall-Module -Name Az.Accounts -RequiredVersion $version.ToString() -Force -ErrorAction Stop
                $removed.Add($version.ToString())
            }
            $remaining = @(Get-Module -ListAvailable -Name Az.Accounts)
            $left = @($remaining | Where-Object { $_.Version -gt [version]'4.0.2' })
            if ($left.Count) {
                $problem = 'Newer Az.Accounts copies remain: ' +
                    (($left | ForEach-Object { "$($_.Version) at $($_.ModuleBase)" }) -join '; ') + '.'
            } elseif (-not ($remaining | Where-Object { $_.Version -eq [version]'4.0.2' -and ([string]$_.ModuleBase).StartsWith($allUsersPath, [StringComparison]::OrdinalIgnoreCase) })) {
                $problem = 'Az.Accounts 4.0.2 is not available in the all-users module folder.'
            }
        } catch {
            $problem = "Uninstall-Module failed ($($_.Exception.Message))."
        }
        if ($problem) {
            $undo = if ($installed) { ', then Uninstall-Module -Name Az.Accounts -RequiredVersion 4.0.2' } else { '' }
            throw ("Post-change verification failed; do not retry registration. $problem Changes made: " +
                $(if ($installed) { 'installed Az.Accounts 4.0.2' } else { 'nothing installed' }) +
                '; Uninstall-Module completed for ' +
                $(if ($removed.Count) { 'Az.Accounts ' + ($removed -join ', ') } else { 'no version' }) +
                ". To roll back, run the section 1 rollback command for each of those versions$undo.")
        }
        Write-Output 'ARC42-MODULE-GATE: REQUIRES-4.0.2'
    }
}
```

If the block reports `KEEP-MODULES`, proceed to the token sections. If it reports
`UNKNOWN-STOP` or throws, stop; do not substitute a guessed version. For other
recipe/module drift, use [Test PowerShell Module Version](../EnvironmentValidator/Troubleshooting-Test-PowerShell-Module-Version.md).
If the image recipe is unavailable, contact Microsoft support with the image
version and module inventory; installed versions alone cannot prove the requirement.

If the block stops because a newer copy was not installed with `Install-Module`
(for example, a copy placed in a module folder by hand or by another tool, or a
copy outside the all-users module folder), it names the version and folder and
makes no changes. Do not delete that folder to force the workaround; contact
Microsoft support with the message.

If the block stops with `Post-change verification failed`, it has already changed
modules: the message names whether it installed 4.0.2 and the versions for which
`Uninstall-Module` completed. Do not retry registration. Restore each version
that the message lists with the rollback command below. If the message says that 4.0.2 was installed, you can
then uninstall that version with the `Uninstall-Module` command that the message
names, to return to the previous module set. Contact Microsoft support with the message.

**Rollback:** Keep the `ARC42-REMOVING` lines the block printed. To restore a
removed version, for example after registration completes, run this for each
printed version, or, after a `Post-change verification failed` stop, for each
version that the message lists. Replace `<removed-version>` with the version, and
set `$Repository` to the same repository that you used in the module block:
leave `'PSGallery'` unless your organization requires an approved internal
repository, in which case use that repository's registered name. The block first
confirms with `Find-Module` that this exact version is listed in that repository.
If it is not, the block stops with `Nothing was installed`; choose an approved
repository that contains this exact version, or contact Microsoft support. As in
the module block, `Find-Module` does not prove that the node can reach the
download hosts listed above; if the download fails, nothing is installed.

**Changes:** installs the named Az.Accounts version for all users from
`$Repository` and prints `ARC42-RESTORED` when that version is available. It does
not remove 4.0.2 or change other modules. A newer version installed again before
registration finishes can reintroduce the problem that the 4.0.2 path addresses.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Repository = 'PSGallery'
    $Version = '<removed-version>'
    if (-not ($Version -as [version])) { throw 'Replace <removed-version> with a version from an ARC42-REMOVING line. Nothing was installed.' }
    try { Get-PSRepository -Name $Repository | Out-Null } catch { throw "The repository $Repository is not registered on this machine. Nothing was installed." }
    $found = @()
    try { $found = @(Find-Module -Name Az.Accounts -RequiredVersion $Version -Repository $Repository) } catch { $found = @() }
    if ($found.Count -ne 1) {
        throw "Az.Accounts $Version is not available in $Repository. Nothing was installed. Choose an approved repository that contains this exact version."
    }
    Install-Module -Name Az.Accounts -RequiredVersion $Version -Repository $Repository -Scope AllUsers -Force
    if (-not (Get-Module -ListAvailable -Name Az.Accounts | Where-Object { $_.Version -eq [version]$Version })) {
        throw "Az.Accounts $Version is not available after installation. Keep this output and contact Microsoft support."
    }
    Write-Output "ARC42-RESTORED: Az.Accounts $Version from $Repository"
}
```

## 2. ARM access token is expired

### Issue Validation

Check the token's expiry (`ExpiresOn` from Azure PowerShell, `expires_on` from
the Azure CLI), not a fixed one-hour age assumption.
The [agent does not renew a supplied access token](https://learn.microsoft.com/en-us/azure/azure-arc/servers/azcmagent-authentication).
The token blocks in section 3 stop unless at least 10 minutes remain.

### Resolution

Mint a fresh ARM access token from the same identity with the token block in
section 3 (option 1, step 2) and retry your original initialization command with
it. If an operator is present, you can instead rerun the initialization command
without `-ArmAccessToken` and complete device code sign-in (option 2 in section 3).

## 3. ARM access token is passed incorrectly

### Issue Validation
Sometimes, azcmagent exit code 42 is seen when the ARM access token is passed as an
object instead of a string. With Az.Accounts 5.x, `.Token` is a `SecureString` by
default, so selecting the property alone is not sufficient.

### Resolution

Registration needs an Azure sign-in by an identity that holds the roles in
[Assign required permissions for Azure Local deployment](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-arc-register-server-permissions).
The initialization command accepts that sign-in in one of two ways
([script parameters](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway#step-1-review-script-parameters)):

| Option | Who supplies the sign-in | Use it for |
| --- | --- | --- |
| 1. Pass `-ArmAccessToken` | Automation signed in as a pre-provisioned identity, such as a service principal or the managed identity of another Arc-enabled machine, or an operator who signs in | Scripted and unattended registration. This is the only option that automation can complete. |
| 2. Device code | A person at a keyboard who completes the sign-in in a browser | Interactive registration only. Unattended or on-box automation cannot complete it. |

With either option, retrying initialization can install an update on the node and
restart it.

**Automation boundary.** A script or an on-box assistant can classify the failed attempt from `azcmagent.log`
(401 here, 403 or a policy or quota error in [cause 4](#4-permissions-policy-or-quota-http-403-or-a-policy-or-quota-error), 429 or 5xx to retry later),
run the module block in section 1, check the lifetime and tenant of a token and
convert it to plain text, retry initialization with a token it was given, and
verify the result. It cannot create the credential or the role assignment, and it
does not make the role, provider, or policy changes in cause 4. The token must
come from an identity that already holds the required roles, through automation
that holds that identity's credential or through an operator who signs in. An
assistant running on a healthy, already registered machine can mint the token
without a person, from that machine's managed identity, but only if the
subscription owner granted that identity the role ahead of time (see step 1). The
failing node itself cannot do this.

**Why the node's managed identity cannot be used.** An Azure Arc-enabled server
gets its managed identity, and the local endpoint that issues its tokens, only
after it is connected to Azure Arc
([managed identity on Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication)).
A node that fails with exit code 42 has no Azure Arc resource yet, so
`az login --identity` or `Connect-AzAccount -Identity` on that node cannot
authenticate its registration. A different machine that is already registered,
such as another node of the same instance, does have a managed identity; step 1
describes how to use it. Do not assume that roles a deployment assigned to that
identity for other purposes include registration; check them as in step 1.

**Option 1 (automation and scripted runs): pass a plain-text ARM token.**

*Step 1: sign in as the identity that will mint the token.* Use an identity that
holds the required roles, on the machine where its credential is kept. For
automation this is normally off the node, on the automation host, so that no
service principal credential is placed on the node.

**Keep this procedure's sign-in separate.** Open a new PowerShell session that
you use only for this procedure, and run steps 1 to 4 in it. Every Azure
PowerShell sign-in below first runs `Disable-AzContextAutosave -Scope Process`
and then signs in with `-Scope Process`. `-Scope Process` alone is not enough.
Whether Azure PowerShell writes secrets and tokens to disk follows the context
autosave setting, which is on by default
([Azure contexts and sign-in credentials](https://learn.microsoft.com/powershell/azure/context-persistence)),
not `-Scope Process`. With autosave on, a client secret sign-in on Windows saves
the secret in `keystore.cache` in `%USERPROFILE%\.Azure`, and a device code
sign-in saves its tokens in the shared token cache under
`%LOCALAPPDATA%\.IdentityService` (other platforms use their own user locations);
`Disconnect-AzAccount -Scope Process` removes neither.
`Disable-AzContextAutosave -Scope Process` keeps contexts, tokens, and secrets in
memory for the current PowerShell process only, and does not change the saved
autosave setting that other sessions use. If you use the Azure CLI,
first point it at a new, empty profile folder for this session, so that
`az login` and `az logout` do not read or change the default Azure CLI profile,
which all sessions of the user share:

```powershell
$env:AZURE_CONFIG_DIR = Join-Path ([System.IO.Path]::GetTempPath()) ('arc42-az-' + [guid]::NewGuid())
```

**Changes:** sets an environment variable for the current PowerShell process
only. The command works in Windows PowerShell 5.1 and in PowerShell 7 on Linux
or macOS, where `$env:TEMP` is not set. The Azure CLI creates the folder when
you sign in. Sign-ins saved earlier, in the user profile or the default Azure
CLI profile, are not read or changed.

For example, for a service principal whose certificate is in that machine's
certificate store, replace the placeholders and run:

```powershell
Disable-AzContextAutosave -Scope Process
Connect-AzAccount -ServicePrincipal -ApplicationId '<application-id>' -CertificateThumbprint '<certificate-thumbprint>' -Tenant '<tenant-id>' -Scope Process
```

If the service principal uses a client secret instead of a certificate, do not
type the secret into a command or a script: Azure Local nodes can have PowerShell
script block logging turned on, which records script text. Let `Get-Credential`
prompt for it instead; it keeps the secret as a `SecureString` and does not
display it:

```powershell
Disable-AzContextAutosave -Scope Process
$credential = Get-Credential -UserName '<application-id>' -Message 'Enter the service principal client secret'
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant '<tenant-id>' -Scope Process
```

Run `Disable-AzContextAutosave -Scope Process` first, as in this block. Without
it, `Connect-AzAccount -ServicePrincipal -Credential` saves the client secret in
`keystore.cache` in `%USERPROFILE%\.Azure` (Az.Accounts 2.10.4 and later) even
with `-Scope Process`, and `Disconnect-AzAccount -Scope Process` and closing the
session leave it there. In validation with Az.Accounts 5.5.3, the file still held
the secret after the sign-out and when read from a new process; with the command
run first, no `keystore.cache` was written and the sign-in still worked.
For the Azure CLI, this procedure uses a certificate; to use a client secret, use
the Azure PowerShell sign-in above instead.

An operator who mints the token instead signs in with device code, which needs a
person to complete it in a browser:

```powershell
Disable-AzContextAutosave -Scope Process
Connect-AzAccount -Tenant '<tenant-id>' -UseDeviceAuthentication -Scope Process
```

**Changes:** `Disable-AzContextAutosave -Scope Process` turns off context
autosave for the current PowerShell process only and prints a setting with `Mode`
set to `Process`; the saved setting for the user, shown by
`Get-AzContextAutosaveSetting -Scope CurrentUser`, is not changed. The sign-in
then applies to that process only: its context, its tokens, and a service
principal's client secret stay in memory and are not written to the user
profile, and sign-ins saved earlier are not changed. Loading the Az.Accounts
module can still create or update its own settings files in `%USERPROFILE%\.Azure`,
which hold no credentials. A device code sign-in also sets the Azure PowerShell
`EnableLoginByWam` setting to `false` for the current user, and that setting
stays after the session ends; if the user relied on the default sign-in and wants
it back, run `Update-AzConfig -EnableLoginByWam $true` afterward. A client secret
entered at the `Get-Credential` prompt stays in the process, in `$credential` and
the sign-in, until step 4. Step 4 signs out of it.
It does not change the node or Azure resources.

*Managed identity of another registered machine (no person, no stored secret).*
An Azure Arc-enabled machine that is already registered and trusted, for example
another node of the same instance, can mint the token with its system-assigned
managed identity
([managed identity on Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication)).
Before the first use, the subscription owner looks up that identity and, unless the
checks below show that it can already register machines there, grants it
**Azure Connected Machine Onboarding** on the resource group where the failing node
registers, and on nothing else. Replace the `<machine-...>` placeholders with
that machine's subscription, resource group, and name (shown by `azcmagent show`
on that machine), and the others with the failing node's registration
subscription and resource group, then run:

```azurecli
az resource show --subscription '<machine-subscription-id>' --resource-group '<machine-resource-group>' --name '<machine-name>' --resource-type Microsoft.HybridCompute/machines --query identity.principalId -o tsv
```

The command prints the identity's principal ID, which you use as
`<principal-id>`. If it prints nothing, the machine has no system-assigned
identity; stop and use another identity.

Then check whether the identity already holds the role on that resource group.
This Bash block (for example, Azure Cloud Shell in Bash) is read-only and prints
exactly one result:

```bash
if ids=$(az role assignment list --assignee-object-id '<principal-id>' --role 'Azure Connected Machine Onboarding' --scope '/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>' --query "[].id" -o tsv); then
  if [ -n "$ids" ]; then echo "EXISTS: $ids"; else echo 'NONE'; fi
else
  echo 'LOOKUP-FAILED'
fi
```

- `EXISTS: <id>`: the identity already holds the role on that resource group, for
  example for other onboarding automation. Do not create another assignment, and
  do not delete that one after registration.
- `NONE`: the lookup succeeded and found no assignment. Only this result permits
  the create command below. A resource group name that does not exist also
  returns `NONE`, so confirm that the scope names the intended resource group.
- `LOOKUP-FAILED`: the lookup itself failed, for example because the account
  cannot read role assignments, the scope is wrong, or the request failed. An
  empty result from a failed lookup does not show that no assignment exists, so do
  not create the assignment. Fix the cause and run the block again.

To see whether other roles already let the identity register machines there,
also list every role assignment that applies to the identity at that resource
group, including those inherited from the subscription or a management group and
those received through groups. This command is read-only and informational:

```azurecli
az role assignment list --assignee-object-id '<principal-id>' --scope '/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>' --include-inherited --include-groups --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

Registering a machine needs more than `Microsoft.HybridCompute/machines/write`;
for example, the agent also reads the machine resource (the `get resource`
request in `azcmagent.log`), so a role that grants only that write permission
can still fail with a 403. So the temporary
assignment is not needed only when the identity's roles at that resource group
together grant every action of the built-in **Azure Connected Machine
Onboarding** role
([role definition](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/management-and-governance#azure-connected-machine-onboarding)):

- `Microsoft.HybridCompute/machines/read`
- `Microsoft.HybridCompute/machines/write`
- `Microsoft.HybridCompute/machines/addExtensions/action`
- `Microsoft.HybridCompute/settings/read`
- `Microsoft.HybridCompute/settings/write`
- `Microsoft.HybridCompute/gateways/read`
- `Microsoft.HybridCompute/privateLinkScopes/read`
- `Microsoft.GuestConfiguration/guestConfigurationAssignments/read`
- `Microsoft.Insights/dataCollectionRuleAssociations/read`
- `Microsoft.Insights/dataCollectionRuleAssociations/write`
- `Microsoft.Insights/dataCollectionRuleAssociations/delete`

**Owner**, **Contributor**, and **Azure Connected Machine Onboarding** each grant
all of these
([privileged roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged)).
**Azure Connected Machine Resource Administrator** on its own does not: it lacks
the `Microsoft.GuestConfiguration` and `Microsoft.Insights` actions. A custom
role grants an action when one of its `actions` entries matches it (an entry
with `*` matches every action it covers) and no entry in its `notActions`
matches it. To check all of the identity's roles together, including custom
roles, run this read-only Bash block (for example, Azure Cloud Shell in Bash)
with the same placeholders. It reads the Onboarding role's current actions and
the definition of every role in the listing, and prints exactly one result:

```bash
(
  set -f
  shopt -s nocasematch
  scope='/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>'
  need=$(az role definition list --name 'Azure Connected Machine Onboarding' --query "[].permissions[].actions[]" -o tsv) && [ -n "$need" ] || { echo 'LOOKUP-FAILED'; exit 1; }
  ids=$(az role assignment list --assignee-object-id '<principal-id>' --scope "$scope" --include-inherited --include-groups --query "[].roleDefinitionId" -o tsv) || { echo 'LOOKUP-FAILED'; exit 1; }
  covered=' '
  for id in $(printf '%s\n' $ids | sort -fu); do
    acts=$(az rest --method get --url "$id?api-version=2022-04-01" --query "properties.permissions[].actions[]" -o tsv) || { echo 'LOOKUP-FAILED'; exit 1; }
    nots=$(az rest --method get --url "$id?api-version=2022-04-01" --query "properties.permissions[].notActions[]" -o tsv) || { echo 'LOOKUP-FAILED'; exit 1; }
    for a in $need; do
      hit=''
      for p in $acts; do [[ $a == $p ]] && hit=1; done
      for p in $nots; do [[ $a == $p ]] && hit=''; done
      [ -n "$hit" ] && covered="$covered$a "
    done
  done
  missing=''
  for a in $need; do [[ $covered == *" $a "* ]] || missing="$missing $a"; done
  if [ -z "$missing" ]; then echo 'COVERED'; else echo "MISSING:$missing"; fi
)
```

- `COVERED`: the identity's roles at that resource group together grant every
  Onboarding action. Do not create the temporary assignment; the identity can
  already register machines there, and that access remains after this procedure.
- `MISSING: <actions>`: the listed actions are not granted. Create the temporary
  assignment below if the check block printed `NONE`.
- `LOOKUP-FAILED`: a lookup failed, for example because the account cannot read
  role assignments or role definitions. Do not create the assignment and do not
  assume the identity has access; fix the cause and run the block again.

Azure role permissions are additive
([Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)),
so deleting the temporary assignment later does not remove access that another
assignment gives. Create the temporary assignment only when the check block
printed `NONE` and the block above printed `MISSING`, and record the ID that
the create command prints as `<assignment-id>`:

```azurecli
az role assignment create --assignee-object-id '<principal-id>' --assignee-principal-type ServicePrincipal --role 'Azure Connected Machine Onboarding' --scope '/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>' --query id -o tsv
```

**Changes:** adds one role assignment; while it applies, anyone who can mint a
token on that machine can register machines into that resource group. Remove it
right after the initialization attempt with `az role assignment delete --ids '<assignment-id>'`,
which deletes only the assignment that this command created. Run that delete
command only for an ID that this create command printed. Azure Resource Manager
checks the identity's role assignments on each request; the token carries no
role data. So once the removal takes effect, requests with any token of this
identity, including one minted before the removal, can no longer register
machines through this assignment. The deletion removes only this assignment's
grant: if another assignment that applies at that resource group, such as an
inherited **Contributor** role shown by the listing above, also grants
registration, the identity can still register machines. The token itself remains a valid credential until it expires and can
still use any other access the identity has. Adding or removing an assignment can
take several minutes to take effect
([Azure RBAC troubleshooting](https://learn.microsoft.com/en-us/azure/role-based-access-control/troubleshooting));
in validation, a new assignment took about 20 minutes, and retries before then
still failed with 403.

**Remove the assignment on every exit.** From the moment the create command prints
an ID until that assignment is deleted, every way out of this procedure includes
the delete. If a token block in step 2 stops, if the initialization retry fails or
reports a 403, or if you abandon the attempt for any reason, either fix the cause
and continue right away, or have the subscription owner run
`az role assignment delete --ids '<assignment-id>'` before you leave the procedure,
then clear the token as in step 4. Run it only for the ID that the create command
printed; if the check printed an existing assignment, delete nothing.

In validation, this role alone let the token register a machine with the agent's
connect command. The initialization command was not validated with this identity.
If its retry reports a 403, stop: do not grant this identity any other role or a
broader scope. If you created an assignment, remove it with the delete command
above, then mint the token from a service principal or operator account that
already holds the roles in the permissions article, or use device code (option 2).

Then, in a new elevated Windows PowerShell 5.1 session on the registered machine
that you use only for this procedure, sign in as its managed identity, and
continue with step 2 in the same session:

```powershell
Disable-AzContextAutosave -Scope Process
Connect-AzAccount -Identity -Scope Process
```

With the Azure CLI on that machine, set `AZURE_CONFIG_DIR` in that session as
shown at the start of step 1, then use `az login --identity --allow-no-subscriptions`
followed by the Azure CLI block in step 2.

**Changes:** turns off context autosave and signs in for the current PowerShell
process only; no context or token is written to the user profile, and the saved
autosave setting is not changed. `az login --identity` saves the sign-in only in the
procedure's Azure CLI profile folder. Step 4 signs out of both and removes that
folder.

> [!IMPORTANT]
> Any local administrator of the minting machine, and any member of its
> **Hybrid Agent Extension Applications** group, can mint this identity's token.
> The token is valid for up to about 24 hours and cannot be revoked. Removing the
> role assignment does not invalidate the token, but once the removal takes effect,
> usually within minutes, Azure no longer grants registration through that
> assignment to any token of this identity, including one minted before the
> removal. Until it expires, the token can still use any other access the identity
> has, including registration through any other role that grants it, so clear it (step 4) and limit
> where you send it. Mint the token just before you start the initialization, and remove
> the assignment right after the initialization attempt. The machine caches the
> token, so it can have much less than 24 hours left; step 2 checks the remaining
> time.

*Step 2: mint and convert the token.* In the same session, replace `<tenant-id>`
in the block below with the resource tenant ID from the deployment plan (in the
Azure portal, **Microsoft Entra ID** > **Properties** > **Tenant ID**), then
run the complete block. It requests an ARM token for the tenant of the current
sign-in and converts only its `Token` property; it does not sign in, switch
context, or display the token. The conversion is compatible with Windows
PowerShell 5.1. It stops if the token is from a different tenant. For a user
account or service principal, sign in again with `-Tenant '<tenant-id>'` (or
`--tenant` with the Azure CLI) as in step 1; a managed identity works only when
its machine is registered in the same tenant as the failing node.

**Paste or run each token block whole, not line by line.** Each block runs as
one unit, so a failed check stops everything after it and leaves `$token` empty.
Each block starts with `. {` so that `$token` remains in the session for step 3,
and it restores the session's `$ErrorActionPreference` when it finishes.

```powershell
. {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $token = $null
    $t = $null
    $TenantId = '<tenant-id>'
    $parsedTenant = [guid]::Empty
    try {
        if (-not [guid]::TryParse($TenantId, [ref]$parsedTenant) -or $parsedTenant -eq [guid]::Empty) {
            throw 'Replace <tenant-id> with the resource tenant ID before requesting a token.'
        }
        $t = Get-AzAccessToken -ResourceTypeName Arm -ErrorAction Stop
        if (-not $t.ExpiresOn -or [DateTimeOffset]$t.ExpiresOn -le [DateTimeOffset]::UtcNow.AddMinutes(10)) {
            throw 'Token expires within 10 minutes; sign in again and rerun this block.'
        }
        if ([guid]$t.TenantId -ne $parsedTenant) { throw 'Token tenant does not match the deployment plan.' }
        if ($t.Token -is [System.Security.SecureString]) {
            $token = [System.Net.NetworkCredential]::new('', $t.Token).Password
        } elseif ($t.Token -is [string]) {
            $token = $t.Token
        } else {
            throw 'Unexpected token property type; stop.'
        }
        if ([string]::IsNullOrWhiteSpace($token) -or $token -eq 'System.Security.SecureString') {
            throw 'Token is empty or incorrectly converted; stop.'
        }
    } catch {
        $token = $null
        throw
    } finally {
        $t = $null
        $ErrorActionPreference = $previousErrorAction
    }
}
```

If the automation host uses the Azure CLI instead of Azure PowerShell, set
`AZURE_CONFIG_DIR` as shown at the start of step 1, then, in the same session,
sign in as the service principal with `az login --service-principal --username '<application-id>' --certificate '<path-to-certificate.pem>' --tenant '<tenant-id>'`
(this saves the sign-in only in the procedure's profile folder, which step 4
removes: a service principal entry that records the application ID, tenant, and
the path of the certificate file, not the certificate itself, and a token cache;
on Windows both files are encrypted), then run this block in that session. It applies the
same lifetime and tenant checks and does not display the token. It requests the
token for the current sign-in without `--tenant`, which the Azure CLI does not
support for a managed identity
([az account get-access-token](https://learn.microsoft.com/en-us/cli/azure/account#az-account-get-access-token)),
so the same block works after `az login --identity --allow-no-subscriptions`.

```powershell
. {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $token = $null
    $r = $null
    $TenantId = '<tenant-id>'
    $parsedTenant = [guid]::Empty
    try {
        if (-not [guid]::TryParse($TenantId, [ref]$parsedTenant) -or $parsedTenant -eq [guid]::Empty) {
            throw 'Replace <tenant-id> with the resource tenant ID before requesting a token.'
        }
        $r = (az account get-access-token --resource https://management.azure.com -o json | Out-String)
        if ($LASTEXITCODE -ne 0) { throw 'az account get-access-token failed; sign in with az login and rerun this block.' }
        $r = $r | ConvertFrom-Json
        if (-not $r.expires_on) { throw 'The response has no expires_on value; update the Azure CLI or use the Azure PowerShell block.' }
        if ([DateTimeOffset]::FromUnixTimeSeconds([long]$r.expires_on) -le [DateTimeOffset]::UtcNow.AddMinutes(10)) {
            throw 'Token expires within 10 minutes; sign in again and rerun this block.'
        }
        if ([guid]$r.tenant -ne $parsedTenant) { throw 'Token tenant does not match the deployment plan.' }
        $token = [string]$r.accessToken
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token is empty; stop.' }
    } catch {
        $token = $null
        throw
    } finally {
        $r = $null
        $ErrorActionPreference = $previousErrorAction
    }
}
```

If either block stops (tenant mismatch, 10 minutes or less remaining, a failed
request, or an empty or unexpected token) after step 1 created an assignment, fix
the cause and rerun the block now, or remove that assignment before you stop, as
described under **Remove the assignment on every exit** in step 1. A tenant
mismatch for a managed identity cannot be fixed by rerunning.

*Step 3: pass the token to the initialization command.* On the node, pass the
string as `-ArmAccessToken $token`, or as `$params.ArmAccessToken = $token` when
you build parameters as in the
[initialization command for your deployment](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway),
keeping its other parameters unchanged. When the token was minted off the node,
deliver it through the channel your automation already uses to run commands on
the node, and start the initialization while at least 10 minutes remain; if
delayed, repeat step 2. Pass the token as a variable or as an argument, for
example with `Invoke-Command -ArgumentList $token`, never as text inside a
script: Azure Local nodes can have PowerShell script block logging turned on
(it was on in validation), which records the text of every script that runs.
Do not write the token to a file, print, export, or transcribe it, or include it
in a ticket. After the initialization attempt, whether or not it succeeded, clear
the token and sign out as described in step 4. If the token came from a managed
identity and step 1 created its **Azure Connected Machine Onboarding** assignment,
have the subscription owner remove that assignment with the `az role assignment delete --ids`
command in step 1 right after the initialization attempt. Once the removal takes
effect, no token of that identity, including the one you minted, can register
machines through that assignment; any other role that grants the identity
registration at that resource group still applies. The token remains a valid credential until it expires, so clearing
`$token` and limiting where it was sent still matter. Do not remove an assignment
that existed before step 1.

**Changes:** The token blocks only set session variables. Retrying initialization
can create Azure resources and change the node's registration configuration and,
when an update is required, install it and restart the node.

*Step 4: clear the token and sign out.* After the initialization attempt, and
whenever you stop after step 2, clean up on every machine and in every session
where the token existed: the minting machine, the node, and any machine used to
pass the token between them. Clean up even if you expect to retry later, for
example after the subscription owner fixes a 403 as in cause 4; for that retry,
repeat steps 1 to 3 in a new session to mint a fresh token, instead of keeping
this one while you wait.

1. In each PowerShell session that held the token, run:

   ```powershell
   Remove-Variable -Name token, t, r, credential -ErrorAction SilentlyContinue
   if (Get-Variable -Name token, credential -ErrorAction SilentlyContinue) { 'Token or credential variable still present' } else { 'Token and credential variables cleared' }
   ```

   Expect `Token and credential variables cleared`. The token blocks already clear their
   intermediate copies when they finish: `$t`, which holds the `SecureString`
   result, and `$r`, which holds the Azure CLI response. The command removes them
   as well in case a block was interrupted, and removes `$credential`, which holds
   a service principal's client secret if you signed in with `Get-Credential` in
   step 1. If you also stored the token elsewhere,
   such as in `$params.ArmAccessToken`, remove it there too, for example with
   `$params.Remove('ArmAccessToken')`.
2. If you passed the token through a remote session that you created, for example
   `$session = New-PSSession ...` used with `Invoke-Command -Session $session`,
   run `Remove-PSSession -Session $session`. This closes the session on the remote
   machine, together with the copy of the token it held. `Invoke-Command -ComputerName`
   without `-Session` closes its temporary session itself.
3. On the minting machine, in the session that step 1 used, sign out of the
   sign-in that step 1 made for this procedure. These commands affect only that
   sign-in: sign-ins saved earlier, in the user profile or the default Azure CLI
   profile, stay as they were.
   - Azure PowerShell (managed identity, service principal, or operator account,
     signed in after `Disable-AzContextAutosave -Scope Process`, as in step 1):
     `Disconnect-AzAccount -Scope Process`, or close the session. This removes
     the process's context for that sign-in. Because autosave was turned off for
     the process, its tokens and, for a service principal, the client secret
     that `Get-Credential` supplied were kept only in that process's memory and
     were not written to `%USERPROFILE%\.Azure` or `%LOCALAPPDATA%\.IdentityService`;
     closing the session removes them. A certificate in the certificate store is
     not changed. Afterward, `Get-AzContext` no longer shows the
     identity that this procedure used. Do not run `Disconnect-AzAccount` without
     `-Scope Process`: it removes all saved credentials and contexts of the
     account from the user profile, including ones that existed before this
     procedure
     ([Disconnect-AzAccount](https://learn.microsoft.com/en-us/powershell/module/az.accounts/disconnect-azaccount)).

     If a sign-in ran without `Disable-AzContextAutosave -Scope Process` while
     autosave was on for the user (the default; check with
     `Get-AzContextAutosaveSetting -Scope CurrentUser`), a client secret sign-in
     left the secret in `%USERPROFILE%\.Azure\keystore.cache`, and a device code
     sign-in left the operator's tokens in the shared token cache under
     `%LOCALAPPDATA%\.IdentityService`. Neither the sign-out above nor closing the
     session removes them, and this article has no validated command that removes
     only this procedure's entries. `Clear-AzContext` removes every saved context,
     secret, and token of the user, not only this procedure's; run it only if
     nothing else on that machine uses the user's saved Azure PowerShell sign-ins.
     Otherwise, ask the administrator of the minting machine to remove the
     entries. For a service principal, removing that client secret from the
     application in Microsoft Entra ID makes the saved copy unusable.
   - Azure CLI (service principal or `az login --identity`): run this block in the
     same session. It signs out and deletes the procedure's profile folder only
     when `AZURE_CONFIG_DIR` names a folder that step 1 created; otherwise it
     changes nothing. If the folder cannot be deleted completely, for example
     because a file is in use, it stops with an error and keeps
     `AZURE_CONFIG_DIR`, so you can close the process using the folder and run
     the block again; it prints `Procedure Azure CLI profile removed` only after
     the folder is gone.

     ```powershell
     & {
         $dir = $env:AZURE_CONFIG_DIR
         if ($dir -and (Split-Path -Path $dir -Leaf) -like 'arc42-az-*' -and (Test-Path -LiteralPath $dir -PathType Container)) {
             # Without this, the Azure CLI telemetry upload that follows az logout can recreate the folder.
             $env:AZURE_CORE_COLLECT_TELEMETRY = 'false'
             az logout 2>$null
             try {
                 Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
             } catch {
                 throw "Could not delete $dir ($($_.Exception.Message)). AZURE_CONFIG_DIR was kept; close any process using that folder and run this block again."
             }
             if (Test-Path -LiteralPath $dir) {
                 throw "$dir still exists. AZURE_CONFIG_DIR was kept; run this block again."
             }
             Remove-Item -Path Env:\AZURE_CORE_COLLECT_TELEMETRY
             Remove-Item -Path Env:\AZURE_CONFIG_DIR
             'Procedure Azure CLI profile removed'
         } else {
             'AZURE_CONFIG_DIR does not name this procedure''s profile folder; nothing removed'
         }
     }
     ```

     Expect `Procedure Azure CLI profile removed`. `az logout` removes the
     sign-in, including a service principal's entry, and deleting the folder
     removes every file the Azure CLI wrote for this procedure, including the
     service principal entry and token cache files. The block turns off Azure CLI
     telemetry for `az logout`; otherwise the telemetry upload that follows it can
     recreate the folder a few seconds later with only a `logs\telemetry.log`
     file, which holds no credentials. Afterward, `az account show`
     uses the default Azure CLI profile again, which this procedure did not
     change. In validation with a managed identity, the Azure CLI did not create
     a token cache file (`msal_token_cache.bin`) in the procedure's profile
     folder at any point.
4. If you copied or exported a certificate file with its private key (a `.pem`
   or `.pfx` file) to the minting machine only for this procedure, delete it now,
   for example with `Remove-Item -LiteralPath '<path-to-certificate.pem>'`, and
   remove any variable that held its password. Neither sign-out removes it: the
   Azure CLI records only the file's path. Do not delete a certificate file or a
   certificate store entry that existed before this procedure.
5. Close the PowerShell windows and sessions that you used. A PowerShell string
   cannot be overwritten in place, so ending the process removes the last copy
   held in memory.

These commands contain no token text, so script block logging records nothing
sensitive from them; still never place the token itself in script text.
Clearing the local copies does not revoke the token: it remains a valid credential
until it expires. For a managed identity, removing the role assignment in step 1
removes only the registration access that this assignment granted; it does not
remove access that other role assignments give the identity.

**Changes:** removes session variables (including a client secret held in
`$credential`), the remote sessions you name, the sign-ins that this procedure
created, the procedure's Azure CLI profile folder, and a certificate file that
you copied for this procedure and name. It does not change sign-ins saved
earlier, the certificate store, the node, Azure resources, or role assignments,
and it does not revoke the token.

**Option 2 (interactive only): let the registration command sign in with device
code.** The `-ArmAccessToken` parameter is optional. If you omit it, the script
prompts for device code authentication. A person must open the displayed address
in a browser and complete the sign-in, so unattended or on-box automation cannot
use this option. Rerun your original initialization command without
`-ArmAccessToken`, keep its other parameters unchanged, and complete the sign-in
with the code it displays. No token conversion or module change is needed.

**Changes:** Retrying initialization can create Azure resources, change the
node's registration configuration, and, when an update is required, install it
and restart the node.

Verify resolution using the original bootstrap status and the node's Azure Arc
registration state. If registration still fails, retain the complete sanitized
error and follow the [agent troubleshooting guidance](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard)
instead of repeating module downgrades. If you stop here and option 1, step 1
created a role assignment, remove it first, then clear the token as in step 4.

## 4. Permissions, policy, or quota (HTTP 403 or a policy or quota error)

### Issue Validation

In `azcmagent.log` and the console output, the failed `AZCM0042` attempt reports
a 403, the code `RequestDisallowedByPolicy`, or a quota error code such as
`QuotaExceeded`. For example, an Azure Policy assignment that denies
the machine resource produces a line ending in
`Code: RequestDisallowedByPolicy httpStatusCode:403`, and the agent also logs
`Please verify that the login credentials or token used has access to create resources in resource group '<resource-group>'`.
These responses are not 401 authentication failures, so the module and token
fixes in sections 1 to 3 do not apply: changing modules, or the source or
format of the token, does not fix this pattern. After the cause below is fixed,
the retry still needs a valid token, as described at the end of this section. A 429 or 5xx status is not this cause either: it is
throttling or a transient service failure; follow its row in
[Which section to follow](#which-section-to-follow) and retry later instead of
changing roles, providers, or policies.

### Resolution

Check the subscription and resource group against
[Assign required permissions for Azure Local deployment](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-arc-register-server-permissions):

- The required resource providers, including `Microsoft.HybridCompute`, are
  registered in the subscription.
- The identity that minted the registration token, or that signed in with device
  code, is the resource group owner or holds the
  **Azure Connected Machine Onboarding** and **Azure Connected Machine Resource
  Administrator** roles on the resource group.
- No Azure Policy assignment denies creation of Azure Arc machine resources in
  that resource group, and the subscription has not reached a resource quota.

These are read-only checks; any role, provider, or policy change is made by the
subscription owner using the linked article. Check the roles of the principal
that minted the registration token, not of the account that runs these checks.
They are often different: for example, the subscription owner runs the checks in
Azure Cloud Shell, while a service principal or another machine's managed
identity minted the token. Get the minting principal's object ID:

- **Managed identity of another registered machine:** the `az resource show`
  command in [section 3, step 1](#3-arm-access-token-is-passed-incorrectly)
  prints it.
- **Service principal:** `az ad sp show --id '<application-id>' --query id -o tsv`.
- **User account:** `az ad signed-in-user show --query id -o tsv`, run while
  signed in as that user. Run by anyone else, it prints their own ID, and it does
  not work for a service principal signed in with `az login --service-principal`.

To run the provider, role, and policy checks with the Azure CLI (for example, in
Azure Cloud Shell), sign in to the same tenant with an account that can read the
subscription's role assignments. Replace the placeholders with the subscription,
the resource group, and the minting principal's object ID, and run:

```azurecli
az provider show --namespace Microsoft.HybridCompute --subscription '<subscription-id>' --query registrationState -o tsv
az role assignment list --assignee-object-id '<minting-principal-object-id>' --resource-group '<resource-group>' --subscription '<subscription-id>' --include-inherited --include-groups --query "[].roleDefinitionName" -o tsv
```

Then list the policy assignments that apply to the resource group. `az rest`
returns one page of results and does not follow the `nextLink` that Azure
Resource Manager includes when more results exist, so this Bash loop (for
example, Azure Cloud Shell in Bash) requests each following page until no
`nextLink` remains:

```bash
url='/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Authorization/policyAssignments?api-version=2023-04-01&$filter=atScope()'
while [ -n "$url" ]; do
  az rest --method get --url "$url" --query "value[].[id, properties.displayName, properties.enforcementMode, properties.policyDefinitionId]" -o tsv || break
  url=$(az rest --method get --url "$url" --query nextLink -o tsv) || break
done
```

Expect `Registered`, then `Owner` or both Azure Connected Machine roles for the
minting principal. A managed identity set up as in section 3 lists only
**Azure Connected Machine Onboarding**; if its retry still returns 403, follow
the stop instruction in section 3, which removes the assignment that section 3
created, instead of granting more roles. The loop prints
one tab-separated line for each policy assignment that applies to the resource
group, including those inherited from the subscription and management groups:
the assignment ID (its scope followed by `/providers/Microsoft.Authorization/policyAssignments/`
and the assignment name), the display name, the enforcement mode, and the policy
definition or initiative ID. If an `az rest` call fails, the loop stops; treat the list as
incomplete and run it again. Keep the first `url` value in single quotes so the
shell does not expand `$filter`. Do not
substitute `az policy assignment list --resource-group`: in validation it listed
only assignments made directly on the resource group, even with
`--disable-scope-strict-match`. To find the denying assignment, match the
`policyAssignment` `id` in the `RequestDisallowedByPolicy` message in
`azcmagent.log` against the first column. The last column matches the message's
`policyDefinition` `id`, or its `policySetDefinition` `id` when the assignment is
for an initiative. Do not match on display names: the `name` shown under
`policyAssignment` in that message is the display name, which can be empty or
shared by several assignments. If the message is not available, review each
assignment whose enforcement is `Default` for a deny on
`Microsoft.HybridCompute/machines` or on the resource group's location.

After the subscription owner fixes the cause, retry your original initialization
command. With a token (section 3, option 1), the retry needs a valid one: if
step 4 already cleared the earlier token, or it has 10 minutes or less left,
repeat section 3, steps 1 and 2 in a new session to sign in and mint a fresh
token, pass it as in step 3, and clean up again with step 4 after the retry. Mint
it from the identity whose access was checked and fixed above. With device code (option 2),
the retry prompts for the sign-in again.

**Changes:** Retrying initialization can create Azure resources, change the
node's registration configuration, and, when an update is required, install it
and restart the node.

## When to contact Microsoft support

Contact Microsoft support when the module block in section 1 stops, when
registration still fails with exit code 42 after the applicable section, when a
5xx status persists after retries, or when `azcmagent.log` shows a status code
that the table in [Which section to follow](#which-section-to-follow) and the
checks in section 4 do not explain.

Before you contact support, if section 3, step 1 created an
**Azure Connected Machine Onboarding** assignment for a managed identity, have the
subscription owner remove it with `az role assignment delete --ids '<assignment-id>'`,
using only the ID that the create command printed, and clear the token as in
section 3, step 4. If support asks for another retry, grant the role again then.

Collect logs on the affected node by running `Collect-ArcBootstrapSupportLogs`,
as described in [Register Azure Local with Azure Arc](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway), and share them
with Microsoft support. Also include:

- The exact error text and the time of the failed attempt.
- The output of `Get-ArcBootstrapStatus` and, from section 1, the module block's
  output and the `Get-Module -ListAvailable -Name Az.Accounts` inventory.
- The `AZCM0042` and status code lines from
  `%ProgramData%\AzureConnectedMachineAgent\Log\azcmagent.log`.

> [!IMPORTANT]
> Bootstrap logs, PowerShell transcripts, and command history can contain access
> tokens. Before you attach any file or paste output into a ticket, review it and
> remove tokens and other secrets. Never include the value of `$token`.

## Validation status of this article

Validated in a lab from 2026-11-23 to 2026-11-25 with Windows PowerShell 5.1 and
Azure Connected Machine agent 1.70.03595.3521. The registration runs used
disposable Windows Server 2022 test machines, not an Azure Local image, and
throwaway resource groups; managed identity tokens were minted on a registered
Azure Local node. In
each run, the article's blocks, in their form at the time of that run, ran
unchanged except for their placeholders. Many blocks changed after earlier runs;
where a bullet describes an earlier form, it says so and names what was checked
for the current form. The agent's connect
command was run directly in place of the initialization command that wraps it;
the full bootstrap was not run.

- **Token cause (sections 2 and 3, option 1):** with Az.Accounts 5.5.3, the
  unconverted token reproduced exit code 42 with `AZCM0042` and
  `status code 401` (`InvalidAuthenticationToken`), and no machine was created.
  The section 3 Azure PowerShell token block produced a plain-text token, and the
  same connect succeeded (machine `Connected`, provisioning `Succeeded`).
  In that run, which predates the `-Scope Process` sign-in in step 1, a bare
  `Disconnect-AzAccount` then removed the saved sign-in. With Az.Accounts 4.0.2,
  the same block used the plain-text token as is, and the connect succeeded. In a
  second run, the 401 was reproduced again, then the section 3 Azure CLI block
  minted the token off the node (PowerShell 7.5 with Azure CLI 2.85.0 on a separate
  workstation, signed in as an existing operator account), the token was passed to
  the node through the remote execution channel, and the connect succeeded
  (machine `Connected`, provisioning `Succeeded`). These runs used the earlier
  token blocks, which passed `-TenantId` or `--tenant` and were not yet single
  statements, and sign-ins made before step 1 used a process-scoped Azure
  PowerShell sign-in and a separate Azure CLI profile folder. The current blocks and sign-ins were checked as
  described in the bullets below; no registration was repeated with them.
- **Token block stop conditions:** against stubbed token responses in Windows
  PowerShell 5.1, the Azure PowerShell block stopped on a token with 10 minutes or
  less remaining, an expired token, a missing expiry, a tenant mismatch, an
  unexpected token type, and the text `System.Security.SecureString`, and left
  `$token` empty each time. The Azure CLI block stopped on 10 minutes or less
  remaining, an expired token, a missing `expires_on`, a tenant mismatch, an empty
  token, and a failed `az` call. Both stopped when `<tenant-id>` was not replaced.
  These cases ran against the earlier blocks, which passed the tenant parameter
  and were not yet single statements. Against stubbed responses, the current
  blocks were rerun only for an unreplaced placeholder, a matching tenant, and a
  mismatched tenant (see the bullet on blocks pasted line by line); the expiry,
  type, and empty-token cases were not rerun with them.
- **Module block (section 1):** with no image recipe, the block printed
  `UNKNOWN-STOP` and changed nothing. With a staged recipe file that requires
  4.0.2 in the older format without a package type, it installed 4.0.2, printed
  `ARC42-REMOVING` for 5.5.3, removed it, and printed `REQUIRES-4.0.2`; a rerun
  changed nothing. This passed with PowerShellGet 1.0.0.1 and 2.2.5. A loaded newer
  version, a newer version copied in by hand, a recipe requiring 4.0.3, and a
  package type other than `PowerShellModule` each stopped without changing modules.
  A recipe requiring 5.5.3 printed `KEEP-MODULES`. The rollback command, in its
  earlier one-line form (`Install-Module` from the PowerShell Gallery, without the
  repository and `Find-Module` checks), restored 5.5.3. This run used an earlier
  form of the block, before the repository, copy-location, and stop-order checks
  described below. Earlier, on a deployed node of solution 12.2701.1004.15 whose real recipe
  requires 5.5.3, the block printed `KEEP-MODULES` and changed no modules.
- **Dependent-module guard (section 1):** on Windows PowerShell 5.1 with
  PowerShellGet 1.0.0.1 and the staged 4.0.2 recipe, `Az.Storage` 9.6.1 was
  installed from the PowerShell Gallery; its manifest declares Az.Accounts 5.4.0
  under `ModuleList`, and installing it added Az.Accounts 5.5.5 beside 5.5.3. The
  block printed `ARC42-DEPENDENT` for `Az.Storage` and stopped with
  `No changes were made`; the module inventory was identical before and after.
  After `Az.Storage` was uninstalled, the block printed `ARC42-REMOVING` for 5.5.3
  and 5.5.5, installed 4.0.2, and printed `REQUIRES-4.0.2`, leaving only 4.0.2.
  The rollback command, in its earlier one-line form, run for each printed
  version, restored 5.5.3 and 5.5.5. The current rollback block was not run live.
  With mocked module inventories in PowerShell 7.5, the guard also stopped for a
  `RequiredModules` entry, a required version, and an unreadable version, and
  continued for a maximum-only or lower requirement.
- **Module block stop order (section 1), 2026-11-24:** the check for newer copies
  not installed with `Install-Module` now runs before 4.0.2 is installed. With
  mocked module cmdlets in PowerShell 7.5, the block stopped with
  `No changes were made` and no install or uninstall call for a hand-placed newer
  copy while 4.0.2 was missing (the earlier order installed 4.0.2 first), for a
  loaded newer version, and for another module that pins an exact newer
  Az.Accounts version under `ModuleList` or `RequiredModules`. It continued for a
  lower minimum, a maximum-only entry, and the normal path, and printed
  `KEEP-MODULES` without changes for a 5.x recipe. In Windows PowerShell 5.1 and
  PowerShell 7.5, an exact `ModuleList` pin is read with an empty `Version` and the
  pinned `RequiredVersion`, which the guard reads first. On the registered Azure
  Local node described below, whose recipe requires 5.5.3, the revised block printed
  `KEEP-MODULES` and the module inventory was unchanged. The 4.0.2 path was not
  rerun live after this change.
- **Module block copy check and post-change message (section 1), revised
  2026-11-24:** the check for newer copies now compares each newer copy's folder
  with the location that `Install-Module` recorded, so a copy with the same version
  as an installed one, or a copy outside the all-users module folder, also stops
  the block before any change. With mocked module cmdlets in PowerShell 7.5, the
  block stopped with `No changes were made` and no install or uninstall call for a
  hand-placed copy with the same version as an installed one (with and without
  4.0.2 already present) and for a copy installed for the current user only; the
  earlier cases above still stopped or continued as before. When an uninstall
  failed or a newer copy remained after removal, the block stopped with
  `Post-change verification failed` and named whether it installed 4.0.2 and the
  versions it had uninstalled. On the registered Azure Local node described below
  (Windows PowerShell 5.1, recipe requiring 5.5.3), the revised block printed
  `KEEP-MODULES`, the module inventory was unchanged, and, read without changes,
  the location recorded by `Install-Module` matched the folder of each installed
  Az.Accounts copy. The 4.0.2 path was not rerun live after this change.
- **Policy listing columns (section 4), revised 2026-11-24:** with Azure CLI
  2.85.0, the revised loop ran read-only against an existing resource group and
  printed one line per assignment with four columns: the assignment ID, display
  name, enforcement mode, and policy definition or initiative ID. The last segment
  of each ID matched the assignment name. With a test-only `$top=1`, the loop
  followed `nextLink` and printed the same lines. The `RequestDisallowedByPolicy`
  message recorded in the cause 4 run lists the assignment's display name under
  `name` and its full ID under `id`.
- **Cause 4:** an Azure Policy assignment that denies Azure Arc machine resources
  in the target resource group reproduced exit code 42 with `AZCM0042` and
  `httpStatusCode:403` (`RequestDisallowedByPolicy`). After the assignment was
  removed, the retry connected. Separately, against a throwaway resource group
  with the same deny assignment, the section 4 commands, in their form before the
  policy listing was changed to follow `nextLink`, ran unchanged except for
  their placeholders, in bash and in PowerShell with Azure CLI 2.85.0. They
  returned `Registered`, the required roles, and the deny assignment together with
  assignments inherited from the subscription and a management group.
  `az policy assignment list --resource-group`, with or without
  `--disable-scope-strict-match`, returned only the resource group's own
  assignment.
- **Managed identity token source (section 3, step 1), 2026-11-24:** on a
  registered node of an Azure Local instance (solution 12.2701.1004.15, Windows
  PowerShell 5.1, Az.Accounts 5.5.3, Azure CLI 2.90.0), `Connect-AzAccount -Identity -Scope Process`
  and `az login --identity --allow-no-subscriptions` signed in as the node's
  system-assigned identity, and the section 3 Azure PowerShell and Azure CLI blocks,
  in their earlier form that passed the tenant parameter, ran unchanged except for
  the tenant placeholder. Each produced a plain-text
  token whose tenant matched; the Azure PowerShell token, served from the node's
  token cache, had about 3 hours left of its 24-hour lifetime. Script block logging
  was turned on by policy on that node. In an earlier run, a token from the same
  identity, passed to a disposable Windows Server 2022 machine, failed the agent's
  connect command with exit code 42, `AZCM0042`, and a 403 while the identity had
  no role; after **Azure Connected Machine Onboarding** was granted on the
  throwaway resource group only, retries at 3 and 11 minutes still returned 403,
  and the retry at about 20 minutes connected (machine created by the identity).
  On a disposable machine before and after the agent was installed, but before it
  connected, the managed identity sign-in failed (no endpoint, then
  `service_unavailable`), which confirms that the failing node cannot use its own
  identity. The section 3 `az resource show`, `az role assignment create`, and
  `az role assignment delete` commands, in their form before the existing-assignment
  check was added, ran unchanged except for their placeholders against a throwaway
  resource group, and the assignment list was empty afterward.
- **Token request without a tenant parameter (section 3, step 2), revised
  2026-11-24:** on the same registered node, after `Connect-AzAccount -Identity -Scope Process`
  and, separately, `az login --identity --allow-no-subscriptions`, the revised
  Azure PowerShell and Azure CLI blocks, which no longer pass `-TenantId` or
  `--tenant`, ran unchanged except for the tenant placeholder, in the form before
  they became single statements. Each produced a
  plain-text token whose tenant matched the node's registration tenant, with about
  11 and 8 hours left. With the managed identity, `az account get-access-token --tenant`
  for another tenant failed with `For managed identity account, getting access token for non-current tenants is not supported`,
  and `Get-AzAccessToken -TenantId` for another tenant returned a token from the
  identity's own tenant while reporting the requested tenant in `TenantId`, which
  is why the blocks check the tenant of the current sign-in instead. On a
  workstation signed in with a user account, the revised Azure CLI block produced a
  token for the matching tenant, stopped on a tenant mismatch, and stopped when
  `<tenant-id>` was not replaced. That a token minted before the role assignment is
  removed loses the permission that the assignment granted once the removal takes
  effect, while access through other role assignments remains, is based on the
  Azure RBAC documentation linked in section 3; it was not tested.
- **Token cleanup (section 3, step 4), 2026-11-24:** on the same registered node
  (Windows PowerShell 5.1, Az.Accounts 5.5.3, Azure CLI 2.90.0, script block
  logging on), after `Connect-AzAccount -Identity -Scope Process` and the Azure
  PowerShell token block, the token was passed as an argument into a loopback
  session created with `New-PSSession`; `Remove-PSSession` closed it. The step 4
  variable cleanup, in its earlier form, which did not yet remove `$credential`,
  then printed `Token variable cleared`, and after
  `Disconnect-AzAccount -Scope Process`, `Get-AzContext` returned nothing. After
  `az login --identity --allow-no-subscriptions` and the Azure CLI token block, run
  with a separate, empty Azure CLI profile folder, `az logout` succeeded and
  `az account show` reported `Please run 'az login' to setup account.` That folder
  never contained `msal_token_cache.bin`; after `az logout` it contained
  `azureProfile.json` and `msal_http_cache.bin`, whose contents were not inspected.
  The user profile's `.azure` folder was only listed, before and after, and was
  unchanged. The token blocks in this run were in their form before they became
  single statements, and step 4 then ran `az logout` alone; the current Azure CLI
  cleanup block, which also deletes the profile folder, is covered in the sign-in
  isolation bullet and the repository and service principal bullet below. The current variable cleanup, run locally in PowerShell 7.5 with dummy
  values, printed `Token and credential variables cleared`, also when none of the
  variables existed. The instruction to remove the role assignment on every exit after it is
  created is procedural; the delete command itself was validated in the role grant
  run below.
- **Sign-in isolation and role coverage (section 3, steps 1 and 4), revised
  2026-11-24:** on the same registered node (Windows PowerShell 5.1, Az.Accounts
  5.5.3 with context autosave on, one saved context already present), a separate
  PowerShell process ran `Connect-AzAccount -Identity -Scope Process`, then
  `Disconnect-AzAccount -Scope Process`, which removed the managed identity
  context from that process. A new session still listed the same one saved
  context, and the user profile's `.Azure` and `.IdentityService` folders, listed
  by file name, size, and time only, were unchanged. In Az.Accounts 5.5.3,
  `-Scope` is available in every `Connect-AzAccount` parameter set, including the
  service principal certificate, device code, and managed identity sets, and in
  every `Disconnect-AzAccount` parameter set; in this run, only the managed
  identity sign-in was run (the service principal certificate sign-in was run
  later; see the repository and service principal bullet). In another separate
  process, the step 1 line set `AZURE_CONFIG_DIR`
  to a folder that did not exist yet; `az login --identity --allow-no-subscriptions`
  created it and signed in, and the step 4 cleanup block, in its first form,
  before it turned off telemetry and before it stopped when the folder could not
  be deleted, printed
  `Procedure Azure CLI profile removed`, deleted the folder, and cleared the
  variable. Run with `AZURE_CONFIG_DIR` unset, or set to the default `.azure`
  folder, the block printed that nothing was removed and the folder remained. The
  default Azure CLI profile folder was listed the same way before and after and was
  unchanged. With Azure CLI 2.85.0, `az role definition list` returned the same 11
  **Azure Connected Machine Onboarding** actions that the role definition article
  lists. The section 3 coverage block, run read-only, printed `MISSING` with the
  three write and extension actions for a user-assigned identity that holds only a
  monitoring role, `COVERED` for an operator account that holds **Owner** and
  **Contributor** roles, and `LOOKUP-FAILED` for a malformed subscription ID, the
  same whether run as a file or piped into a new Bash shell. With `az` replaced by a
  Bash function, it printed `COVERED` for **Owner**, **Contributor**, and the
  Onboarding role; `MISSING` for **Azure Connected Machine Resource Administrator**
  alone (the four `Microsoft.GuestConfiguration` and `Microsoft.Insights` actions),
  for a custom role with only `Microsoft.HybridCompute/machines/write`, and for a
  wildcard custom role whose `notActions` excluded `machines/read`; `COVERED` when
  another role supplied the missing actions; and `LOOKUP-FAILED` for each failed
  lookup. No role assignment was created or deleted, and no machine was registered.
  Repeating the sign-in and token steps after a fixed 403 is procedural and was
  not rerun.
- **Blocks pasted line by line (sections 1 and 3), 2026-11-24:** when PSReadLine
  reads a paste as keystrokes, PowerShell runs each top-level statement as soon as
  it is complete, and a `throw` ends only that statement. To reproduce this, each
  block was split into its top-level statements, which were run one at a time in
  the same session, continuing after each error. In the earlier form of the
  section 1 block, the recipe check was separate from the statement that changes
  modules. With mocked module cmdlets in PowerShell 7.5, a run with no recipe, or
  with a recipe requiring 3.0.5, printed `UNKNOWN-STOP`, then installed 4.0.2,
  removed 5.5.3, and printed `REQUIRES-4.0.2`. The section 1 block is now a single
  statement. Run that way, it printed only `UNKNOWN-STOP`, made no install or
  uninstall call, and left the session's `$ErrorActionPreference` unchanged.
  Recipes requiring 4.0.2 and 5.5.3 still printed `REQUIRES-4.0.2` and
  `KEEP-MODULES`, run whole or line by line, and the 15 mocked cases above gave the
  same results as before. On the registered Azure Local node described above
  (Windows PowerShell 5.1, PSReadLine 2.0.0, recipe requiring 5.5.3), the revised
  block, run as one input, printed `KEEP-MODULES` and left the module inventory
  unchanged. Run line by line on that node, with `Install-Module` and
  `Uninstall-Module` replaced by functions that only recorded calls, and with the
  recipe read redirected to a missing file or to a recipe requiring 3.0.5, the
  earlier block printed `UNKNOWN-STOP` and then went on to the 4.0.2 checks: it
  printed `ARC42-DEPENDENT` for the node's other Az modules and stopped there. The
  revised block printed only `UNKNOWN-STOP`. Neither made a module call, and the
  inventory was unchanged. The earlier section 3 token blocks, run line by line
  with `<tenant-id>` not replaced, still requested a token after the placeholder
  stop. Each token block is now a single dot-sourced statement. Against stubbed
  token responses, the revised blocks requested no token in that case. With a
  matching tenant they left `$token` set in the session, cleared `$t` or `$r`, and
  restored the session's `$ErrorActionPreference`, run whole or line by line.
- **Automation status:** remains `proven` because the documented token fix
  (section 3, option 1) and policy fix (remove the denying assignment, then
  retry) each connected the machine live, including with a token minted off the
  node. The sign-in that produces the token is supplied by an operator, by
  automation that holds a pre-provisioned identity, or, without a person, by the
  managed identity of a registered machine that was granted the role ahead of time;
  see the automation boundary in section 3.
- **Status code routing, role lookup outcomes, and inherited roles (sections 3
  and 4), 2026-11-24:** the section 3 lookup block now prints `EXISTS`, `NONE`, or
  `LOOKUP-FAILED`. With `az` replaced by a Bash function, it printed `EXISTS` with
  the ID for a successful call that returned one, `NONE` for a successful empty
  call, and `LOOKUP-FAILED` for a failed call, both when run as a block and when
  pasted into a new Bash shell. With Azure CLI 2.85.0, read-only against an
  existing user-assigned identity and its resource group, the block printed `NONE`
  for that identity, `LOOKUP-FAILED` for a malformed subscription ID, and `NONE`
  for a resource group that does not exist; the inherited-roles listing printed the
  identity's one role and its scope. No role assignment was created or deleted in
  this run. The routing of 429 and 5xx responses follows the linked Azure Resource
  Manager throttling and Service Health documentation; neither response was
  reproduced. That deleting the temporary assignment leaves access from other
  assignments in place follows from the additive role model in the linked Azure
  RBAC overview; it was not tested.
- **Not validated:** device code sign-in (option 2, and the operator's
  `Connect-AzAccount -UseDeviceAuthentication` sign-in in option 1), which needs a
  person; where a device code sign-in stores its tokens without
  `Disable-AzContextAutosave -Scope Process`, and that it sets `EnableLoginByWam`
  to `false`, are taken from the Az.Accounts source (`ConnectAzureRmAccount.cs`),
  and `Update-AzConfig -EnableLoginByWam $true` was not run; the service principal client secret sign-in is covered by the
  2026-11-25 bullet below; service principal tokens
  passed to registration (the service principal held no role); a token that Azure rejects because it expired (expiry was
  tested only against stubbed responses); the quota variant of cause 4 (the
  missing-role variant is covered by the managed identity run above); a real image
  whose recipe requires 4.0.2 (none was available, so a staged recipe file stood
  in); and the full bootstrap command on an unregistered Azure Local machine,
  including whether it needs roles beyond **Azure Connected Machine Onboarding**
  when the token comes from a managed identity. No unregistered Azure Local machine
  was available for that run. The section 4 object ID lookups for a service
  principal (`az ad sp show`) and a user (`az ad signed-in-user show`) were not run;
  the managed identity lookup (`az resource show`) and the role list command were.
  The Windows event logs were not characterized for this failure: in one run of the agent's connect command on a test machine, a query of the Application and System logs for the 10 minutes up to and including the failed attempt, filtered to the Arc agent's providers, returned only event IDs 348 (Azure Arc Proxy) and 148 (Azure Hybrid Instance Metadata Service), whose messages were not read, and no other log and no run of the full bootstrap on an Azure Local image were checked.
- **Repository choice and service principal cleanup (sections 1 and 3),
  2026-11-24:** with mocked module and repository cmdlets in PowerShell 7.5, the
  section 1 block, on the 4.0.2 path, stopped with `No changes were made` and made
  no `Install-Module` or `Uninstall-Module` call when a version it would remove, or
  4.0.2 when it had to be installed, was not in the repository, and when the
  repository was not registered. It used an internal repository name for every
  repository command when `$Repository` was set to one, did not query the
  repository when 4.0.2 was already present and only newer versions were checked,
  and made no repository call for a 5.x recipe. The 15 earlier mocked cases gave
  the same output, errors, and module changes as before. The rollback block, with
  mocked cmdlets, installed from the PowerShell Gallery by default, used an
  internal repository name when `$Repository` was set to one, and stopped with
  `Nothing was installed` when the exact version was not found, when the
  repository was not registered, or when the placeholder was not replaced. On the
  registered Azure Local node (Windows PowerShell 5.1, PowerShellGet 2.2.5, recipe
  requiring 5.5.3), the revised block, run as one input, printed `KEEP-MODULES`, and
  the module inventory was identical before and after; `Find-Module -RequiredVersion`
  found 4.0.2, 5.5.1, and 5.5.3 in the PowerShell Gallery. The 4.0.2 path and the
  rollback were not run against a real repository after this change. A throwaway
  service principal with no role assignment was created in a lab tenant for the
  sign-in checks and deleted afterward. On that node, with context autosave on for
  the user, `Connect-AzAccount -ServicePrincipal -CertificateThumbprint -Scope Process`
  signed in and issued an ARM token; the user profile's `.Azure` folder, listed by
  file name, size, and time, was unchanged while signed in and after
  `Disconnect-AzAccount -Scope Process`, a new process had no saved context for the
  service principal, and the current context reverted to the context saved before
  the test. The throwaway certificate was then removed from the store. That
  sign-in ran without `Disable-AzContextAutosave -Scope Process`, which step 1 now
  runs first; a certificate sign-in stores no secret. With Azure
  CLI 2.85.0 on a macOS workstation and a new `arc42-az-*` profile folder, `az login --service-principal`
  with a certificate and, separately, with a client secret signed in and issued a
  token. The service principal entry recorded the application ID, tenant, and the
  certificate file's path (not its content) for the certificate, and the client
  secret for the secret; the token cache file was in the same folder. The step 4
  cleanup block printed `Procedure Azure CLI profile removed` and deleted the
  folder, and the certificate file stayed where it was. In the first run, the
  telemetry upload that followed `az logout` recreated the folder within seconds,
  holding only `logs/telemetry.log`; with telemetry turned off for `az logout`, as
  the block now does, the folder was still absent 45 seconds later in both runs.
  On Windows, the Azure CLI encrypts these files and names them differently
  ([MSAL-based Azure CLI](https://learn.microsoft.com/cli/azure/msal-based-azure-cli));
  the Windows file names were not observed. After this run, the Azure CLI cleanup
  block was changed to stop with an error and keep `AZURE_CONFIG_DIR` when the
  folder cannot be deleted completely. That form was run only locally, in
  PowerShell 7.5 on macOS against a dummy profile folder without a sign-in: it
  printed `Procedure Azure CLI profile removed` and removed the folder and the
  variable; with a file that could not be deleted, it stopped with the
  `Could not delete` error and kept the folder and the variable, and a rerun after
  the file could be deleted removed both; with the variable unset, it changed
  nothing. It was not rerun on Windows or after a real sign-in. The section 1
  block was also changed after this run to count 4.0.2 as present only when it is
  in the all-users module folder. With mocked module and repository cmdlets in
  PowerShell 7.5, the 26 mocked module and rollback cases described above (the 15
  earlier cases and the 11 added in this run) gave the same
  results, and with 4.0.2 installed only for the current user, the block installed
  4.0.2 for all users before it removed 5.5.3, where the earlier form removed 5.5.3
  without installing it. This change was not run on a node.
- **Role grant and policy listing, revised 2026-11-24:** with Azure CLI 2.85.0
  against a throwaway resource group and two throwaway user-assigned identities,
  the section 3 role commands ran unchanged except for their placeholders. For an
  identity without the role, the `az role assignment list` check printed nothing,
  `az role assignment create` printed the new assignment ID, the check then printed
  that same ID, and `az role assignment delete --ids` removed it. For an identity
  whose assignment was created beforehand to stand in for other automation, the
  check printed that assignment's ID, so the procedure created and deleted nothing,
  and that assignment remained. The section 4 policy loop, with its earlier
  columns, listed the three assignments that apply to the resource group in one
  page. To confirm that it
  follows `nextLink`, it was also run with a test-only `$top=1` added to the first
  URL: a single `az rest` call then returned one assignment and a `nextLink`, and
  the loop followed the links and listed the same three assignments. The resource
  group, identities, and assignments were deleted afterward. These were not rerun
  with a managed identity of a registered machine.
- **Client secret sign-in and context autosave, 2026-11-25:** on the registered
  Azure Local node (Windows PowerShell 5.1, Az.Accounts 5.5.3), in the new profile
  of a throwaway local account with context autosave on for the user (the
  default), a throwaway service principal with a client secret and no role
  assignment signed in with
  `Connect-AzAccount -ServicePrincipal -Credential -Tenant -Scope Process` and
  issued an ARM token. Without `Disable-AzContextAutosave -Scope Process`, the
  sign-in wrote `keystore.cache` (502 bytes) to `%USERPROFILE%\.Azure`; after
  `Disconnect-AzAccount -Scope Process`, and again in a new process, the
  decrypted file still held the application ID and the client secret. The file
  was then deleted. With `Disable-AzContextAutosave -Scope Process` run first,
  the command printed `Mode` `Process`, the sign-in and token request worked, no
  `keystore.cache` was written, the folder listing (file name, size, and time)
  did not change from before the sign-in to after the sign-out, a new process had
  no context for the service principal, and `Get-AzContextAutosaveSetting -Scope CurrentUser`
  still returned `CurrentUser`. In both runs, loading Az.Accounts created its own
  settings files in `%USERPROFILE%\.Azure`, with no credentials, and the
  service principal sign-in wrote nothing to `%LOCALAPPDATA%\.IdentityService`.
  The account, its profile, and the service principal were deleted afterward.
  The `AZURE_CONFIG_DIR` line in step 1 was run in PowerShell 7.5 on macOS, where
  `$env:TEMP` is not set: the earlier form stopped with `Cannot bind argument to
  parameter 'Path' because it is null` and did not set the variable, and the
  current form set an `arc42-az-*` folder under the temporary folder, which the
  step 4 Azure CLI cleanup block then removed. The current form was not run in
  Windows PowerShell 5.1 or after a real Azure CLI sign-in.

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-25 | Every Azure PowerShell sign-in in section 3 now runs `Disable-AzContextAutosave -Scope Process` first. `-Scope Process` alone does not stop Azure PowerShell from saving a client secret in `keystore.cache` or device code tokens in the shared token cache, and `Disconnect-AzAccount -Scope Process` does not remove them; section 3 now says so, names those locations, notes that a device code sign-in sets `EnableLoginByWam` to `false` for the user, and step 4 explains what to do if a sign-in ran without the command. The `AZURE_CONFIG_DIR` line now uses the system temporary folder, so it also works in PowerShell 7 on Linux and macOS, where `$env:TEMP` is not set. |
| 2026-11-24 | The section 1 module block and its rollback now install from the repository in `$Repository`, which defaults to the PowerShell Gallery and can name an approved internal repository. Before it changes anything, the module block confirms that the repository is registered and has 4.0.2, when it must be installed, and every version it would remove, so the rollback can restore them; otherwise it stops with `No changes were made`. The rollback confirms the exact version with `Find-Module` and stops with `Nothing was installed` if it is missing. Section 1 lists the PowerShell Gallery download hosts that must be reachable. Section 3 adds a client secret sign-in that prompts with `Get-Credential` instead of placing the secret in script text, and step 4 states what each sign-out removes, clears `$credential`, deletes a certificate file copied only for this procedure, and keeps Azure CLI telemetry from recreating the procedure's profile folder. |
| 2026-11-24 | Section 3 now skips the temporary **Azure Connected Machine Onboarding** assignment only when the identity's roles together grant every action of that role, not just `Microsoft.HybridCompute/machines/write`; it lists those actions and adds a read-only check that prints `COVERED`, `MISSING`, or `LOOKUP-FAILED`. Every Azure PowerShell sign-in now uses `-Scope Process` in a session used only for this procedure, and the Azure CLI uses a separate profile folder that step 4 removes, so cleanup no longer touches sign-ins saved earlier; step 4 warns against running `Disconnect-AzAccount` without `-Scope Process`. For a 403, the status code table, section 4, and step 4 now say that the fix is the permission, policy, or quota, and that the retry needs a fresh sign-in and token when the earlier one was cleared or is near expiry. |
| 2026-11-24 | The status code table now sends only 403, `RequestDisallowedByPolicy`, and quota errors to section 4; a 429 is throttling (wait for the `Retry-After` interval, then retry), a 5xx is a transient service failure (retry later, check Azure Service Health, contact support if it persists), and other statuses go to support. Section 4 no longer states that any non-401 response means the token was accepted. The section 3 role lookup now prints `EXISTS`, `NONE`, or `LOOKUP-FAILED`, and the assignment is created only after `NONE`, so a failed lookup no longer looks like a missing assignment. Section 3 adds a read-only listing of the identity's roles at the resource group, including inherited ones, and states that deleting the temporary assignment removes only that assignment's grant, not access from other roles. |
| 2026-11-24 | The section 1 module block now runs as a single statement (`& { ... }`), so a failed recipe check stops the module changes even when the block is pasted line by line, and its `$ErrorActionPreference` setting no longer carries over into the session. The section 3 token blocks are now single dot-sourced statements (`. { ... }`): a failed check stops the token request, `$token` stays in the session for step 3, and the session's `$ErrorActionPreference` is restored. Sections 1 and 3 now say to paste or run each block whole. |
| 2026-11-24 | The section 1 module block now checks for newer Az.Accounts copies that were not installed with `Install-Module` before it installs 4.0.2, so that stop, like the other precondition stops, happens before any module changes. The section 4 role check now uses the object ID of the identity that minted the registration token, with a lookup for each identity type, instead of the account that runs the checks. |
| 2026-11-24 | Section 3 now checks whether the managed identity already holds **Azure Connected Machine Onboarding** on the resource group before granting it. If it does, no assignment is created and none is deleted afterward; otherwise the cleanup deletes only the assignment that the procedure created, by its ID. The section 4 policy listing now follows `nextLink`, so assignments on later result pages are not missed. |
| 2026-11-24 | The section 1 module block now stops before any change for every Az.Accounts copy that `Install-Module` cannot remove, including a copy with the same version as an installed one. Its final check, which runs after the changes, now reports what it installed and uninstalled and how to roll back. Section 3 now describes what removing the role assignment means for a token already minted. The section 4 policy listing now prints each assignment's ID and policy definition ID, and explains how to match them to the denying assignment named in the error. |
| 2026-11-24 | Section 3 now explains that Azure checks role assignments on each request: once the removal of the managed identity's role assignment takes effect, no token of that identity can register machines through that assignment, including one minted before the removal, although the token remains a valid credential until it expires. The section 3 token blocks no longer pass `-TenantId` or `--tenant`, which the Azure CLI does not support for a managed identity; they request the token for the current sign-in and still stop if its tenant does not match the deployment plan. |
| 2026-11-24 | Section 3 now states that once the managed identity's **Azure Connected Machine Onboarding** assignment is created, every stop or abandoned attempt must remove it, and the token block stops, the 403 stop, the section 4 stop, and the support section point to that removal. A new section 3, step 4 clears the token on every machine and session where it existed: it removes the variables and any remote session, signs out of the sign-ins this procedure made, and explains that clearing local copies does not revoke the token. |
| 2026-11-24 | The 429 and 5xx rows now say that a retry with a token is a new attempt: repeat section 3, option 1, steps 1 to 3 after waiting, to get a fresh token and, if needed, the temporary role assignment again, then clean up again. |
| 2026-11-24 | The Azure CLI cleanup block now stops with an error and keeps `AZURE_CONFIG_DIR` when the procedure's profile folder cannot be deleted completely, so it reports success only after the folder is gone and the cleanup can be run again. |
| 2026-11-24 | The section 1 block now counts Az.Accounts 4.0.2 as present only when it is in the all-users module folder, so a copy installed only for the current user no longer lets it remove the shared newer versions; in that case it installs 4.0.2 for all users first. |
| 2026-11-24 | The **Windows event logs** entry under "Where this problem appears" no longer states that the Application and System logs do not record this failure, which validation did not establish; it now marks that surface as not characterized and points to the PowerShell status and the bootstrap and agent log files. The validation status now states which earlier form of each sign-in, token, cleanup, and rollback block was run, and what was checked for the current form. |
