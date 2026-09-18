---
ArticleType: "TSG"
Article_ID: "20260917160007"
Title: "AzStackHci_DNS_ExternalDnsResolution"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-18"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "DNS"
Engineering_ID:
  Source: "ADO Work Item"
  ID: 38356875
Tags: ["DNS", "Validation"]
---
[[_TOC_]]

# Revision History

| Date | Description |
| --- | --- |
| 2026-09-18 | Revalidated the live DNS failure and recovery loop and synchronized the standalone PR with the current publication design. |
| 2026-09-17 | Retrofitted mandatory publication metadata, audience scope, revision history, and source-article layout without changing the technical procedure. |

# AzStackHci_DNS_ExternalDnsResolution

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_DNS_ExternalDnsResolution</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">ArticleType</th>
    <td><code>TSG</code></td>
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
    <th style="text-align:left;">Display name</th>
    <td>External DNS Resolution</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Invoke-AzStackHciDNSValidation</code> with <code>Test-ExternalDnsResolution</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>DNS (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: failed external DNS resolution blocks readiness checks for deployment and updates.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The customer's network or DNS owner applies the node or upstream change. Microsoft support can guide evidence collection and verification; the OEM is involved only when imaging has pinned stale DNS.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Plan 10-20 minutes per node for read-only evidence and configuration capture. A supported deployment-time node-side correction and revalidation usually takes 15-30 minutes per node, with no reboot or drain. An upstream forwarder or firewall change has a separate, owner-controlled duration; do not promise a completion time until that team accepts the change.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Local workloads continue to run, but deployment, updates, Arc connectivity, billing, and telemetry can remain impaired until every affected node can resolve the required external name.</td>
  </tr>
</table>

> **At a glance**
> - **Owner and support role:** the customer's network or DNS administrator owns the change. Microsoft support can help interpret the validator output, identify the failing lane, and verify the result. The OEM is involved only when imaging has pinned stale DNS.
> - **Impact:** Critical for readiness. Local VMs and live migration continue, but deployment, updates, Arc connectivity, billing, and telemetry can remain impaired until external DNS works on every affected node.
> - **Effort and downtime:** read-only evidence and configuration capture usually take 10 to 20 minutes per node. A node-side correction and revalidation usually take 15 to 30 minutes per node, with no reboot or cluster drain. An upstream forwarder or firewall change follows the owning team's change process.
> - **Before you change anything:** do not guess DNS server IP addresses. Get the cluster's intended DNS servers from your network or DNS administrator first.

> **Customer-facing framing:** This is an external-DNS path issue that blocks readiness, not a request to rebuild the cluster. Microsoft support can help identify the failing node and DNS server, interpret the evidence, and verify the fresh result. The customer's network or DNS owner applies the node-side or upstream change, with the change scope and rollback recorded before action.

## Overview

This Environment Validator check confirms that each Azure Local node can resolve an
external (public) DNS name. On every node, for each DNS server configured on every
network adapter that is up, the dedicated DNS validator resolves the public name
`management.azure.com` and expects at least one A record back. It retries up to three
times before it fails, and it lists each failing node as its own bullet. If any
configured DNS server returns no records (or no DNS server is configured at all), the
check fails for that node.

- **Severity:** Critical. When this check fails on a node and no proxy is in use, it
  reports a FAILURE for that node and fails the pre-update health check overall.
- **When it runs:** pre-deployment readiness, deployment, add-node, and the pre-update
  health check. In practice you will most often see it block a pending Azure Local
  update.
- **Result names.** This is the dedicated DNS validator that resolves
  `management.azure.com`. On current builds the same external-DNS test is reported under
  one of two result names, so search the health-check results for either:
  `AzStackHci_DNS_ExternalDnsResolution` or
  `AzStackHci_DNS_Test_External_Hostname_Resolution`.
- These are alternate result-name shapes for the same external-DNS validation path, not
  two failures to add together. Do not use the result name alone as a fixed-release
  detector; use the name present in the fresh payload and keep both filters.
- **Same check, older name.** This validator is the successor of the legacy
  connectivity test `AzStackHci_Connectivity_Test_Dns`, which resolved `microsoft.com`
  instead of `management.azure.com` and reported a single flat `Detail` line rather than
  per-node bullets. The cause and the fix are identical; only the validator name and the
  queried hostname differ.

**Ownership and support role.** This is a customer network and DNS configuration check.
The customer's network or DNS administrator applies the node-side or upstream change.
Microsoft support can guide the customer through the evidence, help distinguish
reachability from resolution, and verify the fresh health result. The OEM is involved only
when the imaging process has pinned stale DNS values.

**Where a node's DNS comes from.** A node's DNS servers are set at deployment time from
the deployment configuration's management network settings and applied to the management
network adapter; they are not baked into the OEM factory image. If you are an OEM or
field engineer checking your own imaging process, confirm the image does not pin DNS
servers and leaves them to be set by deployment, so each cluster picks up the customer's
intended DNS rather than a stale value carried over from imaging.

> **Related guide.** This guide is self-contained for the dedicated `management.azure.com`
> DNS validator: the discovery, per-node fan-out, remediation, verification, and a DNS
> glossary are all below. A related guide covers the legacy connectivity DNS test
> `AzStackHci_Connectivity_Test_Dns` (which resolves `microsoft.com`); the root cause and
> fix are the same, so consult it only if you also see that older check. It is a separate,
> in-progress supportability PR, so this guide does not depend on it:
> [Troubleshooting AzStackHci_Connectivity_Test_Dns](./Troubleshooting-Connectivity-Test-Dns.md).

## Quick fix (start here)

First decide whether the node is being deployed or added, or is already a deployed
cluster member. The supported fix differs:

- **Deploying or adding a node:** if the node is not yet a deployed cluster member, you
  may correct its management-adapter DNS client with the documented values.
- **Already-deployed cluster:** do **not** re-point the node's DNS client. Azure Local does
  not support changing DNS server settings post-deployment
  ([management-adapter readiness guidance](./Networking/Troubleshoot-Network-Test-ManagementAdapterReadiness.md)).
  Fix the currently configured DNS server upstream instead, usually by adding an
  external-resolving forwarder or correcting the firewall path, then use
  [Verify the fix](#verify-the-fix).

> **Do not guess DNS server IP addresses.** If you do not have the deployment's intended
> DNS servers, stop and involve the network or DNS owner. Changing the management adapter
> can also interrupt the current remote session, so use local console or out-of-band access,
> or confirm an alternate management path, before applying a node-side change.

**Deployment-time only:** identify the management adapter by the node's known management
IPv4 address, capture its current DNS values, apply the documented DNS servers, and verify
each configured server directly:

```powershell
$ManagementIp = '<node-management-ipv4>'
$mgmt = @(Get-NetIPConfiguration | Where-Object {
    $_.NetAdapter.Status -eq 'Up' -and ($_.IPv4Address.IPAddress -contains $ManagementIp)
})
if ($mgmt.Count -ne 1) {
    throw "Expected exactly one up adapter owning $ManagementIp; found $($mgmt.Count). Confirm the management IP and adapter before proceeding."
}
$mgmtAlias = $mgmt[0].InterfaceAlias
"Management adapter: $mgmtAlias"

$dnsSnapshot = @(Get-DnsClientServerAddress -InterfaceAlias $mgmtAlias -AddressFamily IPv4 |
    Select-Object InterfaceAlias, @{ n = 'ServerAddresses'; e = { @($_.ServerAddresses) } })
$dnsSnapshot | ConvertTo-Json -Depth 3

Set-DnsClientServerAddress -InterfaceAlias $mgmtAlias -ServerAddresses '<dns1>','<dns2>'

foreach ($dns in ((Get-DnsClientServerAddress -InterfaceAlias $mgmtAlias -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique)) {
    try {
        $records = @(Resolve-DnsName -Name management.azure.com -Server $dns -Type A -DnsOnly -ErrorAction Stop)
        '{0}: {1} A record(s)' -f $dns, $records.Count
    }
    catch {
        '{0}: query failed: {1}' -f $dns, $_.Exception.Message
    }
}
```

If this does not resolve the issue, or the node is already a deployed cluster member,
follow the upstream-server decision tree in [Remediation](#remediation). To restore the
live node configuration, use the recorded `$dnsSnapshot` values, not a blind reset.

### Fast read-only check

If the failure is already known, run these two read-only checks before changing anything.
They list only DNS servers on adapters that are currently up, matching the validator's
scope, and then test each server separately:

```powershell
$upAliases = @(Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object Status -eq 'Up' |
    Select-Object -ExpandProperty Name)
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
```

```powershell
$externalName = 'management.azure.com'
$dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    ForEach-Object { $_.ServerAddresses } |
    Sort-Object -Unique)
foreach ($dns in $dnsServers) {
    try {
        $records = @(Resolve-DnsName -Name $externalName -Server $dns -Type A -DnsOnly -ErrorAction Stop)
        [pscustomobject]@{
            DnsServer = $dns
            Status    = if ($records.Count -gt 0) { 'PASS: A records returned' } else { 'FAILURE: no A records' }
            Records   = ($records | ForEach-Object IPAddress) -join ', '
        }
    }
    catch {
        [pscustomobject]@{
            DnsServer = $dns
            Status    = 'FAILURE: query failed'
            Records   = $_.Exception.Message
        }
    }
}
```

An upstream DNS-server or forwarder change is a **[MEDIUM RISK]** shared
infrastructure change, not a beginner action. It belongs with the network or DNS owner,
who should record the prior setting and rollback before changing a server used by other
clients.

## Requirements

- Administrative (local administrator) access to each Azure Local node, or a remote
  PowerShell session to the nodes.
- The list of DNS servers the cluster is supposed to use, from the deployment's network
  configuration.
- Access to, or coordination with, whoever administers those DNS servers, in case an
  upstream server needs a forwarder or an external-resolution fix.
- Console or out-of-band access, or a confirmed alternate management path, before changing
  the management adapter on a node.
- No maintenance window is required for a supported deployment-time node DNS-client change.
  It applies immediately and does not need a reboot or a cluster drain. Upstream DNS
  changes follow the owning team's change process.

## Where this failure appears

The same failure surfaces in several places; they all converge on the same `Detail`
string. The health-check result file is the recommended entry point (below); the Windows
event log (Event ID 17205) and the Azure portal **Updates** tab show the same failure and
are covered right after it.

Read the newest health-check result file on the cluster's infrastructure share and
filter to this check. The on-box result stores the human-readable status and message
under `AdditionalData`, so project those (the top-level `Status` is a numeric enum and
the top-level `Description` is generic):

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    # Fallback: walk all ClusterStorage volumes for the HealthCheck folder.
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

$latest = $null
if ($base) {
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not $latest) {
    Write-Warning "No HealthCheck result file found on this node (the folder is missing or no health check has run yet). Read the AzStackHciEnvironmentChecker event log (Event ID 17205) instead, or run this on a different node."
}
else {
    Write-Host "Reading: $($latest.FullName)"
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -like '*ExternalDnsResolution*' -or $_.Name -like '*Test_External_Hostname_Resolution*' } |
        Where-Object { $_.AdditionalData.Status -eq 'FAILURE' } |
        Select-Object Name, Severity,
            @{ n = 'Status'; e = { $_.AdditionalData.Status } },
            @{ n = 'Detail'; e = { $_.AdditionalData.Detail } },
            Remediation
}
```

Each row is one currently-failing DNS server on one node. The dedicated validator can
appear as either `AzStackHci_DNS_ExternalDnsResolution` or
`AzStackHci_DNS_Test_External_Hostname_Resolution`, depending on the build and health-check
path, so keep both filters. The human-readable status and message are under
`AdditionalData.Status` and `AdditionalData.Detail`; the top-level `Status` is a numeric
enum and the top-level `Description` is generic.

When the shared result file is unavailable, use the runnable Event ID 17205 path on the
affected node. The event message is JSON, so parse it before filtering and project the
same `AdditionalData` fields:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object {
        try {
            $r = $_.Message | ConvertFrom-Json
        }
        catch {
            return
        }

        if ($r.Name -like '*ExternalDnsResolution*' -or
            $r.Name -like '*Test_External_Hostname_Resolution*') {
            [pscustomobject]@{
                TimeCreated = $_.TimeCreated
                Name        = $r.Name
                Status      = $r.AdditionalData.Status
                Detail      = $r.AdditionalData.Detail
                Remediation = $r.Remediation
            }
        }
    } |
    Where-Object { $_.Status -eq 'FAILURE' } |
    Sort-Object TimeCreated -Descending |
    Select-Object -First 20
```

The event-log query is an on-node evidence path, not a substitute for a fresh
cluster-wide health check. In the Azure portal, open the Azure Local cluster then the
**Updates** tab; a failing pre-update health check names the failing validator there.

### What it looks like: example failure signature

The dedicated validator lists each failing node as its own bullet and adds an
`(Attempt: n/3)` retry suffix, for example:

```
- AzL-Node-01
  - Queried dns server 10.0.0.10 for management.azure.com on AzL-Node-01 (Attempt: 3/3). Result returned 0 A records. Expected at least 1. Error:
```

This means the node reached the DNS server at that IP, but the server returned no A
records for `management.azure.com` after three attempts. A `No DNS server configured`
message instead means the node's up adapters have no DNS server configured at all. A
passing node reports a count of one or more and lists the resolved addresses.

> If a proxy is configured on a node (WinHTTP proxy), the check is skipped on that node
> and reported as success, with a `Detail` of `Skipping DNS resolution test on <node>
> because a proxy is configured.` That is expected behavior, not a failure.

### Identify every affected node

Run across all cluster nodes so you see the current DNS-client configuration on each
up adapter and the latest validator state. This prevents a stale result file or a
different node's configuration from being mistaken for the current state:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    $node = $env:COMPUTERNAME
    $upAliases = @(Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object Status -eq 'Up' |
        Select-Object -ExpandProperty Name)
    $current = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
        ForEach-Object {
            [pscustomobject]@{
                InterfaceAlias = $_.InterfaceAlias
                DnsServers     = $_.ServerAddresses -join ', '
            }
        })
    $currentText = if ($current) {
        ($current | ForEach-Object { "$($_.InterfaceAlias): $($_.DnsServers)" }) -join '; '
    }
    else {
        '<none on up adapters>'
    }

    $base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
    if (-not (Test-Path $base)) {
        $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    $latest = $null
    if ($base) {
        $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $latest) {
        # Emit an explicit NO DATA row so this node is never silently treated as passing.
        [pscustomobject]@{
            Node               = $node
            UpAdapters         = $upAliases -join ', '
            CurrentDnsServers  = $currentText
            ResultName         = ''
            Status             = 'NO DATA'
            Detail             = 'No HealthCheck result file found; read Event ID 17205 on this node'
        }
        return
    }

    $results = @(Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object {
            $_.Name -like '*ExternalDnsResolution*' -or
            $_.Name -like '*Test_External_Hostname_Resolution*'
        })
    $failure = @($results | Where-Object { $_.AdditionalData.Status -eq 'FAILURE' } | Select-Object -First 1)
    if ($failure) {
        [pscustomobject]@{
            Node              = $node
            UpAdapters        = $upAliases -join ', '
            CurrentDnsServers = $currentText
            ResultName        = $failure.Name
            Status            = $failure.AdditionalData.Status
            Detail            = $failure.AdditionalData.Detail
        }
    }
    else {
        [pscustomobject]@{
            Node              = $node
            UpAdapters        = $upAliases -join ', '
            CurrentDnsServers = $currentText
            ResultName        = if ($results) { ($results | Select-Object -First 1).Name } else { '' }
            Status            = 'PASS'
            Detail            = 'No failing DNS result in the latest health check'
        }
    }
} | Sort-Object Node | Format-Table -AutoSize
```

Every node reports its up adapters, the current DNS servers on those adapters, and one of
three result states: a failing `Detail` (fix it), `PASS` (the latest result has no
failure), or `NO DATA` (the result could not be read, so confirm it with the event log
rather than assuming it passed). The result file is cluster-wide; the current DNS
configuration is collected from each node independently.

### Admin-surface map

The eight administrator surfaces are covered explicitly below. "Shown" means the
surface carries this check's evidence. "Not evident" means it is not an authoritative
place to look for this validator.

- **PowerShell on an Azure Local node:** **Shown.** Use the health-check result,
  `Get-WinEvent`, the per-node fan-out, and the direct `Resolve-DnsName` checks above.
- **Azure portal:** **Shown.** Open the Azure Local cluster's **Updates** view. A
  failing pre-update health check names this validator there.
- **Windows event logs:** **Shown.** The `AzStackHciEnvironmentChecker` log carries
  Event ID 17205 with the parsed `AdditionalData.Status` and `AdditionalData.Detail`.
- **Cluster logs (`Get-ClusterLog`):** not evident in the cluster logs for this
  validator; use that source only to correlate a separate node, membership, or network
  event.
- **Windows Failover Cluster Manager (`cluadmin.msc`):** not evident in Failover
  Cluster Manager for this validator; it is not a dedicated cluster resource, role, node
  property, or MMC signal.
- **Windows Admin Center on a standalone host:** not evident in Windows Admin Center on
  a standalone host for this validator; use the node PowerShell and event-log paths.
- **Windows Admin Center in the Azure portal:** not evident in Windows Admin Center in
  the Azure portal for this validator; use the Azure portal **Updates** view instead.
- **Component and tool log files on disk:** **Shown.** The Environment Checker writes
  supporting evidence under `%USERPROFILE%\.AzStackHci` on the node and profile that ran
  the check. List the files and timestamps, then search their text for either dedicated
  validator name:

  ```powershell
  $componentLogRoot = Join-Path $env:USERPROFILE '.AzStackHci'
  $componentFiles = @(Get-ChildItem $componentLogRoot -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'AzStackHciEnvironmentChecker|AzStackHciEnvironmentReport' } |
      Select-Object FullName, LastWriteTime, Length)
  $componentFiles
  $componentFiles | Select-String -Pattern 'ExternalDnsResolution|Test_External_Hostname_Resolution'
  ```

For the four not-evident surfaces, do not treat the absence of a matching entry as
proof that the cluster is healthy. Use the shown PowerShell, event-log, portal, or
component-log evidence instead.

## Consequences if you do not fix this

This check is Critical. When it fails on a node and no proxy is configured, it reports a
FAILURE for that node and fails the pre-update health check overall. A pending Azure
Local update or a deployment that runs this readiness check will not proceed until
external DNS resolution succeeds on every node, and the cluster's cloud-managed lifecycle
(Arc, updates, billing, telemetry) is impaired until external DNS works, even though
local workloads keep running.

- **Workload plane:** running VMs and live migration continue during the supported
  deployment-time node-side correction; no reboot or cluster drain is required.
- **Management plane:** readiness, updates, Arc connectivity, billing, and telemetry can
  remain impaired until every affected node resolves the required external name.

## Remediation

The check fails when a DNS server configured on a node cannot resolve the external name
`management.azure.com`. The fix is a customer-side DNS change, either on the node's
DNS-client configuration or on the upstream DNS server. The essential steps are below,
including a per-node fan-out to find every affected node and an option-by-option decision
tree for the fix.

**Most common fix (start here).** The usual cause is a node pointed at a DNS server that
cannot resolve external names, and the **supported** fix depends on whether the cluster is
already deployed. On an **already-deployed** cluster, do not re-point the node's DNS client;
make the currently configured server resolve the external name by adding an
external-resolving forwarder or correcting its firewall path. Only when **deploying or
adding a node** may you re-point that node's management adapter at a DNS server that can
resolve. The numbered steps confirm which server is failing and which path applies.

_New to any DNS term used here (A record, forwarder, split-horizon, WinHTTP proxy)? See
the [Glossary](#glossary) at the end of this guide._

1. List the DNS servers currently configured on the affected node's up adapters:

   ```powershell
   $upAliases = @(Get-NetAdapter |
       Where-Object Status -eq 'Up' |
       Select-Object -ExpandProperty Name)
   Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
       Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
   ```

2. Separate DNS-server reachability from name resolution. The first field is a
   TCP/53 routing or firewall clue; the second field is the actual A-record result.
   Do not treat an unreachable server and a reachable server that returns no A records
   as the same failure:

   ```powershell
   $externalName = 'management.azure.com'
   $upAliases = @(Get-NetAdapter |
       Where-Object Status -eq 'Up' |
       Select-Object -ExpandProperty Name)
   $dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
       ForEach-Object { $_.ServerAddresses } |
       Sort-Object -Unique)

   if (-not $dnsServers) {
       'NO DNS SERVER CONFIGURED on an up adapter'
   }
   else {
       foreach ($dns in $dnsServers) {
           $tcp53Reachability = Test-NetConnection -ComputerName $dns -Port 53 `
               -InformationLevel Quiet -WarningAction SilentlyContinue
           try {
               $records = @(Resolve-DnsName -Name $externalName -Server $dns `
                   -Type A -DnsOnly -ErrorAction Stop)
               $resolution = if ($records.Count -gt 0) { 'A records returned' } else { 'No A records' }
               $detail = if ($records.Count -gt 0) {
                   ($records | ForEach-Object IPAddress) -join ', '
               }
               else {
                   "The server answered, but returned no A record for $externalName."
               }
           }
           catch {
               $resolution = 'Query failed'
               $detail = $_.Exception.Message
           }

           [pscustomobject]@{
               DnsServer          = $dns
               Tcp53Reachability  = if ($tcp53Reachability) { 'Reachable' } else { 'Unreachable' }
               Resolution         = $resolution
               Detail             = $detail
           }
       }
   }
   ```

   Interpret the lanes independently. `Reachable` plus `No A records` means the server
   answered but cannot resolve the required public name, so investigate forwarders,
   conditional forwarders, or split-horizon zones. `Unreachable` or `Query failed`
   points first to routing, firewall, service availability, or a timeout. A server can
   answer DNS over UDP while TCP/53 is blocked, so `Tcp53Reachability` is a secondary
   reachability clue, not proof by itself; do not change DNS based on that field alone.

   A correct result is `Reachable` with `A records returned` for each configured server.
   `Unreachable` or `Query failed` means the server path needs investigation first; it
   is not evidence that the server answered and returned zero A records. Keep the
   reachability result and the resolution result in the incident record.

3. Fix the failing DNS server, choosing the option that matches the environment:

   - If the configured server is wrong or stale, and the node is **not yet a deployed
     cluster member** (deploying or adding a node), re-point the node's management adapter
     at a DNS server that can resolve external names. On an already-deployed cluster this
     is unsupported; use the forwarder option below instead. First identify the management
     adapter (the up adapter whose IPv4 address is the node's management IP), so the
     `<ManagementAdapter>` placeholder is concrete:

     ```powershell
     Get-NetIPConfiguration | Where-Object { $_.IPv4Address } |
         Select-Object InterfaceAlias, @{ n = 'IPv4'; e = { $_.IPv4Address.IPAddress -join ', ' } }
     ```

     Capture the current values before changing anything and keep the output with the
     incident record:

     ```powershell
     $upAliases = @(Get-NetAdapter |
         Where-Object Status -eq 'Up' |
         Select-Object -ExpandProperty Name)
     $dnsSnapshot = @(Get-DnsClientServerAddress -AddressFamily IPv4 |
         Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
         Select-Object InterfaceAlias, @{ n = 'ServerAddresses'; e = { @($_.ServerAddresses) } })
     $dnsSnapshot | ConvertTo-Json -Depth 3
     ```

     Changing the management adapter can interrupt the remote PowerShell session. Use
     local console or out-of-band access, or confirm an alternate management path, before
     applying the new values. The correct `<dns1>`,`<dns2>` are your deployment's
     documented management DNS servers, not guessed addresses:

     ```powershell
     Set-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -ServerAddresses '<dns1>','<dns2>'
     ```

     To restore the live configuration, use the recorded values from `$dnsSnapshot`:

     ```powershell
     Set-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -ServerAddresses '<originalDns1>','<originalDns2>'
     ```

     Do not use a blind reset or leave the management adapter without a restorable
     configuration.

   - If the configured server is correct but internal-only, add a forwarder on that DNS
     server to a resolver that can answer external queries. This change is made on the DNS
     server, not on the Azure Local node, so coordinate with whoever owns that server.
   - If the server resolves internal names but returns nothing for the external name, an
     internal-only or split-horizon DNS zone may be shadowing external resolution; add a
     forwarder or otherwise enable external resolution as above.
   - Confirm that DNS traffic on port 53 from the nodes to the DNS servers is not blocked
     by a firewall.

4. If the cluster intentionally has no direct outbound name resolution and uses a proxy
   for all outbound traffic, configure the WinHTTP proxy on each node. When a proxy is
   present, this check self-skips and reports success. Only do this if a proxy is
   genuinely part of the design.

Re-pointing a node's DNS client during deployment or add-node work is a [LOW RISK] change:
it is per-node, immediate, and reversible by restoring the previous servers. On an
already-deployed cluster that path is unsupported, so use the upstream DNS server or
forwarder change, a [MEDIUM RISK] change because it can affect other systems that use it,
and coordinate with its owner. No node drain or reboot is required for a supported
deployment-time DNS-client change.

### Pre-deployment environment check

For a deployment that spans multiple sites or clusters, validate the intended DNS-server
list on each pre-deployment host before the deployment starts. This is a read-only
environment gate: it catches a site with stale imaging or a different DNS list before the
same forwarder problem is repeated cluster by cluster.

```powershell
$intendedDnsServers = @('<dns1>', '<dns2>') | Sort-Object -Unique
$upAliases = @(Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object Status -eq 'Up' |
    Select-Object -ExpandProperty Name)
$currentDnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    ForEach-Object { $_.ServerAddresses } |
    Sort-Object -Unique)

[pscustomobject]@{
    IntendedDnsServers = $intendedDnsServers -join ', '
    CurrentDnsServers  = $currentDnsServers -join ', '
    MissingFromHost    = @($intendedDnsServers | Where-Object { $_ -notin $currentDnsServers }) -join ', '
    UnexpectedOnHost   = @($currentDnsServers | Where-Object { $_ -notin $intendedDnsServers }) -join ', '
}
```

An empty `MissingFromHost` and `UnexpectedOnHost` value means the host matches the
documented list at this point in time; it does not replace the per-node validator run
after deployment.

## Verify the fix

Re-run the pre-update health check so a fresh result file and fresh event-log entries are
written on every node:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` (not `Failure`) with a current `HealthCheckDate`, then
re-read the health-check result (the query in "Where this failure appears" above): the
check should return no failing rows. You can also confirm the underlying resolution
directly against every configured DNS server on each node. Do not use only the node's
default resolver, because it can hide a configured server that still fails:

```powershell
$upAliases = @(Get-NetAdapter |
    Where-Object Status -eq 'Up' |
    Select-Object -ExpandProperty Name)
$dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    ForEach-Object { $_.ServerAddresses } |
    Sort-Object -Unique)

foreach ($dns in $dnsServers) {
    try {
        $records = @(Resolve-DnsName -Name management.azure.com -Server $dns `
            -Type A -DnsOnly -ErrorAction Stop)
        [pscustomobject]@{
            DnsServer = $dns
            Status    = if ($records.Count -gt 0) { 'PASS' } else { 'FAILURE: no A records' }
            Records   = ($records | ForEach-Object IPAddress) -join ', '
        }
    }
    catch {
        [pscustomobject]@{
            DnsServer = $dns
            Status    = 'FAILURE: query failed'
            Records   = $_.Exception.Message
        }
    }
}
```

Every configured server should return one or more A records. If failures remain, re-read
the new `Detail` text: the failure may have moved to a different DNS server or a different
node that needs the same fix.

> **Note:** the Azure portal readiness view and the cluster-wide `HealthCheckResult` file
> refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a
> targeted per-node re-test. The portal can therefore lag a just-applied fix until the
> next precheck or the periodic (roughly daily) health check, so confirm the fix on-node
> with `Resolve-DnsName` rather than waiting on the portal.

### Imaging validation before deployment

DNS is applied from deployment configuration; it is not a required OEM factory-image
value. On a freshly imaged, not-yet-deployed host, capture the current state so an OEM or
deployment owner can prove whether the image already contains a DNS setting:

```powershell
$upAliases = @(Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object Status -eq 'Up' |
    Select-Object -ExpandProperty Name)
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases } |
    Select-Object InterfaceAlias, ServerAddresses
```

An empty `ServerAddresses` value on the up adapters is evidence that no DNS server is
currently pinned at this pre-deployment checkpoint. A non-empty value must be explained
or cleared by the imaging owner before deployment applies the intended configuration.
This check does not prove the post-deployment DNS state.

## Glossary

Plain-language definitions of the DNS terms used in this guide. Experienced readers can
skip this section.

- **A record:** the basic DNS record that maps a name (such as `management.azure.com`) to
  an IPv4 address. This check passes only when a configured DNS server returns at least one
  A record for the external name.
- **DNS server / resolver:** the server a node asks to turn a name into an address. Each
  node lists one or more on its network adapters; this check tests each one.
- **Forwarder:** a setting on a DNS server that hands off queries it cannot answer itself
  (such as external or public names) to another resolver that can. An internal-only DNS
  server usually needs a forwarder to resolve external names.
- **Conditional forwarder:** a forwarder that applies only to a specific domain, so a
  server can send just some queries (for example external names) to a particular resolver.
- **Split-horizon (split-brain) DNS:** a setup where the same DNS name resolves differently
  for internal versus external clients. An internal-only zone can shadow an external name,
  so the server answers internal lookups but returns nothing for the public name this check
  asks for.
- **WinHTTP proxy:** a system-level outbound proxy configured on a node. When one is set,
  the node routes outbound traffic through it, and this DNS check self-skips on that node
  and reports success.

::: audience-css

# Source Articles

- [Troubleshooting AzStackHci_Connectivity_Test_Dns](./Troubleshooting-Connectivity-Test-Dns.md)
- [Management adapter readiness guidance](./Networking/Troubleshoot-Network-Test-ManagementAdapterReadiness.md)

:::
