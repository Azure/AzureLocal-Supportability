<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {"type": "manual", "signal": "Bootstrap Arc registration error 42"},
  "validation": {
    "fidelity_level": "L2",
    "technical_grade": "B",
    "reproduction_substrate": "vm",
    "automation_status": "ready",
    "last_validated": "2026-11-23",
    "spec_ref": "AzLocal_ArcRegistration_Error42"
  }
}
-->

# Symptoms
When trying to Arc Register the new node, user sees the error code 42.

# Error: 
Bootstrap reported error: A ArcAgentConnectionException error occurred with the message: 'AZCMAgent command failed with error:  >> exitcode: 42. Additional Info: See https://aka.ms/arc/azcmerror'

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
does not require a deployed cluster. It keeps every installed version when the
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
    if ($accounts.Count -ne 1 -or [string]$accounts[0].PackageType -ne 'PowerShellModule') {
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
