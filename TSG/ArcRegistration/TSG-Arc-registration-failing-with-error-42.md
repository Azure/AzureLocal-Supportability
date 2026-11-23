<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {"type": "manual", "signal": "Bootstrap Arc registration error 42"},
  "validation": {
    "fidelity_level": "L2",
    "technical_grade": "C",
    "reproduction_substrate": "vm",
    "automation_status": "ready",
    "last_validated": "2026-11-23",
    "spec_ref": "AzLocal_ArcRegistration_Error42"
  }
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
- [4. Permissions, policy, or quota (HTTP 403 or another non-401 status)](#4-permissions-policy-or-quota-http-403-or-another-non-401-status)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)
- [Validation status of this article](#validation-status-of-this-article)

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
`System.Security.SecureString` instead of the token. A 403 or another status
points to permissions, policy, or quota instead; see
[cause 4](#4-permissions-policy-or-quota-http-403-or-another-non-401-status).

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
- **Windows event logs:** The Application and System logs do not record this failure; the agent writes only service start events there. Bootstrap diagnostics are Event Tracing for Windows (ETW) trace files named `Microsoft-AzureStack-Bootstrap-Diagnostics-EventSource-<timestamp>.etl` in the bootstrap logs directory below, not an Event Viewer channel.
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
4. Permissions, policy, or quota (HTTP 403 or another non-401 status).

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

Run the complete block below in an elevated Windows PowerShell session on the
node being registered. The release check reads the node's own image recipe, which
does not require a deployed cluster. The check reads the node's current recipe,
which reflects its installed image, including any image update applied during
registration. Rerun this block after any reboot that registration triggers. It keeps every installed version when the
recipe requires 5.x or later. Only a recipe explicitly requiring 4.0.2 permits
removal of newer versions; older versions and 4.0.2 are preserved. If the recipe
is missing, ambiguous, or different, it stops without changing any modules.

**Changes:** On the 4.0.2 path only, this installs 4.0.2 first if missing and
uninstalls newer Az.Accounts versions, printing each version and path as
`ARC42-REMOVING` before it removes it. It does not change other modules or register
the node. Installing 4.0.2 needs access to the PowerShell Gallery. Do not run this
legacy path during deployment or solution servicing.

```powershell
$ErrorActionPreference = 'Stop'
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
    if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        Install-Module -Name Az.Accounts -RequiredVersion 4.0.2 -Scope AllUsers `
            -Repository PSGallery -Force -ErrorAction Stop | Out-Null
        $available = @(Get-Module -ListAvailable -Name Az.Accounts)
    }
    if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        throw 'Required version 4.0.2 was not installed; nothing will be removed.'
    }
    # PowerShellGet 2.x returns Version as a string, so cast before comparing.
    $galleryVersions = @(Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction SilentlyContinue |
        ForEach-Object { [version]$_.Version })
    $newer = @($available | Where-Object { $_.Version -gt [version]'4.0.2' } | Sort-Object Version)
    $unmanaged = @($newer | Where-Object { $galleryVersions -notcontains $_.Version })
    if ($unmanaged.Count) {
        throw ('Uninstall-Module cannot remove these newer Az.Accounts copies; nothing was removed: ' +
            (($unmanaged | ForEach-Object { "$($_.Version) at $($_.ModuleBase)" }) -join '; '))
    }
    foreach ($module in $newer) {
        Write-Output "ARC42-REMOVING: Az.Accounts $($module.Version) at $($module.ModuleBase)"
    }
    foreach ($version in @($newer | ForEach-Object { $_.Version } | Sort-Object -Unique)) {
        Uninstall-Module -Name Az.Accounts -RequiredVersion $version.ToString() -Force -ErrorAction Stop
    }
    $remaining = @(Get-Module -ListAvailable -Name Az.Accounts)
    $left = @($remaining | Where-Object { $_.Version -gt [version]'4.0.2' })
    if ($left.Count) {
        throw ('Newer Az.Accounts copies remain; stop before retrying registration: ' +
            (($left | ForEach-Object { "$($_.Version) at $($_.ModuleBase)" }) -join '; '))
    }
    if (-not ($remaining | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        throw 'Module verification failed; stop before retrying registration.'
    }
    Write-Output 'ARC42-MODULE-GATE: REQUIRES-4.0.2'
}
```

If the block reports `KEEP-MODULES`, proceed to the token sections. If it reports
`UNKNOWN-STOP` or throws, stop; do not substitute a guessed version. For other
recipe/module drift, use [Test PowerShell Module Version](../EnvironmentValidator/Troubleshooting-Test-PowerShell-Module-Version.md).
If the image recipe is unavailable, contact Microsoft support with the image
version and module inventory; installed versions alone cannot prove the requirement.

If the block stops because a newer copy was not installed with `Install-Module`
(for example, a copy placed in a module folder by hand or by another tool), it
names the version and folder and removes nothing. Do not delete that folder to
force the workaround; contact Microsoft support with the message.

**Rollback:** Keep the `ARC42-REMOVING` lines the block printed. To restore a
removed version, for example after registration completes, run this for each
printed version (requires access to the PowerShell Gallery).

**Changes:** installs the named Az.Accounts version for all users. It does not
remove 4.0.2 or change other modules. A newer version installed again before
registration finishes can reintroduce the problem that the 4.0.2 path addresses.

```powershell
Install-Module -Name Az.Accounts -RequiredVersion '<removed-version>' -Scope AllUsers -Repository PSGallery -Force
```

## 2. ARM access token is expired

### Issue Validation

Check the response's `ExpiresOn`, not a fixed one-hour age assumption.
The [agent does not renew a supplied access token](https://learn.microsoft.com/en-us/azure/azure-arc/servers/azcmagent-authentication).
The token block in section 3 stops unless at least 10 minutes remain.

### Resolution

Rerun your original initialization command without `-ArmAccessToken` (option 1
in section 3), or create a fresh ARM access token using the complete block in
section 3 (option 2) and retry your original initialization command in the same
session.

## 3. ARM access token is passed incorrectly

### Issue Validation
Sometimes, azcmagent exit code 42 is seen when the ARM access token is passed as an
object instead of a string. With Az.Accounts 5.x, `.Token` is a `SecureString` by
default, so selecting the property alone is not sufficient.

### Resolution

**Option 1 (simplest): let the registration command sign in.** The
`-ArmAccessToken` parameter is optional. If you omit it, the script prompts for
device code authentication
([script parameters](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway#step-1-review-script-parameters)).
Rerun your original initialization command without `-ArmAccessToken`, keep its
other parameters unchanged, and complete the sign-in with the code it displays.
No token conversion or module change is needed.

**Changes:** Retrying initialization can create Azure resources, change the
node's registration configuration, and, when an update is required, install it
and restart the node.

**Option 2: pass a converted token.** Use this when you must supply
`-ArmAccessToken`, for example from automation. If this PowerShell session has
no Azure sign-in, sign in first, replacing `<tenant-id>` with the resource
tenant ID from the deployment plan:

```powershell
Connect-AzAccount -Tenant '<tenant-id>' -UseDeviceAuthentication
```

**Changes:** signs you in to Azure PowerShell. By default the sign-in context is
saved in your user profile; run `Disconnect-AzAccount` after registration to
remove it. It does not change the node or Azure resources.

Replace `<tenant-id>` in the block below with the same tenant ID, then run the
complete block. It requests an ARM token and converts only its `Token` property;
it does not sign in, switch context, or display the token.

```powershell
$ErrorActionPreference = 'Stop'
$token = $null
$t = $null
$TenantId = '<tenant-id>'
$parsedTenant = [guid]::Empty
if (-not [guid]::TryParse($TenantId, [ref]$parsedTenant) -or $parsedTenant -eq [guid]::Empty) {
    throw 'Replace <tenant-id> with the resource tenant ID before requesting a token.'
}
try {
    $t = Get-AzAccessToken -ResourceTypeName Arm -TenantId $TenantId -ErrorAction Stop
    if (-not $t.ExpiresOn -or [DateTimeOffset]$t.ExpiresOn -le [DateTimeOffset]::UtcNow.AddMinutes(10)) {
        throw 'Token expires within 10 minutes; sign in again with Connect-AzAccount and rerun this block, or use option 1.'
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
}
```

The conversion is compatible with Windows PowerShell 5.1. In this **same session**,
pass `-ArmAccessToken $token` to the
[initialization command for your deployment](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway),
keeping its other parameters unchanged. If delayed, repeat the complete token
block. Do not print, export, transcribe, or include the token in a ticket; clear
`$token = $null` after the initialization attempt.

**Changes:** The token block only sets session variables. Retrying initialization
can create Azure resources and change the node's registration configuration and,
when an update is required, install it and restart the node.

Verify resolution using the original bootstrap status and the node's Azure Arc
registration state. If registration still fails, retain the complete sanitized
error and follow the [agent troubleshooting guidance](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard)
instead of repeating module downgrades.

## 4. Permissions, policy, or quota (HTTP 403 or another non-401 status)

### Issue Validation

In `azcmagent.log`, the `AZCM0042` line for the failed attempt is followed by a
status code other than 401, for example `status code 403`. The token was
accepted, so the module and token steps in sections 1 to 3 do not apply; do not
change modules or request a new token for this pattern.

### Resolution

Check the subscription and resource group against
[Assign required permissions for Azure Local deployment](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-arc-register-server-permissions):

- The required resource providers, including `Microsoft.HybridCompute`, are
  registered in the subscription.
- The account that signs in is the resource group owner or holds the
  **Azure Connected Machine Onboarding** and **Azure Connected Machine Resource
  Administrator** roles on the resource group.
- No Azure Policy assignment denies creation of Azure Arc machine resources in
  that resource group, and the subscription has not reached a resource quota.

These are read-only checks; any role, provider, or policy change is made by the
subscription owner using the linked article. Then retry your original
initialization command.

**Changes:** Retrying initialization can create Azure resources, change the
node's registration configuration, and, when an update is required, install it
and restart the node.

## When to contact Microsoft support

Contact Microsoft support when the module block in section 1 stops, when
registration still fails with exit code 42 after the applicable section, or when
`azcmagent.log` shows a status code that the checks in section 4 do not explain.

Collect logs on the affected node by running `Collect-ArcBootstrapSupportLogs`,
as described in [Register Azure Local with Azure Arc](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway), and share them
with Microsoft support. Also include:

- The exact error text and the time of the failed attempt.
- The output of `Get-ArcBootstrapStatus` and, from section 1, the module block's
  output and the `Get-Module -ListAvailable -Name Az.Accounts` inventory.
- The `AZCM0042` and status code lines from
  `%ProgramData%\AzureConnectedMachineAgent\Log\azcmagent.log`.

> [!WARNING]
> Bootstrap logs, PowerShell transcripts, and command history can contain access
> tokens. Before you attach any file or paste output into a ticket, review it and
> remove tokens and other secrets. Never include the value of `$token`.

## Validation status of this article

Validated in a lab on solution 12.2701.1004.15 with Windows PowerShell 5.1:

- **Token fix (section 3, option 2), real node:** on a disposable test node with
  Az.Accounts 5.5.3, the unconverted token reproduced exit code 42 with
  `status code 401`, and the converted token from the token block connected the
  machine. The agent's connect command was run directly; the full bootstrap was
  not run on an unregistered node.
- **Recipe gate, real node:** on a node whose recipe requires Az.Accounts 5.5.3,
  the section 1 block printed `KEEP-MODULES` and changed no modules.
- **4.0.2 module path, stand-in only:** no image that requires 4.0.2 was
  available, so the install-and-remove branch ran against a recorded stand-in,
  not a real node. The current version of that branch, including the
  `Get-Module -ListAvailable` inventory and the string-to-version comparison
  fix, has been exercised only with mocked cmdlets in PowerShell 7, not on
  Windows PowerShell 5.1 or a real node.
- **Not validated:** device code sign-in (option 1) and the section 4 checks.
