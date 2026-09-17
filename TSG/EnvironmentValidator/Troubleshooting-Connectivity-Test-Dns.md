---
ArticleType: "TSG"
Article_ID: "20260917160014"
Title: "AzStackHci_Connectivity_Test_Dns"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
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
  ID: 38357445
Tags: ["DNS", "Validation", "Cloud Deployment", "Solution Update", "Diagnostics"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|------|---------|---------|
| 2026-09-17 | 2.0 | Added mandatory PickleFactory metadata, audience scopes, revision history, and source scope without changing the validated technical procedure. |

:::

# AzStackHci_Connectivity_Test_Dns

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Connectivity_Test_Dns</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td>Legacy: <code>Invoke-AzStackHciConnectivityValidation</code>. Current successor: <code>Invoke-AzStackHciDNSValidation</code> with <code>Test-ExternalDnsResolution</code>.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Connectivity and DNS (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: failed external DNS resolution blocks deployment or update readiness.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The customer's network or DNS administrator applies the node-side or upstream change. Microsoft support can guide evidence collection and verification. The OEM is involved only if imaging pinned stale DNS.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Read-only evidence and configuration capture usually take 10-20 minutes per node. A deployment-time node correction and revalidation usually take 15-30 minutes per node. An upstream forwarder or firewall change follows the owning team's change process, so do not promise its completion time before that team accepts the change.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Local workloads continue to run, but deployment, updates, Arc connectivity, billing, and telemetry can remain impaired until every affected node resolves the required external name.</td>
  </tr>
</table>

> **At a glance**
> - **Owner and support role:** the customer's network or DNS administrator owns the change. Microsoft support can help identify the failing node and DNS lane, interpret the evidence, and verify the fresh result. The OEM is involved only if imaging pinned stale DNS.
> - **Impact:** Critical for readiness. Local VMs and live migration continue, but deployment, updates, Arc connectivity, billing, and telemetry can remain impaired until external DNS works on every affected node.
> - **Effort and downtime:** read-only evidence and configuration capture usually take 10 to 20 minutes per node. A supported deployment-time node correction and revalidation usually take 15 to 30 minutes per node, with no reboot or cluster drain. An upstream forwarder or firewall change follows the owning team's change process.
> - **Before you change anything:** do not guess DNS server IP addresses. Get the cluster's intended DNS servers from your network or DNS administrator first.

> **Customer-facing framing:** This is an external-DNS path issue that blocks
> readiness, not a request to rebuild the cluster. Microsoft support can help identify
> the failing node and DNS server, interpret the evidence, and verify the fresh result.
> The customer's network or DNS owner applies the node-side or upstream change, with
> the change scope and rollback recorded before action.

## Overview

This Environment Validator check confirms that each Azure Local node can resolve an
external (public) DNS name. On every node, for each DNS server configured on every
network adapter that is up, the check resolves the public name `microsoft.com` and
expects at least one A record back. If any configured DNS server returns no records
(or no DNS server is configured at all), the check fails for that node.

- **Severity:** Critical. When this check fails on a node and no proxy is in use,
  the validator stops the remaining connectivity tests for that node, so a single
  DNS failure can also hide other connectivity findings.
- **When it runs:** pre-deployment readiness, deployment, add-node, and the
  pre-update health check. In practice you will most often see it block a pending
  Azure Local update.
- **Product movement and validation fidelity:** the legacy
  `AzStackHci_Connectivity_Test_Dns` result is not emitted by the 2610 module tested
  for this article. On current connected-Azure builds the equivalent external-DNS
  test runs in the dedicated DNS validator and is reported under one of two names,
  `AzStackHci_DNS_ExternalDnsResolution` or
  `AzStackHci_DNS_Test_External_Hostname_Resolution`. The successor uses the same
  configured-DNS-server A-record test and the same remediation direction, but resolves
  the Azure cloud management endpoint, such as `management.azure.com`, retries up to
  three times, and aggregates per-node bullets. The live validation for this legacy
  guide is therefore **L2 successor equivalence**, not proof that the legacy result
  name fired on 2610.

**Who owns this fix.** The customer's network or DNS administrator applies the
node-side or upstream change. Microsoft support can guide the evidence collection,
help distinguish DNS reachability from external resolution, and verify the fresh
result. The OEM is involved only if a factory or recovery image pinned stale DNS.

**Where a node's DNS comes from.** A node's DNS servers are set at deployment time from
the deployment configuration's management network settings and applied to the management
network adapter; they are not baked into the OEM factory image. If you are an OEM or
field engineer checking your own imaging process, confirm the image does not pin DNS
servers and leaves them to be set by deployment, so each cluster picks up the customer's
intended DNS rather than a stale value carried over from imaging.

## Quick fix (start here)

First decide whether the node is being deployed or added, or is already a deployed
cluster member:

- **Deploying or adding a node:** if the node is not yet a deployed cluster member,
  you may correct its management-adapter DNS client with the documented values.
- **Already-deployed cluster:** do **not** re-point the node's DNS client. Azure Local
  does not support changing DNS server settings post-deployment. Fix the currently
  configured DNS server upstream instead, usually by adding an external-resolving
  forwarder or correcting the firewall path, then use
  [Verification: prove the failure cleared](#6-verification-prove-the-failure-cleared).

> **Do not guess DNS server IP addresses.** If you do not have the deployment's
> intended DNS servers, stop and involve the network or DNS owner. Changing the
> management adapter can also interrupt the current remote session, so use local
> console or out-of-band access, or confirm an alternate management path, before
> applying a deployment-time node-side change.

If the failure is already known, run these two read-only checks first. They list only
DNS servers on adapters that are currently up, matching the validator's scope, and
then test each server separately against both the legacy and successor external names:

```powershell
$upAliases = @(Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object Status -eq 'Up' |
    Select-Object -ExpandProperty Name)
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
```

```powershell
$externalNames = @('microsoft.com', 'management.azure.com')
$dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    ForEach-Object { $_.ServerAddresses } |
    Sort-Object -Unique)
foreach ($dns in $dnsServers) {
    foreach ($name in $externalNames) {
        try {
            $records = @(Resolve-DnsName -Name $name -Server $dns -Type A -DnsOnly -ErrorAction Stop)
            [pscustomobject]@{
                DnsServer = $dns
                Name      = $name
                Status    = if ($records.Count -gt 0) { 'PASS: A records returned' } else { 'FAILURE: no A records' }
                Records   = ($records | ForEach-Object IPAddress) -join ', '
            }
        }
        catch {
            [pscustomobject]@{
                DnsServer = $dns
                Name      = $name
                Status    = 'FAILURE: query failed or server unreachable'
                Records   = $_.Exception.Message
            }
        }
    }
}
```

Expected healthy output is `PASS: A records returned` with one or more addresses for
the name used by the validator on that build. `FAILURE: no A records` means the server
answered but returned no A records. `FAILURE: query failed or server unreachable`
preserves the actual error instead of mislabeling every failure as a zero-record answer.

An upstream DNS-server or forwarder change is a **[MEDIUM RISK]** shared
infrastructure change, not a beginner action. It belongs with the network or DNS owner,
who must record the prior setting and rollback before changing a server used by other
clients.

## Requirements

- Administrative (local administrator) access to each Azure Local node, or a remote
  PowerShell session to the nodes.
- The list of DNS servers the cluster is supposed to use, from the deployment's
  network configuration.
- Access to, or coordination with, whoever administers those DNS servers, in case an
  upstream server needs a forwarder or an external-resolution fix.
- Console or out-of-band access, or a confirmed alternate management path, before
  changing the management adapter on a node.
- No maintenance window is required for a supported deployment-time node DNS-client
  change. It applies immediately and does not need a reboot or a cluster drain.
  Upstream DNS changes follow the owning team's change process.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

The same failure surfaces in several places depending on how it was noticed. Pick the
entry point that matches; they all converge on the same `Detail` string.

#### Option A: Health-check result files on the cluster shared volume (recommended)

Every pre-update health check writes one JSON result file to the cluster's
infrastructure share. Read the newest one and filter to this check:

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
    Write-Warning "No HealthCheck result file found on this node (the folder is missing or no health check has run yet). Use Option B, C, or D, or run this on a different node."
}
else {
    Write-Host "Reading: $($latest.FullName)"
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object {
            $_.Name -eq 'AzStackHci_Connectivity_Test_Dns' -or
            $_.Name -eq 'AzStackHci_DNS_ExternalDnsResolution' -or
            $_.Name -eq 'AzStackHci_DNS_Test_External_Hostname_Resolution'
        } |
        Where-Object { $_.AdditionalData.Status -eq 'FAILURE' } |
        Select-Object Name, Severity,
            @{ n = 'Status';      e = { $_.AdditionalData.Status } },
            @{ n = 'Source';      e = { $_.AdditionalData.Source } },
            @{ n = 'Detail';      e = { $_.AdditionalData.Detail } },
            Remediation
}
```

Each row is one currently-failing DNS server on one node. The `Detail` column is the
precise error string; the `Remediation` column points at the public
[Azure Local network requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements)
documentation. Keep all three result-name filters because the legacy connectivity
result can coexist in fleet history with either current dedicated-DNS result. The
human-readable status and message are under `AdditionalData.Status` and
`AdditionalData.Detail`; the top-level `Status` is a numeric enum and the top-level
`Description` is generic.

#### Option B: `Get-SolutionUpdate` (is an update being blocked?)

If the failure was noticed because a pending update will not start, this is the
fastest confirmation:

```powershell
Get-SolutionUpdate |
    Select-Object DisplayName, Version, State, HealthCheckResult, HealthCheckDate |
    Format-Table -AutoSize
```

`HealthCheckResult = Failure` with a recent `HealthCheckDate` means the pre-update
validators failed. Use Option A to see which validator caused it.

#### Option C: Windows event log (when the result files are missing)

The same data is written to the Windows event log on each node. In Event Viewer, open
`Applications and Services Logs` then `AzStackHciEnvironmentChecker` and filter for
Event ID 17205, or from PowerShell:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath "*[System[(EventID=17205)]]" -MaxEvents 2000 |
    ForEach-Object {
        try { $r = $_.Message | ConvertFrom-Json } catch { return }
        if ($r.Name -eq 'AzStackHci_Connectivity_Test_Dns' -or
            $r.Name -eq 'AzStackHci_DNS_ExternalDnsResolution' -or
            $r.Name -eq 'AzStackHci_DNS_Test_External_Hostname_Resolution') {
            [pscustomobject]@{
                TimeCreated = $_.TimeCreated
                Name        = $r.Name
                Status      = $r.AdditionalData.Status
                Source      = $r.AdditionalData.Source
                Detail      = $r.AdditionalData.Detail
                Remediation = $r.Remediation
            }
        }
    } |
    Where-Object { $_.Status -eq 'FAILURE' } |
    Sort-Object TimeCreated -Descending |
    Select-Object -First 20
```

#### Option D: Azure portal

In the Azure portal, open the Azure Local cluster, then the **Updates** tab. When a
pre-update health check fails, the portal shows a banner naming the failing
validators. `Test DNS` (the display name of this check) appearing there is the same
failure.

#### Option E: Environment Checker component files

The Environment Checker also writes its own on-disk evidence on the node where it
runs. Collect the current files from:

- `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`
- `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentReport.json`
- `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentReport.xml`

Use these component files with the health-check JSON, Event ID 17205, and UTC
timestamps when escalating a result that contradicts direct DNS testing.

#### Where this does not appear

- **Cluster logs (`Get-ClusterLog`)**: this validator result does not appear there;
  DNS-client resolution is not a failover-clustering event.
- **Failover Cluster Manager**: this validator result does not appear there because
  it is not a clustered role, resource, or node state.
- **Windows Admin Center on a standalone host**: this specific validator result does
  not appear there; use node PowerShell, Event ID 17205, or the Environment Checker
  component files.
- **Windows Admin Center in the Azure portal**: this specific validator result does
  not appear there; use the Azure Local cluster's **Updates** blade instead.

### 2. What it looks like: example failure signatures

The check emits one of these `Detail` strings per failing DNS server (the IP address,
the node name, and the record count vary):

```
Queried dns server 10.0.0.10 for microsoft.com on AzL-Node-01. Result returned 0 A records. Expected at least 1.
```

```
No DNS server configured
```

The first signature means the node reached the DNS server at that IP, but the server
returned no A records for the external name `microsoft.com`. The second means the
node's up adapters have no DNS server configured at all.

A passing node, for contrast, reports a count of one or more and lists the resolved
addresses, for example `Result returned 1 A records: <address>, expected at least 1.`

> If a proxy is configured on a node (WinHTTP proxy), the check is skipped on that
> node and reported as success, with a `Detail` of
> `Skipping DNS resolution test on <node> because a proxy is configured.` That is
> expected behavior, not a failure.

On builds that use the dedicated DNS validator (see "Product movement and validation
fidelity" in the overview),
the same failure reads slightly differently: it resolves `management.azure.com`,
retries up to three times, and lists each failing node as its own bullet, for example:

```
- AzL-Node-01
  - Queried dns server 10.0.0.10 for management.azure.com on AzL-Node-01 (Attempt: 3/3). Result returned 0 A records. Expected at least 1. Error:
```

The meaning is the same external-A-record failure as the first signature above. Only
the queried hostname, the `(Attempt: n/3)` suffix, and the per-node bullet layout
differ. If the line includes a non-empty `Error:` value, retain it because it may
identify an unreachable server or another query failure rather than a valid zero-record
response.

### 3. Identify the affected nodes

Run across all nodes to see exactly which ones are failing and against which DNS
server:

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

    $names = 'AzStackHci_Connectivity_Test_Dns',
        'AzStackHci_DNS_ExternalDnsResolution',
        'AzStackHci_DNS_Test_External_Hostname_Resolution'
    $escapedNode = [regex]::Escape($node)
    $localResults = @(
        Get-WinEvent -LogName AzStackHciEnvironmentChecker `
            -FilterXPath "*[System[(EventID=17205)]]" `
            -MaxEvents 2000 `
            -ErrorAction SilentlyContinue |
            ForEach-Object {
                $event = $_
                try { $result = $event.Message | ConvertFrom-Json } catch { return }
                if ($result.Name -notin $names) { return }

                $source = [string]$result.AdditionalData.Source
                $target = [string]$result.TargetResourceName
                $detail = [string]$result.AdditionalData.Detail
                $belongsToNode = (
                    $source -eq $node -or
                    $target -eq $node -or
                    $detail -match "(?i)\b$escapedNode\b"
                )
                if (-not $belongsToNode) { return }

                [pscustomobject]@{
                    TimeCreated = $event.TimeCreated
                    ResultName  = $result.Name
                    Status      = [string]$result.AdditionalData.Status
                    Source      = $source
                    Detail      = $detail
                }
            }
    )
    $latest = @($localResults | Sort-Object TimeCreated -Descending | Select-Object -First 1)
    if ($latest) {
        [pscustomobject]@{
            Node              = $node
            UpAdapters        = $upAliases -join ', '
            CurrentDnsServers = $currentText
            ResultName        = $latest[0].ResultName
            Status            = $latest[0].Status
            Source            = $latest[0].Source
            Detail            = $latest[0].Detail
        }
    }
    else {
        [pscustomobject]@{
            Node              = $node
            UpAdapters        = $upAliases -join ', '
            CurrentDnsServers = $currentText
            ResultName        = ''
            Status            = 'NO DATA'
            Source            = ''
            Detail            = 'No node-attributed Event ID 17205 DNS result was found. Run the direct DNS probe; do not assume PASS.'
        }
    }
} | Sort-Object Node | Format-Table -AutoSize
```

This query reads each node's local event channel and requires the payload's source,
target, or detail to identify that node. It does not relabel the cluster-wide shared
health-check file as a per-node result. Treat `NO DATA` as unknown and run the direct
DNS probe; do not treat absence as a pass.

Every node now reports its up adapters, current DNS servers, result name, and one of
three states: a failing `Detail`, `PASS`, or `NO DATA`. Confirm a `NO DATA` node with
Option C rather than assuming it passed.

### 4. Consequences if you do not fix this

This check is Critical. When it fails on a node and no proxy is configured, the
validator stops the remaining connectivity tests for that node, so one DNS failure
can mask other connectivity problems and fails the pre-update health check overall.
Concretely:

- A pending Azure Local update or a deployment that runs this readiness check will not
  proceed until external DNS resolution succeeds on every node.
- External name resolution is required for the cluster to reach Azure for Arc,
  updates, billing, and telemetry. The cluster keeps running local workloads, but its
  cloud-managed lifecycle is impaired until external DNS works.

### 5. Remediation

The legacy check fails when a DNS server configured on a node cannot resolve
`microsoft.com`; the current successor uses the Azure cloud management endpoint, such
as `management.azure.com`. The supported fix depends on deployment state:

- On a node being deployed or added, correct the management-adapter DNS client with
  the intended deployment values.
- On an already-deployed cluster, do not re-point the node DNS client. Correct the
  currently configured DNS server upstream.

**Most common fix (start here).** The usual cause is a node pointed at a DNS server that
cannot resolve external names. For a deployment-time node, set the intended DNS servers.
For a deployed cluster, add an external-resolving forwarder on the configured server or
correct the firewall path.

_New to any DNS term used below (A record, forwarder, split-horizon, WinHTTP proxy)? See
the [Glossary](#glossary) at the end of this guide._

1. List the DNS servers currently configured on up adapters:

   ```powershell
   $upAliases = @(Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -ExpandProperty Name)
   Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
       Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
   ```

2. Confirm these are the DNS servers the cluster is supposed to use, comparing against
   your documented management DNS servers. If this is an already-deployed cluster,
   record the configured values and continue to Step 4. Do not change the node.

   If the node is being deployed or added and has no DNS server on its management
   adapter, or the configured servers are wrong, identify the management adapter by its
   documented management IP:

   ```powershell
   $ManagementIp = '<node-management-ipv4>'
   $mgmt = @(Get-NetIPConfiguration | Where-Object {
       $_.NetAdapter.Status -eq 'Up' -and ($_.IPv4Address.IPAddress -contains $ManagementIp)
   })
   if ($mgmt.Count -ne 1) {
       throw "Expected exactly one up adapter owning $ManagementIp; found $($mgmt.Count). Stop and confirm the management IP."
   }
   $mgmtAlias = $mgmt[0].InterfaceAlias
   "Management adapter: $mgmtAlias"
   ```

   The correct `<dns1>`,`<dns2>` are your deployment's documented management DNS servers
   (the same ones the healthy nodes resolve against). Capture the exact original values
   before changing anything:

   ```powershell
   $dnsSnapshot = @(Get-DnsClientServerAddress -InterfaceAlias $mgmtAlias -AddressFamily IPv4 |
       Select-Object InterfaceAlias, @{ n = 'ServerAddresses'; e = { @($_.ServerAddresses) } })
   $dnsSnapshot | ConvertTo-Json -Depth 3
   ```

   Keep `$dnsSnapshot` in the current session or save its JSON in the case notes. Then set
   the intended values:

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias $mgmtAlias -ServerAddresses '<dns1>','<dns2>'
   ```

   If remote access is affected or verification fails, restore the captured values:

   ```powershell
   foreach ($saved in $dnsSnapshot) {
       Set-DnsClientServerAddress -InterfaceAlias $saved.InterfaceAlias -ServerAddresses $saved.ServerAddresses
   }
   ```

3. Use the error-preserving read-only loop in [Quick fix](#quick-fix-start-here).
   Expected healthy output is `PASS: A records returned`. Treat `FAILURE: no A
   records` and `FAILURE: query failed or server unreachable` as different lanes.

4. Fix the failing DNS server, choosing the option that matches the environment:

   - If this is a deployment-time node and the configured server is wrong or stale,
     set the intended deployment DNS values in Step 2.
   - If the configured server is correct but internal-only, add a forwarder on that
     DNS server to a resolver that can answer external queries, or otherwise enable
     external resolution on it. This change is made on the DNS server, not on the
     Azure Local node, so coordinate with whoever owns that server.
   - If the server resolves internal names but returns nothing for the external name,
     an internal-only or split-horizon DNS zone may be shadowing external resolution;
     add a forwarder or otherwise enable external resolution as above.
   - Confirm that DNS traffic on port 53 from the nodes to the DNS servers is not
     blocked by a firewall.

5. If the cluster intentionally has no direct outbound name resolution and uses a
   proxy for all outbound traffic, configure the WinHTTP proxy on each node. When a
   proxy is present, this check self-skips and reports success. Only do this if a
   proxy is genuinely part of the design.

A deployment-time node DNS-client correction is a [LOW RISK] change when the exact
original values were captured and alternate access is available. Changing an upstream
DNS server is a [MEDIUM RISK] change because it can affect other systems that use it,
so coordinate with its owner. No node drain or reboot is required.

### 6. Verification: prove the failure cleared

Re-run the pre-update health check. This writes a fresh result file to the cluster
shared volume and fresh event-log entries on every node:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

This typically takes several minutes depending on cluster size. When it finishes,
require `HealthState` to be `Success`, then re-run any option from Step 1. The check
should return no failing rows. Also confirm the underlying resolution directly on each
node, using the name associated with the result that failed:

```powershell
$externalNames = @('microsoft.com', 'management.azure.com')
foreach ($name in $externalNames) {
    Resolve-DnsName -Name $name -Type A -DnsOnly -ErrorAction Stop |
        Select-Object Name, Type, IPAddress
}
```

A result containing one or more A records means external DNS resolution is working for
that name. If Step 1 still shows failures, re-read the new `Detail` text. The failure
may have moved to a different DNS server or a different node that needs the same fix.

> **Note:** the Azure portal readiness view and the cluster-wide `HealthCheckResult`
> file refresh only when a full health check or
> `Invoke-SolutionUpdatePrecheck -SystemHealth` runs, not on a targeted per-node
> re-test. The portal can therefore lag a just-applied fix until the next precheck or
> the periodic health check. Use direct on-node resolution and the fresh precheck
> timestamp together rather than treating a stale portal row as current.

## Prevent the issue before the next deployment

For each deployment environment or site, validate the intended DNS servers before
deploying nodes:

```powershell
$IntendedDnsServers = @('<dns1>', '<dns2>')
$ExternalNames = @('microsoft.com', 'management.azure.com')
foreach ($dns in $IntendedDnsServers) {
    foreach ($name in $ExternalNames) {
        try {
            $records = @(Resolve-DnsName -Name $name -Server $dns -Type A -DnsOnly -ErrorAction Stop)
            [pscustomobject]@{
                DnsServer = $dns
                Name      = $name
                Status    = if ($records.Count -gt 0) { 'PASS' } else { 'FAILURE: no A records' }
                Count     = $records.Count
            }
        }
        catch {
            [pscustomobject]@{
                DnsServer = $dns
                Name      = $name
                Status    = 'FAILURE: query failed or server unreachable'
                Count     = 0
            }
        }
    }
}
```

Do not begin deployment until the intended server list is approved and each server
returns A records for the endpoint used by the target build. Re-run the same check
after deployment on every node so site-wide DNS readiness is verified rather than
inferred from one cluster or one server.

## OEM imaging validation

On a freshly imaged host, before Azure Local deployment applies the customer's
management configuration, list any statically pinned DNS servers:

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object ServerAddresses |
    Select-Object InterfaceAlias, AddressFamily,
        @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
```

Unexpected static DNS values in a reusable image must be removed through the image
owner's supported process before the image is released. A clean pre-deployment image
check does not prove the post-deployment configuration; the deployment values and
fresh validator result remain authoritative.

## Escalation boundary

Escalate to Microsoft support or the Environment Validator product group only after
all of the following are captured:

- Every DNS server configured on every up adapter returns one or more A records for
  the exact external name in the fresh validator `Detail`.
- A fresh `Invoke-SolutionUpdatePrecheck -SystemHealth` still records the DNS result
  as `FAILURE`.
- The newest health-check JSON, Event ID 17205 payload, Environment Checker component
  files, direct per-server test output, node name, module version, solution version,
  and UTC timestamps are collected.

This boundary distinguishes a validator inconsistency from a customer DNS-path failure.
Do not escalate a stale portal row or a suppressed `Resolve-DnsName` error as a product
defect.

## Glossary

Plain-language definitions of the DNS terms used in this guide. Experienced readers can
skip this section; it is here so the steps above stay short.

- **A record:** the basic DNS record that maps a name (such as `microsoft.com`) to an
  IPv4 address. This check passes only when a configured DNS server returns at least one
  A record for the external name.
- **DNS server / resolver:** the server a node asks to turn a name into an address. Each
  node lists one or more on its network adapters; this check tests each one.
- **Forwarder:** a setting on a DNS server that hands off queries it cannot answer itself
  (such as external or public names) to another resolver that can. An internal-only DNS
  server usually needs a forwarder to resolve external names.
- **Conditional forwarder:** a forwarder that applies only to a specific domain, so a
  server can send just some queries (for example external names) to a particular
  resolver.
- **Split-horizon (split-brain) DNS:** a setup where the same DNS name resolves
  differently for internal versus external clients. An internal-only zone can shadow an
  external name, so the server answers internal lookups but returns nothing for the
  public name this check asks for.
- **WinHTTP proxy:** a system-level outbound proxy configured on a node. When one is set,
  the node routes outbound traffic through it, and this DNS check self-skips on that node
  and reports success.

::: audience-css

# Source Articles

- Azure Local Environment Validator product source and result semantics reviewed during the September 17, 2026 TSG Forge validation.
- The prior live-validation evidence, command results, safety gates, and fidelity classification remain unchanged by this structural retrofit.

:::
