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
    "last_validated": "2026-11-24",
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
`System.Security.SecureString` instead of the token. A 403 or another status
points to permissions, policy, or quota instead; see
[cause 4](#4-permissions-policy-or-quota-http-403-or-another-non-401-status).

### Which section to follow

Read the status code of the failed attempt in `azcmagent.log` first:

| The failed attempt shows | Follow | Who acts |
| --- | --- | --- |
| `status code 401` | [Section 1](#1-azaccounts-version-on-the-system-is-incorrect) (module check), then [sections 2 and 3](#3-arm-access-token-is-passed-incorrectly): mint a new plain-text token and retry | The node administrator, with a token from an identity that holds the required roles |
| `httpStatusCode:403` or another non-401 status | [Section 4](#4-permissions-policy-or-quota-http-403-or-another-non-401-status). Do not change modules or tokens | The subscription owner makes any role, provider, or policy change |
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

Run the complete block below in an elevated Windows PowerShell 5.1 session on the
node being registered (right-click **Windows PowerShell** and select **Run as
administrator**; do not use PowerShell 7). The release check reads the node's own
image recipe, which does not require a deployed cluster. The check reads the node's current recipe,
which reflects its installed image, including any image update applied during
registration. Rerun this block after any reboot that registration triggers. It keeps every installed version when the
recipe requires 5.x or later. Only a recipe explicitly requiring 4.0.2 permits
removal of newer versions; older versions and 4.0.2 are preserved. If the recipe
is missing, ambiguous, or different, it stops without changing any modules.
When a newer version is present, the 4.0.2 path also stops, before it installs or
removes anything, if any other available module declares in `RequiredModules` or
`ModuleList` that it needs an Az.Accounts version newer than 4.0.2, or if a newer
copy was not installed with `Install-Module`.
`Uninstall-Module -Force` skips PowerShellGet's dependency check, and current Az
modules declare their Az.Accounts minimum under `ModuleList`, so both lists are
read.

**[HIGH RISK]**

**Changes:** On the 4.0.2 path only, this installs 4.0.2 first if missing and
uninstalls newer Az.Accounts versions, printing each version and path as
`ARC42-REMOVING` before it removes it. It does not uninstall other modules or
register the node, but other modules that need a removed version stop loading.
Installing 4.0.2 needs access to the PowerShell Gallery. Do not run this legacy
path during deployment or solution servicing.

> [!WARNING]
> Removing a newer Az.Accounts version breaks any module that requires it: importing
> that module fails with `This module requires Az.Accounts version ...`. The block
> stops with `No changes were made` when an available module declares such a
> requirement, but it cannot detect a module that loads Az.Accounts without
> declaring it. The removal is undone only by reinstalling each printed version
> with the rollback command below, which needs access to the PowerShell Gallery.

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
    # PowerShellGet 2.x returns Version as a string, so cast before comparing.
    $galleryVersions = @(Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction SilentlyContinue |
        ForEach-Object { [version]$_.Version })
    $newer = @($available | Where-Object { $_.Version -gt [version]'4.0.2' } | Sort-Object Version)
    $unmanaged = @($newer | Where-Object { $galleryVersions -notcontains $_.Version })
    if ($unmanaged.Count) {
        throw ('Uninstall-Module cannot remove these newer Az.Accounts copies. No changes were made: ' +
            (($unmanaged | ForEach-Object { "$($_.Version) at $($_.ModuleBase)" }) -join '; '))
    }
    if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        Install-Module -Name Az.Accounts -RequiredVersion 4.0.2 -Scope AllUsers `
            -Repository PSGallery -Force -ErrorAction Stop | Out-Null
        $available = @(Get-Module -ListAvailable -Name Az.Accounts)
    }
    if (-not ($available | Where-Object { $_.Version -eq [version]'4.0.2' })) {
        throw 'Required version 4.0.2 was not installed; nothing will be removed.'
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
names the version and folder and makes no changes. Do not delete that folder to
force the workaround; contact Microsoft support with the message. If a hand-placed
copy has the same version as a copy installed with `Install-Module`, the block
treats that version as removable: it prints both copies as `ARC42-REMOVING`,
uninstalls the installed copy, and then stops at its final check, naming the copy
that remains. Use the rollback command below for the printed version and contact
Microsoft support.

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
(401 here, 403 or another status in [cause 4](#4-permissions-policy-or-quota-http-403-or-another-non-401-status)),
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
describes how to use it. Do not rely on roles that a deployment assigned to that
identity for other purposes; grant the registration role to it explicitly.

**Option 1 (automation and scripted runs): pass a plain-text ARM token.**

*Step 1: sign in as the identity that will mint the token.* Use an identity that
holds the required roles, on the machine where its credential is kept. For
automation this is normally off the node, on the automation host, so that no
service principal credential is placed on the node. For example, for a service
principal whose certificate is in that machine's certificate store, replace the
placeholders and run:

```powershell
Connect-AzAccount -ServicePrincipal -ApplicationId '<application-id>' -CertificateThumbprint '<certificate-thumbprint>' -Tenant '<tenant-id>'
```

An operator who mints the token instead signs in with device code, which needs a
person to complete it in a browser:

```powershell
Connect-AzAccount -Tenant '<tenant-id>' -UseDeviceAuthentication
```

**Changes:** signs in to Azure PowerShell. By default the sign-in context is
saved in the user profile; run `Disconnect-AzAccount` after registration to
remove it. It does not change the node or Azure resources.

*Managed identity of another registered machine (no person, no stored secret).*
An Azure Arc-enabled machine that is already registered and trusted, for example
another node of the same instance, can mint the token with its system-assigned
managed identity
([managed identity on Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication)).
Before the first use, the subscription owner looks up that identity and grants it
**Azure Connected Machine Onboarding** on the resource group where the failing node
registers, and on nothing else. Replace the `<machine-...>` placeholders with
that machine's subscription, resource group, and name (shown by `azcmagent show`
on that machine), and the others with the failing node's registration
subscription and resource group, then run:

```azurecli
az resource show --subscription '<machine-subscription-id>' --resource-group '<machine-resource-group>' --name '<machine-name>' --resource-type Microsoft.HybridCompute/machines --query identity.principalId -o tsv
az role assignment list --assignee-object-id '<principal-id>' --role 'Azure Connected Machine Onboarding' --scope '/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>' --query "[].id" -o tsv
```

The first command prints the identity's principal ID, which you use as
`<principal-id>`. If it prints nothing, the machine has no system-assigned
identity; stop and use another identity. The second command is read-only. If it
prints an assignment ID, the identity already holds the role on that resource
group, for example for other onboarding automation: do not create another
assignment, and do not delete that one after registration. If it prints nothing,
create the assignment and record the ID that it prints as `<assignment-id>`:

```azurecli
az role assignment create --assignee-object-id '<principal-id>' --assignee-principal-type ServicePrincipal --role 'Azure Connected Machine Onboarding' --scope '/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>' --query id -o tsv
```

**Changes:** adds one role assignment; until it is removed, anyone who can mint a
token on that machine can register machines into that resource group. Remove it
after registration with `az role assignment delete --ids '<assignment-id>'`,
which deletes only the assignment that this command created. Run that delete
command only for an ID that this create command printed.
A new assignment can take several minutes to apply; in validation it took about
20 minutes, and retries before then still failed with 403.

In validation, this role alone let the token register a machine with the agent's
connect command. The initialization command was not validated with this identity.
If its retry reports a 403, stop: do not grant this identity any other role or a
broader scope. If you created an assignment, remove it with the delete command
above, then mint the token from a service principal or operator account that
already holds the roles in the permissions article, or use device code (option 2).

Then, in an elevated Windows PowerShell 5.1 session on the registered machine,
sign in as its managed identity, and continue with step 2 in the same session:

```powershell
Connect-AzAccount -Identity -Scope Process
```

With the Azure CLI on that machine, use `az login --identity --allow-no-subscriptions`
followed by the Azure CLI block in step 2, and run `az logout` afterward.

**Changes:** signs in for the current PowerShell process only; nothing is saved.
Close the session, or run `Disconnect-AzAccount -Scope Process`, after
registration. `az login --identity` saves the sign-in in the Azure CLI profile
until `az logout`.

> [!IMPORTANT]
> Any local administrator of the minting machine, and any member of its
> **Hybrid Agent Extension Applications** group, can mint this identity's token.
> The token is valid for up to about 24 hours and cannot be revoked. Removing the
> role assignment is the only way to stop an issued token from registering
> machines, and it takes effect only after the role change applies. The machine
> caches the token, so it can have much less than 24 hours left; step 2 checks the
> remaining time.

*Step 2: mint and convert the token.* In the same session, replace `<tenant-id>`
in the block below with the resource tenant ID from the deployment plan (in the
Azure portal, **Microsoft Entra ID** > **Properties** > **Tenant ID**), then
run the complete block. It requests an ARM token and converts only its `Token`
property; it does not sign in, switch context, or display the token. The
conversion is compatible with Windows PowerShell 5.1. It stops if the identity
belongs to a different tenant, so a managed identity works only when its machine
is registered in the same tenant as the failing node.

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
}
```

If the automation host uses the Azure CLI instead of Azure PowerShell, sign in
as the service principal with `az login --service-principal --username '<application-id>' --certificate '<path-to-certificate.pem>' --tenant '<tenant-id>'`
(this saves the sign-in in the Azure CLI profile; run `az logout` after
registration), then run this block in PowerShell on that host. It applies the
same lifetime and tenant checks and does not display the token.

```powershell
$ErrorActionPreference = 'Stop'
$token = $null
$r = $null
$TenantId = '<tenant-id>'
$parsedTenant = [guid]::Empty
if (-not [guid]::TryParse($TenantId, [ref]$parsedTenant) -or $parsedTenant -eq [guid]::Empty) {
    throw 'Replace <tenant-id> with the resource tenant ID before requesting a token.'
}
try {
    $r = (az account get-access-token --resource https://management.azure.com --tenant $TenantId -o json | Out-String)
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
}
```

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
in a ticket; clear `$token = $null` after the initialization attempt and sign out
as described in step 1. If the token came from a managed identity and step 1
created its **Azure Connected Machine Onboarding** assignment, have the
subscription owner remove that assignment with the `az role assignment delete --ids`
command in step 1. Do not remove an assignment that existed before step 1.

**Changes:** The token blocks only set session variables. Retrying initialization
can create Azure resources and change the node's registration configuration and,
when an update is required, install it and restart the node.

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
instead of repeating module downgrades.

## 4. Permissions, policy, or quota (HTTP 403 or another non-401 status)

### Issue Validation

In `azcmagent.log` and the console output, the failed `AZCM0042` attempt reports
an HTTP status other than 401. For example, an Azure Policy assignment that denies
the machine resource produces a line ending in
`Code: RequestDisallowedByPolicy httpStatusCode:403`, and the agent also logs
`Please verify that the login credentials or token used has access to create resources in resource group '<resource-group>'`.
The token was accepted, so the module and token steps in sections 1 to 3 do not
apply; do not change modules or request a new token for this pattern.

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
  az rest --method get --url "$url" --query "value[].[properties.displayName, properties.scope, properties.enforcementMode]" -o tsv || break
  url=$(az rest --method get --url "$url" --query nextLink -o tsv) || break
done
```

Expect `Registered`, then `Owner` or both Azure Connected Machine roles for the
minting principal. A managed identity set up as in section 3 lists only
**Azure Connected Machine Onboarding**; if its retry still returns 403, follow
the stop instruction in section 3 instead of granting more roles. The loop prints
one line for each policy assignment that applies to the resource group (name,
scope, and enforcement), including those inherited from the subscription and
management groups. If an `az rest` call fails, the loop stops; treat the list as
incomplete and run it again. Keep the first `url` value in single quotes so the
shell does not expand `$filter`. Do not
substitute `az policy assignment list --resource-group`: in validation it listed
only assignments made directly on the resource group, even with
`--disable-scope-strict-match`. Compare the listed names with the
`policyAssignment` name in the `RequestDisallowedByPolicy` message, and review
each assignment whose enforcement is `Default` for a deny on
`Microsoft.HybridCompute/machines` or on the resource group's location. Then
retry your original initialization command.

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

> [!IMPORTANT]
> Bootstrap logs, PowerShell transcripts, and command history can contain access
> tokens. Before you attach any file or paste output into a ticket, review it and
> remove tokens and other secrets. Never include the value of `$token`.

## Validation status of this article

Validated in a lab on 2026-11-23 and 2026-11-24 with Windows PowerShell 5.1 and
Azure Connected Machine agent 1.70.03595.3521. The registration runs used
disposable Windows Server 2022 test machines, not an Azure Local image, and
throwaway resource groups; managed identity tokens were minted on a registered
Azure Local node. The
article's blocks ran unchanged except for their placeholders. The agent's connect
command was run directly in place of the initialization command that wraps it;
the full bootstrap was not run.

- **Token cause (sections 2 and 3, option 1):** with Az.Accounts 5.5.3, the
  unconverted token reproduced exit code 42 with `AZCM0042` and
  `status code 401` (`InvalidAuthenticationToken`), and no machine was created.
  The section 3 Azure PowerShell token block produced a plain-text token, and the
  same connect succeeded (machine `Connected`, provisioning `Succeeded`).
  `Disconnect-AzAccount` then removed the saved sign-in. With Az.Accounts 4.0.2,
  the same block used the plain-text token as is, and the connect succeeded. In a
  second run, the 401 was reproduced again, then the section 3 Azure CLI block
  minted the token off the node (PowerShell 7.5 with Azure CLI 2.85.0 on a separate
  workstation, signed in as an existing operator account), the token was passed to
  the node through the remote execution channel, and the connect succeeded
  (machine `Connected`, provisioning `Succeeded`).
- **Token block stop conditions:** against stubbed token responses in Windows
  PowerShell 5.1, the Azure PowerShell block stopped on a token with 10 minutes or
  less remaining, an expired token, a missing expiry, a tenant mismatch, an
  unexpected token type, and the text `System.Security.SecureString`, and left
  `$token` empty each time. The Azure CLI block stopped on 10 minutes or less
  remaining, an expired token, a missing `expires_on`, a tenant mismatch, an empty
  token, and a failed `az` call. Both stopped when `<tenant-id>` was not replaced.
- **Module block (section 1):** with no image recipe, the block printed
  `UNKNOWN-STOP` and changed nothing. With a staged recipe file that requires
  4.0.2 in the older format without a package type, it installed 4.0.2, printed
  `ARC42-REMOVING` for 5.5.3, removed it, and printed `REQUIRES-4.0.2`; a rerun
  changed nothing. This passed with PowerShellGet 1.0.0.1 and 2.2.5. A loaded newer
  version, a newer version copied in by hand, a recipe requiring 4.0.3, and a
  package type other than `PowerShellModule` each stopped without changing modules.
  A recipe requiring 5.5.3 printed `KEEP-MODULES`. The rollback command restored
  5.5.3. Earlier, on a deployed node of solution 12.2701.1004.15 whose real recipe
  requires 5.5.3, the block printed `KEEP-MODULES` and changed no modules.
- **Dependent-module guard (section 1):** on Windows PowerShell 5.1 with
  PowerShellGet 1.0.0.1 and the staged 4.0.2 recipe, `Az.Storage` 9.6.1 was
  installed from the PowerShell Gallery; its manifest declares Az.Accounts 5.4.0
  under `ModuleList`, and installing it added Az.Accounts 5.5.5 beside 5.5.3. The
  block printed `ARC42-DEPENDENT` for `Az.Storage` and stopped with
  `No changes were made`; the module inventory was identical before and after.
  After `Az.Storage` was uninstalled, the block printed `ARC42-REMOVING` for 5.5.3
  and 5.5.5, installed 4.0.2, and printed `REQUIRES-4.0.2`, leaving only 4.0.2.
  The rollback command, run for each printed version, restored 5.5.3 and 5.5.5.
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
  system-assigned identity, and the section 3 Azure PowerShell and Azure CLI blocks
  ran unchanged except for the tenant placeholder. Each produced a plain-text
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
- **Automation status:** remains `proven` because the documented token fix
  (section 3, option 1) and policy fix (remove the denying assignment, then
  retry) each connected the machine live, including with a token minted off the
  node. The sign-in that produces the token is supplied by an operator, by
  automation that holds a pre-provisioned identity, or, without a person, by the
  managed identity of a registered machine that was granted the role ahead of time;
  see the automation boundary in section 3.
- **Not validated:** device code sign-in (option 2, and the operator's
  `Connect-AzAccount -UseDeviceAuthentication` sign-in in option 1), which needs a
  person; service principal sign-in (`Connect-AzAccount -ServicePrincipal` and
  `az login --service-principal`), because no service principal was created for the
  test (an existing operator account minted the token instead, and the
  `Connect-AzAccount` certificate parameter set was confirmed present in
  Az.Accounts 5.5.3); a token that Azure rejects because it expired (expiry was
  tested only against stubbed responses); the quota variant of cause 4 (the
  missing-role variant is covered by the managed identity run above); a real image
  whose recipe requires 4.0.2 (none was available, so a staged recipe file stood
  in); and the full bootstrap command on an unregistered Azure Local machine,
  including whether it needs roles beyond **Azure Connected Machine Onboarding**
  when the token comes from a managed identity. No unregistered Azure Local machine
  was available for that run. The section 4 object ID lookups for a service
  principal (`az ad sp show`) and a user (`az ad signed-in-user show`) were not run;
  the managed identity lookup (`az resource show`) and the role list command were.
- **Role grant and policy listing, revised 2026-11-24:** with Azure CLI 2.85.0
  against a throwaway resource group and two throwaway user-assigned identities,
  the section 3 role commands ran unchanged except for their placeholders. For an
  identity without the role, the `az role assignment list` check printed nothing,
  `az role assignment create` printed the new assignment ID, the check then printed
  that same ID, and `az role assignment delete --ids` removed it. For an identity
  whose assignment was created beforehand to stand in for other automation, the
  check printed that assignment's ID, so the procedure created and deleted nothing,
  and that assignment remained. The section 4 policy loop listed the three
  assignments that apply to the resource group in one page. To confirm that it
  follows `nextLink`, it was also run with a test-only `$top=1` added to the first
  URL: a single `az rest` call then returned one assignment and a `nextLink`, and
  the loop followed the links and listed the same three assignments. The resource
  group, identities, and assignments were deleted afterward. These were not rerun
  with a managed identity of a registered machine.

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-24 | The section 1 module block now checks for newer Az.Accounts copies that were not installed with `Install-Module` before it installs 4.0.2, so that stop, like the other precondition stops, happens before any module changes. The section 4 role check now uses the object ID of the identity that minted the registration token, with a lookup for each identity type, instead of the account that runs the checks. |
| 2026-11-24 | Section 3 now checks whether the managed identity already holds **Azure Connected Machine Onboarding** on the resource group before granting it. If it does, no assignment is created and none is deleted afterward; otherwise the cleanup deletes only the assignment that the procedure created, by its ID. The section 4 policy listing now follows `nextLink`, so assignments on later result pages are not missed. |
