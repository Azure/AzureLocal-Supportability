<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {"type": "manual", "signal": "Bootstrap Arc registration error 42"},
  "validation": {
    "fidelity_level": "L3",
    "technical_grade": "A",
    "reproduction_substrate": "vm",
    "automation_status": "proven",
    "last_validated": "2026-11-23",
    "spec_ref": "AzLocal_ArcRegistration_Error42"
  }
}
-->

# Symptoms
When trying to Arc Register the new node, user sees the error code 42.

**Severity:** High. New-node registration blocks deployment or adding that node.
This error alone does not establish an outage on existing nodes.

# Error: 
Bootstrap reported error: A ArcAgentConnectionException error occurred with the message: 'AZCMAgent command failed with error:  >> exitcode: 42. Additional Info: See https://aka.ms/arc/azcmerror'

The quoted `exitcode: 42` is the Azure Connected Machine agent process exit
code. Its corresponding `AZCM0042` error means that creation of the Azure
Arc-enabled server resource failed, not that Az.Accounts is necessarily wrong.
Read the accompanying error before choosing a fix; permissions and resource
creation failures also require investigation
([agent error and exit codes](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard#agent-error-codes)).

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
points to permissions or policy instead.

## Version-dependent behavior

The recipe check in section 1 decides which row applies to the machine being
registered. Do not infer the requirement from the cluster's target solution
version, from an installed module, or from the `11.x` versus `12.x` train alone.

| Node's image recipe | Applicable images and behavior | What to do |
| --- | --- | --- |
| Requires Az.Accounts 4.0.2 | Older image recipes can require 4.0.2 on either OS train, including older recipes that do not record a package type. A newer installed module can change the token type expected by an older registration script; error 42 alone does not prove this is the cause. | Use the guarded 4.0.2 path in section 1, then request and pass a plain-text ARM token using sections 2 and 3. |
| Requires Az.Accounts 5.x or later | Newer image recipes require the newer module. `Get-AzAccessToken.Token` is a `SecureString` by default starting with 5.0.0. An unconverted token is not a valid replacement for the plain-text token parameter. | Keep the product modules. Check expiry and convert the token using sections 2 and 3; do not downgrade to 4.0.2. |
| Missing or unrecognized recipe information | The recipe file is missing, lists no Az.Accounts package or more than one, names a package type other than `PowerShellModule`, or requires a version other than 4.0.2 or 5.x and later. The installed module inventory cannot establish the image requirement. | Stop without changing modules and contact Microsoft support. |

See [Azure PowerShell secret handling](https://learn.microsoft.com/en-us/powershell/azure/protect-secrets)
for the token-type change and [Azure Local release information](https://learn.microsoft.com/en-us/azure/azure-local/release-information-23h2)
for release support status. The module requirement remains a per-node recipe check.

## Where this problem appears

- **PowerShell on the node:** The initialization command reports bootstrap failure and `ArcAgentConnectionException`; `Get-ArcBootstrapStatus` reads the bootstrap status without retrying registration.
- **Azure portal:** Check the intended resource group under **Azure Arc > Machines** for the expected machine. When resource creation fails, the machine does not appear there; absence alone does not identify a token problem. Check the subscription, resource group, filters, and permissions before concluding it was not created.
- **Windows event logs:** The Application and System logs do not record this failure; the agent writes only service start events there. Bootstrap diagnostics are Event Tracing for Windows (ETW) trace files named `Microsoft-AzureStack-Bootstrap-Diagnostics-EventSource-<timestamp>.etl` in the bootstrap logs directory below, not an Event Viewer channel.
- **Windows Admin Center (standalone host):** If an existing connection to the server is available, use its **PowerShell** tool to run `Get-ArcBootstrapStatus`; read the same bootstrap status rather than interpreting an unrelated server-health alert as error 42.
- **Component / tool log files:** The agent's `%ProgramData%\AzureConnectedMachineAgent\Log\azcmagent.log` records each connection attempt, including the `AZCM0042` and status code lines shown above; `himds.log` records heartbeat and identity activity ([agent log locations](https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#windows-agent-installation-details)). The bootstrap logs directory `%SystemRoot%\System32\Bootstrap\Logs` holds the `.etl` trace files, `arcInstallLog-<timestamp>.txt`, and `setup.log`; setup logs describe installation, not necessarily the registration failure. Match timestamps to the failed attempt and remove tokens or other secrets before sharing diagnostics.

For a new machine that is not yet registered or clustered:

- **Cluster logs:** not applicable to the pre-cluster registration failure on a node that has not joined a cluster.
- **Failover Cluster Manager:** not applicable to the pre-cluster registration failure because the affected machine is not yet a clustered node or role.
- **Windows Admin Center in Azure:** not applicable before this machine is connected to Azure Arc; this experience requires an Arc-connected machine ([requirements](https://learn.microsoft.com/en-us/windows-server/manage/windows-admin-center/azure/manage-arc-hybrid-machines#hybrid-machine-requirements)).

# Potential causes
1. Az.Accounts version on the system is incorrect.
2. ARM access token is expired.
3. ARM access token is passed incorrectly.

# 1. Az.Accounts version on the system is incorrect

## Issue Validation
Run this cmdlet on each affected node to list installed versions:
`Get-InstalledModule -Name Az.Accounts -AllVersions`

Az.Accounts 5.0.0 changed the default `Get-AzAccessToken.Token` from plain text to
`SecureString` ([Azure PowerShell secret handling](https://learn.microsoft.com/en-us/powershell/azure/protect-secrets)).
Version 5.x is required by newer image recipes; its presence alone is not a module
version error. Convert the token as shown in section 3 instead of downgrading it.
For image/servicing version evidence, read
`(Get-Content -LiteralPath C:\ImageComposition\VSRInfo.json -Raw | ConvertFrom-Json).SolutionVersion`.
The recipe's Az.Accounts version, not this display value, controls the workaround.

## Resolution

Run the complete block below in an elevated Windows PowerShell session on the
node being registered. The release check reads the node's own image recipe, which
does not require a deployed cluster. A node being registered has not yet received
a solution update, so its recipe matches the image it was installed from, even
when it joins a cluster that runs a newer release. It keeps every installed version when the
recipe requires 5.x or later. Only a recipe explicitly requiring 4.0.2 permits
removal of newer versions; older versions and 4.0.2 are preserved. If the recipe
is missing, ambiguous, or different, it stops without changing any modules.

**Changes:** On the 4.0.2 path only, this installs 4.0.2 first if missing and
uninstalls newer Az.Accounts versions. It does not change other modules or register
the node. Do not run this legacy path during deployment or solution servicing.

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
    $installed = @(Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction Stop)
    if (-not ($installed | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        Install-Module -Name Az.Accounts -RequiredVersion 4.0.2 -Scope AllUsers `
            -Repository PSGallery -Force -ErrorAction Stop | Out-Null
    }
    $installed = @(Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction Stop)
    if (-not ($installed | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        throw 'Required version 4.0.2 was not installed; nothing will be removed.'
    }
    $installed | Where-Object { $_.Version -gt [version]'4.0.2' } |
        Select-Object -ExpandProperty Version -Unique | ForEach-Object {
            Uninstall-Module -Name Az.Accounts -RequiredVersion $_ -Force -ErrorAction Stop
        }
    $remaining = @(Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction Stop)
    if (-not ($remaining | Where-Object { $_.Version -eq [version]'4.0.2' }) -or
        ($remaining | Where-Object { $_.Version -gt [version]'4.0.2' })) {
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

# 2. ARM Access token is expired

## Issue validation

Check the response's `ExpiresOn`, not a fixed one-hour age assumption.
The [agent does not renew a supplied access token](https://learn.microsoft.com/en-us/azure/azure-arc/servers/azcmagent-authentication).

## Resolution

Create a fresh ARM access token using the complete block in section 3 and retry
your original initialization command in the same session.

# 3. ARM access token is passed incorrectly

## Issue Validation
Sometimes, AZCMAGENT Error 42 is seen when the ARM access token is passed as an
object instead of a string. With Az.Accounts 5.x, `.Token` is a `SecureString` by
default, so selecting the property alone is not sufficient.

## Resolution

Use an existing Azure PowerShell sign-in for your deployment. Replace
`<tenant-id>` with the resource tenant ID from the deployment plan, then run the
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
    if (-not $t.ExpiresOn -or [DateTimeOffset]$t.ExpiresOn -le [DateTimeOffset]::UtcNow) { throw 'Token has expired; request a fresh token.' }
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
can create Azure resources and change the node's registration configuration.

Verify resolution using the original bootstrap status and the node's Azure Arc
registration state. If registration still fails, retain the complete sanitized
error and follow the [agent troubleshooting guidance](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard)
instead of repeating module downgrades.
