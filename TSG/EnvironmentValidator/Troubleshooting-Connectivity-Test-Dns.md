# AzStackHci_Connectivity_Test_Dns

> **At a glance**
> - **Owner:** the customer's network or DNS administrator. This is not a Microsoft software defect and not an OEM hardware or firmware issue.
> - **Impact:** Critical. It blocks Azure Local deployment and updates until external DNS resolution works on every node.
> - **Effort and downtime:** small. A per-node DNS change applies immediately, with no reboot, no cluster drain, and no impact to running VMs or live migration.
> - **Before you change anything:** do not guess DNS server IP addresses. Get the cluster's intended DNS servers from your network or DNS administrator first.

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
- **Newer builds:** on recent Azure Local builds this external-DNS test was moved
  into a dedicated DNS validator and is reported under one of two names,
  `AzStackHci_DNS_ExternalDnsResolution` or
  `AzStackHci_DNS_Test_External_Hostname_Resolution` (both are in use across current
  builds, so search the health-check results for either). The dedicated validator
  resolves `management.azure.com` rather than `microsoft.com` and retries before it
  fails, so its `Detail` adds an `(Attempt: n/3)` suffix and lists each failing node
  as its own bullet. The cause and the fix in this guide are the same; only the
  validator name and the queried hostname differ.

**Who owns this fix.** This is a customer network and DNS configuration check. The
owner is the customer's network or DNS administrator. It is not a Microsoft software
defect, and it is not an OEM hardware or firmware issue, so it does not require a
hardware vendor or a Microsoft product fix. A Microsoft support engineer can guide
the customer through it, but the change itself is made in the customer's DNS
infrastructure or in a node's network configuration.

## Requirements

- Administrative (local administrator) access to each Azure Local node, or a remote
  PowerShell session to the nodes.
- The list of DNS servers the cluster is supposed to use, from the deployment's
  network configuration.
- Access to, or coordination with, whoever administers those DNS servers, in case an
  upstream server needs a forwarder or an external-resolution fix.
- No maintenance window is required. A node DNS-client change applies immediately and
  does not need a reboot or a cluster drain.

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
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not $latest) {
    Write-Warning "No HealthCheck result file found on this node (the folder is missing or no health check has run yet). Use Option B, C, or D, or run this on a different node."
}
else {
    Write-Host "Reading: $($latest.FullName)"
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -eq 'AzStackHci_Connectivity_Test_Dns' -and $_.Status -ne 0 -and $_.Status -ne 'SUCCESS' } |
        Select-Object Severity,
            @{ n = 'Source';      e = { $_.AdditionalData.Source } },
            @{ n = 'Detail';      e = { $_.AdditionalData.Detail } },
            Remediation
}
```

Each row is one currently-failing DNS server on one node. The `Detail` column is the
precise error string; the `Remediation` column points at the public
[Azure Local network requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements)
documentation.

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
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath "*[System[(EventID=17205)]]" |
    ForEach-Object {
        try { $r = $_.Message | ConvertFrom-Json } catch { return }
        if ($r.Name -eq 'AzStackHci_Connectivity_Test_Dns' -and $r.Status -ne 0 -and $r.Status -ne 'SUCCESS') {
            [pscustomobject]@{
                TimeCreated = $_.TimeCreated
                Source      = $r.AdditionalData.Source
                Detail      = $r.AdditionalData.Detail
            }
        }
    } | Sort-Object TimeCreated -Descending | Select-Object -First 20
```

#### Option D: Azure portal

In the Azure portal, open the Azure Local cluster, then the **Updates** tab. When a
pre-update health check fails, the portal shows a banner naming the failing
validators. `Test DNS` (the display name of this check) appearing there is the same
failure.

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

On builds that use the dedicated DNS validator (see "Newer builds" in the overview),
the same failure reads slightly differently: it resolves `management.azure.com`,
retries up to three times, and lists each failing node as its own bullet, for example:

```
- AzL-Node-01
  - Queried dns server 10.0.0.10 for management.azure.com on AzL-Node-01 (Attempt: 3/3). Result returned 0 A records. Expected at least 1. Error:
```

The meaning is the same as the first signature above (the server was reached but
returned no A records); only the queried hostname, the `(Attempt: n/3)` suffix, and
the per-node bullet layout differ.

### 3. Identify the affected nodes

Run across all nodes to see exactly which ones are failing and against which DNS
server:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    $base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
    if (-not (Test-Path $base)) {
        # Same fallback as Step 1 Option A: walk all ClusterStorage volumes.
        $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    $latest = $null
    if ($base) {
        $latest = Get-ChildItem $base -Filter 'HealthCheckResult.*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $latest) {
        # Emit an explicit NO DATA row so this node is never silently treated as passing.
        return [pscustomobject]@{ Detail = 'NO DATA: no HealthCheck result file on this node (use Option C, the event log)' }
    }
    $failing = Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -eq 'AzStackHci_Connectivity_Test_Dns' -and $_.Status -ne 0 -and $_.Status -ne 'SUCCESS' } |
        Select-Object @{ n = 'Detail'; e = { $_.AdditionalData.Detail } }
    if ($failing) { $failing }
    else { [pscustomobject]@{ Detail = 'PASS: no failing DNS result in the latest health check' } }
} | Sort-Object PSComputerName | Select-Object PSComputerName, Detail
```

Every node now reports one of three things: a failing `Detail` (the node is failing,
fix it), `PASS` (the check passed on that node), or `NO DATA` (the result could not be
read on that node, so confirm it with Option C rather than assuming it passed).

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

The check fails when a DNS server configured on a node cannot resolve the external
name `microsoft.com`. The fix is a customer-side DNS change, either on the node's
DNS-client configuration or on the upstream DNS server. Work through this on each node
identified in Step 3.

1. List the DNS servers currently configured on the node:

   ```powershell
   Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object ServerAddresses |
       Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
   ```

2. Confirm these are the DNS servers the cluster is supposed to use, comparing against
   your documented management DNS servers. If the node has no DNS server on its
   management adapter (the `No DNS server configured` signature), or the configured
   servers are wrong, set the correct ones (per node, applies immediately, no reboot):

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -ServerAddresses '<dns1>','<dns2>'
   ```

   Record the original values first so the change can be rolled back.

3. Test each configured DNS server the same way the validator does, resolving the
   external name directly against that server:

   ```powershell
   foreach ($dns in ((Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique)) {
       $count = (Resolve-DnsName -Name microsoft.com -Server $dns -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue).Count
       '{0}: {1} A record(s)' -f $dns, ([int]$count)
   }
   ```

   A server reporting `0 A record(s)` is the failing one: the node reaches it, but it
   cannot resolve external names.

4. Fix the failing DNS server, choosing the option that matches the environment:

   - If the configured server is wrong or stale, re-point the node at a DNS server
     that can resolve external names (Step 2).
   - If the configured server is correct but internal-only, add a forwarder on that
     DNS server to a resolver that can answer external queries, or otherwise enable
     external resolution on it. This change is made on the DNS server, not on the
     Azure Local node, so coordinate with whoever owns that server.
   - Confirm that DNS traffic on port 53 from the nodes to the DNS servers is not
     blocked by a firewall.

5. If the cluster intentionally has no direct outbound name resolution and uses a
   proxy for all outbound traffic, configure the WinHTTP proxy on each node. When a
   proxy is present, this check self-skips and reports success. Only do this if a
   proxy is genuinely part of the design.

**Risk:** LOW for re-pointing a node's DNS client, which is per-node, immediate, and
reversible by restoring the previous servers. MEDIUM for changes on an upstream DNS
server, which can affect other systems that use it, so coordinate with its owner. No
node drain or reboot is required for DNS-client changes.

### 6. Verification: prove the failure cleared

Re-run the pre-update health check. This writes a fresh result file to the cluster
shared volume and fresh event-log entries on every node:

```powershell
Invoke-SolutionUpdatePrecheck
```

This typically takes several minutes depending on cluster size. When it finishes,
re-run any option from Step 1. The check should return no failing rows. You can also
confirm the underlying resolution directly on each node:

```powershell
Resolve-DnsName -Name microsoft.com -Type A
```

A result containing one or more A records means external DNS resolution is working. If
Step 1 still shows failures, re-read the new `Detail` text: the failure may have moved
to a different DNS server or a different node that needs the same fix.
