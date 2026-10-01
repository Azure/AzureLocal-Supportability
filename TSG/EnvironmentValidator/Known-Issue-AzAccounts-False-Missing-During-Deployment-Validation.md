<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "AzStackHci_OSImageRecipeValidation_Package_Version"
  },
  "validation": {
    "fidelity_level": "L4",
    "technical_grade": "A",
    "reproduction_substrate": "vm",
    "automation_status": "proven",
    "last_validated": "2026-09-15",
    "spec_ref": "AzStackHci_OSImageRecipeValidation_Package_Version-Az.Accounts-culture"
  }
}
-->

# `Az.Accounts` Is Reported as Missing During Azure Local Deployment Validation

## Table of contents

- [Revision history](#revision-history)
- [Symptoms](#symptoms)
- [Where this appears](#where-this-appears)
- [Check whether you are affected](#check-whether-you-are-affected)
- [Resolution](#resolution)
- [Verify the resolution](#verify-the-resolution)
- [Applicable versions](#applicable-versions)
- [Source articles](#source-articles)

## Revision history

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-28 | 1.0 | Published the live-validated diagnosis and recovery procedure for culture-related false missing-module results. |

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr><th style="text-align:left; width:180px;">Component</th><td><strong>Azure Local Environment Validator - OS image recipe validation</strong></td></tr>
  <tr><th style="text-align:left;">Severity</th><td><strong>Critical</strong></td></tr>
  <tr><th style="text-align:left;">Applicable scenarios</th><td><strong>Azure Local deployments blocked in the Validate phase</strong></td></tr>
  <tr><th style="text-align:left;">Affected versions</th><td><strong>Confirmed in Azure Local 2604</strong></td></tr>
  <tr><th style="text-align:left;">Audience</th><td>Azure Local deployment administrators and systems integrators</td></tr>
  <tr><th style="text-align:left;">Primary owner</th><td>Deployment administrator</td></tr>
  <tr><th style="text-align:left;">Execution surface</th><td>mixed</td></tr>
  <tr><th style="text-align:left;">Risk summary</th><td>Account-profile changes are low risk. Correcting a node system locale requires an administrator and a node restart.</td></tr>
</table>

> **At a glance**
> - **What it is:** deployment validation incorrectly reports `Az.Accounts` as missing even though the module is installed.
> - **When this article applies:** the exact validator message is present, `Az.Accounts` is discoverable, and account or node cultures differ across the deployment PowerShell sessions.
> - **Safe repair:** align every node system locale, then align the deployment-supplied account profile on every node.
> - **Do not do:** do not manually install, remove, or pin `Az.Accounts` when this culture-related pattern is present.

## Symptoms

This article applies only when the failed validation result is:

```text
AzStackHci_OSImageRecipeValidation_Package_Version
```

and the validation details contain:

```text
Package [Az.Accounts] is NOT installed on host [...] and it should be
```

The message can be a false negative when `Az.Accounts` is installed but the
deployment account uses a different regional format across the PowerShell
remote session used by validation. Simply put, the deployment account and
every node declared during deployment should use the same culture. This
includes the account profile on the seed node, the seed node system locale,
the account profile on each remote node, and each remote node system locale.

## Where this appears

Use the failed deployment's Environment Validator result as the applicability
signal for this article.

| Administrator surface | Status | What to check |
| --- | --- | --- |
| Azure portal or ARM deployment output | Shown | Open the failed Validate operation and inspect its Environment Validator results for the result name and message above. |
| Node deployment logs | Shown | The same result is written under the available deployment log roots: `C:\CloudDeployment\Logs`, `C:\CloudContent\MASLogs`, or `C:\MASLogs`. |
| Windows event logs | shown | Open the `AzStackHciEnvironmentChecker` log and inspect shared Event ID `17205` for `AzStackHci_OSImageRecipeValidation_Package_Version` from the failed validation run. |
| Cluster logs and Failover Cluster Manager | not-evident | The failure occurs during deployment Validate and does not identify a cluster role or resource failure. |
| Windows Admin Center | not-evident | This issue is identified from the failed deployment validation result, not a Windows Admin Center health signal. |

## Check whether you are affected

On the seed node, sign in and open **Windows PowerShell 5.1** as the account
supplied during deployment:

- For a domain-joined deployment, use the **Deployment account**
  (`AzureStackLCMAdminUsername` in an ARM template).
- For a deployment using **local identity with Azure Key Vault**, use the
  **Local administrator** credentials supplied during deployment
  (`localAdminUserName` in an ARM template).

### 1. Check the seed node

Run:

```powershell
[pscustomobject]@{
    Node         = $env:COMPUTERNAME
    UserCulture  = (
        Get-ItemProperty 'HKCU:\Control Panel\International').LocaleName
    SystemLocale = (Get-WinSystemLocale).Name
    SessionCulture = $PSCulture
}
```

`UserCulture`, `SystemLocale`, and `SessionCulture` should match.

### 2. Check each remote node through PowerShell remoting

Set the affected or other deployment node, and then enter the same deployment
account when prompted. For local identity, enter the remote account as
`REMOTENODE\localAdminUserName`.

```powershell
$remoteNode = 'REPLACE-WITH-REMOTE-NODE'
$credential = Get-Credential -Message 'Enter the deployment account'
$session = New-PSSession -ComputerName $remoteNode `
    -Credential $credential -Authentication Default -ErrorAction Stop
Invoke-Command -Session $session -ScriptBlock {
    $module = Get-Module -ListAvailable Az.Accounts |
        Sort-Object Version -Descending | Select-Object -First 1
    [pscustomobject]@{
        Node              = $env:COMPUTERNAME
        UserCulture       = (
            Get-ItemProperty 'HKCU:\Control Panel\International').LocaleName
        SystemLocale      = (Get-WinSystemLocale).Name
        SessionCulture    = $PSCulture
        AzAccountsFound   = [bool]$module
        AzAccountsVersion = [string]$module.Version
    }
}
Remove-PSSession $session
```

Repeat this step for every other deployment node. Compare each remote result
with the seed-node result. You are likely affected by this known issue when
all three conditions are true:

1. The validation error exactly matches the result and message above.
2. `AzAccountsFound` is `True`.
3. Any `UserCulture`, `SystemLocale`, or `SessionCulture` value differs
   between the seed node and a remote node.

Example affected output:

```text
Node              : NODE02
UserCulture       : en-GB
SystemLocale      : en-US
SessionCulture    : en-US
AzAccountsFound   : True
AzAccountsVersion : 5.3.4
```

> [!IMPORTANT]
> If `AzAccountsFound` is `False`, this article does not apply. Do not install
> or remove modules manually. Use the product-owned OS image recipe
> remediation process for a genuinely missing module.

## Resolution

Set the deployment account's regional format to the server's existing system
locale.

First confirm that the `SystemLocale` shown by the seed-node check and every
remote-node check is identical.

### [MEDIUM RISK] Correct an incorrect node system locale

If a node has the wrong system locale, sign in to that node as an
administrator, open an elevated Windows PowerShell session, and set it to the
intended common locale. This restarts the node. Continue only during the
deployment Validate phase and after confirming that the node can be
restarted.

```powershell
$previousSystemLocale = (Get-WinSystemLocale).Name
$previousSystemLocale
```

Record the displayed original locale outside the PowerShell session before
continuing. Then set the intended locale and restart:

```powershell
$ErrorActionPreference = 'Stop'
$targetCulture = 'REPLACE-WITH-INTENDED-CULTURE'
Set-WinSystemLocale -SystemLocale $targetCulture
Restart-Computer
```

Repeat the checks after the node restarts. Continue only when every node shows
the same `SystemLocale`. To roll back, set `SystemLocale` to the recorded
`$previousSystemLocale` value and restart the node again.

### [LOW RISK] Align the deployment account profiles

In the seed-node Windows PowerShell session, set the seed account profile:

```powershell
$previousCulture = (Get-Culture).Name
$targetCulture = (Get-WinSystemLocale).Name
Set-Culture -CultureInfo $targetCulture
```

Then set the same account profile on the remote node by using a new
PowerShell remote session:

```powershell
$session = New-PSSession -ComputerName $remoteNode `
    -Credential $credential -Authentication Default -ErrorAction Stop
try {
    Invoke-Command -Session $session -ArgumentList $targetCulture `
        -ScriptBlock {
            param($culture)
            Set-Culture -CultureInfo $culture
        }
}
finally {
    Remove-PSSession $session
}
```

Repeat the remote correction for every deployment node, using the same
account type supplied during deployment.

Close all existing PowerShell and remote sessions after running
`Set-Culture`. The change is used by new sessions.

If validation produces a new culture-related failure, restore each account's
recorded `UserCulture` value with `Set-Culture`, close existing sessions, and
verify again from new sessions.

## Verify the resolution

Open a new Windows PowerShell 5.1 session on the seed node as the deployment
account. Repeat **Check whether you are affected** for every deployment node.
This creates a new PowerShell remote session for each comparison.

Confirm that:

- every `UserCulture`, `SystemLocale`, and `SessionCulture` value matches
  across the seed node and every remote node;
- `AzAccountsFound` is `True`.

Rerun validation:

- **Portal deployment:** Open the Azure Local instance, select
  **Deployments**, and then select **Resume deployment**.
- **ARM-template deployment:** Open **Resource group** > **Deployments**,
  select the failed `azlocal-validate-*` deployment, select **Redeploy**, and
  keep **Deployment Mode** set to **Validate**.

Continue deployment only after validation succeeds.

If validation now reports an `Az.Accounts` version mismatch instead of a
missing module, use the product-owned OS image recipe remediation process.
Do not manually install, remove, or pin a module version.

## Applicable versions

This issue is confirmed in Azure Local 2604. The prevention fix is pending.

## Source articles

- [Set-WinSystemLocale](https://learn.microsoft.com/powershell/module/international/set-winsystemlocale)
