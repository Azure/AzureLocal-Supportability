---
ArticleType: "KI"
Article_ID: "20260917160013"
Title: "Known issue: WinRM cannot process the TrustedHosts configuration request"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
EngineeringStatus: "Pending"
FixedInBuild:
  OS: []
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: ""
  ID: 0
Tags: ["Validation", "Cloud Deployment", "Solution Update", "Diagnostics", "Log Collection"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|------|---------|---------|
| 2026-09-17 | 2.0 | Added mandatory PickleFactory metadata, accepted Known Issue layout, audience scopes, revision history, and source scope without changing the validated commands or technical evidence. |

:::

# Known issue: WinRM cannot process the TrustedHosts configuration request

# Symptoms

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width:180px;">ArticleType</th>
    <td><code>KI</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><code>['Engineering', 'CSS', 'OEM Partners', 'External']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.Product</th>
    <td><code>Azure Local</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.OEM</th>
    <td><code>['All']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Environment Validator session setup and the WinRM client <code>TrustedHosts</code> setting</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical when reproduced</strong>: the affected validation or lifecycle operation cannot create the required remote sessions.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected versions</th>
    <td>Legacy implementations that append node entries when <code>TrustedHosts</code> is exactly <code>*</code>. The earliest fixed release is not established by this article.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Confirmed current boundary</th>
    <td>On September 17, 2026, the product failure did not reproduce with Azure Local solution <code>12.2610.1004.30</code>, platform <code>12.2610.0.3059</code>, and AzStackHci.EnvironmentChecker <code>10.2610.0.2039</code>. The raw invalid WSMan append still returned the historical error, but the current product's wildcard guard avoided that append.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Deployment, Add Node, update readiness, or another Environment Validator operation can stop at remote-session setup. Running virtual machines and cluster storage are not directly changed by the mitigation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 10-20 minutes to inventory all nodes, confirm ownership, apply the scoped change, and rerun validation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The Azure Local or Windows administrator owns the node-local WinRM client setting. Route policy-owned values to the Group Policy or security-baseline owner. No OEM, firmware, switch, or physical-hardware action is required.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td><strong>[LOW RISK]</strong> inventory and evidence collection. <strong>[MEDIUM RISK]</strong> clear an unmanaged exact wildcard because it can change outbound remoting trust from that node. <strong>[HIGH RISK]</strong> do not weaken or bypass Group Policy.</td>
  </tr>
</table>

**Decision summary**

Use this article only when the lifecycle operation emits the exact hostname-pattern
error shown below. The presence of `TrustedHosts = '*'` by itself is not sufficient
reason to change a current system.

1. **[LOW RISK]** Inventory every affected node and record the exact value and
   policy ownership.
2. Stop if the value is not exactly `*`, if Group Policy owns it, or if the
   current lifecycle operation no longer emits the error.
3. **[MEDIUM RISK]** On an affected legacy implementation, clear only the
   unmanaged exact wildcard. Do not remove an explicit node list.
4. Rerun the original validation. If it succeeds, preserve the new explicit
   entries written by the product.
5. If validation still fails, restore the exact saved value and escalate with
   the evidence listed below.

This is a host operating-system configuration issue. It does not require a node
drain, virtual-machine shutdown, WinRM service restart, firmware change, network
switch change, or OEM action. Use a console or other control path when changing
a workgroup or non-domain host because altering its outbound trust list can
affect the remoting path you are using.

Cluster validation or another Environment Validator operation fails while
configuring remote sessions:

```text
Type 'ValidateCluster' of Role 'EnvironmentValidator' raised an exception:

{
    "ExceptionType": "text",
    "ErrorMessage": "WinRM cannot process the configuration request. The hostname pattern is invalid: \"*\" Hostname patterns must contain one or more patterns. A pattern can contain at most one wildcard (\"*\"). The special pattern \"<local>\" can be used to indicate all hostnames that do not have a '.'. To trust all hosts use \"*\" as the only pattern.",
    "ExceptionStackTrace": "at <ScriptBlock>, <No file>: line 8"
}
```

The defining signature is the rejection of a hostname pattern that tries to
combine `*` with another entry. A generic WinRM connection error, firewall
timeout, access-denied message, or listener failure is a different scenario.

# Issue Validation

## Errors or Failures

The defining error and applicability boundaries are described in Symptoms. A generic WinRM connection, firewall, listener, authentication, or access-denied failure is outside this Known Issue.

## PowerShell Detection Script

Run this read-only inventory from an elevated Windows PowerShell session. It
checks every currently Up cluster node when `Get-ClusterNode` is available and
checks the local host otherwise. It writes the exact values to a timestamped
JSON file in the current directory.

```powershell
$ErrorActionPreference = 'Stop'
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$backupPath = Join-Path (Get-Location) "TrustedHosts-before-$timestamp.json"

$nodes = @(
    if (Get-Command Get-ClusterNode -ErrorAction SilentlyContinue) {
        Get-ClusterNode |
            Where-Object State -eq 'Up' |
            Select-Object -ExpandProperty Name
    }
    else {
        $env:COMPUTERNAME
    }
)

if ($nodes.Count -eq 0) {
    throw 'No target nodes were found.'
}

$inventory = foreach ($node in $nodes) {
    Invoke-Command -ComputerName $node -ScriptBlock {
        $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client'
        $policy = Get-ItemProperty -LiteralPath $policyPath -ErrorAction SilentlyContinue
        $policyValue = if ($policy) {
            $policy.PSObject.Properties['TrustedHosts']
        }
        else {
            $null
        }
        $rsop = @(
            Get-CimInstance -Namespace 'root\rsop\computer' `
                -ClassName 'RSOP_RegistryPolicySetting' `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.ValueName -eq 'TrustedHosts' -or
                    $_.KeyName -match '(?i)Windows\\WinRM\\Client'
                } |
                Select-Object KeyName, ValueName, Value, GPOID, SOMID, Precedence
        )

        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            ObservedAtUtc = [DateTime]::UtcNow.ToString('o')
            TrustedHosts = [string](
                Get-Item WSMan:\localhost\Client\TrustedHosts
            ).Value
            PolicyRegistryValue = if ($policyValue) {
                [string]$policyValue.Value
            }
            else {
                $null
            }
            Rsop = $rsop
            PolicyOwned = [bool]($policyValue -or $rsop.Count -gt 0)
            WinRMStatus = [string](Get-Service WinRM).Status
        }
    }
}

$inventory | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $backupPath
$inventory | Format-Table Node, TrustedHosts, PolicyOwned, WinRMStatus -AutoSize
Write-Host "Exact rollback inventory: $backupPath"
```

Interpret the result:

- **Current lifecycle operation does not emit the exact error:** stop. Do not
  clear `*` solely because the value exists.
- **`TrustedHosts` is not exactly `*`:** stop. This article does not authorize
  deleting an explicit list or another wildcard pattern.
- **`PolicyOwned` is `True`:** stop. Send the JSON to the Group Policy or
  security-baseline owner. Do not set the policy to Not Configured or bypass it
  as part of this procedure.
- **The exact error and unmanaged exact wildcard occur on an affected legacy
  build:** continue to the mitigation.
- **The same exact error occurs on 2610 or later:** preserve the module,
  solution, and platform versions and escalate. The confirmed 2610 path avoided
  the invalid append, so another caller or code path must be identified.

# Root Cause

WinRM allows `*` as a special `TrustedHosts` value only when it is the entire
pattern. An affected legacy Environment Validator path read the existing value
and attempted to append node IP addresses or names. Appending to `*` would
produce a mixed list such as `*,192.0.2.10`, which WSMan rejects because the
unqualified wildcard must be the only pattern.

The period in an IP address or fully qualified domain name is not the cause.
The factual error in the earlier version of this article was attributing the
failure to WSMan treating the period as a special pattern.

Current 2610 product code contains a guard that skips the append when the
existing value is exactly `*`. On the confirmed build in the metadata table,
the source-exact guard left `*` unchanged without error. The underlying WSMan
constraint remains, so another caller that performs the raw invalid append can
still produce the same message.

**Terms**

- **WinRM** is Windows Remote Management, the service used for remote
  PowerShell and management operations.
- **WSMan** is the configuration provider and protocol implementation used by
  WinRM.
- **TrustedHosts** is a WinRM **client-side** list. It controls which remote
  computers this node may trust when mutual authentication is not available.
  It is not the WinRM listener or firewall configuration.
- **Policy-owned** means Group Policy or another managed security baseline
  controls the setting. A local command must not override that ownership.

::: audience-css

# Internal Root Cause

The September 17, 2026 source review confirmed that current 2610 product code contains the exact-wildcard guard described above. The earliest fixed release remains unestablished, so this article does not claim a public fixed-in-build boundary.

:::

# Mitigation Details

**Before you start**

1. Open an elevated Windows PowerShell session.
2. Identify every node in the affected deployment or cluster. A passing first
   node does not establish the state of the other nodes.
3. Use console, PowerShell Direct, or another independent control path when the
   node is not domain joined or when your current session depends on
   `TrustedHosts`.
4. Do not change the WinRM service, listener, authentication methods, firewall,
   Group Policy, node power state, cluster membership, or workload state for
   this procedure.
5. Preserve the inventory JSON. It is the exact rollback source if the
   validation does not recover.

**Where this failure appears**

| Admin surface | What to expect |
|---|---|
| PowerShell on an Azure Local node | **Shown**: `Get-Item WSMan:\localhost\Client\TrustedHosts` and the inventory below show the exact client value and policy ownership. |
| Azure portal | **Shown** when the deployment, Add Node, or update-readiness operation reports the Environment Validator exception. The portal does not show the exact local TrustedHosts value. |
| Windows event logs | **Shown when persisted**: an Environment Checker Event ID 17205 can contain the validation result. Use it for timestamp correlation, then confirm the current node state with PowerShell. |
| Cluster logs from `Get-ClusterLog` | This client configuration rejection is **not evident in cluster logs** as a cluster membership, quorum, storage, or resource failure. |
| Windows Failover Cluster Manager | This setting is **not evident in Failover Cluster Manager** as a node, role, or resource state. |
| Windows Admin Center on a standalone host | The exact Environment Validator rejection is **not evident in Windows Admin Center on a standalone host**. Use node PowerShell. |
| Windows Admin Center in the Azure portal | The exact client value is **not evident in Windows Admin Center in the Azure portal**. Use the Azure Local lifecycle view for correlation and node PowerShell for evidence. |
| Component or tool log files on disk | **Shown when written**: preserve `C:\CloudDeployment\Logs` and, for a user-profile Environment Checker run, `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` plus `AzStackHciEnvironmentReport.json` or `.xml`. |

**Mitigation**

**Clear only the unmanaged exact wildcard**

**[MEDIUM RISK]** Run the following only after reviewing the inventory. The
script processes nodes serially, refuses policy-owned values, and changes only a
value that is exactly `*`. It is non-interactive and does not restart WinRM.

```powershell
$ErrorActionPreference = 'Stop'

if (-not $backupPath -or -not (Test-Path -LiteralPath $backupPath)) {
    throw 'Run Issue validation first in this same session. The backupPath is missing.'
}

$inventory = @(Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json)
$blocked = @(
    $inventory |
        Where-Object { $_.PolicyOwned -or $_.TrustedHosts -ne '*' }
)
if ($blocked.Count -gt 0) {
    $blocked |
        Select-Object Node, TrustedHosts, PolicyOwned |
        Format-Table -AutoSize
    throw 'No changes were made. Every target must have an unmanaged exact wildcard.'
}

$changed = foreach ($item in $inventory) {
    Invoke-Command -ComputerName $item.Node -ScriptBlock {
        $before = [string](
            Get-Item WSMan:\localhost\Client\TrustedHosts
        ).Value
        if ($before -ne '*') {
            throw "TrustedHosts changed after inventory. Current value is '$before'."
        }

        Clear-Item -Path WSMan:\localhost\Client\TrustedHosts -Force
        $after = [string](
            Get-Item WSMan:\localhost\Client\TrustedHosts
        ).Value
        if (-not [string]::IsNullOrEmpty($after)) {
            throw "TrustedHosts did not clear. Current value is '$after'."
        }

        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            Before = $before
            After = $after
            WinRMStatus = [string](Get-Service WinRM).Status
        }
    }
}

$changed | Format-Table Node, Before, After, WinRMStatus -AutoSize
```

Expected result: every targeted node reports `Before` as `*`, an empty `After`,
and `WinRMStatus` as `Running`.

**Rerun the original validation**

Return to the same Azure portal deployment, Add Node, or update-readiness
operation and select **Retry**, **Resume**, or rerun the same validation action.
Do not substitute an unrelated connectivity test.

The mitigation is successful only when:

- the original hostname-pattern exception no longer appears;
- the lifecycle operation advances or returns its normal result;
- each affected node's `TrustedHosts` value is either empty or contains the
  explicit entries written by the product; and
- WinRM remains Running on every affected node.

**Rollback**

If the original validation still fails, restore the exact pre-change values
from the inventory. Do not invent a replacement list.

```powershell
$ErrorActionPreference = 'Stop'
$inventory = @(Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json)

foreach ($item in $inventory) {
    Invoke-Command -ComputerName $item.Node -ScriptBlock {
        param([AllowEmptyString()][string]$OriginalValue)

        if ([string]::IsNullOrEmpty($OriginalValue)) {
            Clear-Item -Path WSMan:\localhost\Client\TrustedHosts -Force
        }
        else {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts `
                -Value $OriginalValue -Force
        }

        $restored = [string](
            Get-Item WSMan:\localhost\Client\TrustedHosts
        ).Value
        if (-not [string]::Equals(
            $restored,
            $OriginalValue,
            [StringComparison]::Ordinal
        )) {
            throw "Exact TrustedHosts restore failed on $env:COMPUTERNAME."
        }

        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            Restored = $restored
            ExactMatch = $true
        }
    } -ArgumentList ([string]$item.TrustedHosts)
}
```

**Verify the fix**

Run the inventory again after the lifecycle operation completes. Save it under
a new filename and compare it with the original backup.

Also review the most recent Environment Checker event when available:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'AzStackHciEnvironmentChecker'
    Id = 17205
} -ErrorAction SilentlyContinue |
    Where-Object Message -Like '*TrustedHosts*' |
    Select-Object -First 5 TimeCreated, Id, Message
```

An empty event query is a data gap, not proof that the issue did not occur. The
authoritative success signal is the result of the original lifecycle operation
plus the current node values.

**Prevention and recurrence**

- Do not configure `TrustedHosts = '*'` as a routine Azure Local prerequisite.
  Prefer mutual authentication and the product-managed explicit node entries.
- If a security baseline intentionally owns `TrustedHosts`, document the owner
  and expected value before deployment. A locally cleared value can be
  reapplied at the next policy refresh.
- Do not concatenate another host to an existing exact wildcard. Replace the
  configuration through its owning system instead.
- On current 2610 systems, do not apply this mitigation merely because `*` is
  present. Confirm the exact lifecycle error first.

# Escalation

Escalate to Microsoft Support or the Environment Validator owner when:

- the exact error occurs on 2610 or later;
- the setting is policy-owned;
- the current value is not exactly `*`;
- a node cannot be reached through an independent control path;
- the exact value cannot be restored;
- WinRM is not Running after the change; or
- the original lifecycle operation still fails after the scoped mitigation.

Collect:

- both timestamped inventory JSON files;
- solution, platform, and AzStackHci.EnvironmentChecker versions;
- the portal operation name, correlation ID, and UTC failure time;
- Event ID 17205 results, if present;
- `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and the
  Environment Checker JSON or XML report, if present; and
- the relevant `C:\CloudDeployment\Logs` slice.

Do not weaken policy, enable CredSSP, alter WinRM listeners, or change firewall
rules to work around this specific error.

::: audience-css

# Internal Escalation

Preserve the exact solution, platform, and AzStackHci.EnvironmentChecker versions, plus the source-exact guard evidence, when routing a current-build reproduction to the Environment Validator owner.

:::

# Related Content

Use the Azure Local lifecycle operation that originally surfaced the error to verify recovery. General WinRM connectivity failures require a separate troubleshooting path.

::: audience-css

# Source Articles

- Azure Local Environment Validator product source reviewed on September 17, 2026.
- The prior L2 faithful-product-path validation evidence, mitigation execution, rollback execution, and zero-residue result remain unchanged by this structural retrofit.

:::
