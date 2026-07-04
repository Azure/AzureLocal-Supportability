# AzStackHci_DNS_ExternalDnsResolution

> **At a glance**
> - **Owner:** the customer's network or DNS administrator. This is not a Microsoft software defect and not an OEM hardware or firmware issue.
> - **Impact:** Critical. It blocks Azure Local deployment and updates until external DNS resolution works on every node.
> - **Effort and downtime:** small. A per-node DNS change applies immediately, with no reboot, no cluster drain, and no impact to running VMs or live migration.
> - **Typical time to resolve:** about 15 to 30 minutes per affected node for a DNS-client fix once you have the correct DNS server addresses. Allow longer if the fix is an upstream DNS server change (a forwarder or firewall rule) that must be coordinated with whoever owns that server.
> - **Before you change anything:** do not guess DNS server IP addresses. Get the cluster's intended DNS servers from your network or DNS administrator first.

## Overview

This Environment Validator check confirms that each Azure Local node can resolve an
external (public) DNS name. On every node, for each DNS server configured on every
network adapter that is up, the dedicated DNS validator resolves the public name
`management.azure.com` and expects at least one A record back. It retries up to three
times before it fails, and it lists each failing node as its own bullet. If any
configured DNS server returns no records (or no DNS server is configured at all), the
check fails for that node.

- **Severity:** Critical. When this check fails on a node and no proxy is in use, the
  validator stops the remaining connectivity tests for that node, so a single DNS
  failure can also hide other connectivity findings.
- **When it runs:** pre-deployment readiness, deployment, add-node, and the pre-update
  health check. In practice you will most often see it block a pending Azure Local
  update.
- **Result names.** This is the dedicated DNS validator that resolves
  `management.azure.com`. On current builds the same external-DNS test is reported under
  one of two result names, so search the health-check results for either:
  `AzStackHci_DNS_ExternalDnsResolution` or
  `AzStackHci_DNS_Test_External_Hostname_Resolution`.
- **Same check, older name.** This validator is the successor of the legacy
  connectivity test `AzStackHci_Connectivity_Test_Dns`, which resolved `microsoft.com`
  instead of `management.azure.com` and reported a single flat `Detail` line rather than
  per-node bullets. The cause and the fix are identical; only the validator name and the
  queried hostname differ.

**Who owns this fix.** This is a customer network and DNS configuration check. The owner
is the customer's network or DNS administrator. It is not a Microsoft software defect,
and it is not an OEM hardware or firmware issue, so it does not require a hardware vendor
or a Microsoft product fix. A Microsoft support engineer can guide the customer through
it, but the change itself is made in the customer's DNS infrastructure or in a node's
network configuration.

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
> [Troubleshooting AzStackHci_Connectivity_Test_Dns](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/EnvironmentValidator/Troubleshooting-Connectivity-Test-Dns.md).

## Requirements

- Administrative (local administrator) access to each Azure Local node, or a remote
  PowerShell session to the nodes.
- The list of DNS servers the cluster is supposed to use, from the deployment's network
  configuration.
- Access to, or coordination with, whoever administers those DNS servers, in case an
  upstream server needs a forwarder or an external-resolution fix.
- No maintenance window is required. A node DNS-client change applies immediately and
  does not need a reboot or a cluster drain.

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
        Select-Object Severity,
            @{ n = 'Status'; e = { $_.AdditionalData.Status } },
            @{ n = 'Detail'; e = { $_.AdditionalData.Detail } },
            Remediation
}
```

Each row is one currently-failing DNS server on one node. On the Windows event log the
same record is written to `AzStackHciEnvironmentChecker` as Event ID 17205; filter its
`Name` the same way, matching BOTH result names
(`$_.Name -like '*ExternalDnsResolution*' -or $_.Name -like '*Test_External_Hostname_Resolution*'`),
and read `AdditionalData.Detail`. In the Azure portal, open the Azure Local cluster then
the **Updates** tab; a failing pre-update health check names the failing validator there.

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

Run across all cluster nodes so you see exactly which ones are failing and against which
DNS server, matching both result names:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
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
        return [pscustomobject]@{ Detail = 'NO DATA: no HealthCheck result file on this node (read the event log instead)' }
    }
    $failing = Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { ($_.Name -like '*ExternalDnsResolution*' -or $_.Name -like '*Test_External_Hostname_Resolution*') -and $_.AdditionalData.Status -eq 'FAILURE' } |
        Select-Object @{ n = 'Detail'; e = { $_.AdditionalData.Detail } }
    if ($failing) { $failing } else { [pscustomobject]@{ Detail = 'PASS: no failing DNS result in the latest health check' } }
} | Sort-Object PSComputerName | Select-Object PSComputerName, Detail
```

Every node reports one of three things: a failing `Detail` (fix it), `PASS` (the check
passed there), or `NO DATA` (the result could not be read, so confirm it with the event
log rather than assuming it passed).

## Consequences if you do not fix this

This check is Critical. When it fails on a node and no proxy is configured, the validator
stops the remaining connectivity tests for that node, so one DNS failure can mask other
connectivity problems and fails the pre-update health check overall. A pending Azure
Local update or a deployment that runs this readiness check will not proceed until
external DNS resolution succeeds on every node, and the cluster's cloud-managed lifecycle
(Arc, updates, billing, telemetry) is impaired until external DNS works, even though
local workloads keep running.

## Remediation

The check fails when a DNS server configured on a node cannot resolve the external name
`management.azure.com`. The fix is a customer-side DNS change, either on the node's
DNS-client configuration or on the upstream DNS server. The essential steps are below,
including a per-node fan-out to find every affected node and an option-by-option decision
tree for the fix.

**Most common fix (start here).** The usual cause is a node pointed at a DNS server that
cannot resolve external names. Re-point that node's management adapter at a DNS server
that can (step 3, first option), or add an external-resolving forwarder on the current
server (step 3, second option). The numbered steps confirm which applies; most failures
are resolved by one of those two.

_New to any DNS term used here (A record, forwarder, split-horizon, WinHTTP proxy)? See
the [Glossary](#glossary) at the end of this guide._

1. List the DNS servers currently configured on the affected node:

   ```powershell
   Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object ServerAddresses |
       Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
   ```

2. Test each configured DNS server the way the validator does, resolving
   `management.azure.com` directly against that server:

   ```powershell
   foreach ($dns in ((Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique)) {
       $count = (Resolve-DnsName -Name management.azure.com -Server $dns -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue).Count
       '{0}: {1} A record(s)' -f $dns, ([int]$count)
   }
   ```

   A server reporting `0 A record(s)` is the failing one: the node reaches it, but it
   cannot resolve the external name.

3. Fix the failing DNS server, choosing the option that matches the environment:

   - If the configured server is wrong or stale, re-point the node's management adapter
     at a DNS server that can resolve external names. First identify the management
     adapter (the up adapter whose IPv4 address is the node's management IP), so the
     `<ManagementAdapter>` placeholder is concrete:

     ```powershell
     Get-NetIPConfiguration | Where-Object { $_.IPv4Address } |
         Select-Object InterfaceAlias, @{ n = 'IPv4'; e = { $_.IPv4Address.IPAddress -join ', ' } }
     ```

     Record the original DNS values first so the change can be rolled back, then set the
     correct servers on that adapter (the correct `<dns1>`,`<dns2>` are your deployment's
     documented management DNS servers; per node, applies immediately, no reboot):

     ```powershell
     Set-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -ServerAddresses '<dns1>','<dns2>'
     ```

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

Re-pointing a node's DNS client is a [LOW RISK] change: it is per-node, immediate, and
reversible by restoring the previous servers. Changing an upstream DNS server is a
[MEDIUM RISK] change, because it can affect other systems that use it, so coordinate with
its owner. No node drain or reboot is required for DNS-client changes.

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
directly on each node:

```powershell
Resolve-DnsName -Name management.azure.com -Type A
```

A result containing one or more A records means external DNS resolution is working. If
failures remain, re-read the new `Detail` text: the failure may have moved to a different
DNS server or a different node that needs the same fix.

> **Note:** the Azure portal readiness view and the cluster-wide `HealthCheckResult` file
> refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a
> targeted per-node re-test. The portal can therefore lag a just-applied fix until the
> next precheck or the periodic (roughly daily) health check, so confirm the fix on-node
> with `Resolve-DnsName` rather than waiting on the portal.

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
